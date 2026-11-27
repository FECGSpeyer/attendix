
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

void main() {
  group('Multi-Tenant Security: Sol round 5', () {
    test('person detail role sync uses the tenant captured before saving', () {
      final src = readDartLibrary('lib/features/redesign/presentation/pages/rd_person_edit_page.dart');
      final start = src.indexOf('Future<void> _syncRoles(');
      expect(start, isNot(-1));
      final end = src.indexOf('await _loadUserRole(after);', start);
      final body = src.substring(start, end);
      expect(body, isNot(contains('ref.read(currentTenantIdProvider)')));
      expect(body, isNot(contains('ref.read(mainGroupProvider')));
      expect(body, contains('final tenantId = _repo?.currentTenantId;'));
      expect(body, contains('mainGroupId: await _mainGroupId,'));
    });

    test('shared person field batch read is paged with stable order', () {
      final src = readDartLibrary('lib/data/repositories/shared_person_fields.dart');
      expect(src, contains('fetchAllPages'));
      expect(src, contains(".order('id', ascending: true)"));
      expect(src, contains('.range(from, to)'));
    });

    test('new song category index continues after the max index', () {
      final src =
          readDartLibrary('lib/core/providers/song_providers.dart');
      expect(src, isNot(contains('index: categories.length')));
    });

    test('shared field writes validate the organisation against the tenant',
        () {
      final src = readDartLibrary('lib/data/repositories/profile_repository.dart');
      final start = src.indexOf('Future<void> updateSharedFieldValues(');
      final body = src.substring(start, src.indexOf('.upsert(rows', start));
      expect(body, contains("from('tenant_group_tenants')"));
      expect(body, contains(".eq('tenant_id', currentTenantId)"));
      expect(body, contains(".eq('tenant_group', organisationId)"));
    });
  });
}
