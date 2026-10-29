// LINKS_STARTUP: legacy Ionic URLs → Flutter routes.
//
// The Ionic app lived under `/tabs/...` (src/app/tabs/tabs-routing.module.ts)
// and the Supabase edge functions still send those links in mails, Telegram
// and push messages (send-message `/tabs/messages/:id`, evaluate-critical-rules
// `/tabs/list?tenantId=`, team-notify `/tabs/settings/tasks/:id`,
// `/tabs/attendance/:id/protocol`, duty-delivery `/tabs/attendance/:id` and
// `/tabs/signout`, attendix-user `/resetPassword`). Bookmarks and installed
// PWAs point there as well. Without this table those paths would fall through
// to the public song-sharing route `/:songSharingId/:songId`.

/// Route that resolves the tenant (cold start or `?tenantId=`) and then opens
/// its `to` location (or the role's home page when `to` is missing).
const String kOpenLinkRoute = '/open-link';

/// Query parameter of [kOpenLinkRoute] holding the target location.
const String kOpenLinkTargetParam = 'to';

/// Translates a legacy Ionic location into the Flutter location, or returns
/// `null` when [uri] is not a legacy URL. Query parameters (e.g. `tenantId`,
/// `tab`) are carried over.
String? legacyRouteRedirect(Uri uri) {
  final path = uri.path;
  if (path == '/resetPassword' || path == '/reset-password') {
    // The recovery tokens are read from the browser URL by the auth link
    // handling; the route itself only needs to show "Neues Passwort".
    return '/new-password';
  }
  if (path != '/tabs' && !path.startsWith('/tabs/')) return null;

  final segments =
      path.substring('/tabs'.length).split('/').where((s) => s.isNotEmpty).toList();
  final target = _mapTabs(segments);
  if (uri.queryParameters.isEmpty) return target;
  return Uri(path: target, queryParameters: uri.queryParameters).toString();
}

String _mapTabs(List<String> s) {
  if (s.isEmpty) return kOpenLinkRoute; // Ionic: '' → /tabs/player (role home)
  final rest = s.sublist(1);
  switch (s.first) {
    case 'player':
      return '/people';
    case 'list': // evaluate-critical-rules: /tabs/list?tenantId=
      return '/attendance';
    case 'attendance':
      if (rest.isEmpty) return '/attendance';
      if (rest.length >= 2 && rest[1] == 'protocol') {
        return '/settings/protocol/${rest.first}';
      }
      return '/attendance/${rest.first}';
    case 'songs-tab':
      return rest.isEmpty ? '/songs-tab' : '/settings/songs/${rest.first}';
    case 'messages':
      return rest.isEmpty ? '/settings/messages' : '/messages/${rest.first}';
    case 'org-plans':
      return rest.isEmpty ? '/org-plans-tab' : '/settings/org-plans/planung';
    case 'signout':
    case 'overview':
    case 'members':
    case 'parents':
    case 'home-dashboard':
    case 'dashboard':
      return '/${s.first}';
    case 'settings':
      return _mapSettings(rest);
    default:
      return kOpenLinkRoute;
  }
}

String _mapSettings(List<String> t) {
  if (t.isEmpty) return '/settings';
  final rest = t.sublist(1);
  switch (t.first) {
    // Ionic redirects the list routes to the team organization page
    case 'agenda-items':
    case 'tasks':
      return rest.isEmpty
          ? '/settings/team-organization'
          : '/settings/${t.first}/${rest.first}';
    case 'meetings':
      return '/settings/team-organization';
    case 'register': // Ionic "Neue Instanz registrieren"
      return '/tenants/new';
    case 'general':
      if (rest.isEmpty) return '/settings/general';
      if (rest.first == 'types') {
        return rest.length > 1 ? '/settings/types/${rest[1]}' : '/settings/types';
      }
      return '/settings/general/${rest.first}'; // branding, extra-fields
    case 'org-settings':
      // Flutter has no separate org branding page (lives in org settings)
      if (rest.isNotEmpty && rest.first == 'branding') return '/settings/org-settings';
      return '/settings/${t.join('/')}';
    default:
      // Same path below /settings: teachers, instruments, songs(/:id), files,
      // messages, notifications, handover(/detail), voice-leader,
      // role-permissions, delete-account, help(/article/:id|/glossary),
      // org-plans(/planung), planung, administration, dashboard,
      // team-organization, tasks/:id, agenda-items/:id
      return '/settings/${t.join('/')}';
  }
}

/// In-app (tenant scoped) routes: they need a selected tenant, honour
/// `?tenantId=` and are resumed after login when opened signed out.
const List<String> _tenantScopedRoots = [
  '/people',
  '/attendance',
  '/overview',
  '/signout',
  '/members',
  '/parents',
  '/statistics',
  '/planning',
  '/history',
  '/export',
  '/messages',
  '/settings',
  '/home-dashboard',
  '/dashboard',
  '/songs-tab',
  '/org-plans-tab',
];

/// Whether [path] is an in-app route that belongs to a tenant.
bool isTenantScopedRoute(String path) {
  for (final root in _tenantScopedRoots) {
    if (path == root || path.startsWith('$root/')) return true;
  }
  return false;
}

/// Location of the tenant resolver for [uri]: `?tenantId=` is removed from
/// the target (it is passed separately) so the resolved link does not loop.
String openLinkLocation(Uri uri, {String? tenantId}) {
  final params = Map<String, String>.of(uri.queryParameters)..remove('tenantId');
  final target = Uri(
    path: uri.path,
    queryParameters: params.isEmpty ? null : params,
  ).toString();
  return Uri(path: kOpenLinkRoute, queryParameters: {
    kOpenLinkTargetParam: target,
    if (tenantId != null) 'tenantId': tenantId,
  }).toString();
}

/// Validates the resolver target: only in-app paths are allowed (no external
/// URLs or protocol-relative `//host` targets).
String? sanitizeOpenLinkTarget(String? target) {
  if (target == null || target.isEmpty) return null;
  if (!target.startsWith('/') || target.startsWith('//')) return null;
  final uri = Uri.tryParse(target);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return isTenantScopedRoute(uri.path) ? target : null;
}

/// With the hash URL strategy a server link like `https://attendix.de/tabs/list?tenantId=3`
/// would open the start page, because Flutter only reads the `#` fragment.
/// Returns the `#/...` form (`/#/tabs/list?tenantId=3`) for such a URL, or
/// `null` when nothing has to change (root path, or a fragment is present —
/// e.g. an existing hash route or Supabase auth tokens).
String? legacyPathToHashUrl(Uri uri, {String basePath = '/'}) {
  if (uri.fragment.isNotEmpty) return null;
  final base = basePath.endsWith('/') ? basePath : '$basePath/';
  final path = uri.path;
  if (!path.startsWith(base)) return null;
  final route = path.substring(base.length - 1);
  if (route == '/' || route.isEmpty) return null;
  // Static files (e.g. /assets/x.png, /manifest.json) are never app routes.
  if (route.split('/').last.contains('.')) return null;
  return '$base#$route${uri.hasQuery ? '?${uri.query}' : ''}';
}
