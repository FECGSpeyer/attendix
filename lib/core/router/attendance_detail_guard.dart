// LEFTOVERS: guard for typed /attendance/:id (and /attendance/new) URLs.
//
// Ionic only opens a Termin from the attendance list for conductors
// (ADMIN/RESPONSIBLE) and helpers (HELPER/VOICE_LEADER_HELPER)
// (att-list.page.ts `openAttendance`: `if (!isConductor && !isHelper) return;`).
// Observers (VIEWER) only see the list. In Flutter the same set is
// `Role.canAddAttendance`. A typed or bookmarked detail URL must not bypass
// that check; such users land on their role's home page (Ionic
// `Utils.getUrl(role)`, Flutter `Role.defaultRoute`).

import '../constants/enums.dart';

/// Returns the redirect target when [role] must not open the attendance
/// sub-route [location] (e.g. `/attendance/42`), or `null` when access is fine
/// or [location] is not an attendance sub-route. The list `/attendance` itself
/// is left to the generic route table.
String? attendanceDetailRedirect(String location, Role role) {
  if (!location.startsWith('/attendance/')) return null;
  if (role.canAddAttendance) return null;
  return role.defaultRoute;
}
