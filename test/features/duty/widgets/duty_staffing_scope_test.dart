import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/duty/presentation/widgets/duty_staffing_section.dart';
import 'package:flutter_test/flutter_test.dart';

PersonAttendance pa(int personId, int? group, {String? notes}) => PersonAttendance(
      id: 'pa$personId',
      personId: personId,
      instrument: group,
      notes: notes,
      status: AttendanceStatus.excused,
    );

void main() {
  // ASTRA_DUTY_GROUPS: Ionic builds the Besetzung block from the
  // helper-group-filtered `this.players`.
  group('dutyStaffingPlayers (helper group restriction)', () {
    final rows = [pa(1, 10), pa(2, 20), pa(3, null), pa(4, 10)];

    test('all groups: every row', () {
      expect(dutyStaffingPlayers(rows, const AttendanceGroupScope.all()), rows);
    });

    test('restricted helper: only own group', () {
      final result = dutyStaffingPlayers(rows, const AttendanceGroupScope.group(10));
      expect(result.map((p) => p.personId), [1, 4]);
    });

    test('denied (loading/error/no own group): nobody', () {
      expect(dutyStaffingPlayers(rows, const AttendanceGroupScope.denied()), isEmpty);
    });
  });

  group('dutyStaffingNote (note permission)', () {
    test('with permission the note is shown', () {
      expect(dutyStaffingNote('Krank', canViewNotes: true, noteAddedLabel: 'Notiz hinzugefügt'), 'Krank');
    });

    test('without permission the note is masked', () {
      expect(dutyStaffingNote('Krank', canViewNotes: false, noteAddedLabel: 'Notiz hinzugefügt'), 'Notiz hinzugefügt');
    });

    test('no note: nothing shown', () {
      expect(dutyStaffingNote(null, canViewNotes: false, noteAddedLabel: 'x'), isNull);
      expect(dutyStaffingNote('', canViewNotes: true, noteAddedLabel: 'x'), isNull);
    });
  });

  test('DutyStaffingSection applies group scope and note permission (source)', () {
    final src = File('lib/features/duty/presentation/widgets/duty_staffing_section.dart').readAsStringSync();
    expect(src, contains('ref.watch(attendanceGroupScopeProvider)'));
    expect(src, contains('dutyStaffingPlayers(allRows, groupScope)'));
    expect(src, contains('ref.watch(canViewAttendanceNotesProvider)'));
    expect(src, isNot(contains('Text(pa.notes!)')));
  });
}
