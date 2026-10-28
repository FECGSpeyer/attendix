import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/people_shift_status.dart';
import 'package:attendix/core/utils/people_sort.dart';
import 'package:attendix/data/models/shift/shift_definition.dart';
import 'package:attendix/data/models/shift/shift_instance.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localeCompareDe (Ionic localeCompare)', () {
    test('is case-insensitive', () {
      final names = ['bauer', 'Adler', 'Clemens'];
      names.sort(localeCompareDe);
      expect(names, ['Adler', 'bauer', 'Clemens']);
    });

    test('sorts umlauts with their base letter', () {
      final names = ['Zimmer', 'Özdemir', 'Otto', 'Pohl'];
      names.sort(localeCompareDe);
      expect(names, ['Otto', 'Özdemir', 'Pohl', 'Zimmer']);
    });
  });

  group('testResultValue', () {
    test('strips the percent sign', () {
      expect(testResultValue('85%'), 85);
      expect(testResultValue('72.5'), 72.5);
    });

    test('missing or invalid values count as 0', () {
      expect(testResultValue(null), 0);
      expect(testResultValue(''), 0);
      expect(testResultValue('n/a'), 0);
    });
  });

  group('peopleStatusByShift (Ionic Utils.getStatusByShift)', () {
    // 1 day early shift 06:00 (8h), 1 day late shift 14:00 (8h), 1 day free.
    const plan = ShiftPlan(
      name: 'Plan',
      definition: [
        ShiftDefinition(startTime: '06:00', duration: 8, repeatCount: 1),
        ShiftDefinition(startTime: '14:00', duration: 8, repeatCount: 1),
        ShiftDefinition(startTime: '00:00', duration: 0, free: true, repeatCount: 1),
      ],
      shifts: [ShiftInstance(date: '2026-01-02', name: 'B')],
    );

    ({AttendanceStatus status, String note}) run(String date,
            {String? shiftName}) =>
        peopleStatusByShift(
          shift: plan,
          attDate: date,
          attendanceStart: '19:00',
          attendanceEnd: '21:00',
          defaultStatus: AttendanceStatus.neutral,
          shiftStart: '2026-01-01',
          shiftName: shiftName,
        );

    test('no plan → default status', () {
      final r = peopleStatusByShift(
        shift: null,
        attDate: '2026-01-02',
        attendanceStart: '19:00',
        attendanceEnd: '21:00',
        defaultStatus: AttendanceStatus.present,
      );
      expect(r.status, AttendanceStatus.present);
      expect(r.note, '');
    });

    test('late shift overlapping the rehearsal → excused "Schichtbedingt"', () {
      final r = run('2026-01-02');
      expect(r.status, AttendanceStatus.excused);
      expect(r.note, 'Schichtbedingt');
    });

    test('early shift day does not overlap the evening', () {
      final r = run('2026-01-04'); // cycle day 0 again (early shift)
      expect(r.status, AttendanceStatus.neutral);
    });

    test('unknown shift name throws like Ionic', () {
      expect(() => run('2026-01-02', shiftName: 'X'), throwsStateError);
    });

    test('named shift instance sets the cycle start', () {
      // 'B' starts the cycle on 2026-01-02 → that day is the early shift.
      final r = run('2026-01-02', shiftName: 'B');
      expect(r.status, AttendanceStatus.neutral);
    });
  });
}
