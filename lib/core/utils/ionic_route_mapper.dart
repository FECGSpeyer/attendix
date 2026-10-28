/// INTEGRATION: maps routes stored by the backend (Edge Functions write Ionic
/// paths into `user_notifications.data.route`, e.g. `team-notify`,
/// `send-task-reminders`, duty delivery) to the Flutter routes.
///
/// - `/tabs` prefix is dropped (`/tabs/settings/tasks/5` → `/settings/tasks/5`)
/// - `/tabs/attendance/:id/protocol` → `/settings/protocol/:id`
/// - `/tabs/settings/meetings…` → `/settings/team-organization`
/// - Query strings (e.g. `?tab=topics`) are kept.
String mapIonicRoute(String route) {
  var path = route.trim();
  if (path.startsWith('/tabs/')) {
    path = path.substring(5);
  } else if (path == '/tabs') {
    path = '/';
  }

  final uri = Uri.tryParse(path);
  if (uri == null) return path;
  final segments = uri.pathSegments;

  // attendance/:id/protocol → settings/protocol/:id
  if (segments.length == 3 &&
      segments[0] == 'attendance' &&
      segments[2] == 'protocol' &&
      int.tryParse(segments[1]) != null) {
    return '/settings/protocol/${segments[1]}';
  }

  // Former Besprechungen → Teamorganisation (Ionic redirect)
  if (segments.length >= 2 &&
      segments[0] == 'settings' &&
      segments[1] == 'meetings') {
    return '/settings/team-organization';
  }

  return path;
}
