import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Security tests for AttendanceTypeRepository
///
/// These tests verify that ALL operations include tenant_id filtering
/// to prevent cross-tenant data access.
///
/// Tables:
/// - attendance_types: uses 'tenant_id' column
///
/// Security Model:
/// - SELECT: Must have .eq('tenant_id', currentTenantId)
/// - UPDATE: Must have .eq('tenant_id', currentTenantId)
/// - DELETE: Must have .eq('tenant_id', currentTenantId)
/// - INSERT: Must set tenant_id in the data object
void main() {
  late String repoSource;

  setUpAll(() {
    final file = File('lib/data/repositories/attendance_type_repository.dart');
    repoSource = file.readAsStringSync();
  });

  group('Multi-Tenant Security - AttendanceTypeRepository', () {
    group('Write Operations - CRITICAL', () {
      test('createType sets tenant_id in insert data', () {
        final section = _extractMethodBody(repoSource, 'createType');
        expect(section, isNotNull, reason: 'createType should exist');
        // LOGIC_SETTINGS: insert payload is built by buildInsertData
        expect(
          section,
          contains('buildInsertData(type, currentTenantId)'),
          reason: 'createType must build insert data with currentTenantId',
        );
        final builderStart = repoSource.indexOf('buildInsertData(\n');
        expect(builderStart, isNonNegative);
        expect(
          repoSource.substring(builderStart),
          contains("'tenant_id': tenantId"),
        );
      });

      test('all UPDATE operations include tenant_id filter', () {
        final updateQueries = RegExp(
          r"supabase[^;]*\.from\('attendance_types'\)[^;]*\.update\([^;]+",
          multiLine: true,
        ).allMatches(repoSource);

        expect(updateQueries, isNotEmpty, reason: 'Should have update queries');

        for (final match in updateQueries) {
          final query = match.group(0)!;
          expect(
            query,
            contains(".eq('tenant_id', currentTenantId)"),
            reason: 'UPDATE query missing tenant_id filter:\n$query',
          );
        }
      });

      test('all DELETE operations include tenant_id filter', () {
        final deleteQueries = RegExp(
          r"supabase[^;]*\.from\('attendance_types'\)[^;]*\.delete\(\)[^;]+",
          multiLine: true,
        ).allMatches(repoSource);

        expect(deleteQueries, isNotEmpty, reason: 'Should have delete queries');

        for (final match in deleteQueries) {
          final query = match.group(0)!;
          expect(
            query,
            contains(".eq('tenant_id', currentTenantId)"),
            reason: 'DELETE query missing tenant_id filter:\n$query',
          );
        }
      });
    });

    group('Read Operations', () {
      test('all SELECT operations include tenant_id filter', () {
        final selectQueries = RegExp(
          r"supabase[^;]*\.from\('attendance_types'\)\s*\n?\s*\.select\([^;]+",
          multiLine: true,
        ).allMatches(repoSource);

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
            contains(".eq('tenant_id', currentTenantId)"),
            reason: 'SELECT query missing tenant_id filter:\n$query',
          );
        }
      });
    });

    group('Core Methods Security', () {
      test('getTypes has tenant_id filter', () {
        final section = _extractMethodBody(repoSource, 'getTypes');
        expect(section, isNotNull, reason: 'getTypes should exist');
        expect(section, contains(".eq('tenant_id', currentTenantId)"));
      });

      test('getTypeById has both id and tenant_id filter', () {
        final section = _extractMethodBody(repoSource, 'getTypeById');
        expect(section, isNotNull, reason: 'getTypeById should exist');
        expect(section, contains(".eq('id', id)"));
        expect(section, contains(".eq('tenant_id', currentTenantId)"));
      });

      test('updateType has both id and tenant_id filter', () {
        final section = _extractMethodBody(repoSource, 'updateType');
        expect(section, isNotNull, reason: 'updateType should exist');
        expect(section, contains(".eq('id', id)"));
        expect(section, contains(".eq('tenant_id', currentTenantId)"));
      });

      test('deleteType has both id and tenant_id filter', () {
        final section = _extractMethodBody(repoSource, 'deleteType');
        expect(section, isNotNull, reason: 'deleteType should exist');
        expect(section, contains(".eq('id', id)"));
        expect(section, contains(".eq('tenant_id', currentTenantId)"));
      });

      test('reorderTypes has tenant_id filter on all updates', () {
        final section = _extractMethodBody(repoSource, 'reorderTypes');
        expect(section, isNotNull, reason: 'reorderTypes should exist');
        expect(section, contains(".eq('tenant_id', currentTenantId)"));
      });
    });

    group('Summary Statistics', () {
      test('high tenant_id filter coverage', () {
        final allQueries = RegExp(
          r"\.from\('attendance_types'\)",
        ).allMatches(repoSource).length;

        final withTenantFilter = RegExp(
          r"\.from\('attendance_types'\)[^;]*\.eq\('tenant_id',\s*currentTenantId\)",
          multiLine: true,
        ).allMatches(repoSource).length;

        final insertWithTenant = repoSource.contains("'tenant_id': currentTenantId")
            ? 1
            : 0;

        final totalCovered = withTenantFilter + insertWithTenant;

        // ignore: avoid_print
        print('Total attendance_types queries: $allQueries');
        // ignore: avoid_print
        print('With tenant_id filter: $withTenantFilter');
        // ignore: avoid_print
        print('Insert with tenant: $insertWithTenant');
        // ignore: avoid_print
        print('Total covered: $totalCovered');

        final coverage = totalCovered / allQueries;
        expect(
          coverage,
          greaterThanOrEqualTo(0.8),
          reason: 'Expected at least 80% tenant_id coverage, got ${(coverage * 100).toStringAsFixed(1)}%',
        );
      });
    });
  });
}

/// Extract method body from source code
String? _extractMethodBody(String source, String methodName) {
  final methodStart = RegExp(
    '(Future<[^>]*(?:<[^>]*>)?[^>]*>|void)\\s+$methodName\\s*\\(',
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
