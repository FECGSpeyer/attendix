import '../router/legacy_routes.dart';

/// INTEGRATION: maps routes stored by the backend (Edge Functions write Ionic
/// paths into `user_notifications.data.route`, e.g. `team-notify`,
/// `send-task-reminders`, duty delivery) to the Flutter routes.
///
/// LINK_AUDIT: uses the same table as links and pushes
/// ([legacyRouteRedirect]), so every Ionic `/tabs/...` route maps the same
/// way everywhere (e.g. `/tabs/player` → `/people`; before, unknown paths such
/// as `/player` were taken by the public song-sharing route).
///
/// - `/tabs/settings/tasks/5` → `/settings/tasks/5`
/// - `/tabs/attendance/:id/protocol` → `/settings/protocol/:id`
/// - `/tabs/settings/meetings…` → `/settings/team-organization`
/// - Query strings (e.g. `?tab=topics`) are kept; Flutter routes stay as they are.
String mapIonicRoute(String route) {
  final path = route.trim();
  final uri = Uri.tryParse(path);
  if (uri == null) return path;
  return legacyRouteRedirect(uri) ?? path;
}
