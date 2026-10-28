// SOL_FIX15: tenant repositories are per (tenant, account). An account
// switch A→B without a tenant change gives every provider built on them a
// new instance, so data loaded by A (e.g. as a leader: all topics and
// protocols) is reloaded under B's RLS instead of staying visible.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/repositories/agenda_item_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late StateProvider<String?> userId;
  late ProviderContainer container;
  late SupabaseClient client;

  setUp(() {
    userId = StateProvider<String?>((ref) => 'leader-a');
    client = SupabaseClient('http://localhost:1', 'anon-key');
    container = ProviderContainer(overrides: [
      currentAuthUserIdProvider.overrideWith((ref) => ref.watch(userId)),
      currentTenantIdProvider.overrideWithValue(7),
      supabaseClientProvider.overrideWithValue(client),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await client.dispose();
  });

  test('an account switch yields a new repository bound to the same tenant',
      () {
    final a = container.read(agendaItemRepositoryWithTenantProvider);
    expect(a.currentTenantId, 7);

    container.read(userId.notifier).state = 'member-b';
    final b = container.read(agendaItemRepositoryWithTenantProvider);

    expect(identical(a, b), isFalse);
    expect(b.currentTenantId, 7);
    // A running flow of the old instance keeps its tenant and can still
    // use its ref (no "ref used while outdated" assertion).
    expect(a.currentTenantId, 7);
    expect(a.supabase, same(client));

    // Same account again → the cached instance of that account.
    container.read(userId.notifier).state = 'leader-a';
    expect(container.read(agendaItemRepositoryWithTenantProvider), same(a));
  });

  test('providers built on a tenant repository rebuild on an account switch',
      () async {
    var builds = 0;
    final probe = FutureProvider<AgendaItemRepository>((ref) async {
      builds++;
      return ref.watch(agendaItemRepositoryWithTenantProvider);
    });
    container.listen(probe, (_, __) {});

    final a = await container.read(probe.future);
    expect(builds, 1);

    container.read(userId.notifier).state = 'member-b';
    final state = container.read(probe);
    // While reloading `.when` shows the loader, not A's data.
    expect(state.isLoading, isTrue);
    final b = await container.read(probe.future);
    expect(builds, 2);
    expect(identical(a, b), isFalse);

    // Token refresh of the same account (same id) → no reload.
    container.read(userId.notifier).state = 'member-b';
    await container.read(probe.future);
    expect(builds, 2);
  });

  test('topics, protocols and tasks are tied to the account', () {
    for (final p in <ProviderListenable<Object?>>[
      protocolRepositoryWithTenantProvider,
      taskRepositoryWithTenantProvider,
    ]) {
      final before = container.read(p);
      container.read(userId.notifier).state =
          container.read(userId) == 'x' ? 'y' : 'x';
      expect(identical(before, container.read(p)), isFalse, reason: '$p');
    }
  });
}
