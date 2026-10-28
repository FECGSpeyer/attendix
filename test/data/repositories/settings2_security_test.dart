import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security source analysis for the SETTINGS2 package.
void main() {
  String read(String path) => File(path).readAsStringSync();

  List<String> queries(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]*;",
        dotAll: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();

  group('Multi-Tenant Security - AdminRepository', () {
    late String source;
    setUpAll(() => source = read('lib/data/repositories/admin_repository.dart'));

    test('extends BaseRepository with TenantAwareRepository', () {
      expect(source,
          matches(RegExp(r'extends BaseRepository\s+with TenantAwareRepository')));
    });

    test('every tenantUsers query filters or sets tenantId', () {
      final q = queries(source, 'tenantUsers');
      expect(q, isNotEmpty);
      for (final query in q) {
        final scoped = query.contains(".eq('tenantId', currentTenantId)") ||
            query.contains("'tenantId': currentTenantId");
        expect(scoped, isTrue, reason: 'tenantUsers query without tenant:\n$query');
      }
    });

    test('remove only deletes admins of the current tenant', () {
      final deletes =
          queries(source, 'tenantUsers').where((q) => q.contains('.delete()'));
      expect(deletes, isNotEmpty);
      for (final q in deletes) {
        expect(q, contains(".eq('role', Role.admin.value)"));
        expect(q, contains(".eq('userId',"));
      }
    });
  });

  group('Multi-Tenant Security - SETTINGS2 tenant/type updates', () {
    test('song source update targets only the current tenant row', () {
      final source = read('lib/data/repositories/song_repository.dart');
      final q = queries(source, 'tenants')
          .where((q) => q.contains('song_source_tenant_id') && q.contains('.update('));
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('id', currentTenantId)"));
      }
    });

    test('planning prefix read filters by tenant_id', () {
      final source = read('lib/data/repositories/attendance_type_repository.dart');
      final q = queries(source, 'attendance_types')
          .where((q) => q.contains('planning_prefix_instance_name'));
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('tenant_id', currentTenantId)"));
      }
    });

    // LOGIC_ATT: attendance.percentage is no longer stored (not an Ionic
    // column); any remaining flag read must still be tenant-scoped.
    test('shift_excused_as_present reads use the current tenant only', () {
      final source = read('lib/data/repositories/attendance_repository.dart');
      expect(source, isNot(contains("'percentage'")));
      final q = queries(source, 'tenants')
          .where((q) => q.contains('shift_excused_as_present'));
      for (final query in q) {
        expect(query, contains(".eq('id', currentTenantId)"));
      }
    });
  });
}
