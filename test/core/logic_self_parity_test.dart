// LOGIC_SELF: parity of attendance percentages, duty notifications,
// parents filter, timestamps and absence ranges with Ionic v4.17.5.
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/utils/attendance_percentage_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/player_absence_repository.dart';
import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _dutyType = AttendanceType(id: 'd', name: 'Dienst', dutyMode: true);
const _normalType = AttendanceType(id: 'n', name: 'Probe');

Map<String, dynamic> _pa(AttendanceStatus s, {String? notes, String? duty}) =>
    {'status': s.value, 'notes': notes, 'duty_state': duty};

CrossTenantPersonAttendance _att(
  String date, {
  String? id,
  int? attendanceId,
  AttendanceStatus status = AttendanceStatus.neutral,
  AttendanceType? type,
  String? dutyState,
  String? notes,
}) =>
    CrossTenantPersonAttendance(
      id: id ?? date,
      attendanceId: attendanceId,
      date: date,
      status: status,
      notes: notes,
      attendanceType: type,
      dutyState: dutyState,
      tenantId: 1,
      tenantName: 'Test',
      tenantColor: '#000000',
    );

void main() {
  group('attendanceListPercentage (Ionic getPercentage(averagePersons))', () {
    test('normal Termin counts all persons', () {
      final perc = attendanceListPercentage([
        _pa(AttendanceStatus.present),
        _pa(AttendanceStatus.late),
        _pa(AttendanceStatus.absent),
        _pa(AttendanceStatus.excused),
      ], _normalType);
      expect(perc, 50);
    });

    test('duty Termin counts only assigned persons', () {
      final perc = attendanceListPercentage([
        _pa(AttendanceStatus.present, duty: 'confirmed'),
        _pa(AttendanceStatus.neutral),
        _pa(AttendanceStatus.neutral),
      ], _dutyType);
      expect(perc, 100);
    });

    test('duty Termin with nobody assigned has no percentage (left out of average)', () {
      expect(
        attendanceListPercentage([_pa(AttendanceStatus.neutral)], _dutyType),
        isNull,
      );
    });

    test('shift_excused_as_present counts Schichtbedingt as present', () {
      final rows = [
        _pa(AttendanceStatus.present),
        _pa(AttendanceStatus.excused, notes: 'Schichtbedingt'),
      ];
      expect(attendanceListPercentage(rows, _normalType), 50);
      expect(
        attendanceListPercentage(rows, _normalType, shiftExcusedAsPresent: true),
        100,
      );
    });

    test('empty normal Termin is 0 like Ionic', () {
      expect(attendanceListPercentage(const [], _normalType), 0);
    });

    test('list starts at season start or 2023-01-01', () {
      expect(attendanceListStartDate('2025-09-01'), '2025-09-01');
      expect(attendanceListStartDate(null), startsWith('2023-01-01'));
    });
  });

  group('Meine Termine percentage (Ionic countsForAverage + attended)', () {
    final now = DateTime(2026, 10, 20, 10);

    test('unassigned duty Termine do not count', () {
      final data = buildSignoutData(
        own: [
          _att('2026-10-10T12:00:00', status: AttendanceStatus.present, type: _normalType),
          _att('2026-10-11T12:00:00', type: _dutyType), // stand-in only
          _att('2026-10-12T12:00:00', status: AttendanceStatus.absent, type: _dutyType, dutyState: 'confirmed'),
        ],
        now: now,
      );
      expect(data.percentage, 50);
    });

    test('shift_excused_as_present counts work-excused as attended', () {
      final own = [
        _att('2026-10-10T12:00:00', status: AttendanceStatus.present, type: _normalType),
        _att('2026-10-11T12:00:00',
            status: AttendanceStatus.excused, notes: 'Arbeitsbedingt', type: _normalType),
      ];
      expect(buildSignoutData(own: own, now: now).percentage, 50);
      expect(
        buildSignoutData(own: own, now: now, shiftExcusedAsPresent: true).percentage,
        100,
      );
    });
  });

  group('cancelledDutyAttendanceIds (Ionic onExcuseConfirm understaffed)', () {
    test('only selected, assigned and not yet cancelled duties', () {
      final atts = [
        _att('a', id: '1', attendanceId: 10, type: _dutyType, dutyState: 'confirmed', status: AttendanceStatus.present),
        _att('b', id: '2', attendanceId: 11, type: _dutyType), // stand-in
        _att('c', id: '3', attendanceId: 12, type: _normalType),
        _att('d', id: '4', attendanceId: 13, type: _dutyType, dutyState: 'requested'),
        _att('e', id: '5', attendanceId: 14, type: _dutyType, dutyState: 'self', status: AttendanceStatus.excused),
      ];
      expect(
        cancelledDutyAttendanceIds(atts, ['1', '2', '3', '5']),
        [10],
      );
      expect(cancelledDutyAttendanceIds(atts, ['4']), [13]);
    });
  });

  group('absence range (Ionic confirmAbsence on the upcoming list)', () {
    final now = DateTime(2026, 10, 20, 10);

    test('running multi-day Termin that started before today is included', () {
      expect(
        PlayerAbsenceRepository.isUpcomingInAbsenceRange(
            '2026-10-19T12:00:00', 3, '2026-10-18', '2026-10-25', now: now),
        isTrue,
      );
    });

    test('ended Termin and Termine outside the range are excluded', () {
      expect(
        PlayerAbsenceRepository.isUpcomingInAbsenceRange(
            '2026-10-19T12:00:00', null, '2026-10-18', '2026-10-25', now: now),
        isFalse,
      );
      expect(
        PlayerAbsenceRepository.isUpcomingInAbsenceRange(
            '2026-10-26T12:00:00', null, '2026-10-18', '2026-10-25', now: now),
        isFalse,
      );
      expect(
        PlayerAbsenceRepository.isUpcomingInAbsenceRange(
            '2026-10-25T12:00:00', null, '2026-10-18', '2026-10-25', now: now),
        isTrue,
      );
    });
  });

  group('source analysis', () {
    String read(String path) => File(path).readAsStringSync();

    test('changed_at is always written as UTC ISO', () {
      for (final path in [
        'lib/data/repositories/sign_in_out_repository.dart',
        'lib/data/repositories/attendance_repository.dart',
        'lib/data/repositories/player_absence_repository.dart',
        'lib/data/repositories/player_repository.dart',
      ]) {
        final src = read(path);
        expect(
          RegExp(r'DateTime\.now\(\)\.toIso8601String\(\)(?!\.(substring|split))')
              .hasMatch(src),
          isFalse,
          reason: '$path writes a local timestamp without offset',
        );
      }
    });

    test('duty decline signs out with isSelf and sends understaffed', () {
      final src = read('lib/core/providers/duty_providers.dart');
      final start = src.indexOf('Future<bool> decline(');
      final body = src.substring(start, src.indexOf('updateDutyRequired', start));
      expect(body, contains('signOut('));
      expect(body, contains('isSelf: true'));
      expect(body, contains('DutyNotifyType.understaffed'));
    });

    test('viewer cannot distribute duties or open the Termin detail', () {
      final src = read('lib/features/attendance/presentation/pages/attendance_list_page.dart');
      expect(src, contains('(role.isAdmin || role.isResponsible) && ref.watch(hasDutyTypesProvider)'));
      expect(src, contains('if (!ref.read(effectiveRoleProvider).canAddAttendance) return;'));
    });

    test('attendance list has no 50-row limit and loads since season start', () {
      final src = read('lib/core/providers/realtime_providers.dart');
      expect(src, isNot(contains('.limit(50)')));
      expect(src, contains("attendanceListStartDate(tenant.seasonStart)"));
    });

    test('parents portal consumes the pending attendance id', () {
      final src = read('lib/features/parents/presentation/pages/parents_portal_page.dart');
      expect(src, contains('pendingAttendanceIdProvider'));
    });
  });
}
