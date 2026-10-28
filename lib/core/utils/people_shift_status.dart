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
