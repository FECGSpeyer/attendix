import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/redesign/data/providers/rd_events_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/data/rd_members_logic.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

/// REDESIGN: logic of the UX package 1 (S5 deadline, D3 "Fehlen oft",
/// D4 "noch nicht erfasst").
void main() {
  final now = DateTime(2026, 10, 31, 12);

  group('S5: answer deadline before it passes', () {
    test('a deadline ahead is returned as local wall time', () {
      expect(rdOpenDeadline('2026-11-02T18:00:00', now: now), DateTime(2026, 11, 2, 18));
      // Stored as UTC wall time: the components are the local time.
      expect(rdOpenDeadline('2026-11-02T18:00:00Z', now: now), DateTime(2026, 11, 2, 18));
    });

    test('no hint without a deadline or once it has passed', () {
      expect(rdOpenDeadline(null, now: now), isNull);
      expect(rdOpenDeadline('', now: now), isNull);
      expect(rdOpenDeadline('2026-10-31T11:59:00', now: now), isNull);
    });

    test('red only in the last 24 hours', () {
      expect(rdDeadlineUrgent(DateTime(2026, 11, 1, 11), now: now), isTrue);
      expect(rdDeadlineUrgent(DateTime(2026, 11, 1, 13), now: now), isFalse);
    });
  });

  group('D4: Termine not yet recorded', () {
    final all = [
      TestFactories.createAttendance(id: 1, date: '2026-10-10'), // older than 14 days
      TestFactories.createAttendance(id: 2, date: '2026-10-22', startTime: '19:00'),
      TestFactories.createAttendance(id: 3, date: '2026-10-29', startTime: '19:00'),
      TestFactories.createAttendance(id: 4, date: '2026-10-31'), // today, not over
      TestFactories.createAttendance(id: 5, date: '2026-11-05'),
    ];

    test('only Termine of the last two weeks that are over, oldest first', () {
      expect(rdRecentPast(all, now: now).map((a) => a.id), [2, 3]);
    });

    test('a Termin counts while someone still has no status', () {
      const rows = [
        PersonAttendance(attendanceId: 2, status: AttendanceStatus.present),
        PersonAttendance(attendanceId: 2, status: AttendanceStatus.excused),
        PersonAttendance(attendanceId: 3, status: AttendanceStatus.present),
        PersonAttendance(attendanceId: 3, status: AttendanceStatus.neutral),
      ];
      expect(rdUnrecordedIds([2, 3], rows), [3]);
      expect(rdUnrecordedIds([2, 3], const []), isEmpty);
    });
  });

  group('D3: "Fehlen oft"', () {
    test('only active, approved members the server flags as critical', () {
      final people = [
        TestFactories.createPerson(id: 1).copyWith(isCritical: true),
        TestFactories.createPerson(id: 2),
        TestFactories.createPerson(id: 3, paused: true).copyWith(isCritical: true),
        TestFactories.createPerson(id: 4, pending: true).copyWith(isCritical: true),
      ];
      expect(rdCriticalMembers(people).map((p) => p.id), [1]);
    });
  });
}
