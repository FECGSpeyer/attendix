import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for parents_providers.
///
/// Sprint 2a Task 4 migrated `parentChildrenProvider` and
/// `childrenAttendancesProvider` from raw `supabaseClientProvider` access
/// to repository-pattern calls. These tests pin that no future change
/// re-introduces a repository bypass.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/people/data/providers/parents_providers.dart',
    ).readAsStringSync();
  });

  group('parents_providers repository migration (Sprint 2a Task 4)', () {
    test('uses repositories, not supabaseClientProvider directly', () {
      expect(
        source,
        isNot(contains('supabaseClientProvider')),
        reason:
            'parents_providers should fetch via playerRepositoryWithTenantProvider '
            'and attendanceRepositoryWithTenantProvider, not raw Supabase client.',
      );
    });

    test('does not force-unwrap tenant.id (no direct tenant access needed)', () {
      expect(
        source,
        isNot(contains('tenant.id!')),
        reason:
            'tenantId filtering belongs in the repository TenantAware mixin, '
            'not via tenant.id! in feature providers.',
      );
    });

    test('parentChildrenProvider delegates to PlayerRepository.getChildrenForParent', () {
      expect(
        source,
        contains('repo.getChildrenForParent('),
        reason:
            'parentChildrenProvider should call '
            'PlayerRepository.getChildrenForParent.',
      );
    });

    test(
        'childrenAttendancesProvider delegates to '
        'AttendanceRepository.getPersonAttendancesForPersons', () {
      expect(
        source,
        contains('repo.getPersonAttendancesForPersons('),
        reason:
            'childrenAttendancesProvider should call '
            'AttendanceRepository.getPersonAttendancesForPersons.',
      );
    });

    test('preserves hasTenantId guard on both migrated providers', () {
      // Two guards: one in parentChildrenProvider, one in childrenAttendancesProvider.
      final guardHits = 'if (!repo.hasTenantId)'.allMatches(source).length;
      expect(
        guardHits,
        greaterThanOrEqualTo(2),
        reason:
            'Both migrated providers must guard with hasTenantId before '
            'making any data request.',
      );
    });
  });
}
