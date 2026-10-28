import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Tests for attendance providers
///
/// These tests verify:
/// 1. Providers return empty/null when no tenant is set (hasTenantId == false)
/// 2. Providers call repository when tenant is set
/// 3. Cache invalidation works correctly after mutations
void main() {
  late String attendanceProvidersSource;

  setUpAll(() {
    final file = File('lib/core/providers/attendance_providers.dart');
    attendanceProvidersSource = file.readAsStringSync();
  });

  group('Attendance Providers', () {
    group('Tenant Guard Pattern', () {
      test('attendancesProvider returns empty when no tenant', () {
        expect(
          attendanceProvidersSource,
          contains('if (!repo.hasTenantId) return [];'),
          reason: 'attendancesProvider must return empty list when no tenant',
        );
      });

      test('upcomingAttendancesProvider returns empty when no tenant', () {
        expect(
          attendanceProvidersSource,
          matches(RegExp(
              r'upcomingAttendancesProvider.*if \(!repo\.hasTenantId\) return \[\]',
              dotAll: true)),
          reason: 'upcomingAttendancesProvider must check hasTenantId',
        );
      });

      test('attendanceByIdProvider returns null when no tenant', () {
        expect(
          attendanceProvidersSource,
          contains('if (!repo.hasTenantId) return null;'),
          reason: 'attendanceByIdProvider must return null when no tenant',
        );
      });

      test('personAttendancesProvider returns empty when no tenant', () {
        expect(
          attendanceProvidersSource,
          matches(RegExp(
              r'personAttendancesProvider.*if \(!repo\.hasTenantId\) return \[\]',
              dotAll: true)),
          reason: 'personAttendancesProvider must check hasTenantId',
        );
      });
    });

    group('Repository Integration', () {
      test('attendanceRepositoryWithTenantProvider sets tenant', () {
        expect(
          attendanceProvidersSource,
          // SOL_FIX1: per-tenant immutable instance
          contains('attendanceRepositoryForTenantProvider(tenant)'),
          reason: 'attendanceRepositoryWithTenantProvider must set tenantId',
        );
      });

      test('attendanceRepositoryWithTenantProvider watches currentTenantIdProvider',
          () {
        expect(
          attendanceProvidersSource,
          contains('ref.watch(currentTenantIdProvider)'),
          reason:
              'attendanceRepositoryWithTenantProvider must watch tenant changes',
        );
      });
    });

    group('Cache Invalidation - CreateAttendance', () {
      test('createAttendance invalidates attendancesProvider', () {
        final createSection =
            _extractMethodFromClass(attendanceProvidersSource, 'createAttendance');
        expect(createSection, isNotNull);
        expect(createSection, contains('ref.invalidate(attendancesProvider)'));
      });

      test('createAttendance invalidates upcomingAttendancesProvider', () {
        final createSection =
            _extractMethodFromClass(attendanceProvidersSource, 'createAttendance');
        expect(createSection, isNotNull);
        expect(
            createSection, contains('ref.invalidate(upcomingAttendancesProvider)'));
      });
    });

    group('Cache Invalidation - UpdateAttendance', () {
      test('updateAttendance invalidates attendancesProvider', () {
        final updateSection =
            _extractMethodFromClass(attendanceProvidersSource, 'updateAttendance');
        expect(updateSection, isNotNull);
        expect(updateSection, contains('ref.invalidate(attendancesProvider)'));
      });

      test('updateAttendance invalidates attendanceByIdProvider for specific id',
          () {
        final updateSection =
            _extractMethodFromClass(attendanceProvidersSource, 'updateAttendance');
        expect(updateSection, isNotNull);
        expect(updateSection, contains('ref.invalidate(attendanceByIdProvider(id))'));
      });
    });

    group('Cache Invalidation - DeleteAttendance', () {
      test('deleteAttendance invalidates attendancesProvider', () {
        final deleteSection =
            _extractMethodFromClass(attendanceProvidersSource, 'deleteAttendance');
        expect(deleteSection, isNotNull);
        expect(deleteSection, contains('ref.invalidate(attendancesProvider)'));
      });
    });

    group('Cache Invalidation - PersonAttendance Operations', () {
      test('createPersonAttendances invalidates attendanceByIdProvider', () {
        final section = _extractMethodFromClass(
            attendanceProvidersSource, 'createPersonAttendances');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(attendanceByIdProvider'));
      });

      test('createPersonAttendances invalidates personAttendancesProvider', () {
        final section = _extractMethodFromClass(
            attendanceProvidersSource, 'createPersonAttendances');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(personAttendancesProvider'));
      });

      test('updatePersonAttendance invalidates attendanceByIdProvider', () {
        final section = _extractMethodFromClass(
            attendanceProvidersSource, 'updatePersonAttendance');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(attendanceByIdProvider'));
      });

      test('updatePersonAttendance invalidates personAttendancesProvider', () {
        final section = _extractMethodFromClass(
            attendanceProvidersSource, 'updatePersonAttendance');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(personAttendancesProvider'));
      });

      test('batchUpdatePersonAttendances invalidates attendanceByIdProvider', () {
        final section = _extractMethodFromClass(
            attendanceProvidersSource, 'batchUpdatePersonAttendances');
        expect(section, isNotNull);
        expect(section, contains('ref.invalidate(attendanceByIdProvider'));
      });
    });

    group('Provider Patterns', () {
      test('uses FutureProvider for data loading', () {
        final futureProviderCount =
            RegExp(r'FutureProvider[.<]').allMatches(attendanceProvidersSource).length;
        expect(
          futureProviderCount,
          greaterThanOrEqualTo(4),
          reason: 'Should use FutureProvider for async data loading',
        );
      });

      test('uses FutureProvider.family for parameterized queries', () {
        expect(
          attendanceProvidersSource,
          contains('FutureProvider.family<'),
          reason: 'Should use FutureProvider.family for parameterized queries',
        );
      });

      test('uses NotifierProvider for mutations', () {
        expect(
          attendanceProvidersSource,
          contains('NotifierProvider<AttendanceNotifier'),
          reason: 'Should use NotifierProvider for mutations',
        );
      });
    });

    group('Error Handling', () {
      test('createAttendance sets error state on failure', () {
        final section =
            _extractMethodFromClass(attendanceProvidersSource, 'createAttendance');
        expect(section, isNotNull);
        expect(section, contains('AsyncValue.error(e, stack)'));
      });

      test('updateAttendance sets error state on failure', () {
        final section =
            _extractMethodFromClass(attendanceProvidersSource, 'updateAttendance');
        expect(section, isNotNull);
        expect(section, contains('AsyncValue.error(e, stack)'));
      });

      test('deleteAttendance sets error state on failure', () {
        final section =
            _extractMethodFromClass(attendanceProvidersSource, 'deleteAttendance');
        expect(section, isNotNull);
        expect(section, contains('AsyncValue.error(e, stack)'));
      });
    });
  });
}

/// Extract a method from the AttendanceNotifier class
String? _extractMethodFromClass(String source, String methodName) {
  final pattern = RegExp(
    'Future<[^>]*>\\s+$methodName\\s*\\([^)]*\\)\\s*async\\s*\\{',
  );
  final match = pattern.firstMatch(source);

  if (match == null) return null;

  final startIndex = match.start;
  int braceIndex = source.indexOf('{', match.end - 1);

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
