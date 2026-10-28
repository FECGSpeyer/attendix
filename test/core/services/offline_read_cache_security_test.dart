// SOL_FIX7: offline read caches are bound to user + tenant, cleared on
// sign-out and never hide auth/permission errors behind an old copy.
import 'dart:io';

import 'package:attendix/core/services/attendance_detail_cache.dart';
import 'package:attendix/core/services/attendance_list_cache.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/base_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Multi-Tenant Security: offline read caches', () {
    test('auth / permission errors are recognised', () {
      for (final code in ['401', '403', '42501', 'PGRST301', 'PGRST302']) {
        expect(isAuthOrPermissionError(PostgrestException(message: 'x', code: code)), isTrue,
            reason: code);
        expect(isOfflineFallbackError(PostgrestException(message: 'Failed to fetch', code: code)),
            isFalse, reason: code);
      }
      expect(
          isAuthOrPermissionError(const RepositoryException(
              message: 'x',
              operation: 'op',
              originalError: PostgrestException(message: 'x', code: '42501'))),
          isTrue);
      expect(isAuthOrPermissionError(const AuthException('expired', statusCode: '401')), isTrue);
      expect(isAuthOrPermissionError(PostgrestException(message: 'x', code: '23505')), isFalse);
      expect(isOfflineFallbackError(http.ClientException('Failed to fetch')), isTrue);
      expect(isOfflineFallbackError(StateError('bug')), isFalse);
    });

    const cache = AttendanceDetailCache();
    final key = AttendanceDetailCache.keyFor('u1', 7, 42, 'attendance');

    test('auth error is rethrown although a cached copy exists', () async {
      await cache.save(key, {'id': 42});
      await expectLater(
        cache.fetchWithCache<Map<String, dynamic>>(
          key: key,
          isOnline: () async => true,
          fetch: () async => throw PostgrestException(message: 'JWT expired', code: 'PGRST301'),
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        cache.fetchWithCache<Map<String, dynamic>>(
          key: key,
          isOnline: () async => true,
          fetch: () async => throw PostgrestException(message: 'denied', code: '42501'),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('non-network errors are rethrown, network errors use the cache', () async {
      await cache.save(key, {'id': 42});
      await expectLater(
        cache.fetchWithCache<Map<String, dynamic>>(
            key: key, isOnline: () async => true, fetch: () async => throw StateError('bug')),
        throwsStateError,
      );
      expect(
        await cache.fetchWithCache<Map<String, dynamic>>(
            key: key,
            isOnline: () async => true,
            fetch: () async => throw http.ClientException('Failed to fetch')),
        {'id': 42},
      );
    });

    test('without a signed-in user nothing is cached', () async {
      final result = await cache.fetchWithCache<Map<String, dynamic>>(
          key: null, isOnline: () async => true, fetch: () async => {'id': 1});
      expect(result, {'id': 1});
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });

    test('attendance list cache is bound to user and tenant', () async {
      const list = AttendanceListCache();
      await list.save('u1', 7, [const Attendance(id: 1, tenantId: 7, date: '2026-01-01')]);
      expect(await list.load('u1', 7), hasLength(1));
      expect(await list.load('u2', 7), isNull);
      expect(await list.load('u1', 8), isNull);
      expect(AttendanceListCache.keyFor('u1', 7), 'offline_att_list_v1_u1_7');
    });

    test('clearOfflineReadCaches removes all read caches only', () async {
      SharedPreferences.setMockInitialValues({
        'offline_att_detail_v1_u1_7_42_persons': '[]',
        'offline_att_list_v1_u1_7': '{}',
        'offline_songs_v1_u1_7': '[]',
        'offline_att_detail_v1_7_42_attendance': '{}', // legacy key
        'offline_writes_v1': '[]',
        'locale': 'de',
      });
      await clearOfflineReadCaches();
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys, {'offline_writes_v1', 'locale'});
    });

    test('caches are cleared on sign-out and account switch only', () {
      expect(shouldClearOfflineReadCaches('u1', null), isTrue);
      expect(shouldClearOfflineReadCaches('u1', 'u2'), isTrue);
      expect(shouldClearOfflineReadCaches(null, 'u1'), isFalse);
      expect(shouldClearOfflineReadCaches('u1', 'u1'), isFalse);
      final main = File('lib/main.dart').readAsStringSync();
      final listener = main.substring(main.indexOf('ref.listen(currentUserProvider'));
      expect(listener.substring(0, 700), contains('clearOfflineReadCaches()'));
    });

    test('list providers only fall back on network errors', () {
      final realtime = File('lib/core/providers/realtime_providers.dart').readAsStringSync();
      expect(realtime, contains('isOfflineFallbackError(e)'));
      expect(realtime, contains('cache.load(cacheUserId, tenantId)'));
      final detail = File('lib/core/providers/attendance_detail_providers.dart').readAsStringSync();
      expect(detail, isNot(contains('AttendanceDetailCache.keyFor(tenant')));
      expect(RegExp(r'_detailCacheKey\(ref,').allMatches(detail).length, 3);
      expect(detail, contains('_playersCacheKey(ref, tenant.id!)'));
    });
  });
}
