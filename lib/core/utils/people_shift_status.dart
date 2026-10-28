import '../../data/models/shift/shift_plan.dart';
import '../constants/enums.dart';
import 'shift_utils.dart';

/// LOGIC_PEOPLE: people flows (add to upcoming Termine, shift change →
/// future Termine) use Ionic `Utils.getStatusByShift` via [ShiftUtils].
///
/// Throws [StateError] when [shiftName] is set but not part of the plan
/// (Ionic throws 'Shift name not found in shift plan').
({AttendanceStatus status, String note}) peopleStatusByShift({
  required ShiftPlan? shift,
  required String attDate,
  required String attendanceStart,
  required String attendanceEnd,
  required AttendanceStatus defaultStatus,
  String? shiftStart,
  String? shiftName,
}) {
  final parsedAtt = DateTime.tryParse(attDate);
  if (parsedAtt == null) return (status: defaultStatus, note: '');
  try {
    final r = ShiftUtils.getStatusByShift(
      shift: shift,
      attendanceDate: parsedAtt,
      attendanceStart: attendanceStart,
      attendanceEnd: attendanceEnd,
      defaultStatus: defaultStatus,
      shiftStart: shiftStart,
      shiftName: shiftName,
    );
    return (status: r.status, note: r.note);
  } on ShiftNameNotFoundException {
    throw StateError('Shift name not found in shift plan');
  }
}

/// SOL_FIX4: whether a person's shift assignment changed in a way that
/// requires recalculating their upcoming shift-based statuses
/// (`updateShiftAssignmentsForPerson`): plan id, shift name or start date.
/// Start dates are compared as instants (`DateTime.parse`), so a string
/// round-trip with a different ISO format is no change.
bool shiftAssignmentChanged({
  required String? oldShiftId,
  required String? oldShiftName,
  required String? oldShiftStart,
  required String? newShiftId,
  required String? newShiftName,
  required DateTime? newShiftStart,
}) {
  String? norm(String? v) => (v == null || v.isEmpty) ? null : v;
  if (norm(oldShiftId) != norm(newShiftId)) return true;
  if (norm(oldShiftName) != norm(newShiftName)) return true;
  final oldStart =
      oldShiftStart == null ? null : DateTime.tryParse(oldShiftStart);
  if (oldStart == null || newShiftStart == null) {
    return (oldStart == null) != (newShiftStart == null);
  }
  return !oldStart.isAtSameMomentAs(newShiftStart);
}
