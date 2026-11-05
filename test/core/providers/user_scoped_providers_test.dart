// SOL_FIX14: per-user providers must follow the signed-in account, not
// only the tenant – an account switch A→B without a tenant change must
// never keep A's data (e.g. "Meine Pläne" with their edit keys).
import 'dart:async';
import 'dart:io';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/plan_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the plans of whichever account [userId] currently names –
/// like the real query (`creator_user_id = auth.uid()`).
class _FakePlanRepository extends PlanRepository {
  _FakePlanRepository(super.ref, this.userId, this.plansByUser);

  final String? Function() userId;
  final Map<String, List<SharedPlan>> plansByUser;
  int calls = 0;

  @override
  Future<List<SharedPlan>> getMySharedPlans() async {
    calls++;
    return plansByUser[userId()] ?? const [];
  }
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('currentAuthUserIdProvider', () {
    test('follows the auth stream and ignores events of the same account',
        () async {
      final controller = StreamController<User?>.broadcast();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => controller.stream),
      ]);
      addTearDown(() {
        container.dispose();
        controller.close();
      });

      final seen = <String?>[];
      container.listen<String?>(
        currentAuthUserIdProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      Future<String?> emit(User? user) async {
        controller.add(user);
        await Future<void>.delayed(Duration.zero);
        return container.read(currentAuthUserIdProvider); // flushes
      }

      expect(await emit(_user('user-a')), 'user-a');
      // Token refresh: new User object, same account → no notification.
      expect(await emit(_user('user-a')), 'user-a');
      expect(await emit(_user('user-b')), 'user-b');
      expect(await emit(null), isNull);

      expect(seen, [null, 'user-a', 'user-b', null]);
    });
  });

  group('mySharedPlansProvider', () {
    SharedPlan plan(String id, String owner) =>
        SharedPlan(id: id, editKey: 'edit-$id', creatorUserId: owner);

    test('reloads on an account switch without a tenant change', () async {
      final userId = StateProvider<String?>((ref) => 'user-a');
      late _FakePlanRepository repo;
      final container = ProviderContainer(overrides: [
        currentAuthUserIdProvider.overrideWith((ref) => ref.watch(userId)),
        currentTenantIdProvider.overrideWithValue(7),
        planRepositoryWithTenantProvider.overrideWith((ref) {
          return repo = _FakePlanRepository(
            ref,
            () => ref.read(userId),
            {
              'user-a': [plan('a1', 'user-a')],
              'user-b': [plan('b1', 'user-b')],
            },
          );
        }),
      ]);
      addTearDown(container.dispose);
      container.listen(mySharedPlansProvider, (_, __) {});

      final a = await container.read(mySharedPlansProvider.future);
      expect(a.map((p) => p.id), ['a1']);

      container.read(userId.notifier).state = 'user-b';
      final state = container.read(mySharedPlansProvider);
      // While reloading, `.when` shows the spinner (no stale data).
      expect(state.isLoading, isTrue);
      expect(state.isReloading, isTrue);

      final b = await container.read(mySharedPlansProvider.future);
      expect(b.map((p) => p.id), ['b1']);
      expect(b.map((p) => p.editKey), isNot(contains('edit-a1')));
      expect(repo.calls, 2);
    });

    test('returns no plans when signed out', () async {
      final container = ProviderContainer(overrides: [
        currentAuthUserIdProvider.overrideWith((ref) => null),
        planRepositoryWithTenantProvider.overrideWith((ref) =>
            _FakePlanRepository(ref, () => 'user-a', {
              'user-a': [plan('a1', 'user-a')],
            })),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(mySharedPlansProvider.future), isEmpty);
    });

    test('drops rows of another creator', () async {
      final container = ProviderContainer(overrides: [
        currentAuthUserIdProvider.overrideWith((ref) => 'user-b'),
        planRepositoryWithTenantProvider.overrideWith((ref) =>
            _FakePlanRepository(ref, () => 'user-b', {
              'user-b': [plan('a1', 'user-a'), plan('b1', 'user-b')],
            })),
      ]);
      addTearDown(container.dispose);
      final plans = await container.read(mySharedPlansProvider.future);
      expect(plans.map((p) => p.id), ['b1']);
    });
  });

  group('currentRoleProvider', () {
    TenantUser tenantUser(String userId) =>
        TenantUser(tenantId: 7, userId: userId, role: Role.admin.value);

    test('uses the role of the signed-in account', () async {
      final container = ProviderContainer(overrides: [
        currentAuthUserIdProvider.overrideWith((ref) => 'user-a'),
        currentTenantUserProvider
            .overrideWith((ref) async => tenantUser('user-a')),
      ]);
      addTearDown(container.dispose);
      await container.read(currentTenantUserProvider.future);
      expect(container.read(currentRoleProvider), Role.admin);
    });

    test("never exposes the previous account's role", () async {
      final container = ProviderContainer(overrides: [
        currentAuthUserIdProvider.overrideWith((ref) => 'user-b'),
        currentTenantUserProvider
            .overrideWith((ref) async => tenantUser('user-a')),
      ]);
      addTearDown(container.dispose);
      await container.read(currentTenantUserProvider.future);
      expect(container.read(currentRoleProvider), Role.none);
    });
  });

  group('user-scoped providers watch the account (source analysis)', () {
    // provider name → file. Each must depend on currentAuthUserIdProvider
    // so it reloads on an account switch.
    const providers = {
      'mySharedPlansProvider': 'lib/core/providers/plan_providers.dart',
      'userTenantsProvider': 'lib/core/providers/tenant_providers.dart',
      'currentTenantUserProvider': 'lib/core/providers/tenant_providers.dart',
      'userOrganisationsProvider':
          'lib/core/providers/organisation_providers.dart',
      'crossTenantAttendancesProvider':
          'lib/core/providers/cross_tenant_providers.dart',
      'allPersonAttendancesAcrossTenantsProvider':
          'lib/core/providers/self_service_providers.dart',
      'ownProfileProvider': 'lib/core/providers/profile_providers.dart',
      'userNotificationsProvider': 'lib/core/providers/message_providers.dart',
      'unreadNotificationCountProvider':
          'lib/core/providers/message_providers.dart',
      'userNotificationsRealtimeProvider':
          'lib/core/providers/message_providers.dart',
      'receivedMessagesProvider': 'lib/core/providers/message_providers.dart',
      'notificationConfigProvider': 'lib/core/services/telegram_service.dart',
      'upcomingSongsProvider':
          'lib/features/self_service/data/providers/upcoming_songs_provider.dart',
      'currentPlayerInstrumentProvider':
          'lib/features/self_service/data/providers/upcoming_songs_provider.dart',
      'userPreferencesProvider':
          'lib/core/providers/user_preferences_provider.dart',
    };

    for (final entry in providers.entries) {
      test(entry.key, () {
        final src = File(entry.value).readAsStringSync();
        final start = src.indexOf('final ${entry.key} =');
        expect(start, isNot(-1), reason: '${entry.key} not found');
        final end = src.indexOf('\n});', start);
        final body = src.substring(start, end);
        expect(body, contains('ref.watch(currentAuthUserIdProvider)'));
        if (entry.key != 'userPreferencesProvider') {
          // The account id comes from the watched provider, not a one-off
          // read (userPreferencesProvider still reads the metadata).
          expect(body, isNot(contains('auth.currentUser?.id')));
        }
      });
    }
  });
}
