import 'dart:io';

import 'package:attendix/core/providers/org_song_providers.dart';
import 'package:attendix/core/utils/song_copy.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/song/org_song.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/models/tenant/tenant.dart' show ExtraField;
import 'package:attendix/data/repositories/org_song_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Group _group(int id, String name, [String? synonyms]) =>
    Group(id: id, name: name, synonyms: synonyms, tenantId: 9);

Song _song(String name, int number, [String? prefix]) =>
    Song(name: name, number: number, prefix: prefix);

ExtraField _field(String id, String name, String type, [List<String>? options]) =>
    ExtraField(id: id, name: name, type: type, options: options);

/// Port of Ionic `song-copy.spec.ts` (4.17.13) plus the Flutter parts.
void main() {
  group('mapGroupByName', () {
    final target = [_group(10, 'Violine 1'), _group(11, 'Cello', 'Violoncello'), _group(12, 'Flöte')];

    test('keeps reserved ids and maps empty ids to null', () {
      expect(mapGroupByName(1, 'Aufnahme', null, target), 1);
      expect(mapGroupByName(2, null, null, target), 2);
      expect(mapGroupByName(null, 'Cello', null, target), isNull);
    });

    test('matches by name case-insensitively', () {
      expect(mapGroupByName(55, 'violine 1', null, target), 10);
    });

    test('matches by synonyms on either side', () {
      expect(mapGroupByName(56, 'Violoncello', null, target), 11);
      expect(mapGroupByName(57, 'Querflöte', 'Flöte', target), 12);
    });

    test('returns null without a match', () {
      expect(mapGroupByName(58, 'Tuba', null, target), isNull);
    });
  });

  group('song numbers and names', () {
    final songs = [_song('Großer Gott', 3), _song('Halleluja', 7, 'A'), _song('Amen', 5)];

    test('finds songs with the same name', () {
      expect(findSongsWithSameName('  großer  gott ', songs).length, 1);
      expect(findSongsWithSameName('Großer Gott wir loben', songs), isEmpty);
    });

    test('checks numbers per prefix', () {
      expect(isSongNumberTaken(3, null, songs), isTrue);
      expect(isSongNumberTaken(7, null, songs), isFalse);
      expect(isSongNumberTaken(7, 'a', songs), isTrue);
      expect(isSongNumberTaken(null, null, songs), isFalse);
    });

    test('suggests the next free number per prefix', () {
      expect(nextFreeSongNumber(null, songs), 6);
      expect(nextFreeSongNumber('A', songs), 8);
      expect(nextFreeSongNumber('B', songs), 1);
    });

    test('label like Ionic songLabel', () {
      expect(orgSongLabel('A', 7, 'Halleluja'), 'A7 Halleluja');
      expect(orgSongLabel(null, null, 'Amen'), 'Amen');
    });
  });

  group('mapExtraFields', () {
    test('maps by name and type and skips empty or unknown values', () {
      final source = [
        _field('a', 'Tonart', 'text'),
        _field('b', 'Dauer', 'number'),
        _field('c', 'Stil', 'select', ['Pop', 'Klassik']),
        _field('d', 'Leer', 'text'),
      ];
      final target = [
        _field('x', 'tonart', 'text'),
        _field('y', 'Dauer', 'text'),
        _field('z', 'Stil', 'select', ['Klassik']),
        _field('w', 'Leer', 'text'),
      ];
      final mapped = mapExtraFields({'a': 'D-Dur', 'b': 4, 'c': 'Pop', 'd': ''}, source, target);
      expect(mapped.map((m) => [m.targetField.id, m.value]).toList(), [
        ['x', 'D-Dur'],
      ]);
    });
  });

  group('instrumentIdsFromCopiedFiles', () {
    test('drops reserved ids, null and the main group', () {
      expect(instrumentIdsFromCopiedFiles([1, 2, null, 9, 9, 4], mainGroupId: 4), [9]);
    });
  });

  group('copy targets (Ionic buildTargets)', () {
    test('admin/responsible instances, one per library, current first', () {
      const tenants = [
        OrgSongTenant(id: 2, shortName: 'B'),
        OrgSongTenant(id: 1, shortName: 'A'),
        OrgSongTenant(id: 3, shortName: 'C', songSourceTenantId: 2),
        OrgSongTenant(id: 4, shortName: 'D', songSourceTenantId: 5),
        OrgSongTenant(id: 5, shortName: 'E'),
        OrgSongTenant(id: 6, shortName: 'F'),
      ];
      final targets = buildOrgSongCopyTargets(
        currentTenantId: 1,
        orgTenants: tenants,
        rolesByTenant: {1: 1, 2: 5, 3: 1, 4: 1, 6: 2},
      );
      expect(targets.map((t) => (t.tenant.id, t.libraryId, t.libraryName)).toList(), [
        (1, 1, null),
        (2, 2, null),
        // 3 uses the library of 2, already listed
        (4, 5, 'E'),
      ]);
    });
  });

  group('copied_from', () {
    test('parses the origin and tolerates malformed values', () {
      final song = Song.fromJson({
        'name': 'X',
        'copied_from': {'tenantId': 4, 'tenantName': 'Chor', 'songId': 9, 'copiedAt': '2026-10-30T10:00:00Z'},
      });
      expect(song.copiedFrom?.tenantName, 'Chor');
      expect(Song.fromJson({'name': 'X', 'copied_from': {'tenantId': 'x'}}).copiedFrom, isNull);
      expect(Song.fromJson({'name': 'X', 'copied_from': 'bad'}).copiedFrom, isNull);
      // never written by Song updates
      expect(song.toJson().containsKey('copied_from'), isFalse);
    });

    test('copiedFromOf takes the source instance and Werk', () {
      const source = OrgSongResult(id: 9, tenantId: 4, tenantName: 'Chor', name: 'X');
      final origin = copiedFromOf(source, DateTime.utc(2026, 10, 30, 10));
      expect(origin.toJson(), {
        'tenantId': 4,
        'tenantName': 'Chor',
        'songId': 9,
        'copiedAt': '2026-10-30T10:00:00.000Z',
      });
    });

    test('RPC rows parse with group names', () {
      final row = OrgSongResult.fromJson({
        'id': 1,
        'tenant_id': 2,
        'tenant_name': 'B',
        'name': 'Amen',
        'number': 5,
        'withChoir': true,
        'withSolo': false,
        'category_names': ['Advent'],
        'field_defs': [
          {'id': 'f', 'name': 'Tonart', 'type': 'text'},
        ],
        'files': [
          {'fileName': 'a.pdf', 'fileType': null, 'url': 'u', 'instrumentId': 7, 'groupName': 'Sopran'},
        ],
        'total_count': 12,
      });
      expect(row.files.single.groupName, 'Sopran');
      expect(row.files.single.fileType, '');
      expect(row.fieldDefs?.single.name, 'Tonart');
      expect(row.totalCount, 12);
    });
  });

  test('storage path from a public URL', () {
    expect(
      OrgSongRepository.storagePathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/songs/songs/4/9/a_123.pdf'),
      'songs/4/9/a_123.pdf',
    );
    expect(OrgSongRepository.storagePathFromPublicUrl('https://example.com/a.pdf'), isNull);
  });

  group('Multi-Tenant Security: org_song_repository', () {
    final source = File('lib/data/repositories/org_song_repository.dart').readAsStringSync();

    test('search runs only via the RPC with the current tenant', () {
      expect(source, matches(RegExp(r"rpc\(\s*'search_org_songs'")));
      expect(source, contains("'p_tenant_id': currentTenantId"));
    });

    test('every songs / instruments query filters the target library', () {
      final queries = RegExp(r"\.from\('(songs|instruments)'\)[\s\S]*?;").allMatches(source);
      expect(queries, isNotEmpty);
      for (final m in queries) {
        final q = m.group(0)!;
        if (q.contains('.insert(')) {
          expect(q, contains("'tenantId': libraryId"), reason: q);
        } else {
          expect(q, contains(".eq('tenantId', libraryId)"), reason: q);
        }
      }
    });

    test('song_categories are scoped to the target library', () {
      final queries = RegExp(r"\.from\('song_categories'\)[\s\S]*?;").allMatches(source);
      for (final m in queries) {
        final q = m.group(0)!;
        expect(q.contains(".eq('tenant_id', libraryId)") || q.contains("'tenant_id': libraryId"), isTrue,
            reason: q);
      }
    });

    test('organisation lookups are scoped to the current tenant org', () {
      expect(source, contains(".eq('tenant_id', currentTenantId)"));
      expect(source, contains(".eq('tenant_group', orgId)"));
    });

    test('writes check the target library belongs to the organisation and demo guard', () {
      expect(RegExp(r'_ensureOrgLibrary\(libraryId\)').allMatches(source).length, greaterThanOrEqualTo(2));
      expect(source, contains("ensureNotDemo('copyOrgSong')"));
      expect(source, contains("ensureNotDemo('ensureSongCategories')"));
    });

    test('uploads go to the target library storage path', () {
      expect(source, contains(r"'songs/$libraryId/$songId/$fileId'"));
    });
  });
}
