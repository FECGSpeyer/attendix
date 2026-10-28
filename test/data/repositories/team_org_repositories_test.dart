import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security tests for the Teamorganisation repositories.
///
/// Tables `agenda_items`, `tasks`, `protocols` and `attendance_types` use the
/// snake_case column `tenant_id`; `attendance` uses `tenantId`.
/// RPCs (save/publish protocol, agenda history) run only after the parent row
/// was verified to belong to the current tenant.
void main() {
  late String agendaSource;
  late String taskSource;
  late String protocolSource;

  setUpAll(() {
    agendaSource = File('lib/data/repositories/agenda_item_repository.dart').readAsStringSync();
    taskSource = File('lib/data/repositories/task_repository.dart').readAsStringSync();
    protocolSource = File('lib/data/repositories/protocol_repository.dart').readAsStringSync();
  });

  /// Every statement on [table] (from `.from('table')` up to the next `;`).
  List<String> queriesOn(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]*",
        multiLine: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();

  void expectAllFiltered(String source, String table, String filter, {bool skipInserts = true}) {
    final queries = queriesOn(source, table);
    expect(queries, isNotEmpty, reason: 'Should query $table');
    for (final q in queries) {
      if (skipInserts && q.contains('.insert(')) continue;
      expect(q, contains(filter), reason: 'Query on $table missing tenant filter:\n$q');
    }
  }

  group('Multi-Tenant Security - Teamorganisation', () {
    group('AgendaItemRepository', () {
      test('all agenda_items queries filter by tenant_id', () {
        expectAllFiltered(agendaSource, 'agenda_items', ".eq('tenant_id', currentTenantId)");
      });

      test('inserts set tenant_id', () {
        final inserts = RegExp(r"'tenant_id': currentTenantId").allMatches(agendaSource);
        expect(inserts.length, greaterThanOrEqualTo(2), reason: 'create and propose must set tenant_id');
      });

      test('updates cannot move a topic to another tenant', () {
        expect(agendaSource, contains("..remove('tenant_id')"));
      });

      test('history RPC checks ownership first', () {
        final idx = agendaSource.indexOf("rpc(");
        final check = agendaSource.lastIndexOf(".eq('tenant_id', currentTenantId)", idx);
        expect(check, greaterThan(-1));
      });
    });

    group('TaskRepository', () {
      test('all tasks queries filter by tenant_id', () {
        expectAllFiltered(taskSource, 'tasks', ".eq('tenant_id', currentTenantId)");
      });

      test('createTask sets tenant_id', () {
        expect(taskSource, contains("'tenant_id': currentTenantId"));
      });

      test('update and delete filter by id and tenant', () {
        for (final q in queriesOn(taskSource, 'tasks').where((q) => q.contains('.update(') || q.contains('.delete()'))) {
          expect(q, contains(".eq('id', id)"));
          expect(q, contains(".eq('tenant_id', currentTenantId)"));
        }
      });
    });

    group('ProtocolRepository', () {
      test('all protocols queries filter by tenant_id', () {
        expectAllFiltered(protocolSource, 'protocols', ".eq('tenant_id', currentTenantId)");
      });

      test('attendance_types queries filter by tenant_id', () {
        expectAllFiltered(protocolSource, 'attendance_types', ".eq('tenant_id', currentTenantId)");
      });

      test('attendance queries filter by tenantId', () {
        expectAllFiltered(protocolSource, 'attendance', ".eq('tenantId', currentTenantId)", skipInserts: false);
      });

      test('protocol RPCs verify the attendance belongs to the tenant', () {
        for (final rpc in ['save_protocol_section', 'publish_protocol']) {
          final idx = protocolSource.indexOf("rpc('$rpc'");
          expect(idx, greaterThan(-1), reason: '$rpc should be called');
          final before = protocolSource.substring(protocolSource.lastIndexOf('Future<', idx), idx);
          expect(before, contains('_ensureAttendanceOfTenant'), reason: '$rpc must check tenant first');
        }
      });
    });
  });
}
