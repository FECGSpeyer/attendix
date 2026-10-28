import 'dart:io';

import 'package:attendix/core/services/song_file_service.dart';
import 'package:attendix/data/repositories/shared_person_fields.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

/// PARITY_B: DB reads/writes identical to Ionic (organisation person fields,
/// general settings, profile image, song categories/files, song copy).
void main() {
  String read(String path) => File(path).readAsStringSync();

  String methodBody(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNot(-1), reason: 'missing $signature');
    final next = source.indexOf(RegExp(r'\n  (Future|///|// =)'), start + 1);
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('shared person fields (Ionic organisation fields)', () {
    test('organisationPersonKeyOf prefers global id, then appId', () {
      expect(
        organisationPersonKeyOf(TestFactories.createPerson(appId: 'u1')
            .copyWith(globalPersonId: 'g1')),
        'global:g1',
      );
      expect(organisationPersonKeyOf(TestFactories.createPerson(appId: 'u1')),
          'app:u1');
      expect(organisationPersonKeyOf(TestFactories.createPerson()), isNull);
    });

    test('mergeSharedPersonFieldValues overrides tenant values (I2)', () {
      final p = TestFactories.createPerson(id: 1, appId: 'u1')
          .copyWith(additionalFields: {'a': 1, 'b': 2});
      final other = TestFactories.createPerson(id: 2);
      final merged = mergeSharedPersonFieldValues([p, other], {
        'app:u1': {'b': 3, 'org': 'x'},
      });
      expect(merged.first.additionalFields, {'a': 1, 'b': 3, 'org': 'x'});
      expect(merged.last, other);
    });

    test('organisationFieldDefaults maps id -> defaultValue (I1)', () {
      expect(
        organisationFieldDefaults([
          {'id': 'f1', 'defaultValue': true},
          {'id': 'f2'},
        ]),
        {'f1': true, 'f2': null},
      );
      expect(organisationFieldDefaults(null), isEmpty);
    });

    test('queries are scoped by tenant_group and upsert like Ionic', () {
      final src = read('lib/data/repositories/shared_person_fields.dart');
      for (final m in RegExp(r"\.from\('tenant_group_person_fields'\)[^;]*;",
              dotAll: true)
          .allMatches(src)) {
        final q = m.group(0)!;
        if (q.contains('.upsert(')) {
          expect(q, contains("onConflict: 'tenant_group,person_key,field_id'"));
        } else {
          expect(q, contains(".eq('tenant_group', organisationId)"));
        }
      }
      expect(src, contains(".inFilter('person_key', chunk)"));
      expect(src, contains("'person_key': 'global:\$globalPersonId'"));
    });

    test('both setGlobalPersonId variants write organisation defaults (I1)',
        () {
      for (final path in [
        'lib/data/repositories/organisation_settings_repository.dart',
        'lib/data/repositories/cross_tenant_person_repository.dart',
      ]) {
        final body =
            methodBody(read(path), 'Future<void> setGlobalPersonId(');
        expect(body, contains('writeOrganisationFieldDefaults('),
            reason: path);
      }
    });

    test('people list, export and bulk edit use organisation fields (I2/I3)',
        () {
      final list = read(
          'lib/features/people/presentation/pages/people_list_page.dart');
      expect(list, contains('mergeSharedPersonFieldValues('));
      expect(list, contains('personListExtraFieldsProvider'));
      final export =
          read('lib/features/export/presentation/pages/export_page.dart');
      expect(export, contains('hydrateSharedPersonFieldValues('));
      final bulk =
          read('lib/features/people/presentation/pages/bulk_edit_page.dart');
      expect(bulk, contains('updateSharedFieldValues('));
      expect(bulk, contains('personListExtraFieldsProvider'));
    });
  });

  test('general settings writes no withExcuses / critical_rules enabled (D6)',
      () {
    final src = read(
        'lib/features/settings/presentation/pages/general_settings_page.dart');
    final update = RegExp(r"\.from\('tenants'\)\.update\(\{.*?\}\)\.eq\(",
            dotAll: true)
        .firstMatch(src)!
        .group(0)!;
    expect(update, isNot(contains("'withExcuses'")));
    expect(update, isNot(contains("'enabled'")));
  });

  test('profile image URL is stored without ?v= (D7)', () {
    final body = methodBody(
        read('lib/data/repositories/profile_repository.dart'),
        'Future<String> uploadOwnImage(');
    expect(body, isNot(contains('?v=')));
  });

  test('deleteSongCategory only deletes (D8)', () {
    final body = methodBody(read('lib/data/repositories/song_repository.dart'),
        'Future<void> deleteSongCategory(');
    expect(body, contains('.delete()'));
    expect(body, isNot(contains('.update(')));
    expect(body, contains(".eq('tenant_id', songTenantId)"));
  });

  test('song files are written with Ionic keys only (D14)', () {
    expect(
      songFileJson({
        'storageName': 's',
        'fileName': 'f.pdf',
        'fileType': 'application/pdf',
        'url': 'u',
        'created_at': '2024-01-01',
      }),
      {
        'storageName': 's',
        'fileName': 'f.pdf',
        'fileType': 'application/pdf',
        'url': 'u',
        'instrumentId': null,
      },
    );
    expect(read('lib/core/services/song_file_service.dart'),
        isNot(contains("'created_at': DateTime")));
  });

  test('song copy does not send category_ids (D15)', () {
    expect(
        read('lib/features/songs/presentation/widgets/copy_to_tenant_sheet.dart'),
        isNot(contains("'category_ids':")));
  });
}
