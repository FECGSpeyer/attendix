import '../../data/models/shift/shift_plan.dart';
import '../constants/enums.dart';

/// LOGIC_PEOPLE: minimal port of Ionic `Utils.getStatusByShift` used by the
/// people flows (add to upcoming Termine, shift change → future Termine).
///
/// NOTE for the integrator: `ShiftUtils.getStatusByShift` (shift_utils.dart)
/// is being ported by another lane; once it takes a [ShiftPlan] this helper
/// can be replaced by it.
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
  if (shift == null || shift.definition.isEmpty) {
    return (status: defaultStatus, note: '');
  }

  final parsedAtt = DateTime.tryParse(attDate);
  if (parsedAtt == null) return (status: defaultStatus, note: '');
  final attDay = DateTime(parsedAtt.year, parsedAtt.month, parsedAtt.day);
  final attStart = _at(attDay, attendanceStart);
  final attEnd = _at(attDay, attendanceEnd);
  if (attStart == null || attEnd == null) {
    return (status: defaultStatus, note: '');
  }

  DateTime current;
  if (shiftName != null && shiftName.isNotEmpty) {
    final match = shift.shifts.where((s) => s.name == shiftName).firstOrNull;
    final d = match == null ? null : DateTime.tryParse(match.date);
    if (d == null) {
      throw StateError('Shift name not found in shift plan');
    }
    current = DateTime(d.year, d.month, d.day);
  } else {
    final d = DateTime.tryParse(shiftStart ?? '') ?? DateTime.now();
    current = DateTime(d.year, d.month, d.day);
  }
  final endDate = attDay.add(const Duration(days: 2));
  final windowStart = attDay.subtract(const Duration(days: 2));

  // Guard against endless loops when every segment has repeat_count 0.
  if (shift.definition.every((d) => d.repeatCount <= 0)) {
    return (status: defaultStatus, note: '');
  }

  while (current.isBefore(endDate)) {
    for (final def in shift.definition) {
      for (var i = 0; i < def.repeatCount; i++) {
        if (current.isAfter(windowStart)) {
          final shiftStartTime = _at(current, def.startTime);
          if (shiftStartTime != null) {
            final shiftEndTime = shiftStartTime
                .add(Duration(minutes: (def.duration * 60).round()));
            if (!def.free &&
                attStart.isBefore(shiftEndTime) &&
                attEnd.isAfter(shiftStartTime)) {
              return (status: AttendanceStatus.excused, note: 'Schichtbedingt');
            }
          }
        }
        current = DateTime(current.year, current.month, current.day + 1);
      }
    }
  }

  return (status: defaultStatus, note: '');
}

DateTime? _at(DateTime day, String time) {
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}
