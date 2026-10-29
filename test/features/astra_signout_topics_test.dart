// ASTRA_SIGNOUT_TOPICS: "Meine Termine" Dienstplan view (Ionic
// applyDutyView / applyDutyLayout) and "Datum ändern" in the Themen tab
// (Ionic topics-tab changeDate → promptAttendanceDateChange).
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_date_change.dart';
import 'package:flutter_test/flutter_test.dart';

const _duty = AttendanceType(id: 'd', name: 'Dienst', dutyMode: true);
const _rehearsal = AttendanceType(id: 'r', name: 'Probe');

CrossTenantPersonAttendance _att(
  String id,
  String date, {
  AttendanceType type = _rehearsal,
  String? dutyState,
  String? typeInfo,
  AttendanceStatus status = AttendanceStatus.neutral,
}) =>
    CrossTenantPersonAttendance(
      id: id,
      date: date,
      typeInfo: typeInfo,
      status: status,
      attendanceType: type,
      dutyState: dutyState,
      tenantId: 1,
      tenantName: 'T',
      tenantColor: '#000000',
    );

void main() {
  group('Meine Termine – Dienstplan (Ionic applyDutyView/applyDutyLayout)', () {
    final rehearsal = _att('1', '2099-01-02T12:00:00Z', typeInfo: 'Probe A');
    final ownDuty = _att('2', '2099-01-03T12:00:00Z', type: _duty, dutyState: 'confirmed', typeInfo: 'Kasse');
    final openDuty = _att('3', '2099-01-04T12:00:00Z', type: _duty, typeInfo: 'Theke');
    final concert = _att('4', '2099-01-05T12:00:00Z', typeInfo: 'Konzert');
    final requestedDuty = _att('5', '2099-01-06T12:00:00Z', type: _duty, dutyState: 'requested');
    final pastOpenDuty = _att('6', '2000-01-01T12:00:00Z', type: _duty);
    final pastRehearsal = _att('7', '2000-01-02T12:00:00Z');
    final data = SignoutData(
      current: rehearsal,
      upcoming: [ownDuty, openDuty, concert, requestedDuty],
      past: [pastRehearsal, pastOpenDuty],
      percentage: 80,
      lateCount: 1,
    );

    test('unassigned duty Termine are hidden everywhere, own duties stay in the list view', () {
      final view = applySignoutDutyView(data, useDutyView: false);
      expect(view.allUpcoming.map((a) => a.id), ['1', '2', '4', '5']);
      expect(view.past.map((a) => a.id), ['7']);
      // Percentage / late count are computed before the filter (Ionic).
      expect(view.percentage, 80);
      expect(view.lateCount, 1);
    });

    test('Dienstplan view: "Weitere Termine" without own duties, counter matches', () {
      final view = applySignoutDutyView(data, useDutyView: true);
      expect(view.current?.id, '1');
      expect(view.upcoming.map((a) => a.id), ['4']);
      expect(view.allUpcoming.length, 2); // otherTermineCount
      expect(otherTermineNames(view), 'Probe A, Konzert');
    });

    test('Dienstplan view: next other Termin becomes the current one', () {
      final view = applySignoutDutyView(
        SignoutData(current: ownDuty, upcoming: [concert, requestedDuty]),
        useDutyView: true,
      );
      expect(view.current?.id, '4');
      expect(view.upcoming, isEmpty);
    });

    test('names: distinct, at most two (Ionic slice(0, 2))', () {
      final view = SignoutData(
        current: _att('a', '2099-01-01', typeInfo: 'X'),
        upcoming: [
          _att('b', '2099-01-02', typeInfo: 'X'),
          _att('c', '2099-01-03', typeInfo: 'Y'),
          _att('d', '2099-01-04', typeInfo: 'Z'),
        ],
      );
      expect(otherTermineNames(view), 'X, Y');
    });

    test('isDutyPa / isUnassignedDuty follow duty_mode and duty_state', () {
      expect(isDutyPaAttendance(ownDuty), isTrue);
      expect(isDutyPaAttendance(openDuty), isFalse);
      expect(isDutyPaAttendance(_att('x', '2099-01-01', dutyState: 'confirmed')), isFalse);
      expect(isUnassignedDutyAttendance(openDuty), isTrue);
      expect(isUnassignedDutyAttendance(rehearsal), isFalse);
    });

    test('signout page uses the filtered view and keeps "Vergangene" outside the toggle', () {
      final src = File('lib/features/self_service/presentation/pages/signout_page.dart').readAsStringSync();
      expect(src, contains('applySignoutDutyView(raw, useDutyView: useDutyView)'));
      expect(src, contains('otherTermineCount: data.allUpcoming.length'));
      expect(src, contains('otherTermineNames: otherTermineNames(data)'));
      final toggle = src.indexOf('if (!useDutyView || _showOtherTermine) ...[');
      final past = src.indexOf('..._buildPast(data, actions)');
      final toggleEnd = src.indexOf('],', src.indexOf('..._buildUpcoming(data, actions)'));
      expect(toggle, greaterThan(0));
      expect(past, greaterThan(toggleEnd));
    });
  });

  group('Datum ändern (Ionic promptAttendanceDateChange)', () {
    test('hasNonDefaultStatus compares with the type default', () {
      const type = AttendanceType(id: 't', name: 'Probe', defaultStatus: AttendanceStatus.present);
      expect(hasNonDefaultStatus([AttendanceStatus.present], type), isFalse);
      expect(hasNonDefaultStatus([AttendanceStatus.present, AttendanceStatus.excused], type), isTrue);
      expect(hasNonDefaultStatus([AttendanceStatus.excused], null), isFalse);
    });

    test('Themen tab opens the shared date dialog and keeps the Termin selected', () {
      final src = File('lib/features/team_organization/presentation/widgets/topics_tab.dart').readAsStringSync();
      final start = src.indexOf('Future<void> _changeDate(ProtocolAttendance current)');
      expect(start, greaterThan(0));
      final body = src.substring(start, src.indexOf('Future<void> _createAttendance', start));
      expect(body, contains('promptAttendanceDateChange(context, ref, current.id)'));
      expect(body, contains('_chosenAttendanceId = current.id'));
      expect(body, contains('refreshAfterTopicsDateChange(container)'));
      expect(src, isNot(contains("context.push('/attendance/\${current.id}')")));
    });

    test('attendance detail reuses the shared date change', () {
      final src = File('lib/features/attendance/presentation/pages/attendance_detail_page.dart').readAsStringSync();
      expect(src, contains('promptAttendanceDateChange('));
      expect(src, isNot(contains('int calendarDayDifference(')));
    });

    test('shared date change writes only through tenant repositories', () {
      final src = File('lib/features/attendance/presentation/widgets/attendance_date_change.dart').readAsStringSync();
      expect(src, contains('ref.read(attendanceRepositoryWithTenantProvider)'));
      expect(src, contains('ref.read(playerAbsenceRepositoryWithTenantProvider)'));
      expect(src, contains('if (!repo.hasTenantId) return false;'));
      expect(src, isNot(contains('supabase.from(')));
      expect(src, isNot(contains('Supabase.instance')));
    });
  });
}
