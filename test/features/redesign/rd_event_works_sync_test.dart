// A Werk in the Ablauf of a Termin belongs to its Werke (Beta).
import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/conductor_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/models/plan/plan.dart' show PlanAttendance;
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/attendance/presentation/attendance_song_history.dart';
import 'package:attendix/features/attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import 'package:attendix/features/redesign/data/providers/rd_event_works_providers.dart';
import 'package:attendix/features/redesign/data/rd_event_works_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';
import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'JC', longName: 'Jugendchor', type: 'choir');
  }
}

class _OnlineQueue extends OfflineQueueNotifier {
  @override
  int build() => 0;
}

void main() {
  const concert = (
    att: PlanAttendance(id: 30, tenantId: 7, date: '2099-12-13', typeId: 'k', typeInfo: 'Adventskonzert'),
    name: 'Adventskonzert',
    entries: [
      SongHistoryEntry(songId: 1, songName: '12 - Machet die Tore weit', conductorId: 5, conductorName: 'Anna Meier'),
      SongHistoryEntry(songId: 2, songName: '31 - Tochter Zion', conductorId: 5, conductorName: 'Anna Meier'),
    ],
  );

  Future<List<Map<String, dynamic>>> run(List<Map<String, dynamic>> fields) async {
    final repo = MockAttendanceRepository();
    final added = <Map<String, dynamic>>[];
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.getHistoryForAttendance(21)).thenAnswer((_) async => const []);
    when(() => repo.addHistoryEntries(any())).thenAnswer((inv) async {
      added.addAll((inv.positionalArguments[0] as List).cast<Map<String, dynamic>>());
    });
    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    final authEvents = StreamController<AuthChangeEvent>.broadcast();
    addTearDown(authEvents.close);
    final container = ProviderContainer(overrides: [
      supabaseAuthProvider.overrideWithValue(auth),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
      offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
      offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
      offlineQueueNotifierProvider.overrideWith(_OnlineQueue.new),
      attendanceDetailProvider.overrideWith((ref, id) async => TestFactories.createAttendance(
            id: 21,
            tenantId: 7,
            date: '2099-12-03',
            typeId: 'p',
          ).copyWith(plan: {'time': '19:30', 'fields': fields})),
      attendanceTypeForAttendanceProvider.overrideWith(
        (ref, id) async => TestFactories.createAttendanceType(id: 'p', name: 'Probe').copyWith(manageSongs: true),
      ),
      attendanceSongEntriesProvider.overrideWith((ref, id) async => const []),
      rdEventWorksSourcesProvider.overrideWith((ref, id) async => const [concert]),
      songsProvider.overrideWith((ref) async => const [
            Song(id: 1, name: 'Machet die Tore weit', number: 12),
            Song(id: 2, name: 'Tochter Zion', number: 31),
            Song(id: 3, name: 'Es ist ein Ros entsprungen', number: 47),
          ]),
      conductorsProvider.overrideWith((ref) async => const []),
    ]);
    addTearDown(container.dispose);
    await rdSyncPlanWorks(container, 21);
    return added;
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  test('a Probe that rehearses Werke of the next Auftritt keeps following it', () async {
    final added = await run([
      {'id': 'a', 'name': 'Einsingen', 'time': '10'},
      {'id': 'b', 'name': '12. Machet die Tore weit', 'time': '5', 'songId': 1},
    ]);
    expect(added, isEmpty);
  });

  test('a Werk from outside the list makes the list the Probe\'s own, with that Werk', () async {
    final added = await run([
      {'id': 'b', 'name': '12. Machet die Tore weit', 'time': '5', 'songId': 1},
      {'id': 'c', 'name': '47. Es ist ein Ros entsprungen', 'time': '5', 'songId': 3, 'conductor': 'Ben Kurz'},
    ]);
    expect([for (final row in added) row['songId']], [1, 2, 3]);
    expect(added.every((row) => row['attendance_id'] == 21 && row['date'] == '2099-12-03'), isTrue);
    expect(added.first['person_id'], 5);
    expect(added.last['otherConductor'], 'Ben Kurz');
  });
}
