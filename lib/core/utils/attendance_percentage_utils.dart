import '../constants/enums.dart';
import '../../data/models/attendance/attendance.dart';
import 'duty_utils.dart';

/// LOGIC_SELF: Ionic `getCurrentAttDate()` — the attendance list loads every
/// Termin after the season start, or after 2023-01-01 without one.
String attendanceListStartDate(String? seasonStart) =>
    (seasonStart != null && seasonStart.isNotEmpty)
        ? seasonStart
        : DateTime.utc(2023).toIso8601String();

/// LOGIC_SELF: Ionic `Utils.getPercentage(averagePersons(att.persons, type),
/// tenant.shift_excused_as_present)` for one Termin of the attendance list.
///
/// [rows] are the raw `person_attendances` rows (`status`, `notes`,
/// `duty_state`). Duty Termine count only assigned persons. Returns `null`
/// for a duty Termin with nobody assigned: Ionic leaves those out of the
/// average (`!isDutyAttendance || some(duty_state)`) and shows the
/// Besetzung badge instead of a percentage.
double? attendanceListPercentage(
  List<Map<String, dynamic>> rows,
  AttendanceType? type, {
  bool shiftExcusedAsPresent = false,
}) {
  final counted = isDutyType(type)
      ? rows.where((r) {
          final state = r['duty_state'] as String?;
          return state != null && state.isNotEmpty;
        }).toList()
      : rows;
  if (counted.isEmpty) {
    return isDutyType(type) ? null : 0;
  }
  final present = counted.where((r) {
    final status = AttendanceStatus.fromValue(r['status'] as int? ?? 0);
    return status.countsAsAttended(
      notes: r['notes'] as String?,
      shiftExcusedAsPresent: shiftExcusedAsPresent,
    );
  }).length;
  return (present / counted.length * 100).roundToDouble();
}
