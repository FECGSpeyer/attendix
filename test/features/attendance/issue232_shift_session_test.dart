import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// #232: the shift recomputation writes under the session captured when the
// user acted; each status write re-checks it before the mutation.
void main() {
  String src(String p) => File(p).readAsStringSync();

  test('repository passes the session to every status write', () {
    final s = src('lib/data/repositories/attendance_repository.dart');
    final start = s.indexOf('Future<void> updateShiftAssignmentsForAttendance(');
    expect(start, isNonNegative);
    final body = s.substring(start, s.indexOf("handleError(e, stack, 'updateShiftAssignmentsForAttendance')", start));
    expect(body, contains('bool Function()? isSessionCurrent'));
    expect(body, contains('String? actingUserId'));
    expect(body, contains('isSessionCurrent: isSessionCurrent,'));
    expect(body, contains('actingUserId: actingUserId,'));
  });

  test('every caller hands over its captured write session', () {
    for (final path in [
      'lib/features/attendance/presentation/widgets/attendance_date_change.dart',
      'lib/features/attendance/presentation/pages/attendance_detail_page.dart',
    ]) {
      final s = src(path);
      var from = 0;
      var calls = 0;
      while (true) {
        final i = s.indexOf('updateShiftAssignmentsForAttendance(', from);
        if (i < 0) break;
        final call = s.substring(i, s.indexOf(');', i));
        expect(call, contains('isSessionCurrent: writeSession.isCurrent'), reason: path);
        expect(call, contains('actingUserId: writeSession.userId'), reason: path);
        calls++;
        from = i + 1;
      }
      expect(calls, greaterThan(0), reason: path);
    }
  });

  test('time pickers capture the session before the picker await', () {
    final s = src('lib/features/attendance/presentation/pages/attendance_detail_page.dart');
    for (final fn in ['_selectStartTime', '_selectEndTime']) {
      final start = s.indexOf('Future<void> $fn() async {');
      final capture = s.indexOf('captureWriteSession()', start);
      final picker = s.indexOf('await showAppTimePicker(', start);
      expect(capture, isNonNegative, reason: fn);
      expect(capture, lessThan(picker), reason: fn);
    }
  });
}
