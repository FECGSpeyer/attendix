// SOL_FIX3: tenant-bound bulk jobs, church merge and paged "all rows" queries.
import 'dart:io';

import 'package:attendix/core/providers/cross_tenant_person_providers.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/import_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/providers/user_registration_providers.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/repositories/user_registration_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

String _read(String path) => File(path).readAsStringSync();

/// Body of [method] in [source] (from its signature to the next method doc).
String _method(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature not found');
  final next = source.indexOf('\n  /// ', start + signature.length);
  return source.substring(start, next == -1 ? source.length : next);
}

/// Records the tenant every account is created in; switches the app's
/// tenant while the first account is being created.
class _FakeRegistrationRepo extends UserRegistrationRepository {
  _FakeRegistrationRepo(super.ref, this.log, this.onFirstCreate);

  final List<(int, int?)> log;
  final void Function() onFirstCreate;

  @override
  Future<int?> getMainGroupId() async => 7;

  @override
  Future<String> createPlayerAccount(Person person, {int? mainGroupId}) async {
    if (log.isEmpty) onFirstCreate();
    await Future<void>.delayed(Duration.zero);
    log.add((currentTenantId, person.id));
    return 'app-${person.id}';
  }
}

void main() {
  group('Multi-Tenant Security: SOL_FIX3 bound bulk jobs', () {
    test('bulk account creation stays in the tenant it started in', () async {
      var tenant = 1;
      final log = <(int, int?)>[];
      late ProviderContainer container;
      container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => tenant),
        userRegistrationRepositoryForTenantProvider.overrideWith(
          (ref, tenantId) => _FakeRegistrationRepo(ref, log, () {
            // Tenant switch A→B in the middle of the job.
            tenant = 2;
            container.invalidate(currentTenantIdProvider);
          })..bindTenantId(tenantId!),
        ),
      ]);
      addTearDown(container.dispose);

      final persons = TestFactories.createPersonList(3, tenantId: 1);
      final result = await container
          .read(accountCreationNotifierProvider.notifier)
          .createAccounts(persons);

      expect(result.created, 3);
      expect(container.read(currentTenantIdProvider), 2);
      expect(log.map((e) => e.$1), [1, 1, 1]);
    });

    test('WithTenant repositories are per-tenant bound instances', () {
      var tenant = 1;
      final container = ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWith((ref) => tenant),
      ]);
      addTearDown(container.dispose);

      final regA = container.read(userRegistrationRepositoryWithTenantProvider);
      final filesA = container.read(filesRepositoryWithTenantProvider);
      final importA = container.read(importRepositoryWithTenantProvider);
      final crossA =
          container.read(crossTenantPersonRepositoryWithTenantProvider);

      tenant = 2;
      container.invalidate(currentTenantIdProvider);

      final regB = container.read(userRegistrationRepositoryWithTenantProvider);
      expect(identical(regA, regB), isFalse);
      expect(regA.currentTenantId, 1);
      expect(regB.currentTenantId, 2);
      expect(filesA.currentTenantId, 1);
      expect(importA.currentTenantId, 1);
      expect(crossA.currentTenantId, 1);
      expect(container.read(filesRepositoryWithTenantProvider).currentTenantId,
          2);
      expect(() => regA.setTenantId(2), throwsStateError);
      expect(() => filesA.setTenantId(2), throwsStateError);
      expect(() => importA.setTenantId(2), throwsStateError);
      expect(() => crossA.setTenantId(2), throwsStateError);
    });

    test('providers never mutate a shared repository instance', () {
      for (final (path, name) in [
        ('lib/core/providers/user_registration_providers.dart',
            'userRegistration'),
        ('lib/core/providers/files_providers.dart', 'files'),
        ('lib/core/providers/import_providers.dart', 'import'),
        ('lib/core/providers/cross_tenant_person_providers.dart',
            'crossTenantPerson'),
      ]) {
        final src = _read(path);
        final start = src.indexOf('final ${name}RepositoryWithTenantProvider');
        expect(start, isNot(-1), reason: path);
        final body = src.substring(start, src.indexOf('});', start));
        expect(body, contains('${name}RepositoryForTenantProvider(tenantId)'),
            reason: path);
        expect(body, isNot(contains('setTenantId(')), reason: path);
      }
    });

    test('notifier loops bind the repository once before the loop', () {
      final reg = _read('lib/core/providers/user_registration_providers.dart');
      final bulk = _method(reg, 'Future<AccountCreationResult> createAccounts(');
      expect(bulk, contains('final repo = _boundRepo();'));
      expect(bulk.indexOf('final repo = _boundRepo();'),
          lessThan(bulk.indexOf('await')));
      expect(bulk, contains('await repo.createPlayerAccount('));
      expect(reg, isNot(contains('mainGroupProvider')));

      final song = _read('lib/core/providers/song_providers.dart');
      final reorder = _method(song, 'Future<bool> reorder(List<SongCategory>');
      expect(reorder, contains('final repo = _repo;'));
      expect(reorder, isNot(contains('await _repo.')));

      final files =
          _read('lib/features/settings/presentation/pages/files_page.dart');
      final upload = _method(files, 'Future<void> _upload()');
      expect(upload, contains('final repo = _repo;'));
      expect(upload, isNot(contains('await _repo.uploadFile')));
    });

    test('main group is read from the bound tenant', () {
      final body = _method(
          _read('lib/data/repositories/user_registration_repository.dart'),
          'Future<int?> getMainGroupId()');
      expect(body, contains(".eq('tenantId', currentTenantId)"));
      expect(body, contains(".eq('maingroup', true)"));
    });
  });

  group('SOL_FIX3 church merge', () {
    final src = _read('lib/data/repositories/church_repository.dart');
    late final merge = _method(src, 'Future<int> mergeChurches(');

    test('loads all referencing persons paged, filtered and ordered', () {
      final load = _method(src,
          'Future<List<Map<String, dynamic>>> _playersReferencingChurch(');
      expect(load, contains('fetchAllPages'));
      expect(load, contains('.eq(_churchFilterColumn, churchId)'));
      expect(load, contains(".order('id')"));
      expect(load, contains('.range(from, to)'));
      expect(src, contains("'additional_fields->>\$kChurchFieldKey'"));
      expect(merge, isNot(contains(".not('additional_fields', 'is', null)")));
    });

    test('each update is scoped to id + tenantId and checked', () {
      expect(merge, contains(".eq('id', row['id'] as Object)"));
      expect(merge, contains(".eq('tenantId', row['tenantId'] as Object)"));
      expect(merge, contains(".select('id')"));
      expect(merge, contains('failed++'));
    });

    test('duplicate is deleted only after all updates succeeded', () {
      final failCheck = merge.indexOf('if (failed > 0)');
      final recheck = merge.indexOf('.eq(_churchFilterColumn, duplicateId)');
      final delete = merge.indexOf(".from('churches').delete()");
      expect(failCheck, isNot(-1));
      expect(recheck, isNot(-1));
      expect(delete, greaterThan(failCheck));
      expect(delete, greaterThan(recheck));
      expect(merge, contains('throw ChurchMergeIncompleteException'));
    });
  });

  group('SOL_FIX3 paged all-rows queries', () {
    test('no large .range/.limit values left in lib/', () {
      final big = RegExp(r'\.(range\(\s*0\s*,\s*\d{4,}|limit\(\s*\d{4,})');
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (big.hasMatch(f.readAsStringSync())) offenders.add(f.path);
      }
      expect(offenders, isEmpty);
    });

    test('message stats and recipients use fetchAllPages, ordered by id', () {
      final src = _read('lib/data/repositories/message_repository.dart');
      for (final sig in [
        'Future<Map<String, MessageStats>> getStats(',
        'Future<List<MessageRecipient>> getRecipients(',
      ]) {
        final body = _method(src, sig);
        expect(body, contains('fetchAllPages'), reason: sig);
        expect(body, contains(".order('id', ascending: true)"), reason: sig);
        expect(body, contains('final tenantId = currentTenantId;'), reason: sig);
        expect(body, contains(".eq('tenantId', tenantId)"), reason: sig);
        expect(body, contains('.range(from, to)'), reason: sig);
      }
    });

    test('duty counts use fetchAllPages, ordered by id, tenant filtered', () {
      final body = _method(
          _read('lib/data/repositories/duty_repository.dart'),
          'Future<Map<int, int>> getDutyCounts(');
      expect(body, contains('fetchAllPages'));
      expect(body, contains(".order('id', ascending: true)"));
      expect(body, contains('final tenantId = currentTenantId;'));
      expect(body, contains(".eq('attendance.tenantId', tenantId)"));
      expect(body, contains('.range(pageFrom, pageTo)'));
    });
  });
}
