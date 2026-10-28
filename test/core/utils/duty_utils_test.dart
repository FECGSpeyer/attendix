import 'dart:math';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/duty_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/duty/person_unavailability.dart';
import 'package:flutter_test/flutter_test.dart';

PersonAttendance pa(int personId, {String? state, AttendanceStatus status = AttendanceStatus.neutral}) =>
    PersonAttendance(id: 'pa$personId', personId: personId, dutyState: state, status: status);

void main() {
  group('dutyStateAfterStatus (sync assignment with status)', () {
    test('present/late confirm a request and turn stand-ins into confirmed', () {
      expect(dutyStateAfterStatus(DutyState.requested, AttendanceStatus.present), DutyState.confirmed);
      expect(dutyStateAfterStatus(null, AttendanceStatus.late), DutyState.confirmed);
      expect(dutyStateAfterStatus(DutyState.self, AttendanceStatus.present), DutyState.self);
    });

    test('neutral after confirmation goes back to requested', () {
      expect(dutyStateAfterStatus(DutyState.confirmed, AttendanceStatus.neutral), DutyState.requested);
      expect(dutyStateAfterStatus(DutyState.self, AttendanceStatus.neutral), DutyState.requested);
      expect(dutyStateAfterStatus(null, AttendanceStatus.neutral), isNull);
    });

    test('excused keeps the state (cancelled duty)', () {
      expect(dutyStateAfterStatus(DutyState.confirmed, AttendanceStatus.excused), DutyState.confirmed);
    });
  });

  group('occupancy', () {
    test('cancelled assignments do not occupy the duty', () {
      final persons = [
        pa(1, state: DutyState.confirmed, status: AttendanceStatus.present),
        pa(2, state: DutyState.requested, status: AttendanceStatus.excused),
        pa(3),
      ];
      expect(occupiedCount(persons), 1);
      expect(dutyFill(persons, 1), DutyFill.full);
      expect(dutyFill(persons, 2), DutyFill.partial);
      expect(dutyFill([pa(3)], 1), DutyFill.open);
      expect(dutyFill([pa(1, state: DutyState.requested)], 1), DutyFill.requested);
    });

    test('dutyRequired falls back to type and is at least 1', () {
      const type = AttendanceType(name: 'Technik', dutyMode: true, dutyRequired: 3);
      expect(dutyRequired(const Attendance(date: '2026-01-01', dutyRequired: 2), type), 2);
      expect(dutyRequired(const Attendance(date: '2026-01-01'), type), 3);
      expect(dutyRequired(null, const AttendanceType(name: 'x', dutyRequired: 0)), 1);
    });

    test('countsForAverage leaves out stand-ins of duty types', () {
      const duty = AttendanceType(name: 'Technik', dutyMode: true);
      expect(countsForAverage(duty, null), isFalse);
      expect(countsForAverage(duty, DutyState.confirmed), isTrue);
      expect(countsForAverage(const AttendanceType(name: 'Probe'), null), isTrue);
    });
  });

  group('matchingUnavailability', () {
    // 2026-11-04 is a Wednesday (ISO 3)
    const rule = PersonUnavailability(tenantId: 1, personId: 7, weekdays: [3], reason: 'Kinderstunde');

    test('matches weekday and person', () {
      expect(matchingUnavailability([rule], 7, '2026-11-04T12:00:00', 't1'), rule);
      expect(matchingUnavailability([rule], 7, '2026-11-05T12:00:00', 't1'), isNull);
      expect(matchingUnavailability([rule], 8, '2026-11-04T12:00:00', 't1'), isNull);
    });

    test('respects type ids and valid_until', () {
      final typed = rule.copyWith(typeIds: ['t2']);
      expect(matchingUnavailability([typed], 7, '2026-11-04T12:00:00', 't1'), isNull);
      expect(matchingUnavailability([typed], 7, '2026-11-04T12:00:00', 't2'), isNotNull);
      final expired = rule.copyWith(validUntil: '2026-11-03');
      expect(matchingUnavailability([expired], 7, '2026-11-04T12:00:00', 't1'), isNull);
    });

    test('note contains the reason', () {
      expect(unavailabilityNote(rule), 'Regelmäßig verhindert: Kinderstunde');
      expect(unavailabilityNote(rule.copyWith(reason: '')), 'Regelmäßig verhindert');
    });
  });

  group('distributeDuties', () {
    test('picks persons with fewest duties first', () {
      final result = distributeDuties(
        const [DutySlot(attendanceId: 1, date: '2026-11-04T12:00:00', candidates: [1, 2, 3], occupied: [], open: 1)],
        {1: 3, 2: 0, 3: 1},
        maxPerPerson: 2,
        notTwiceSameDay: true,
        random: Random(1),
      );
      expect(result[1], [2]);
    });

    test('respects maxPerPerson and notTwiceSameDay', () {
      final slots = [
        const DutySlot(attendanceId: 1, date: '2026-11-04T10:00:00', candidates: [1, 2], occupied: [], open: 1),
        const DutySlot(attendanceId: 2, date: '2026-11-04T18:00:00', candidates: [1, 2], occupied: [], open: 1),
        const DutySlot(attendanceId: 3, date: '2026-11-11T18:00:00', candidates: [1], occupied: [], open: 1),
      ];
      final result = distributeDuties(slots, {}, maxPerPerson: 1, notTwiceSameDay: true, random: Random(2));
      expect(result[1]!.single, isNot(result[2]!.single));
      // person 1 already has one duty in this run (max 1) unless 2 took the first two
      final ones = result.values.expand((e) => e).where((id) => id == 1).length;
      expect(ones, lessThanOrEqualTo(1));
    });

    test('does not pick persons already busy that day', () {
      final result = distributeDuties(
        const [
          DutySlot(attendanceId: 1, date: '2026-11-04T10:00:00', candidates: [], occupied: [5], open: 0),
          DutySlot(attendanceId: 2, date: '2026-11-04T18:00:00', candidates: [5], occupied: [], open: 1),
        ],
        {},
        maxPerPerson: 3,
        notTwiceSameDay: true,
      );
      expect(result[2], isNull);
    });
  });
}
