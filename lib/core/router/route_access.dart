// PARITY_R7: role and tenant gates of in-app routes whose Ionic access is
// more than a plain role set (the plain ones stay in app_router's
// `_protectedRoutes`).
//
// Ionic sources:
// - tabs.page.ts: on (re)load, a URL that `Utils.isUrlAccessAllowed(url, role)`
//   rejects is replaced by `Utils.getUrl(role)` (Flutter `Role.defaultRoute`).
// - tabs.page.html: which tabs a role sees (signout, parents, members,
//   overview, songs-tab).
// - settings.page.html: which modals/pages a role can open (history,
//   planning, statistics, export, voice-leader).
// - att-list/attendance pages: helpers edit the Ablaufplan of a Termin
//   (`canEdit: isConductor || isHelper`), but "Ablaufplan erstellen" from the
//   settings is admin/responsible only (`showPlanning = isAdmin`).
//
// Pages that only exist as a modal in Ionic (history, planning, statistics,
// export) are gated like their in-app entry point.

import '../constants/enums.dart';

/// Tenant facts the gates need. `null` means "not known yet": the gate does
/// not deny on missing data (a cold start resolves the tenant first).
class RouteAccessTenant {
  const RouteAccessTenant({
    this.type,
    this.showMembersList,
    this.tenantCount,
  });

  /// `tenants.type` (`'general'` hides the Werke area in Ionic).
  final String? type;

  /// `tenants.showMembersList` (Ionic `showMembersTab`).
  final bool? showMembersList;

  /// Number of instances of the user (Ionic `hasMultipleTenants`).
  final int? tenantCount;
}

bool _isAdminOrResponsible(Role role) => role.isAdmin || role.isResponsible;

/// Werke tab (`/songs-tab`): Ionic isUrlAccessAllowed
/// `role !== APPLICANT && role !== PARENT`. SOL_FIX22: also gates the tab
/// itself and its "Als Tab anzeigen" toggle (`songsTabAllowedProvider`), so
/// no role sees a tab the guard would redirect away from.
bool canOpenSongsTab(Role role) => !role.isApplicant && !role.isParent;

/// Ionic `isPlayer || isHelper` of tabs.page.ts.
bool _isPlayerOrHelper(Role role) =>
    role == Role.player ||
    role == Role.none ||
    role == Role.helper ||
    role == Role.voiceLeaderHelper;

bool _matches(String location, String root) =>
    location == root || location.startsWith('$root/');

/// Whether [location] is one of the routes gated by [routeAccessRedirect]
/// (used to wait for the role before deciding).
bool isRoleGatedRoute(String location) => _gates.any((g) => g.applies(location));

class _Gate {
  const _Gate(this.applies, this.allowed);
  final bool Function(String location) applies;
  final bool Function(Role role, Uri uri, RouteAccessTenant tenant) allowed;
}

final List<_Gate> _gates = [
  // Eltern-Portal: only parents (Ionic AuthGuard + isUrlAccessAllowed).
  _Gate((l) => _matches(l, '/parents'), (role, _, __) => role.isParent),
  // "Meine Termine": tab for !isConductor && !isParent.
  _Gate(
    (l) => _matches(l, '/signout'),
    (role, _, __) => !role.isConductor && !role.isParent,
  ),
  // "Übersicht": (isPlayer || isHelper) && hasMultipleTenants.
  _Gate(
    (l) => _matches(l, '/overview'),
    (role, _, t) =>
        _isPlayerOrHelper(role) && (t.tenantCount == null || t.tenantCount! > 1),
  ),
  // "Mitglieder": HELPER/VL/VLH/PLAYER/NONE when the tenant shows the list.
  _Gate(
    (l) => _matches(l, '/members'),
    (role, _, t) =>
        (role.canSeeMembersTab || role == Role.none) &&
        t.showMembersList != false,
  ),
  // Werke tab: Ionic isUrlAccessAllowed `role !== APPLICANT && role !== PARENT`.
  _Gate(
    (l) => _matches(l, '/songs-tab'),
    (role, _, __) => canOpenSongsTab(role),
  ),
  // Stimmführer settings: VOICE_LEADER / VOICE_LEADER_HELPER.
  _Gate(
    (l) => _matches(l, '/settings/voice-leader'),
    (role, _, __) => role.canSeeVoiceLeaderSettings,
  ),
  // Werkhistorie: settings `!isGeneral && !isApplicant` and
  // `isAdmin || isHelper` (admin, responsible, helper, VL-helper).
  _Gate(
    (l) => _matches(l, '/history'),
    (role, _, t) =>
        (_isAdminOrResponsible(role) || role.isHelperRole) && t.type != 'general',
  ),
  // Ablaufplan: "Ablaufplan erstellen" (no Termin) is admin/responsible only;
  // the plan of a Termin (`?attendanceId=`) is edited by everyone who may
  // open the Termin (conductors and helpers, not observers).
  _Gate(
    (l) => _matches(l, '/planning'),
    (role, uri, _) =>
        _isAdminOrResponsible(role) ||
        (role.canAddAttendance &&
            int.tryParse(uri.queryParameters['attendanceId'] ?? '') != null),
  ),
  // Werk anlegen/bearbeiten: Ionic songs page `isAdmin` (admin/responsible).
  _Gate(
    (l) =>
        l == '/settings/songs/new' ||
        RegExp(r'^/settings/songs/[^/]+/edit$').hasMatch(l),
    (role, _, __) => _isAdminOrResponsible(role),
  ),
];

/// Returns the redirect target (the role's start page, Ionic
/// `Utils.getUrl(role)`) when [role] must not open [location], or `null`.
String? routeAccessRedirect(
  String location,
  Uri uri,
  Role role,
  RouteAccessTenant tenant,
) {
  for (final gate in _gates) {
    if (gate.applies(location)) {
      return gate.allowed(role, uri, tenant) ? null : role.defaultRoute;
    }
  }
  return null;
}
