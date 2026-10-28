// SOL_FIX10: the attendance list purges the offline caches on auth errors of
// ANY part of its load (incl. attendance types), and a per user/tenant purge
// ends the cache session so in-flight loads cannot recreate entries.
import 'dart:io';

import 'package:attendix/core/services/attendance_detail_cache.dart';
import 'package:attendix/core/services/attendance_list_cache.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const list = AttendanceListCache();
  const att = [Attendance(id: 1, date: '2026-01-01')];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Multi-Tenant Security: purgeOfflineCachesOnAuthError', () {
    test('auth error in a later step (types) purges the user/tenant caches',
        () async {
      await list.save('u1', 42, att);
      await list.save('u1', 7, att);
      await expectLater(
        purgeOfflineCachesOnAuthError('u1', 42, () async {
          await Future<void>.delayed(Duration.zero); // attendances loaded
          throw PostgrestException(message: 'denied', code: '42501'); // types
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(await list.load('u1', 42), isNull);
      expect(await list.load('u1', 7), hasLength(1), reason: 'other tenant kept');
    });

    for (final code in ['401', '403', 'PGRST301', 'PGRST303']) {
      test('$code purges', () async {
        await list.save('u1', 42, att);
        await expectLater(
          purgeOfflineCachesOnAuthError<void>('u1', 42,
              () async => throw PostgrestException(message: 'x', code: code)),
          throwsA(isA<PostgrestException>()),
        );
        expect(await list.load('u1', 42), isNull);
      });
    }

    test('network error keeps the cache; success returns the value', () async {
      await list.save('u1', 42, att);
      await expectLater(
        purgeOfflineCachesOnAuthError<void>(
            'u1', 42, () async => throw http.ClientException('Failed to fetch')),
        throwsA(isA<http.ClientException>()),
      );
      expect(await list.load('u1', 42), hasLength(1));
      expect(await purgeOfflineCachesOnAuthError('u1', 42, () async => 5), 5);
    });

    test('attendance list wraps attendances AND types (source)', () {
      final src =
          File('lib/core/providers/realtime_providers.dart').readAsStringSync();
      final start = src.indexOf('purgeOfflineCachesOnAuthError(\n');
      expect(start, greaterThan(0));
      final end = src.indexOf('} catch (e) {', start);
      final wrapped = src.substring(start, end);
      expect(wrapped, contains(".from('attendance')"));
      expect(wrapped, contains('attendanceTypesProvider.future'));
      expect(src.substring(end).contains('attendanceTypesProvider'), isFalse);
    });
  });

  test('purge ends the cache session: in-flight load does not recreate',
      () async {
    final inFlight = OfflineReadCacheGuard.capture(userId: 'u1');
    await purgeOfflineReadCachesFor('u1', 42);
    expect(inFlight.isCurrent, isFalse);
    await list.save('u1', 42, att, guard: inFlight);
    expect(await list.load('u1', 42), isNull);

    final fresh = OfflineReadCacheGuard.capture(userId: 'u1');
    await list.save('u1', 42, att, guard: fresh);
    expect(await list.load('u1', 42), hasLength(1));
  });

  test('fetchWithCache: purge during another in-flight fetch -> no entry',
      () async {
    const cache = AttendanceDetailCache();
    final key = AttendanceDetailCache.keyFor('u1', 42, 5, 'attendance');
    final result = cache.fetchWithCache<Map<String, dynamic>>(
      key: key,
      scope: (userId: 'u1', tenantId: 42),
      isOnline: () async => true,
      fetch: () async {
        await purgeOfflineReadCachesFor('u1', 42); // e.g. parallel 403
        return {'id': 5};
      },
    );
    expect(await result, {'id': 5});
    expect(await cache.load(key), isNull);
  });
}
