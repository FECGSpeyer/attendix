import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:flutter_test/flutter_test.dart';

CrossTenantPersonAttendance _att(
  int attendanceId,
  String date, {
  bool isMember = true,
  AttendanceStatus status = AttendanceStatus.neutral,
}) =>
    CrossTenantPersonAttendance(
      id: isMember ? 'pa$attendanceId' : null,
      attendanceId: attendanceId,
      date: date,
      status: status,
      isMember: isMember,
      tenantId: 1,
      tenantName: 'Test',
      tenantColor: 'primary',
    );

void main() {
  final now = DateTime(2026, 10, 30, 12);

  group('Termine without the person (show_all_attendances)', () {
    // Same start: an info entry for those not invited (no own row) and the
    // Termin the person is part of and declined.
    final info = _att(20, '2026-10-31T19:00:00', isMember: false);
    final own = _att(10, '2026-10-31T19:00:00', status: AttendanceStatus.excused);

    test('own Termin comes first at the same start, whatever the database order', () {
      for (final order in [
        [info, own],
        [own, info],
      ]) {
        final data = buildSignoutData(own: const [], allUpcoming: order, now: now);
        expect(data.current?.attendanceId, 10);
        expect(data.upcoming.map((a) => a.attendanceId), [20]);
      }
    });

    test('ties between Termine of the same kind keep a fixed order', () {
      final a = _att(3, '2026-11-02T10:00:00', isMember: false);
      final b = _att(1, '2026-11-02T10:00:00', isMember: false);
      final data = buildSignoutData(own: const [], allUpcoming: [a, b], now: now);
      expect(data.allUpcoming.map((x) => x.attendanceId), [1, 3]);
    });

    test('"Heute" card shows the next own Termin, not an earlier one without the person', () {
      final earlierInfo = _att(30, '2026-10-31T10:00:00', isMember: false);
      final data = buildSignoutData(
        own: const [],
        allUpcoming: [earlierInfo, info, own],
        now: now,
      );
      expect(data.current?.attendanceId, 30);
      expect(rdTodayFocus(data)?.attendanceId, 10);
      expect(rdTodayFocus(data)?.status, AttendanceStatus.excused);
    });

    test('"Heute" card falls back to the first Termin without own ones', () {
      final data = buildSignoutData(own: const [], allUpcoming: [info], now: now);
      expect(rdTodayFocus(data)?.attendanceId, 20);
      expect(rdTodayFocus(const SignoutData()), isNull);
    });
  });
}
