import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Security tests for SongRepository / PublicSongRepository (source analysis)
///
/// Song library sync (Ionic `song_source_tenant_id`): songs and song
/// categories live in the *song source tenant* (`songTenantId` =
/// source tenant ?? current tenant), history always stays per tenant.
///
/// Tables:
/// - songs: 'tenantId' column, filtered by songTenantId
/// - song_categories: 'tenant_id' column, filtered by songTenantId
/// - history: 'tenantId' column, filtered by currentTenantId
void main() {
  late String repo;
  late String publicRepo;

  setUpAll(() {
    repo = File('lib/data/repositories/song_repository.dart').readAsStringSync();
    publicRepo =
        File('lib/data/repositories/public_song_repository.dart').readAsStringSync();
  });

  /// All query chains (from `.from('<table>')` up to the next `;`)
  List<String> queries(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]*;",
        dotAll: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();

  group('Multi-Tenant Security - SongRepository', () {
    test('songTenantId falls back to the current tenant', () {
      expect(repo, contains('songSourceTenantId ?? currentTenantId'));
    });

    test('every songs query filters by songTenantId or inserts it', () {
      final songQueries = queries(repo, 'songs');
      expect(songQueries, isNotEmpty);
      for (final q in songQueries) {
        if (q.contains('.insert(')) continue;
        expect(q, contains(".eq('tenantId', songTenantId)"),
            reason: 'songs query without tenant filter:\n$q');
      }
      expect(repo, contains("data['tenantId'] = songTenantId"),
          reason: 'createSong must set the song tenant');
    });

    test('songs UPDATE / DELETE filter by id AND tenantId', () {
      for (final q in queries(repo, 'songs')) {
        if (q.contains('.update(') || q.contains('.delete(')) {
          expect(q, contains(".eq('id', id)"));
          expect(q, contains(".eq('tenantId', songTenantId)"));
        }
      }
    });

    test('every song_categories query filters by tenant_id or inserts it', () {
      final catQueries = queries(repo, 'song_categories');
      expect(catQueries, isNotEmpty);
      for (final q in catQueries) {
        if (q.contains('.insert(')) {
          expect(q, contains("'tenant_id': songTenantId"));
        } else {
          expect(q, contains(".eq('tenant_id', songTenantId)"),
              reason: 'song_categories query without tenant filter:\n$q');
        }
      }
    });

    test('history queries are per tenant (never the song source tenant)', () {
      final historyQueries = queries(repo, 'history');
      expect(historyQueries, isNotEmpty);
      for (final q in historyQueries) {
        if (q.contains('.insert(')) {
          expect(q, contains("'tenantId': currentTenantId"));
        } else {
          expect(
            q.contains(".eq('tenantId', currentTenantId)") ||
                q.contains(".eq('tenantId', tenantId)"),
            isTrue,
            reason: 'history query without tenant filter:\n$q',
          );
        }
        expect(q, isNot(contains('songTenantId')));
      }
    });

    test('history uses the real column names (songId, not song_id)', () {
      expect(repo, isNot(contains("'song_id'")));
      expect(repo, contains("'songId'"));
    });

    test('attendance_types lookup is tenant filtered', () {
      for (final q in queries(repo, 'attendance_types')) {
        expect(q, contains(".eq('tenant_id', tenantId)"));
      }
    });

    test('tenants queries document why they cannot filter by tenantId', () {
      expect(repo, contains('`tenants` has no tenantId column'));
      for (final q in queries(repo, 'tenants')) {
        expect(
          q.contains(".eq('id', currentTenantId)") || q.contains('song_source_tenant_id.eq.'),
          isTrue,
          reason: 'tenants query must be scoped to the song library:\n$q',
        );
      }
    });
  });

  group('Multi-Tenant Security - PublicSongRepository', () {
    test('every query except the tenant lookup filters by the shared tenant', () {
      const tables = {
        'songs': "'tenantId'",
        'instruments': "'tenantId'",
        'song_categories': "'tenant_id'",
        'group_categories': "'tenant_id'",
      };
      for (final entry in tables.entries) {
        final qs = queries(publicRepo, entry.key);
        expect(qs, isNotEmpty, reason: 'expected queries on ${entry.key}');
        for (final q in qs) {
          expect(q, contains('.eq(${entry.value}, tenantId)'),
              reason: '${entry.key} query without tenant filter:\n$q');
        }
      }
    });

    test('public repository never writes', () {
      expect(publicRepo, isNot(contains('.insert(')));
      expect(publicRepo, isNot(contains('.update(')));
      expect(publicRepo, isNot(contains('.delete(')));
    });

    test('tenant is resolved by song_sharing_id only', () {
      final qs = queries(publicRepo, 'tenants');
      expect(qs, hasLength(1));
      expect(qs.single, contains(".eq('song_sharing_id', sharingId)"));
    });
  });
}
