import '../constants/enums.dart';
import 'event_list_utils.dart';

/// Ionic 4.17.24 `utilities/archived.ts`: archived Termine are only visible
/// to admins and responsible persons.
bool canSeeArchivedAttendances(Role? role) =>
    role == Role.admin || role == Role.responsible;

/// Ionic `filterArchivedForRole`: drops archived Termine for every role that
/// must not see them.
List<T> filterArchivedForRole<T>(
  List<T> items,
  Role? role,
  bool Function(T item) isArchived,
) {
  if (canSeeArchivedAttendances(role)) return items;
  return items.where((item) => !isArchived(item)).toList();
}

/// Ionic `canArchiveAttendance`: only Termine that are over can be archived;
/// restoring is always possible.
bool canArchiveAttendance({
  required String? date,
  required int? durationDays,
  required bool archived,
  required Role? role,
}) {
  if (date == null || !canSeeArchivedAttendances(role)) return false;
  return archived || EventListUtils.hasEnded(date, durationDays);
}

/// Reads the `archived` flag of a nested `attendance` row (`person_attendances`
/// joins). Missing column/value counts as not archived.
bool isArchivedRow(Map<String, dynamic>? attendance) =>
    attendance?['archived'] == true;
