import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Multi-Tenant Security tests for PlayerAbsenceRepository and
/// ImportRepository (source-code analysis).
///
/// Tables:
/// - player_absences / tenant_role_permissions: snake_case `tenant_id`
/// - person_attendances: no tenant column -> inner join on attendance.tenantId
/// - player / songs: `tenantId`
void main() {
  late String absenceSource;
  late String importSource;

  setUpAll(() {
    absenceSource =
        File('lib/data/repositories/player_absence_repository.dart').readAsStringSync();
    importSource =
        File('lib/data/repositories/import_repository.dart').readAsStringSync();
  });

  group('Multi-Tenant Security - PlayerAbsenceRepository', () {
    test('all player_absences SELECT/DELETE queries filter by tenant_id', () {
      final queries = RegExp(
        r"supabase[^;]*\.from\('player_absences'\)[^;]*\.(select|delete)\([^;]+",
        multiLine: true,
      ).allMatches(absenceSource).toList();

      // select x2 (person, tenant), delete x1 – insert chain excluded below
      final nonInsert =
          queries.where((m) => !m.group(0)!.contains('.insert(')).toList();
      expect(nonInsert.length, greaterThanOrEqualTo(3));
      for (final m in nonInsert) {
        expect(
          m.group(0),
          contains(".eq('tenant_id', currentTenantId)"),
          reason: 'player_absences query missing tenant filter:\n${m.group(0)}',
        );
      }
    });

    test('deleteAbsence filters by id AND tenant_id', () {
      final query = RegExp(
        r"\.from\('player_absences'\)\s*\.delete\(\)[^;]+",
        multiLine: true,
      ).firstMatch(absenceSource)!.group(0)!;
      expect(query, contains(".eq('id', id)"));
      expect(query, contains(".eq('tenant_id', currentTenantId)"));
    });

    test('addAbsence sets tenant_id from currentTenantId', () {
      expect(absenceSource, contains("data['tenant_id'] = currentTenantId"));
    });

    test('role flags are not queried here (single source: RolePermissionRepository)', () {
      expect(absenceSource, isNot(contains("'tenant_role_permissions'")));
    });

    test('person_attendances reads use tenant-scoped inner join', () {
      final selects = RegExp(
        r"\.from\('person_attendances'\)\s*\.select\([^;]+",
        multiLine: true,
      ).allMatches(absenceSource).toList();
      expect(selects, isNotEmpty);
      for (final m in selects) {
        final q = m.group(0)!;
        expect(q, contains('attendance:attendance_id!inner'));
        expect(q, contains(".eq('attendance.tenantId', currentTenantId)"));
      }
    });

    test('person_attendances updates are scoped to the person', () {
      final updates = RegExp(
        r"\.from\('person_attendances'\)\s*\.update\([^;]+",
        multiLine: true,
      ).allMatches(absenceSource).toList();
      expect(updates, isNotEmpty);
      for (final m in updates) {
        expect(m.group(0), contains(".eq('person_id',"));
      }
    });

    test('attendance_types lookup filters by tenant_id', () {
      final q = RegExp(r"\.from\('attendance_types'\)[^;]+", multiLine: true)
          .firstMatch(absenceSource)!
          .group(0)!;
      expect(q, contains(".eq('tenant_id', currentTenantId)"));
    });
  });

  group('Multi-Tenant Security - ImportRepository', () {
    test('player/songs SELECT queries filter by tenantId', () {
      final selects = RegExp(
        r"supabase[^;]*\.from\('(player|songs)'\)\s*\.select\([^;]+",
        multiLine: true,
      ).allMatches(importSource).toList();
      expect(selects.length, 2);
      for (final m in selects) {
        // songs: effective song library (Werk-Synchronisierung source tenant
        // or the current tenant), Ionic getExistingNumbers.
        final q = m.group(0)!;
        expect(
          q.contains(".eq('tenantId', currentTenantId)") ||
              q.contains(".eq('tenantId', libraryTenantId)") ||
              // SOL_FIX1: tenant captured once for all pages
              q.contains(".eq('tenantId', tenantId)"),
          isTrue,
          reason: q,
        );
      }
      expect(importSource, contains('final libraryTenantId = songTenantId ?? currentTenantId;'));
      expect(importSource, contains('final tenantId = currentTenantId;'));
    });

    test('inserts always set tenantId (current tenant / song library)', () {
      expect("data['tenantId'] = currentTenantId".allMatches(importSource).length, 1);
      expect("data['tenantId'] = songTenantId ?? currentTenantId".allMatches(importSource).length, 1);
    });

    test('tenants lookup is restricted to the current tenant row', () {
      final q = RegExp(r"\.from\('tenants'\)[^;]+", multiLine: true)
          .firstMatch(importSource)!
          .group(0)!;
      expect(q, contains(".eq('id', currentTenantId)"));
    });
  });
}
