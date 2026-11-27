import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_config.dart';
import '../providers/user_preferences_provider.dart'
    show InstanceSelectionGate, userPreferencesProvider;
import '../constants/enums.dart';
import '../providers/tenant_providers.dart';
import '../providers/role_permission_providers.dart';
import 'page_transitions.dart';
import 'tracking_observer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;
import '../services/tracking/tracking_event.dart';
import '../services/browser_navigation.dart'
    show browserNavigationRouteChanged, setBrowserNavigationContext;
import '../services/tracking/tracking_service.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/tenant_selection/presentation/pages/tenant_selection_page.dart';
import '../../features/tenant_selection/presentation/pages/tenant_create_page.dart';
import '../../features/tenant_selection/presentation/pages/tenant_detail_page.dart';
import '../../features/settings/presentation/pages/attendance_type_edit_page.dart';
import '../../features/people/person_create_prefill.dart';
import '../../features/songs/presentation/pages/songs_list_page.dart';
import '../../features/songs/presentation/pages/song_detail_page.dart';
import '../../features/songs/presentation/utils/song_utils.dart' show SongUtils;
import '../../features/planning/presentation/pages/planning_page.dart';
// TEAM_ORG: Teamorganisation replaces the old meetings pages
import '../../features/team_organization/presentation/pages/agenda_item_detail_page.dart';
import '../../features/team_organization/presentation/pages/protocol_page.dart';
import '../../features/team_organization/presentation/pages/task_detail_page.dart';
import '../../features/team_organization/presentation/pages/rd_meeting_page.dart';
import '../../features/team_organization/presentation/pages/rd_team_page.dart';
import '../../features/team_organization/presentation/pages/teams_config_page.dart';
import '../../features/registration/presentation/pages/tenant_registration_page.dart';
import '../../features/shifts/presentation/pages/shift_detail_page.dart';
import '../../data/repositories/account_repository.dart';
import '../../features/legal/presentation/pages/legal_page.dart';
import '../../features/legal/presentation/pages/terms_page.dart';
import '../../features/assistant/presentation/pages/assistant_page.dart';
import '../../features/settings/presentation/pages/delete_account_page.dart';
import '../../features/settings/presentation/pages/files_page.dart';
// END SETTINGS_EXT
import '../../features/messages/presentation/pages/message_detail_page.dart';
import '../../features/messages/presentation/pages/auto_message_list_page.dart';
import '../../features/messages/presentation/pages/auto_message_rule_page.dart';
import '../providers/dashboard_providers.dart';
import '../../features/settings/presentation/pages/administration_page.dart';
import '../../features/settings/presentation/pages/usage_dashboard_page.dart';
import '../../features/settings/data/handover_logic.dart' show HandoverData;
import '../../features/public_links/presentation/pages/app_redirect_page.dart';
import '../../features/public_links/presentation/pages/open_file_page.dart';
import '../../features/organisation/presentation/pages/org_plan_public_page.dart';
import '../../features/organisation/presentation/pages/org_planning_templates_page.dart';
import '../../features/organisation/presentation/pages/org_plans_page.dart';
import '../../features/planning/presentation/pages/open_attendance_page.dart';
import '../../features/planning/presentation/pages/public_planning_page.dart';
import '../../features/planning/presentation/pages/shared_plan_page.dart';
// ORG_PLANS end
import '../../features/public_links/presentation/pages/open_link_page.dart';
import '../../shared/widgets/dialogs/native_app_ad.dart';
import 'legacy_routes.dart';
import 'attendance_detail_guard.dart';
import 'route_access.dart';
import '../../l10n/l10n.dart';
// Standard app design
import 'redesign_routes.dart';
import '../../shared/shell/rd_shell.dart';
import '../../features/export/presentation/pages/rd_export_page.dart';
import '../../features/songs/presentation/pages/rd_work_categories_page.dart';
import '../../features/instruments/presentation/pages/rd_group_categories_page.dart';
import '../../features/organisation/presentation/pages/rd_org_person_fields_page.dart';
import '../../features/songs/presentation/pages/rd_work_history_page.dart';
import '../../features/people/presentation/pages/rd_handover_detail_page.dart';
import '../../features/people/presentation/pages/rd_handover_page.dart';
import '../../features/people/presentation/pages/rd_link_persons_page.dart';
import '../../features/organisation/presentation/pages/rd_org_settings_page.dart';
import '../../features/songs/presentation/pages/rd_org_songs_page.dart';
import '../../features/settings/presentation/pages/rd_branding_page.dart';
import '../../features/settings/presentation/pages/rd_general_settings_page.dart';
import '../../features/today/presentation/pages/rd_today_page.dart';
import '../../features/songs/presentation/pages/rd_import_page.dart';
import '../../features/settings/presentation/pages/rd_folder_page.dart';
import '../../features/songs/presentation/pages/rd_collections_page.dart';
import '../../features/songs/presentation/pages/rd_collection_edit_page.dart';
import '../../features/songs/presentation/pages/rd_work_create_page.dart';
import '../../features/songs/presentation/pages/rd_work_edit_page.dart';
import '../../features/songs/presentation/pages/rd_work_page.dart';
import '../../features/songs/presentation/pages/rd_works_page.dart';
import '../../features/attendance/presentation/pages/rd_event_create_page.dart';
import '../../features/attendance/presentation/pages/rd_event_edit_page.dart';
import '../../features/attendance/presentation/pages/rd_event_page.dart';
import '../../features/attendance/presentation/pages/rd_events_page.dart';
import '../../features/attendance/presentation/pages/rd_events_split_home.dart';
import '../../features/profile/presentation/pages/rd_me_page.dart';
import '../../features/people/presentation/pages/rd_members_page.dart';
import '../../features/people/presentation/pages/rd_voice_leader_page.dart';
import '../../features/attendance/presentation/pages/rd_own_event_page.dart';
import '../../features/people/presentation/pages/rd_person_page.dart';
import '../../features/people/presentation/pages/rd_person_create_page.dart';
import '../../features/people/presentation/pages/rd_person_edit_page.dart';
import '../../features/people/presentation/pages/rd_person_history_page.dart';
import '../../features/profile/presentation/pages/rd_appearance_page.dart';
import '../../features/messages/presentation/pages/rd_message_compose_page.dart';
import '../../features/profile/presentation/pages/rd_notifications_page.dart';
import '../../features/statistics/presentation/pages/rd_stats_page.dart';
import '../../features/settings/presentation/pages/rd_attendance_types_page.dart';
import '../../features/settings/presentation/pages/rd_extra_field_edit_page.dart';
import '../../features/settings/presentation/pages/rd_extra_fields_page.dart';
import '../../features/instruments/presentation/pages/rd_group_edit_page.dart';
import '../../features/instruments/presentation/pages/rd_groups_page.dart';
import '../../features/teachers/presentation/pages/rd_teacher_edit_page.dart';
import '../../features/teachers/presentation/pages/rd_teachers_page.dart';
import '../../features/shifts/presentation/pages/rd_shift_plans_page.dart';
import '../../features/settings/presentation/pages/rd_role_permissions_page.dart';
import '../../features/messages/presentation/pages/rd_messages_page.dart';
import '../../features/settings/presentation/pages/rd_admins_page.dart';
import '../../features/people/presentation/pages/rd_archive_page.dart';
import '../../features/people/presentation/pages/rd_critical_members_page.dart';
import '../../features/people/presentation/pages/rd_parents_page.dart';
import '../../features/people/presentation/pages/rd_pending_page.dart';
import '../../features/people/presentation/pages/rd_pending_review_page.dart';
import '../../features/settings/data/rd_manage_logic.dart' show RdManageArea, RdManageEntry;
import '../redesign/rd_roles_logic.dart' show RdRoleView;
import '../../features/settings/presentation/pages/rd_manage_page.dart';
import '../../features/help/presentation/pages/rd_help_pages.dart';
import '../../shared/widgets/redesign/rd_split_view.dart';
import '../../shared/widgets/redesign/rd_overview.dart';
import '../../features/songs/presentation/pages/song_import_page.dart';

part 'app_router_classic_routes.dart';
part 'app_router_public_routes.dart';
part 'app_router_redesign_routes.dart';

/// Listenable that notifies when auth state changes
/// Used by GoRouter to re-evaluate redirects without recreating the router
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, next) {
      // Ionic: "Instanzauswahl" only after a real sign-in, not on restore.
      if (next.valueOrNull?.event == AuthChangeEvent.signedIn) InstanceSelectionGate.afterSignIn = true;
      if (next.valueOrNull?.event == AuthChangeEvent.signedIn) _ref.read(trackingServiceProvider).track(TrackingEvent.login);
      // LINKS_STARTUP: Ionic shows the native app ad after SIGNED_IN
      if (next.valueOrNull?.event == AuthChangeEvent.signedIn) _ref.read(nativeAppAdPendingProvider.notifier).state = true;
      notifyListeners();
    });
  }

  final Ref _ref;
}

/// SEC-006: Protected routes with their required role checks
/// SEC-017: Extended with missing analytics and export routes
typedef RoleCheck = bool Function(Role role);

const Map<String, RoleCheck> _protectedRoutes = {
  // Admin-only routes
  '/settings/users': _isAdmin,
  // PARITY_R7: Ionic "Benutzer & Rollen" (Beobachter, Eltern) is shown for
  // isAdmin = ADMIN || RESPONSIBLE; only "Admins" is ADMIN-only.
  '/settings/viewers': _isAdminOrResponsible,
  '/settings/parents': _isAdminOrResponsible,

  // Ionic LinkPersonsPage: modal only for isSuperAdmin (ADMIN), no URL.
  // Must precede '/settings/general' (first prefix match wins).
  '/settings/general/link-persons': _isAdmin,

  // Admin or Responsible
  '/settings/general': _isAdminOrResponsible,
  '/settings/types': _isAdminOrResponsible,
  '/settings/instruments': _isAdminOrResponsible,
  // INTEGRATION: '/settings/meetings' only redirects to the team organization
  // (Ionic), which gates access itself; no role check here.
  '/settings/shifts': _isAdminOrResponsible,
  '/settings/pending': _isAdminOrResponsible,
  '/settings/left': _isAdminOrResponsible,
  '/settings/role-permissions': _isAdminOrResponsible,
  // (/settings/files prüft den Zugriff selbst: abhängig von tenants.files_shared)
  // END SETTINGS_EXT
  '/settings/messages': _isAdminOrResponsible,
  // AUTO_MESSAGES (Ionic 4.18): rules are admin/responsible only (RLS too)
  '/settings/auto-messages': _isAdminOrResponsible,
  '/settings/handover': _isAdminOrResponsible,
  // ORG_PLANS: Ablaufplanung & Organisation (Ionic: admin/responsible)
  '/settings/planung': _isAdminOrResponsible,
  '/settings/org-plans': _isAdminOrResponsible,
  '/settings/org-settings': _isAdminOrResponsible,

  // Conductor routes (Admin, Responsible, Viewer)
  '/settings/teachers': _isConductor,
  '/people/new': _isAdminOrResponsible, // ROLLEN-B-45: create = Admin/Verantwortlich (person_create_page _canEdit)
  '/people': _canSeePeopleTab,
  // SEC-017 / PARITY_R7: Statistik + Export (Ionic settings `isAdmin`:
  // ADMIN/RESPONSIBLE, not VIEWER). /planning and /history: route_access.dart.
  '/statistics': _isAdminOrResponsible,
  '/export': _isAdminOrResponsible,

  // Attendance management
  '/attendance': _canSeeAttendanceTab,

  '/home-dashboard': _isAdminOrResponsible,
  '/settings/dashboard': _isAdminOrResponsible,
  // SETTINGS2: optional "Org" tab (Ionic: Admin/Responsible)
  '/org-plans-tab': _isAdminOrResponsible,
};

bool _isAdmin(Role role) => role.isAdmin;
bool _isAdminOrResponsible(Role role) => role.isAdmin || role.isResponsible;
bool _isConductor(Role role) => role.isConductor;
bool _canSeePeopleTab(Role role) => role.canSeePeopleTab;
bool _canSeeAttendanceTab(Role role) => role.canSeeAttendanceTab;
/// ORG_PLANS: public plan routes reachable without login (share keys)
const Set<String> _publicPlanRoutes = {'/plan', '/planung', '/org-plan'};

/// PARITY_R7: role-based access of a logged-in user with a loaded role
/// (Ionic AuthGuard + TabsPage `Utils.isUrlAccessAllowed`/`getUrl`).
/// Returns the redirect target (the role's start page) or `null`.
@visibleForTesting
String? roleRouteRedirect(
  String location,
  Uri uri,
  Role role, {
  required bool canCreateAttendance,
  RouteAccessTenant tenant = const RouteAccessTenant(),
}) {
  // LEFTOVERS: typed /attendance/:id only for roles that may open a
  // Termin in Ionic (canAddAttendance); must run before the generic
  // '/attendance' prefix entry below (first match wins).
  final attendanceDetailTarget = attendanceDetailRedirect(
    location,
    role,
    canCreate: canCreateAttendance,
  );
  if (attendanceDetailTarget != null) return attendanceDetailTarget;
  // END LEFTOVERS

  // PARITY_R7: role + tenant gates (parents, signout, overview, members,
  // songs-tab, voice-leader, history, planning, song create/edit).
  final accessTarget = routeAccessRedirect(location, uri, role, tenant);
  if (accessTarget != null) return accessTarget;

  // Check if route (or parent route) is protected
  for (final entry in _protectedRoutes.entries) {
    if (location == entry.key || location.startsWith('${entry.key}/')) {
      // PARITY_R7: the role's start page (Ionic Utils.getUrl(role));
      // parents land on /parents instead of the blocked /signout.
      return entry.value(role) ? null : role.defaultRoute;
    }
  }
  return null;
}

/// TERMINE-02 / EINST-03: on a cold start the auth stream has not emitted
/// yet, but Supabase already restored the stored session. Treat that as
/// signed in so the login form does not flash before the page (a failed
/// refresh emits `signedOut` and the redirect sends the user to /login).
bool _sessionRestoring(Ref ref, AsyncValue<AuthState> authState) {
  if (!authState.isLoading || authState.hasValue || authState.hasError) return false;
  try {
    return ref.read(supabaseAuthProvider).currentSession != null;
  } catch (_) {
    return false;
  }
}

/// Provider for the auth change notifier
final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier(ref);
});

// SONGS: routes reachable without login (see public GoRoutes at the end)
bool _isPublicSongsRoute(GoRouterState state) {
  final path = state.fullPath;
  return path == '/app' ||
      path == '/open-file' ||
      path == '/:songSharingId' ||
      path == '/:songSharingId/:songId';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  // Use refreshListenable instead of watching authState directly
  // This prevents router recreation on auth changes (like updateUser)
  final authNotifier = ref.watch(authChangeNotifierProvider);
  // LINKS_STARTUP: true once a session was seen; links opened before that
  // (cold start / reload while the session restores) are resumed after login,
  // locations left by a logout are not.
  var sessionSeen = false;

  final router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // Read auth state inside redirect (not watch)
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.whenOrNull(
        data: (auth) => auth.session != null,
      ) ?? _sessionRestoring(ref, authState);

      // LINKS_STARTUP: legacy Ionic URLs (/tabs/..., /resetPassword) first,
      // before they can fall through to the public `/:songSharingId` routes.
      final legacyTarget = legacyRouteRedirect(state.uri);
      if (legacyTarget != null) return legacyTarget;
      if (isLoggedIn) sessionSeen = true;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/forgot-password';

      // Public tenant registration route - allow access without login
      final isTenantRegistration = state.matchedLocation.startsWith('/register/');

      // LEGAL_HELP: Impressum & Datenschutz is public (Ionic /legal)
      final isLegalRoute = state.matchedLocation == '/legal';
      if (isLegalRoute) return null;
      // INTEGRATION: Teams tab config is a top-level public route in Ionic
      // (outside the tabs/login guard); it only works inside Teams (TEAMS).
      if (state.matchedLocation == '/teams-config') return null;
      // SONGS: public routes (song share links, /app, /open-file) need no
      // login; /open-file handles auth itself and stashes the link.
      if (_isPublicSongsRoute(state)) return null;
      // ORG_PLANS: public plan links work without login; logged-in users use the in-app planner
      final isPublicPlanRoute = _publicPlanRoutes.contains(state.matchedLocation);
      if (isPublicPlanRoute) {
        return isLoggedIn && state.matchedLocation == '/planung' ? '/settings/planung' : null;
      }

      // INTEGRATION: remember an /open-attendance deep link opened while
      // signed out and resume it after login (Ionic pendingAttendanceId).
      if (!isLoggedIn && state.matchedLocation == '/open-attendance') {
        PendingFileLink.set(state.uri.toString());
        return '/login';
      }

      // LINKS_STARTUP: resume an in-app link opened while signed out
      // (Ionic keeps the URL through login).
      if (!isLoggedIn &&
          !sessionSeen &&
          (isTenantScopedRoute(state.matchedLocation) ||
              state.matchedLocation == kOpenLinkRoute)) {
        PendingFileLink.set(state.uri.toString());
        return '/login';
      }

      // If not logged in and not on auth route or tenant registration, redirect to login
      if (!isLoggedIn && !isAuthRoute && !isTenantRegistration) {
        return '/login';
      }

      // If logged in and on auth route, redirect to tenant selection
      if (isLoggedIn && isAuthRoute) {
        // REVIEW_FIX2: keep a stashed link through the terms gate – it is
        // consumed once /terms is passed (Ionic keeps the URL through login).
        if (!ref.read(accountRepositoryProvider).hasAcceptedTerms) {
          return '/terms';
        }
        // SONGS: resume a shared file link opened while signed out
        final pending = PendingFileLink.consume();
        if (pending != null) return pending;
        // NAV_REPLACE: browser Back onto /login with an instance already
        // open returns to its start page (Ionic replaces the login/tenant
        // steps), not to the instance selection.
        if (ref.read(currentTenantIdProvider) != null &&
            !ref.read(isRoleLoadingProvider) &&
            !InstanceSelectionGate.wanted(ref.read(userPreferencesProvider))) {
          return homeRouteFor(
            ref.read(currentRoleProvider),
            ref.read(currentTenantIdProvider),
            ref.read(supabaseClientProvider).auth.currentUser?.userMetadata,
          );
        }
        return '/tenants';
      }

      // LEGAL_HELP: Terms consent gate (Ionic TermsGuard) — logged-in users
      // without user_metadata.terms_accepted_at must accept first.
      if (isLoggedIn && !isTenantRegistration) {
        final termsAccepted =
            ref.read(accountRepositoryProvider).hasAcceptedTerms;
        final isTermsRoute = state.matchedLocation == '/terms';
        if (!termsAccepted && !isTermsRoute) return '/terms';
        if (termsAccepted && isTermsRoute) {
          final pending = PendingFileLink.consume();
          if (pending != null) return pending;
          // Ionic terms accept(): Utils.getUrl(tenantUser.role) – the start
          // page of the open instance, '/register' without one. While the
          // role still loads the terms page navigates itself.
          final tenantId = ref.read(currentTenantIdProvider);
          if (tenantId == null) return '/register';
          if (ref.read(isRoleLoadingProvider)) return null;
          return homeRouteFor(
            ref.read(currentRoleProvider),
            tenantId,
            ref.read(supabaseClientProvider).auth.currentUser?.userMetadata,
          );
        }
        if (isTermsRoute) return null;
      } else if (state.matchedLocation == '/terms') {
        return '/login';
      }

      // LINKS_STARTUP: in-app links need the right tenant first:
      // `?tenantId=` switches the instance (Ionic att-list/attendance pages),
      // a cold start without a selected tenant restores it.
      if (isLoggedIn && isTenantScopedRoute(state.matchedLocation)) {
        final linkTenantId = state.uri.queryParameters['tenantId'];
        final currentTenantId = ref.read(currentTenantIdProvider);
        if (currentTenantId == null ||
            (linkTenantId != null &&
                int.tryParse(linkTenantId) != null &&
                int.tryParse(linkTenantId) != currentTenantId)) {
          return openLinkLocation(state.uri, tenantId: linkTenantId);
        }
      }

      // SEC-006: Role-based access control for protected routes
      // SEC-008: Skip role check while role is still loading
      if (isLoggedIn && !isAuthRoute && !isTenantRegistration) {
        final isRoleLoading = ref.read(isRoleLoadingProvider);

        // SEC-008: If role is still loading and trying to access protected route,
        // redirect to tenant selection to ensure role is loaded first
        if (isRoleLoading) {
          final location = state.matchedLocation;
          for (final routePath in _protectedRoutes.keys) {
            if (location == routePath || location.startsWith('$routePath/')) {
              return '/tenants';
            }
          }
          if (isRoleGatedRoute(location)) return '/tenants';
        }

        final role = ref.read(currentRoleProvider);
        final location = state.matchedLocation;

        final legacyTarget = RedesignRoutes.legacyTarget(location);
        if (legacyTarget != null) return legacyTarget;
        final redesignTarget = RedesignRoutes.roleRedirect(location, role);
        if (redesignTarget != null) return redesignTarget;

        // PARITY_R7: all role/tenant checks in one pure function (tested).
        final tenant = ref.read(currentTenantProvider);
        final roleTarget = roleRouteRedirect(
          location,
          state.uri,
          role,
          canCreateAttendance: ref.read(canCreateAttendanceProvider),
          tenant: RouteAccessTenant(
            type: tenant?.type,
            showMembersList: tenant?.showMembersList,
            tenantCount: ref.read(userTenantsProvider).valueOrNull?.length,
          ),
        );
        if (roleTarget != null) return roleTarget;
      }

      return null;
    },
    routes: [
      ..._publicAuthRoutes(ref),

      // Main app shell with tabs
      ShellRoute(
        builder: (context, state, child) => RdShell(child: child),
        routes: [
          ..._redesignShellRoutes(ref),
          ..._classicShellRoutes(ref),
        ],
      ),
      ..._publicTailRoutes(ref),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: Text(context.l10n.commonError)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(context.l10n.coreFlutterRouterPageNotFound(state.matchedLocation)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RedesignRoutes.today),
              child: Text(context.l10n.coreFlutterRouterGoHome),
            ),
          ],
        ),
      ),
    ),
  );

  // TRACKING: page_view {url} for every navigation incl. ShellRoute tabs
  // (Ionic app.component trackPageViews).
  final pageViewTracker = PageViewTracker(ref.container, router);
  ref.onDispose(pageViewTracker.dispose);

  // SWIPE_BACK_WEB: a browser-animated history step counts as handled after
  // the frame of its route change, also when that change has no transition
  // (tab switch). The page pictures for Safari's swipe belong to one account
  // and group; switching either drops them.
  router.routerDelegate.addListener(browserNavigationRouteChanged);
  ref.onDispose(
      () => router.routerDelegate.removeListener(browserNavigationRouteChanged));
  void updateNavigationContext() => setBrowserNavigationContext(
      '${ref.read(currentAuthUserIdProvider)}:${ref.read(currentTenantIdProvider)}');
  ref.listen(currentAuthUserIdProvider, (_, __) => updateNavigationContext());
  ref.listen(currentTenantIdProvider, (_, __) => updateNavigationContext());
  updateNavigationContext();
  return router;
});

/// Route names for type-safe navigation
class AppRoutes {
  AppRoutes._();

  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgotPassword';
  static const String tenants = 'tenants';
  static const String people = 'people';
  static const String personDetail = 'personDetail';
  static const String attendance = 'attendance';
  static const String attendanceDetail = 'attendanceDetail';
  static const String attendanceCreate = 'attendanceCreate';
  static const String settings = 'settings';
  static const String profile = 'profile';
  static const String songs = 'songs';
  static const String songDetail = 'songDetail';
  static const String songCreate = 'songCreate';
  static const String songEdit = 'songEdit';
  static const String instruments = 'instruments';
  static const String teachers = 'teachers';
  static const String meetings = 'meetings';
  static const String meetingDetail = 'meetingDetail';
  static const String notifications = 'notifications';
  static const String general = 'general';
  static const String statistics = 'statistics';
  static const String planning = 'planning';
  static const String history = 'history';
  static const String shifts = 'shifts';
  static const String shiftDetail = 'shiftDetail';
  static const String tenantDetail = 'tenantDetail';
}
