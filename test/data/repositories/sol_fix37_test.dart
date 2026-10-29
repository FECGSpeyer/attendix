import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _body(String path, String start, String end) {
  final s = File(path).readAsStringSync();
  final i = s.indexOf(start);
  return s.substring(i, s.indexOf(end, i + start.length));
}

void main() {
  const plans = 'lib/data/repositories/public_plan_repository.dart';

  test('SOL_FIX37: shared plan saves fail when no row was updated', () {
    for (final (start, end) in [
      ('Future<void> updateSharedAttendancePlan(', '/// An ad-hoc plan by its id'),
      ('Future<void> updateSharedPlan(', '/// Columns written by'),
    ]) {
      final body = _body(plans, start, end);
      expect(body, contains(".select('id')"), reason: start);
      expect(body, contains('throw StateError('), reason: start);
    }
  });

  test('SOL_FIX37: Meine Termine are paged in a stable order, tenant-filtered', () {
    final body = _body('lib/data/repositories/sign_in_out_repository.dart',
        'Future<List<CrossTenantPersonAttendance>> getPersonAttendances(', 'getAllUpcomingAttendancesForSignout(');
    expect(body, contains('fetchAllPages'));
    expect(body, contains(".order('id', ascending: true).range(from, to)"));
    expect(body, contains(".eq('attendance.tenantId', currentTenantId)"));
  });
}
