// SOL_FIX8: offline read caches drop the affected user/tenant entries on
// auth/permission errors and remove an entry whose fresh fetch is null.
import 'dart:io';

import 'package:attendix/core/services/attendance_detail_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const cache = AttendanceDetailCache();
  final key = AttendanceDetailCache.keyFor('u1', 7, 42, 'attendance');
  const OfflineCacheScope scope = (userId: 'u1', tenantId: 7);

  Future<Map<String, dynamic>?> fetch(
    Future<Map<String, dynamic>?> Function() f, {
    bool online = true,
  }) =>
      cache.fetchWithCache<Map<String, dynamic>>(
        key: key,
        scope: scope,
        isOnline: () async => online,
        fetch: f,
      );

  Never networkDown() => throw http.ClientException('Failed to fetch');

  group('Multi-Tenant Security: offline read cache purge', () {
    test('online ok -> cached; 403 -> entry gone, offline read finds nothing',
        () async {
      expect(await fetch(() async => {'id': 42}), {'id': 42});
      expect(await cache.load(key), {'id': 42});
      // Offline the copy is shown.
      expect(await fetch(networkDown, online: false), {'id': 42});

      await expectLater(
        fetch(() async => throw PostgrestException(message: 'denied', code: '403')),
        throwsA(isA<PostgrestException>()),
      );
      expect(await cache.load(key), isNull);
      // Offline read: no copy any more -> the network error surfaces.
      await expectLater(
          fetch(networkDown, online: false), throwsA(isA<http.ClientException>()));
    });

    test('online ok -> cached; null (not found) -> entry removed', () async {
      expect(await fetch(() async => {'id': 42}), {'id': 42});
      expect(await fetch(() async => null), isNull);
      expect(await cache.load(key), isNull);
      await expectLater(
          fetch(networkDown, online: false), throwsA(isA<http.ClientException>()));
    });

    for (final code in ['401', '42501', 'PGRST301', 'PGRST303']) {
      test('$code purges all entries of the user in the tenant only', () async {
        SharedPreferences.setMockInitialValues({
          key: '{"id":42}',
          'offline_att_detail_v1_u1_7_42_persons': '[]',
          'offline_att_detail_v1_u1_7_players': '[]',
          'offline_att_list_v1_u1_7': '{}',
          'offline_songs_v1_u1_7': '[]',
          // other tenant / other user / unrelated keys stay
          'offline_att_detail_v1_u1_70_1_attendance': '{}',
          'offline_att_list_v1_u1_8': '{}',
          'offline_songs_v1_u2_7': '[]',
          'offline_writes_v1': '[]',
        });
        await expectLater(
          fetch(() async => throw PostgrestException(message: 'x', code: code)),
          throwsA(isA<PostgrestException>()),
        );
        expect((await SharedPreferences.getInstance()).getKeys(), {
          'offline_att_detail_v1_u1_70_1_attendance',
          'offline_att_list_v1_u1_8',
          'offline_songs_v1_u2_7',
          'offline_writes_v1',
        });
      });
    }

    test('auth error without scope still removes the entry itself', () async {
      SharedPreferences.setMockInitialValues({
        key: '{"id":42}',
        'offline_att_list_v1_u1_7': '{}',
      });
      await expectLater(
        cache.fetchWithCache<Map<String, dynamic>>(
          key: key,
          isOnline: () async => true,
          fetch: () async => throw const AuthException('expired', statusCode: '401'),
        ),
        throwsA(isA<AuthException>()),
      );
      expect((await SharedPreferences.getInstance()).getKeys(),
          {'offline_att_list_v1_u1_7'});
    });

    test('network errors keep the cached entry', () async {
      await fetch(() async => {'id': 42});
      expect(await fetch(networkDown), {'id': 42});
      expect(await cache.load(key), {'id': 42});
    });

    test('attendance list + songs purge on auth errors (source)', () {
      final realtime =
          File('lib/core/providers/realtime_providers.dart').readAsStringSync();
      expect(realtime, contains('isAuthOrPermissionError(e)'));
      expect(realtime, contains('purgeOfflineReadCachesFor(cacheUserId, tenantId)'));
      final songs = File('lib/data/repositories/song_repository.dart').readAsStringSync();
      expect(songs, contains('isAuthOrPermissionError(e)'));
      expect(songs, contains('_purgeOfflineSongs(cacheKey, tenantId)'));
      expect(songs, contains('purgeOfflineReadCachesFor(userId, tenantId)'));
      final detail =
          File('lib/core/providers/attendance_detail_providers.dart').readAsStringSync();
      expect('scope: _cacheScope('.allMatches(detail).length, 4);
    });
  });
}
