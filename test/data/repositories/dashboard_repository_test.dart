import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security tests for the dashboard / administration repositories
/// (source-code analysis like the other repository tests).
///
/// Tables:
/// - player, attendance, history: `tenantId`
/// - player_absences: `tenant_id`
/// - tenants: scoped by `id` = current tenant
void main() {
  late String dashboardSource;
  late String adminSource;
  late String churchSource;

  setUpAll(() {
    dashboardSource =
        File('lib/data/repositories/dashboard_repository.dart').readAsStringSync();
    adminSource =
        File('lib/data/repositories/administration_repository.dart').readAsStringSync();
    churchSource =
        File('lib/data/repositories/church_repository.dart').readAsStringSync();
  });

  Iterable<String> queriesOn(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]+",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!);

  group('Multi-Tenant Security - DashboardRepository', () {
    test('repository is tenant aware', () {
      expect(dashboardSource, contains('with TenantAwareRepository'));
    });

    for (final table in ['player', 'attendance', 'history']) {
      test('all $table queries filter by tenantId', () {
        final queries = queriesOn(dashboardSource, table).toList();
        expect(queries, isNotEmpty, reason: 'expected $table queries');
        for (final q in queries) {
          expect(q, contains(".eq('tenantId', currentTenantId)"),
              reason: '$table query missing tenantId filter:\n$q');
        }
      });
    }

    test('player_absences queries filter by tenant_id', () {
      final queries = queriesOn(dashboardSource, 'player_absences').toList();
      expect(queries, isNotEmpty);
      for (final q in queries) {
        expect(q, contains(".eq('tenant_id', currentTenantId)"));
      }
    });

    test('tenants queries are scoped to the current tenant id', () {
      for (final q in queriesOn(dashboardSource, 'tenants')) {
        expect(q, contains(".eq('id', currentTenantId)"));
      }
    });

    test('dashboard repository performs no writes', () {
      expect(dashboardSource, isNot(contains('.update(')));
      expect(dashboardSource, isNot(contains('.insert(')));
      expect(dashboardSource, isNot(contains('.delete(')));
    });
  });

  group('Multi-Tenant Security - AdministrationRepository', () {
    test('tenant quota queries and updates are scoped to the current tenant', () {
      final queries = queriesOn(adminSource, 'tenants').toList();
      expect(queries.length, greaterThanOrEqualTo(2));
      for (final q in queries) {
        expect(q, contains(".eq('id', currentTenantId)"),
            reason: 'tenants query not scoped:\n$q');
      }
    });

    test('files_used_bytes RPC uses the current tenant', () {
      expect(adminSource, contains("'p_tenant_id': currentTenantId"));
    });

    test('church merge updates players one id at a time', () {
      final updates = RegExp(r"\.from\('player'\)\s*\.update\([^;]+")
          .allMatches(churchSource)
          .map((m) => m.group(0)!)
          .toList();
      expect(updates, isNotEmpty);
      for (final u in updates) {
        expect(u, contains(".eq('id', row['id'])"));
      }
    });
  });
}
