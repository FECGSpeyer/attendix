import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security source analysis for the STATS_PEOPLE_FIXES package.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// All supabase query chains (from `.from(` up to the terminating `;`).
  List<String> queries(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]*;",
        dotAll: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();

  group('Multi-Tenant Security - CrossTenantPersonRepository', () {
    late String source;
    setUpAll(() {
      source = read('lib/data/repositories/cross_tenant_person_repository.dart');
    });

    test('extends BaseRepository with TenantAwareRepository', () {
      expect(
        source,
        matches(RegExp(r'extends BaseRepository\s+with TenantAwareRepository')),
      );
    });

    test('every player query is restricted with inFilter on tenantId', () {
      final playerQueries = queries(source, 'player');
      expect(playerQueries, isNotEmpty);
      for (final q in playerQueries) {
        expect(q, contains(".inFilter('tenantId',"),
            reason: 'Cross-tenant query must be limited to linked tenants:\n$q');
      }
    });

    test('updates include the current tenant in the allowed set', () {
      for (final q in queries(source, 'player').where((q) => q.contains('.update('))) {
        expect(q, contains('[currentTenantId, ...linkedTenantIds]'));
      }
    });
  });

  group('Multi-Tenant Security - GroupRepository sort orders', () {
    late String source;
    setUpAll(() => source = read('lib/data/repositories/group_repository.dart'));

    test('instrument sort_order updates filter by id and tenantId', () {
      final q = queries(source, 'instruments')
          .where((q) => q.contains("'sort_order'") && q.contains('.update('))
          .toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('id',"));
        expect(query, contains(".eq('tenantId', currentTenantId)"));
      }
    });

    test('category sort_order updates filter by id and tenant_id', () {
      final q = queries(source, 'group_categories')
          .where((q) => q.contains("'sort_order'") && q.contains('.update('))
          .toList();
      expect(q, isNotEmpty);
      for (final query in q) {
        expect(query, contains(".eq('id',"));
        expect(query, contains(".eq('tenant_id', currentTenantId)"));
      }
    });
  });

  group('Multi-Tenant Security - AttendanceRepository export batch', () {
    test('getPersonAttendancesForAttendances joins on the current tenant', () {
      final source = read('lib/data/repositories/attendance_repository.dart');
      final start = source.indexOf('getPersonAttendancesForAttendances(');
      expect(start, greaterThan(-1));
      final body = source.substring(start, start + 2000);
      expect(body, contains('!inner'));
      expect(body, contains(".eq('attendance.tenantId', currentTenantId)"));
    });
  });

  group('Multi-Tenant Security - PlayerRepository email match', () {
    test('email duplicate check is case-insensitive and tenant-filtered', () {
      final source = read('lib/data/repositories/player_repository.dart');
      final start = source.indexOf('playerExistsInTenant(');
      final body = source.substring(start, start + 2000);
      expect(body, contains(".ilike('email'"));
      expect(body, contains(".eq('tenantId', targetTenantId)"));
    });
  });

  group('Multi-Tenant Security - TenantCreateRepository', () {
    late String source;
    setUpAll(() =>
        source = read('lib/data/repositories/tenant_create_repository.dart'));

    test('creator becomes admin via Role enum (not a magic number)', () {
      expect(source, contains("'role': Role.admin.value"));
    });

    test('all follow-up inserts are scoped to the new tenant id', () {
      expect(source, contains("'tenantId': tenantId"));
      expect(source, contains('buildMainGroupPayload(tenantId: tenantId'));
      expect(source, contains('buildDefaultAttendanceTypes(tenantId: tenantId'));
      expect(source, isNot(contains('.update(')));
      expect(source, isNot(contains('.delete(')));
    });
  });

  group('Multi-Tenant Security - performance history', () {
    test('history and rehearsal queries filter by tenantId', () {
      final source = read('lib/core/providers/history_providers.dart');
      for (final q in [...queries(source, 'history'), ...queries(source, 'attendance')]) {
        expect(q, contains(".eq('tenantId', tenant.id!)"), reason: q);
      }
    });

    test('history uses the songId DB column', () {
      final source = read('lib/features/history/presentation/pages/history_page.dart');
      expect(source, contains("'songId': songId"));
      expect(source, isNot(contains("'song_id': songId")));
    });
  });
}
