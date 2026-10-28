import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Security tests for DutyRepository (Dienstplan)
///
/// Source-code analysis: every query must be scoped to the current tenant.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/data/repositories/duty_repository.dart').readAsStringSync();
  });

  Iterable<String> queriesOn(String table) => RegExp(
        "supabase[^;]*\\.from\\('$table'\\)[^;]+",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!);

  group('Multi-Tenant Security - DutyRepository', () {
    test('all attendance queries filter by tenantId', () {
      final queries = queriesOn('attendance').toList();
      expect(queries, isNotEmpty);
      for (final q in queries) {
        expect(q, contains(".eq('tenantId', currentTenantId)"), reason: 'Missing tenantId filter:\n$q');
      }
    });

    test('person_unavailability SELECT/UPDATE/DELETE filter by tenant_id', () {
      final queries = queriesOn('person_unavailability').where((q) => !q.contains('.insert(')).toList();
      expect(queries, isNotEmpty);
      for (final q in queries) {
        expect(q, contains(".eq('tenant_id', currentTenantId)"), reason: 'Missing tenant_id filter:\n$q');
      }
    });

    test('person_unavailability INSERT payload uses currentTenantId', () {
      expect(source, contains("'tenant_id': currentTenantId"));
    });

    test('person_attendances SELECTs join attendance with !inner and filter attendance.tenantId', () {
      final selects = queriesOn('person_attendances').where((q) => q.contains('.select(')).toList();
      expect(selects, isNotEmpty);
      for (final q in selects) {
        expect(q, contains('attendance:attendance_id!inner'), reason: q);
        expect(q, contains(".eq('attendance.tenantId', currentTenantId)"), reason: q);
      }
    });

    test('person_attendances UPDATEs only use validated ids', () {
      final updates = queriesOn('person_attendances').where((q) => q.contains('.update(')).toList();
      expect(updates, isNotEmpty);
      for (final q in updates) {
        expect(
          q.contains('validIds') || q.contains('.inFilter(\'id\', ids)'),
          isTrue,
          reason: 'UPDATE must target validated ids:\n$q',
        );
      }
      // assign/unassign/confirm/decline validate first
      for (final method in ['assign', 'unassign', 'confirm', 'decline']) {
        final start = source.indexOf('Future<void> $method(');
        expect(start, greaterThan(-1), reason: '$method missing');
        final body = source.substring(start, source.indexOf('handleError', start));
        expect(body, contains('_validIdsForTenant('), reason: '$method must validate tenant');
      }
    });

    test('take checks the Termin belongs to the tenant before calling the RPC', () {
      final start = source.indexOf('Future<DutyTakeResult> take(');
      final rpc = source.indexOf("supabase.rpc('duty_take'", start);
      final check = source.indexOf(".eq('tenantId', currentTenantId)", start);
      expect(check, greaterThan(start));
      expect(check, lessThan(rpc));
    });
  });
}
