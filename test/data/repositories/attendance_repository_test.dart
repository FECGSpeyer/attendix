import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Security tests for AttendanceRepository
///
/// These tests verify that ALL operations include tenantId filtering
/// to prevent cross-tenant data access.
void main() {
  late String attendanceRepoSource;

  setUpAll(() {
    final file = File('lib/data/repositories/attendance_repository.dart');
    attendanceRepoSource = file.readAsStringSync();
  });

  group('Multi-Tenant Security - AttendanceRepository', () {
    test('createAttendance sets tenantId in data', () {
      expect(
        attendanceRepoSource,
        contains("data['tenantId'] = currentTenantId"),
        reason: 'createAttendance must set tenantId in insert data',
      );
    });

    group('Write Operations - CRITICAL', () {
      test('all UPDATE operations on attendance table include tenantId filter', () {
        final updateQueries = RegExp(
          r"supabase[^;]*\.from\('attendance'\)[^;]*\.update\([^;]+",
          multiLine: true,
        ).allMatches(attendanceRepoSource);

        expect(updateQueries, isNotEmpty, reason: 'Should have update queries');

        for (final match in updateQueries) {
          final query = match.group(0)!;
          expect(
            query,
            contains(".eq('tenantId', currentTenantId)"),
            reason: 'UPDATE query missing tenantId filter:\n$query',
          );
        }
      });

      test('all DELETE operations on attendance table include tenantId filter', () {
        final deleteQueries = RegExp(
          r"supabase[^;]*\.from\('attendance'\)[^;]*\.delete\(\)[^;]+",
          multiLine: true,
        ).allMatches(attendanceRepoSource);

        expect(deleteQueries, isNotEmpty, reason: 'Should have delete queries');

        for (final match in deleteQueries) {
          final query = match.group(0)!;
          expect(
            query,
            contains(".eq('tenantId', currentTenantId)"),
            reason: 'DELETE query missing tenantId filter:\n$query',
          );
        }
      });
    });

    group('Read Operations', () {
      test('all SELECT operations on attendance table include tenantId filter', () {
        final selectQueries = RegExp(
          r"supabase[^;]*\.from\('attendance'\)\s*\n?\s*\.select\([^;]+",
          multiLine: true,
        ).allMatches(attendanceRepoSource);

        // Filter out INSERT chains
        final readQueries = selectQueries.where((m) {
          final query = m.group(0)!;
          return !query.contains('.insert(');
        }).toList();

        expect(readQueries, isNotEmpty, reason: 'Should have select queries');

        for (final match in readQueries) {
          final query = match.group(0)!;
          expect(
            query,
            contains(".eq('tenantId', currentTenantId)"),
            reason: 'SELECT query missing tenantId filter:\n$query',
          );
        }
      });
    });

    group('Core Mutation Methods', () {
      test('updateAttendance has both id and tenantId filter', () {
        final section = _extractMethodBody(attendanceRepoSource, 'updateAttendance');
        expect(section, isNotNull, reason: 'updateAttendance should exist');
        expect(section, contains(".eq('id', id)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('deleteAttendance has both id and tenantId filter', () {
        final section = _extractMethodBody(attendanceRepoSource, 'deleteAttendance');
        expect(section, isNotNull, reason: 'deleteAttendance should exist');
        expect(section, contains(".eq('id', id)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });

      test('getAttendanceById has both id and tenantId filter', () {
        final section = _extractMethodBody(attendanceRepoSource, 'getAttendanceById');
        expect(section, isNotNull, reason: 'getAttendanceById should exist');
        expect(section, contains(".eq('id', id)"));
        expect(section, contains(".eq('tenantId', currentTenantId)"));
      });
    });

    group('PersonAttendance Security - SEC-012 to SEC-016', () {
      test('updatePersonAttendance validates tenant (SEC-012)', () {
        final section = _extractMethodBody(attendanceRepoSource, 'updatePersonAttendance');
        expect(section, isNotNull);
        // Should validate tenant before update
        expect(
          section,
          contains('attendanceTenantId != currentTenantId'),
          reason: 'updatePersonAttendance must validate tenant ownership (SEC-012)',
        );
      });

      test('batchUpdatePersonAttendances validates tenant (SEC-013)', () {
        final section = _extractMethodBody(attendanceRepoSource, 'batchUpdatePersonAttendances');
        expect(section, isNotNull);
        // Should validate each record belongs to current tenant
        expect(
          section,
          contains('attendanceTenantId == currentTenantId'),
          reason: 'batchUpdatePersonAttendances must validate tenant for each record (SEC-013)',
        );
      });

      test('deletePersonAttendances validates tenant (SEC-014)', () {
        final section = _extractMethodBody(attendanceRepoSource, 'deletePersonAttendances');
        expect(section, isNotNull);
        // Should validate attendance IDs belong to current tenant
        expect(
          section,
          contains(".eq('tenantId', currentTenantId)"),
          reason: 'deletePersonAttendances must validate attendance IDs belong to tenant (SEC-014)',
        );
      });

      // LOGIC_ATT: Ionic never stores attendance.percentage and never
      // auto-creates person rows when a Termin is opened.
      test('does not write attendance.percentage nor auto-fill persons', () {
        expect(attendanceRepoSource, isNot(contains('recalculatePercentage')));
        expect(attendanceRepoSource, isNot(contains("'percentage'")));
        expect(attendanceRepoSource, isNot(contains('ensurePersonAttendances')));
      });

      test('getPersonAttendancesForPerson uses inner join for tenant (SEC-016)', () {
        // Search directly in source as method has complex signature
        expect(
          attendanceRepoSource,
          contains("attendance:attendance_id!inner"),
          reason: 'getPersonAttendancesForPerson must use inner join (SEC-016)',
        );
        expect(
          attendanceRepoSource,
          contains(".eq('attendance.tenantId', currentTenantId)"),
          reason: 'getPersonAttendancesForPerson must filter by attendance.tenantId (SEC-016)',
        );
      });

      test('getUpcomingAbsencesForPersons uses inner join for tenant', () {
        final section = _extractMethodBody(
          attendanceRepoSource,
          'getUpcomingAbsencesForPersons',
        );
        expect(section, isNotNull, reason: 'getUpcomingAbsencesForPersons should exist');
        expect(
          section,
          contains('attendance:attendance_id!inner'),
          reason: 'getUpcomingAbsencesForPersons must use inner join on attendance',
        );
        expect(
          section,
          contains(".eq('attendance.tenantId', currentTenantId)"),
          reason: 'getUpcomingAbsencesForPersons must filter by attendance.tenantId',
        );
      });

      test('getPersonAttendancesForPersons filters by attendance.tenantId', () {
        final section = _extractMethodBody(
          attendanceRepoSource,
          'getPersonAttendancesForPersons',
        );
        expect(section, isNotNull, reason: 'getPersonAttendancesForPersons should exist');
        expect(
          section,
          contains(".eq('attendance.tenantId', currentTenantId)"),
          reason:
              'getPersonAttendancesForPersons must filter by attendance.tenantId '
              '(person_attendances has no tenantId column)',
        );
        expect(
          section,
          contains("inFilter('person_id', personIds)"),
          reason: 'getPersonAttendancesForPersons must filter by person_id list',
        );
      });
    });

    group('Sprint 2a Task 7 - New Methods', () {
      test('validatePersonAttendanceTenant uses inner join with attendance.tenantId filter', () {
        final section = _extractMethodBody(
          attendanceRepoSource,
          'validatePersonAttendanceTenant',
        );
        expect(section, isNotNull, reason: 'validatePersonAttendanceTenant should exist');
        expect(
          section,
          contains('attendance:attendance_id!inner'),
          reason: 'validatePersonAttendanceTenant must use inner join on attendance',
        );
        expect(
          section,
          contains(".eq('attendance.tenantId', currentTenantId)"),
          reason: 'validatePersonAttendanceTenant must filter by attendance.tenantId',
        );
      });

      test('deletePersonAttendance validates tenant before deleting', () {
        final section = _extractMethodBody(
          attendanceRepoSource,
          'deletePersonAttendance',
        );
        expect(section, isNotNull, reason: 'deletePersonAttendance should exist');
        expect(
          section,
          contains('validatePersonAttendanceTenant'),
          reason: 'deletePersonAttendance must call validatePersonAttendanceTenant first',
        );
        expect(
          section,
          contains('RepositoryException'),
          reason: 'deletePersonAttendance must throw on cross-tenant access',
        );
      });
    });

    group('Summary Statistics', () {
      test('high tenantId filter coverage', () {
        final allAttendanceQueries = RegExp(
          r"\.from\('attendance'\)",
        ).allMatches(attendanceRepoSource).length;

        final withTenantFilter = RegExp(
          r"\.from\('attendance'\)[^;]*\.eq\('tenantId',\s*currentTenantId\)",
          multiLine: true,
        ).allMatches(attendanceRepoSource).length;

        final insertWithTenant = attendanceRepoSource.contains("data['tenantId'] = currentTenantId")
            ? 1
            : 0;

        final totalCovered = withTenantFilter + insertWithTenant;

        // ignore: avoid_print
        print('Total attendance queries: $allAttendanceQueries');
        // ignore: avoid_print
        print('With tenantId filter: $withTenantFilter');
        // ignore: avoid_print
        print('Insert with tenant: $insertWithTenant');
        // ignore: avoid_print
        print('Total covered: $totalCovered');

        final coverage = totalCovered / allAttendanceQueries;
        expect(
          coverage,
          greaterThanOrEqualTo(0.9),
          reason: 'Expected at least 90% tenantId coverage, got ${(coverage * 100).toStringAsFixed(1)}%',
        );
      });
    });
  });
}

/// Extract method body from source code
String? _extractMethodBody(String source, String methodName) {
  // Supports up to two levels of nested generics in the return type, while
  // restricting the match to a single line so the engine cannot greedily
  // span an earlier method's signature.
  final methodStart = RegExp(
    '(Future<[^\\n>]*(?:<[^\\n>]*(?:<[^\\n>]*>[^\\n>]*)?>[^\\n>]*)?>|void)\\s+$methodName\\s*[(<]',
  ).firstMatch(source);

  if (methodStart == null) return null;

  final startIndex = methodStart.start;
  int braceIndex = startIndex;
  int parenCount = 0;
  bool foundMethodBrace = false;

  for (int i = startIndex; i < source.length && !foundMethodBrace; i++) {
    final char = source[i];
    if (char == '(' || char == '{' && parenCount > 0) {
      parenCount++;
    } else if (char == ')' || char == '}' && parenCount > 1) {
      parenCount--;
    } else if (char == '{' && parenCount == 0) {
      braceIndex = i;
      foundMethodBrace = true;
    }
  }

  if (!foundMethodBrace) return null;

  int braceCount = 0;
  int endIndex = braceIndex;

  for (int i = braceIndex; i < source.length; i++) {
    if (source[i] == '{') {
      braceCount++;
    } else if (source[i] == '}') {
      braceCount--;
      if (braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
  }

  return source.substring(startIndex, endIndex);
}
