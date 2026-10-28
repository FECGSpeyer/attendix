// SOL_FIX9: a load that is still in flight when the offline read caches are
// cleared (sign-out / account switch) must not recreate cache entries.
import 'dart:async';
import 'dart:io';

import 'package:attendix/core/services/attendance_detail_cache.dart';
import 'package:attendix/core/services/attendance_list_cache.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cache = AttendanceDetailCache();
  final key = AttendanceDetailCache.keyFor('u1', 42, 5, 'attendance');
  String? currentUser;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    currentUser = 'u1';
  });

  Future<Map<String, dynamic>?> startFetch(
          Completer<Map<String, dynamic>?> pending) =>
      cache.fetchWithCache<Map<String, dynamic>>(
        key: key,
        scope: (userId: 'u1', tenantId: 42),
        currentUserId: () => currentUser,
        isOnline: () async => true,
        fetch: () => pending.future,
      );

  group('AttendanceDetailCache.fetchWithCache', () {
    test('stores the result when the session is unchanged', () async {
      final pending = Completer<Map<String, dynamic>?>();
      final result = startFetch(pending);
      pending.complete({'id': 5});
      expect(await result, {'id': 5});
      expect(await cache.load(key), {'id': 5});
    });

    test('start fetch → clear → fetch completes → no entry', () async {
      final pending = Completer<Map<String, dynamic>?>();
      final result = startFetch(pending);
      await Future<void>.delayed(Duration.zero);
      await clearOfflineReadCaches();
      pending.complete({'id': 5});
      expect(await result, {'id': 5}, reason: 'result is still returned');
      expect(await cache.load(key), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith(AttendanceDetailCache.prefix)),
        isEmpty,
      );
    });

    test('signed-in user changed during the fetch → no entry', () async {
      final pending = Completer<Map<String, dynamic>?>();
      final result = startFetch(pending);
      currentUser = 'u2';
      pending.complete({'id': 5});
      await result;
      expect(await cache.load(key), isNull);
    });

    test('a later fetch in the new session caches again', () async {
      await clearOfflineReadCaches();
      final pending = Completer<Map<String, dynamic>?>();
      final result = startFetch(pending);
      pending.complete({'id': 6});
      await result;
      expect(await cache.load(key), {'id': 6});
    });
  });

  test('AttendanceListCache.save skips a stale session', () async {
    const list = AttendanceListCache();
    final stale = OfflineReadCacheGuard.capture(
        userId: 'u1', currentUserId: () => currentUser);
    bumpOfflineReadCacheGeneration();
    await list.save('u1', 42, [const Attendance(id: 1, date: '2026-01-01')],
        guard: stale);
    expect(await list.load('u1', 42), isNull);

    final fresh = OfflineReadCacheGuard.capture(
        userId: 'u1', currentUserId: () => currentUser);
    await list.save('u1', 42, [const Attendance(id: 1, date: '2026-01-01')],
        guard: fresh);
    expect(await list.load('u1', 42), hasLength(1));
  });

  test('replayed writes do not recreate a cleared detail cache', () async {
    final personsKey = AttendanceDetailCache.keyFor('u1', 42, 5, 'persons');
    final guard = OfflineReadCacheGuard.capture(
        userId: 'u1', currentUserId: () => currentUser);
    await clearOfflineReadCaches();
    // an entry (re)written without a guard after the clear is not touched
    // by a replay that started in the old session
    await cache.save(personsKey, [
      {'id': 'pa1', 'status': 0},
    ]);
    await applyConfirmedWritesToDetailCache(
      [
        QueuedWrite(
          id: 'w',
          personAttendanceId: 'pa1',
          payload: const {'status': 1},
          tenantId: 42,
          attendanceId: 5,
          userId: 'u1',
          createdAt: 'now',
        ),
      ],
      guard: guard,
    );
    expect(((await cache.load(personsKey)) as List).single['status'], 0);
  });

  test('songs and list caches capture the session before loading (source)', () {
    final songs =
        File('lib/data/repositories/song_repository.dart').readAsStringSync();
    final getSongs =
        songs.substring(songs.indexOf('Future<List<Song>> getSongs()'));
    expect(getSongs.indexOf('OfflineReadCacheGuard.capture'),
        lessThan(getSongs.indexOf(".from('songs')")));
    expect(songs, contains('_writeOfflineSongs(cacheKey, rawRows, cacheGuard)'));
    expect(songs, contains('if (!guard.isCurrent) return;'));

    final list =
        File('lib/core/providers/realtime_providers.dart').readAsStringSync();
    expect(list.indexOf('OfflineReadCacheGuard.capture'),
        lessThan(list.indexOf(".from('attendance')")));
    expect(list, contains('guard: cacheGuard'));

    final detail = File('lib/core/providers/attendance_detail_providers.dart')
        .readAsStringSync();
    final fetches = 'fetchWithCache'.allMatches(detail).length;
    expect(fetches, greaterThan(0));
    expect(
      'currentUserId: ref.read(offlineQueueUserIdProvider)'
          .allMatches(detail)
          .length,
      fetches,
    );
  });
}
