import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/shift_utils.dart';
import 'package:attendix/data/models/shift/shift_definition.dart';
import 'package:attendix/data/models/shift/shift_instance.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const n = AttendanceStatus.neutral;
  const e = AttendanceStatus.excused;
  const p = AttendanceStatus.present;

  // 2 early shifts (06:00, 8h), then 2 days off.
  const early = ShiftPlan(
    id: 'early',
    name: 'Früh',
    definition: [
      ShiftDefinition(startTime: '06:00', duration: 8, repeatCount: 2),
      ShiftDefinition(startTime: '00:00', duration: 0, free: true, repeatCount: 2),
    ],
    shifts: [ShiftInstance(date: '2026-01-03', name: 'B')],
  );

  // Night shift 22:00 + 10h, then a day off.
  const night = ShiftPlan(
    id: 'night',
    name: 'Nacht',
    definition: [
      ShiftDefinition(startTime: '22:00', duration: 10, repeatCount: 1),
      ShiftDefinition(startTime: '00:00', duration: 0, free: true, repeatCount: 1),
    ],
  );

  ShiftStatusResult status(ShiftPlan? plan, DateTime day, String start, String end,
          {String? shiftStart = '2026-01-01', String? shiftName}) =>
      ShiftUtils.getStatusByShift(
        shift: plan,
        attendanceDate: day,
        attendanceStart: start,
        attendanceEnd: end,
        defaultStatus: n,
        shiftStart: shiftStart,
        shiftName: shiftName,
      );

  group('ShiftUtils.getStatusByShift (Ionic Utils.getStatusByShift)', () {
    test('working shift overlapping the Termin → Entschuldigt "Schichtbedingt"', () {
      final r = status(early, DateTime(2026, 1, 2), '07:00', '09:00');
      expect(r.status, e);
      expect(r.note, 'Schichtbedingt');
    });

    test('free day / no overlap → default status, empty note', () {
      expect(status(early, DateTime(2026, 1, 3), '19:00', '21:00').status, n);
      expect(status(early, DateTime(2026, 1, 2), '19:00', '21:00').status, n);
      expect(status(early, DateTime(2026, 1, 2), '19:00', '21:00').note, '');
    });

    test('rotation repeats after the cycle', () {
      // Cycle of 4 days: Jan 5 + 6 are working again.
      expect(status(early, DateTime(2026, 1, 5), '07:00', '08:00').status, e);
      expect(status(early, DateTime(2026, 1, 8), '07:00', '08:00').status, n);
    });

    test('night shift of the previous day reaching into the Termin', () {
      // Jan 1 22:00 → Jan 2 08:00 overlaps Jan 2 07:00-09:00.
      expect(status(night, DateTime(2026, 1, 2), '07:00', '09:00').status, e);
      // Jan 2 is free and Jan 3 22:00 is after the Termin.
      expect(status(night, DateTime(2026, 1, 2), '10:00', '12:00').status, n);
    });

    test('shift start in the future → default', () {
      expect(status(early, DateTime(2026, 1, 2), '07:00', '09:00', shiftStart: '2026-02-01').status, n);
    });

    test('shift name uses the date of the named shift', () {
      // Named shift "B" starts the rotation on Jan 3.
      expect(status(early, DateTime(2026, 1, 3), '07:00', '09:00', shiftName: 'B').status, e);
      expect(status(early, DateTime(2026, 1, 5), '07:00', '09:00', shiftName: 'B').status, n);
    });

    test('unknown shift name throws like Ionic', () {
      expect(
        () => status(early, DateTime(2026, 1, 3), '07:00', '09:00', shiftName: 'X'),
        throwsA(isA<ShiftNameNotFoundException>()),
      );
      final r = ShiftUtils.statusByShiftOrDefault(
        shift: early,
        attendanceDate: DateTime(2026, 1, 3),
        attendanceStart: '07:00',
        attendanceEnd: '09:00',
        defaultStatus: n,
        shiftName: 'X',
      );
      expect(r.status, n);
    });

    test('no plan / empty definition → default', () {
      expect(status(null, DateTime(2026, 1, 2), '07:00', '09:00').status, n);
      expect(status(const ShiftPlan(name: 'x'), DateTime(2026, 1, 2), '07:00', '09:00').status, n);
    });

    test('ISO noon UTC date is evaluated on its local day', () {
      final r = ShiftUtils.getStatusByShift(
        shift: early,
        attendanceDate: DateTime(2026, 1, 2, 12).toUtc(),
        attendanceStart: '07:00',
        attendanceEnd: '09:00',
        defaultStatus: n,
        shiftStart: '2026-01-01',
      );
      expect(r.status, e);
    });
  });

  test('isWorkExcused', () {
    expect(ShiftUtils.isWorkExcused('Schichtbedingt'), isTrue);
    expect(ShiftUtils.isWorkExcused('Arbeitsbedingt (Nachtdienst)'), isTrue);
    expect(ShiftUtils.isWorkExcused('Urlaub'), isFalse);
    expect(ShiftUtils.isWorkExcused(null), isFalse);
  });

  group('ShiftUtils.shiftUpdatesForAttendance (Ionic updateShiftAssignmentsForAttendance)', () {
    final now = DateTime(2026, 1, 1, 10);
    final persons = {
      1: const ShiftPerson(shiftId: 'early', shiftStart: '2026-01-01'),
      2: const ShiftPerson(shiftId: 'early', shiftStart: '2026-01-01'),
      3: const ShiftPerson(shiftId: 'early', shiftStart: '2026-01-03'),
      4: const ShiftPerson(),
    };

    List<ShiftAssignmentUpdate> run({
      String date = '2026-01-02T11:00:00.000Z',
      String? start = '07:00',
      String? end = '09:00',
      bool allDay = false,
      required List<ShiftAttendanceRow> rows,
    }) =>
        ShiftUtils.shiftUpdatesForAttendance(
          attendanceDate: date,
          attendanceStart: start,
          attendanceEnd: end,
          typeStart: '19:00',
          typeEnd: '21:00',
          typeAllDay: allDay,
          defaultStatus: n,
          rows: rows,
          persons: persons,
          shifts: const [early],
          now: now,
        );

    test('excuses default rows, keeps manual statuses, resets stale shift excuses', () {
      final updates = run(rows: const [
        ShiftAttendanceRow(id: 'a', personId: 1, status: n),
        ShiftAttendanceRow(id: 'b', personId: 2, status: p),
        // person 3 works from Jan 3 → no overlap anymore
        ShiftAttendanceRow(id: 'c', personId: 3, status: e, notes: 'Schichtbedingt'),
        // person 4 has no shift but still a shift excuse
        ShiftAttendanceRow(id: 'd', personId: 4, status: e, notes: 'Schichtbedingt'),
        // manual excuse without shift note is untouched
        ShiftAttendanceRow(id: 'e', personId: 4, status: e, notes: 'Urlaub'),
      ]);
      expect(updates.map((u) => (u.id, u.status, u.notes)), [
        ('a', e, 'Schichtbedingt'),
        ('c', n, ''),
        ('d', n, ''),
      ]);
    });

    test('falls back to the type times when the Termin has none', () {
      // 19:00-21:00 does not overlap the early shift
      final updates = run(start: null, end: null, rows: const [
        ShiftAttendanceRow(id: 'a', personId: 1, status: n),
      ]);
      expect(updates, isEmpty);
    });

    test('skips past Termine and all-day types', () {
      const rows = [ShiftAttendanceRow(id: 'a', personId: 1, status: n)];
      expect(run(date: '2025-12-30T11:00:00.000Z', rows: rows), isEmpty);
      expect(run(allDay: true, rows: rows), isEmpty);
    });
  });
}
