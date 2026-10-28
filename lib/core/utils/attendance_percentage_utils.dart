import '../constants/enums.dart';
import '../../data/models/attendance/attendance.dart';
import 'duty_utils.dart';

/// LOGIC_SELF: Ionic `db.getCurrentAttDate()` — the attendance list (and the
/// planning Termine) load every Termin after the season start, or after
/// 2023-01-01 without one. Single implementation (REVIEW_FIX3).
String attendanceListStartDate(String? seasonStart) =>
    (seasonStart != null && seasonStart.isNotEmpty)
        ? seasonStart
        : DateTime.utc(2023).toIso8601String();

/// One person attendance as counted by Ionic `Utils.getPercentage`.
/// Common row type for raw `person_attendances` maps and [PersonAttendance].
typedef AttendanceCountRow = ({
  AttendanceStatus status,
  String? notes,
  String? dutyState,
});

/// [AttendanceCountRow] from a raw `person_attendances` row
/// (`status`, `notes`, `duty_state`).
AttendanceCountRow attendanceCountRowFromMap(Map<String, dynamic> row) => (
      status: AttendanceStatus.fromValue(row['status'] as int? ?? 0),
      notes: row['notes'] as String?,
      dutyState: row['duty_state'] as String?,
    );

/// [AttendanceCountRow] from a [PersonAttendance].
AttendanceCountRow attendanceCountRowOf(PersonAttendance pa) =>
    (status: pa.status, notes: pa.notes, dutyState: pa.dutyState);

/// Ionic `Utils.getPercentage(averagePersons(persons, type),
/// tenant.shift_excused_as_present)` — the single percentage implementation.
///
/// Duty Termine count only assigned persons (`duty_state` set). Returns
/// `null` for a duty Termin with nobody assigned (Ionic leaves those out of
/// the average and shows the Besetzung badge), `0` for no rows otherwise.
/// Present, late and late-excused count as attended; with
/// [shiftExcusedAsPresent] also a shift-/work-excused absence.
double? attendanceRowsPercentage(
  Iterable<AttendanceCountRow> rows,
  AttendanceType? type, {
  bool shiftExcusedAsPresent = false,
}) {
  final duty = isDutyType(type);
  final counted = duty
      ? rows.where((r) => r.dutyState != null && r.dutyState!.isNotEmpty).toList()
      : rows.toList();
  if (counted.isEmpty) return duty ? null : 0;
  final present = counted
      .where((r) => r.status.countsAsAttended(
            notes: r.notes,
            shiftExcusedAsPresent: shiftExcusedAsPresent,
          ))
      .length;
  return (present / counted.length * 100).roundToDouble();
}

/// LOGIC_SELF: [attendanceRowsPercentage] for one Termin of the attendance
/// list, over the raw `person_attendances` rows (`status`, `notes`,
/// `duty_state`).
double? attendanceListPercentage(
  List<Map<String, dynamic>> rows,
  AttendanceType? type, {
  bool shiftExcusedAsPresent = false,
}) =>
    attendanceRowsPercentage(
      rows.map(attendanceCountRowFromMap),
      type,
      shiftExcusedAsPresent: shiftExcusedAsPresent,
    );
