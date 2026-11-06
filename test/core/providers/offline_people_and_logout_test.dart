import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';

/// Realtime channel that accepts every call and never connects.
class _FakeChannel implements RealtimeChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #unsubscribe ? Future.value('ok') : this;
}

class _FakeClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #channel ? _FakeChannel() : super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // #384 A: the people list is an autoDispose provider; a tab switch drops
  // it. Offline it must come back with the last loaded list.
  test('people list: offline after dispose shows the last loaded list', () async {
    SharedPreferences.setMockInitialValues({});
    var online = true;
    final repo = MockPlayerRepository();
    final people = [
      TestFactories.createPerson(id: 1, tenantId: 42, instrument: 7),
      TestFactories.createPerson(id: 2, tenantId: 42, lastName: 'Zweite'),
    ];
    when(() => repo.getPlayers()).thenAnswer((_) async => people);

    Future<List<String?>> load() async {
      final c = ProviderContainer(overrides: [
        supabaseClientProvider.overrideWithValue(_FakeClient()),
        currentTenantIdProvider.overrideWithValue(42),
        playerRepositoryWithTenantProvider.overrideWithValue(repo),
        groupsMapProvider.overrideWith((ref) async => {7: 'Geige'}),
        connectivityCheckProvider.overrideWithValue(() async => online),
        offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      ]);
      addTearDown(c.dispose);
      c.listen(realtimePlayersProvider, (_, __) {});
      final list = await c.read(realtimePlayersProvider.future);
      c.dispose();
      return [for (final p in list) '${p.id} ${p.groupName}'];
    }

    expect(await load(), ['1 Geige', '2 null']);

    online = false;
    when(() => repo.getPlayers())
        .thenThrow(Exception('SocketException: Failed host lookup'));
    expect(await load(), ['1 Geige', '2 null']);
  });

  // #384 B: offline the sign-out request fails after the local session is
  // gone; the selected group must be cleared anyway.
  test('sign-out failing offline still clears the selected group', () async {
    var cleared = false;
    await signOutAndClearTenant(
      signOut: () async => throw Exception('SocketException: Failed host lookup'),
      clearTenant: () async => cleared = true,
    );
    expect(cleared, isTrue);
  });
}
