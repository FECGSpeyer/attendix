import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/utils/event_list_utils.dart';
import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:flutter_test/flutter_test.dart';

CrossTenantPersonAttendance _att(
  String date, {
  int? durationDays,
  AttendanceStatus status = AttendanceStatus.neutral,
  bool includeInAverage = true,
}) =>
    CrossTenantPersonAttendance(
      id: date,
      date: date,
      durationDays: durationDays,
      status: status,
      includeInAverage: includeInAverage,
      tenantId: 1,
      tenantName: 'Test',
      tenantColor: 'primary',
    );

void main() {
  final now = DateTime(2026, 10, 20, 15);

  group('EventListUtils.hasEnded (multi-day aware)', () {
    test('single-day Termin of yesterday has ended, today has not', () {
      expect(EventListUtils.hasEnded('2026-10-19T12:00:00', 1, now: now), isTrue);
      expect(EventListUtils.hasEnded('2026-10-20T12:00:00', 1, now: now), isFalse);
    });

    test('multi-day Termin counts as past only after its last day', () {
      // 18.–20.10.: last day is today -> still running
      expect(EventListUtils.hasEnded('2026-10-18T12:00:00', 3, now: now), isFalse);
      expect(EventListUtils.isRunning('2026-10-18T12:00:00', 3, now: now), isTrue);
      // 17.–19.10.: ended yesterday
      expect(EventListUtils.hasEnded('2026-10-17T12:00:00', 3, now: now), isTrue);
    });

    test('future Termin is neither ended nor running', () {
      expect(EventListUtils.hasEnded('2026-10-25T12:00:00', 1, now: now), isFalse);
      expect(EventListUtils.isRunning('2026-10-25T12:00:00', 1, now: now), isFalse);
    });
  });

  group('EventListUtils labels', () {
    test('present reads "Zugesagt" upcoming and "Anwesend" in the past', () {
      expect(EventListUtils.statusLabel(AttendanceStatus.present), 'Zugesagt');
      expect(EventListUtils.statusLabel(AttendanceStatus.present, past: true), 'Anwesend');
      expect(EventListUtils.statusLabel(AttendanceStatus.excused), 'Entschuldigt');
      expect(EventListUtils.statusLabel(AttendanceStatus.late), 'Verspätet');
      expect(EventListUtils.statusLabel(AttendanceStatus.absent), 'Abwesend');
    });

    test('tenant reasons fall back to the defaults', () {
      expect(EventListUtils.absenceReasonsOf(null), EventListUtils.defaultAbsenceReasons);
      expect(EventListUtils.absenceReasonsOf(const []), EventListUtils.defaultAbsenceReasons);
      expect(EventListUtils.absenceReasonsOf(const ['Krank']), ['Krank']);
      expect(EventListUtils.lateReasonsOf(null), EventListUtils.defaultLateReasons);
    });

    test('time range and meta line', () {
      expect(EventListUtils.timeRange('19:00:00', '21:30:00'), '19:00–21:30');
      expect(EventListUtils.timeRange('19:00', null), '19:00');
      expect(EventListUtils.meta(['a', null, '', 'b']), 'a · b');
    });
  });

  group('buildSignoutData', () {
    test('splits current / upcoming / past with multi-day awareness', () {
      final data = buildSignoutData(
        own: [
          _att('2026-10-10T12:00:00', status: AttendanceStatus.present),
          _att('2026-10-18T12:00:00', durationDays: 3), // running Freizeit
          _att('2026-10-30T12:00:00'),
          _att('2026-10-12T12:00:00', status: AttendanceStatus.late),
        ],
        now: now,
      );

      expect(data.current?.date, '2026-10-18T12:00:00');
      expect(data.upcoming.map((a) => a.date), ['2026-10-30T12:00:00']);
      // past sorted descending
      expect(data.past.map((a) => a.date), ['2026-10-12T12:00:00', '2026-10-10T12:00:00']);
      expect(data.lateCount, 1);
      expect(data.percentage, 100);
    });

    test('Termine excluded from the average do not count', () {
      final data = buildSignoutData(
        own: [
          _att('2026-10-10T12:00:00', status: AttendanceStatus.absent),
          _att('2026-10-11T12:00:00', status: AttendanceStatus.absent, includeInAverage: false),
          _att('2026-10-12T12:00:00', status: AttendanceStatus.present),
        ],
        now: now,
      );
      expect(data.percentage, 50);
    });
  });
}
