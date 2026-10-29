import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = File('lib/features/attendance/presentation/widgets/attendance_date_change.dart').readAsStringSync();

  test('SOL_FIX38: absences are loaded before the first write; failure aborts', () {
    final load = s.indexOf('absences = await playerAbsenceRepo.getAbsencesForTenant()');
    expect(load, greaterThan(0));
    expect(load, lessThan(s.indexOf('await repo.updateAttendance(attendanceId')));
    expect(s, isNot(contains('non-fatal — proceed without absence check')));
  });

  test('SOL_FIX38: every write step checks the captured session', () {
    for (final call in [
      'await repo.updateAttendance(attendanceId',
      'await repo.updateHistoryDatesForAttendance(',
      'await repo.updateShiftAssignmentsForAttendance(',
    ]) {
      final i = s.indexOf(call);
      final before = s.substring(s.lastIndexOf('writeSession.ensureCurrent();', i), i);
      expect(before.split('\n').length, lessThan(5), reason: call);
    }
  });

  test('SOL_FIX38: caches are reloaded in finally', () {
    final fin = s.indexOf('} finally {');
    expect(fin, greaterThan(0));
    expect(s.substring(fin), contains('container.invalidate(attendanceDetailProvider(attendanceId))'));
  });
}
