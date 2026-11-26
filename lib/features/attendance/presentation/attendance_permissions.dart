import '../../../core/constants/enums.dart';
import '../../../data/models/attendance/attendance.dart';

/// Whether [role] may use mutating attendance-detail actions (add persons,
/// checklist, reminder, photo, description). Viewers are read-only and helpers
/// only set statuses (Stimmführer-Helfer may use them).
bool canMutateAttendanceDetail(Role role) =>
    role.canEdit && role != Role.helper;

/// Every role that edits Termine (Helfer included) may edit descriptions.
bool canEditAttendanceDescription(Role role) => role.canEdit;

/// Whether a realtime `person_attendances` payload carries a `duty_state` that
/// differs from the loaded row.
bool realtimeDutyStateChanged(
  Map<String, dynamic> newRecord,
  List<PersonAttendance> rows,
) {
  if (!newRecord.containsKey('duty_state')) return false;
  final id = newRecord['id']?.toString();
  if (id == null) return false;
  final row = rows.where((r) => r.id == id).firstOrNull;
  if (row == null) return false;
  final incoming = newRecord['duty_state']?.toString();
  return (incoming ?? '') != (row.dutyState ?? '');
}

/// Only a Termin that already has a deadline and whose date lies before now has
/// a read-only deadline.
bool isDeadlineReadonly(Attendance attendance, {DateTime? now}) {
  if (attendance.deadline == null) return false;
  final date = DateTime.tryParse(attendance.date);
  if (date == null) return false;
  return date.isBefore(now ?? DateTime.now());
}
