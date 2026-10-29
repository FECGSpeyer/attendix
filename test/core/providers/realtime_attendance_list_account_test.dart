// SOL_FIX16: the offline attendance list follows the signed-in account.
// An account switch A→B in the same tenant must never keep A's list, and a
// cached list is only returned while its session is still current.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/services/attendance_list_cache.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/supabase_mocks.dart';

class _MockChannel extends Mock implements RealtimeChannel {}

const _tenantId = 7;

void main() {
  late MockSupabaseClient supabase;
  late String? clientUser;
  late StateProvider<String?> authUser;

  setUpAll(() {
    registerFallbackValue(PostgresChangeEvent.all);
    registerFallbackValue(PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'tenantId',
      value: _tenantId,
    ));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    const cache = AttendanceListCache();
    await cache.save('user-a', _tenantId, [
      TestFactories.createAttendance(id: 1, tenantId: _tenantId, date: '2026-10-01', notes: 'A'),
    ]);
    await cache.save('user-b', _tenantId, [
      TestFactories.createAttendance(id: 2, tenantId: _tenantId, date: '2026-10-02', notes: 'B'),
    ]);

    supabase = MockSupabaseClient();
    final channel = _MockChannel();
    when(() => supabase.channel(any())).thenReturn(channel);
    when(() => channel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        )).thenReturn(channel);
    when(() => channel.subscribe()).thenReturn(channel);
    when(() => channel.unsubscribe()).thenAnswer((_) async => 'ok');

    clientUser = 'user-a';
    authUser = StateProvider<String?>((ref) => 'user-a');
  });

  ProviderContainer container({String? Function()? readUser}) {
    final c = createTestContainer(
      tenantId: _tenantId,
      mockSupabase: supabase,
      overrides: [
        currentAuthUserIdProvider.overrideWith((ref) => ref.watch(authUser)),
        offlineQueueUserIdProvider.overrideWithValue(readUser ?? () => clientUser),
        connectivityCheckProvider.overrideWithValue(() async => false),
      ],
    );
    addTearDown(c.dispose);
    c.listen(realtimeAttendanceListProvider, (_, __) {});
    return c;
  }

  test('offline: the cached list of the signed-in account is shown', () async {
    final c = container();
    final list = await c.read(realtimeAttendanceListProvider.future);
    expect(list.map((a) => a.notes), ['A']);
  });

  test('account switch A→B in the same tenant reloads for B', () async {
    final c = container();
    expect((await c.read(realtimeAttendanceListProvider.future)).single.notes, 'A');

    clientUser = 'user-b';
    c.read(authUser.notifier).state = 'user-b';
    await Future<void>.delayed(Duration.zero);

    final list = await c.read(realtimeAttendanceListProvider.future);
    expect(list.map((a) => a.notes), ['B']);
  });

  test('a cache read whose session ended meanwhile is not returned', () async {
    // The signed-in user at capture time is A, but by the time the cache is
    // read back the session belongs to B (sign-out / switch during load).
    var reads = 0;
    final c = container(readUser: () => reads++ == 0 ? 'user-a' : 'user-b');
    final result = c.read(realtimeAttendanceListProvider.future);
    await expectLater(result, throwsA(anything));
  });
}
