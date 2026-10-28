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
///
/// SOL_FIX2: `/attendance/new` additionally requires [canCreate], the
/// resolved `canCreateAttendanceProvider` (helpers: role permission
/// `attendance_create`, denied while permissions are not confirmed). Ionic
/// only hides the "+" button (att-list.page.ts `canCreate`); a typed URL must
/// not bypass it. Such users go back to the list.
String? attendanceDetailRedirect(String location, Role role, {required bool canCreate}) {
  if (!location.startsWith('/attendance/')) return null;
  if (!role.canAddAttendance) return role.defaultRoute;
  if (_isCreateRoute(location) && !canCreate) return '/attendance';
  return null;
}

bool _isCreateRoute(String location) {
  final path = Uri.parse(location).path;
  return path == '/attendance/new' || path.startsWith('/attendance/new/');
}
