import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../providers/tenant_providers.dart';
import 'page_transitions.dart';
import 'tracking_observer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent; // MISC2
import '../services/tracking/tracking_event.dart'; // MISC2
import '../services/tracking/tracking_service.dart'; // MISC2
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/tenant_selection/presentation/pages/tenant_selection_page.dart';
import '../../features/tenant_selection/presentation/pages/tenant_create_page.dart';
import '../../features/tenant_selection/presentation/pages/tenant_detail_page.dart';
import '../../shared/widgets/layout/main_shell.dart';
import '../../features/people/presentation/pages/people_list_page.dart';
import '../../features/people/presentation/pages/person_detail_page.dart';
import '../../features/people/presentation/pages/person_create_page.dart';
import '../../features/attendance/presentation/pages/attendance_list_page.dart';
import '../../features/attendance/presentation/pages/attendance_detail_page.dart';
import '../../features/attendance/presentation/pages/attendance_create_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/general_settings_page.dart';
import '../../features/settings/presentation/pages/attendance_types_page.dart';
import '../../features/settings/presentation/pages/attendance_type_edit_page.dart';
import '../../features/settings/presentation/pages/user_management_page.dart';
import '../../features/settings/presentation/pages/pending_players_page.dart';
import '../../features/settings/presentation/pages/batch_account_creation_page.dart';
import '../../features/settings/presentation/pages/left_players_page.dart';
import '../../features/settings/presentation/pages/calendar_subscription_page.dart';
import '../../features/settings/presentation/pages/viewers_page.dart';
import '../../features/settings/presentation/pages/parents_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/teachers/presentation/pages/teachers_list_page.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/songs/presentation/pages/songs_list_page.dart';
import '../../features/songs/presentation/pages/song_detail_page.dart';
import '../../features/songs/presentation/pages/song_create_page.dart';
import '../../features/songs/presentation/pages/song_edit_page.dart';
import '../../features/instruments/presentation/pages/instruments_list_page.dart';
import '../../features/self_service/presentation/pages/self_service_overview_page.dart';
import '../../features/self_service/presentation/pages/signout_page.dart'; // ATTENDANCE_SIGNOUT
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/planning/presentation/pages/planning_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
// TEAM_ORG: Teamorganisation replaces the old meetings pages (kept, unlinked)
import '../../features/team_organization/presentation/pages/agenda_item_detail_page.dart';
import '../../features/team_organization/presentation/pages/protocol_page.dart';
import '../../features/team_organization/presentation/pages/task_detail_page.dart';
import '../../features/team_organization/presentation/pages/team_organization_page.dart';
import '../../features/team_organization/presentation/pages/teams_config_page.dart';
import '../../features/voice_leader/presentation/pages/voice_leader_page.dart';
import '../../features/members/presentation/pages/members_page.dart';
import '../../features/registration/presentation/pages/tenant_registration_page.dart';
import '../../features/parents/presentation/pages/parents_portal_page.dart';
import '../../features/shifts/presentation/pages/shifts_list_page.dart';
import '../../features/shifts/presentation/pages/shift_detail_page.dart';
// LEGAL_HELP
import '../../data/repositories/account_repository.dart';
import '../../features/legal/presentation/pages/legal_page.dart';
import '../../features/legal/presentation/pages/terms_page.dart';
import '../../features/help/presentation/pages/help_page.dart';
import '../../features/help/presentation/pages/help_article_page.dart';
import '../../features/help/presentation/pages/help_glossary_page.dart';
import '../../features/settings/presentation/pages/delete_account_page.dart';
// SETTINGS_EXT
import '../../features/settings/presentation/pages/files_page.dart';
import '../../features/settings/presentation/pages/role_permissions_page.dart';
import '../../features/settings/presentation/pages/extra_fields_page.dart';
import '../../features/settings/presentation/pages/branding_page.dart';
import '../../features/settings/presentation/pages/link_persons_page.dart';
// END SETTINGS_EXT
// MESSAGES
import '../../features/messages/presentation/pages/message_detail_page.dart';
import '../../features/messages/presentation/pages/message_list_page.dart';
// DASHBOARD
import '../providers/dashboard_providers.dart';
import '../../features/dashboard/presentation/pages/home_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_settings_page.dart';
import '../../features/dashboard/presentation/pages/administration_page.dart';
import '../../features/dashboard/presentation/pages/usage_dashboard_page.dart';
// PEOPLE_IMPORT
import '../../features/settings/presentation/pages/handover_page.dart';
import '../../features/settings/presentation/pages/handover_detail_page.dart';
// SONGS
import '../../features/public_links/presentation/pages/app_redirect_page.dart';
import '../../features/public_links/presentation/pages/open_file_page.dart';
// ORG_PLANS
import '../../features/organisation/presentation/pages/org_person_fields_page.dart';
import '../../features/organisation/presentation/pages/org_plan_public_page.dart';
import '../../features/organisation/presentation/pages/org_planning_templates_page.dart';
import '../../features/organisation/presentation/pages/org_plans_page.dart';
import '../../features/organisation/presentation/pages/org_settings_page.dart';
import '../../features/planning/presentation/pages/open_attendance_page.dart';
import '../../features/planning/presentation/pages/public_planning_page.dart';
import '../../features/planning/presentation/pages/shared_plan_page.dart';
// ORG_PLANS end

/// Listenable that notifies when auth state changes
/// Used by GoRouter to re-evaluate redirects without recreating the router
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.signedIn) _ref.read(trackingServiceProvider).track(TrackingEvent.login); // MISC2
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
  '/settings/viewers': _isAdmin,
  '/settings/parents': _isAdmin,

  // Admin or Responsible
  '/settings/general': _isAdminOrResponsible,
  '/settings/types': _isAdminOrResponsible,
  '/settings/instruments': _isAdminOrResponsible,
  // INTEGRATION: '/settings/meetings' only redirects to the team organization
  // (Ionic), which gates access itself; no role check here.
  '/settings/shifts': _isAdminOrResponsible,
  '/settings/pending': _isAdminOrResponsible,
  '/settings/batch-accounts': _isAdmin,
  '/settings/left': _isAdminOrResponsible,
  // SETTINGS_EXT
  '/settings/role-permissions': _isAdminOrResponsible,
  // (/settings/files prüft den Zugriff selbst: abhängig von tenants.files_shared)
  // END SETTINGS_EXT
  // MESSAGES
  '/settings/messages': _isAdminOrResponsible,
  // PEOPLE_IMPORT
  '/settings/handover': _isAdminOrResponsible,
  // ORG_PLANS: Ablaufplanung & Organisation (Ionic: admin/responsible)
  '/settings/planung': _isAdminOrResponsible,
  '/settings/org-plans': _isAdminOrResponsible,
  '/settings/org-settings': _isAdminOrResponsible,

  // Conductor routes (Admin, Responsible, Viewer)
  '/settings/teachers': _isConductor,
  '/people': _canSeePeopleTab,
  // SEC-017: Analytics and export routes require conductor role
  '/statistics': _isConductor,
  '/planning': _canEditPlans, // ORG_PLANS: observers must not see the plan
  '/history': _isConductor,
  '/export': _isConductor,

  // Attendance management
  '/attendance': _canSeeAttendanceTab,

  // DASHBOARD (Ionic Utils.isUrlAccessAllowed: Admin/Responsible)
  '/home-dashboard': _isAdminOrResponsible,
  '/settings/dashboard': _isAdminOrResponsible,
};

bool _isAdmin(Role role) => role.isAdmin;
bool _isAdminOrResponsible(Role role) => role.isAdmin || role.isResponsible;
bool _isConductor(Role role) => role.isConductor;
bool _canSeePeopleTab(Role role) => role.canSeePeopleTab;
bool _canSeeAttendanceTab(Role role) => role.canSeeAttendanceTab;
// ORG_PLANS: Ablaufplan editing (Role.isConductor includes observers/viewers)
bool _canEditPlans(Role role) => role.isAdmin || role.isResponsible || role.isHelper;
/// ORG_PLANS: public plan routes reachable without login (share keys)
const Set<String> _publicPlanRoutes = {'/plan', '/planung', '/org-plan'};

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

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    observers: [TrackingObserver(ref.container)],
    redirect: (context, state) {
      // Read auth state inside redirect (not watch)
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.whenOrNull(
        data: (auth) => auth.session != null,
      ) ?? false;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';

      // Public tenant registration route - allow access without login
      final isTenantRegistration = state.matchedLocation.startsWith('/register/');

      // LEGAL_HELP: Impressum & Datenschutz is public (Ionic /legal)
      final isLegalRoute = state.matchedLocation == '/legal';
      if (isLegalRoute) return null;
      // INTEGRATION: Teams tab config is a top-level public route in Ionic
      // (outside the tabs/login guard); the Flutter page is a static hint.
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

      // If not logged in and not on auth route or tenant registration, redirect to login
      if (!isLoggedIn && !isAuthRoute && !isTenantRegistration) {
        return '/login';
      }

      // If logged in and on auth route, redirect to tenant selection
      if (isLoggedIn && isAuthRoute) {
        // SONGS: resume a shared file link opened while signed out
        return PendingFileLink.consume() ?? '/tenants';
      }

      // LEGAL_HELP: Terms consent gate (Ionic TermsGuard) — logged-in users
      // without user_metadata.terms_accepted_at must accept first.
      if (isLoggedIn && !isTenantRegistration) {
        final termsAccepted =
            ref.read(accountRepositoryProvider).hasAcceptedTerms;
        final isTermsRoute = state.matchedLocation == '/terms';
        if (!termsAccepted && !isTermsRoute) return '/terms';
        if (termsAccepted && isTermsRoute) return '/tenants';
        if (isTermsRoute) return null;
      } else if (state.matchedLocation == '/terms') {
        return '/login';
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
        }

        final role = ref.read(currentRoleProvider);
        final location = state.matchedLocation;

        // Check if route (or parent route) is protected
        for (final entry in _protectedRoutes.entries) {
          if (location == entry.key || location.startsWith('${entry.key}/')) {
            final hasAccess = entry.value(role);
            if (!hasAccess) {
              // Redirect to appropriate default route based on role
              if (role.canSeePeopleTab) {
                return '/people';
              } else if (role.canSeeAttendanceTab) {
                return '/attendance';
              } else {
                return '/signout';
              }
            }
            break;
          }
        }
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => RegisterPage(
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // Public tenant registration (no auth required)
      GoRoute(
        path: '/register/:id',
        name: 'tenantRegistration',
        builder: (context, state) {
          final registerId = state.pathParameters['id'] ?? '';
          return TenantRegistrationPage(registerId: registerId);
        },
      ),

      // LEGAL_HELP: public legal page + terms consent gate
      GoRoute(
        path: '/legal',
        name: 'legal',
        builder: (context, state) => const LegalPage(),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsPage(),
      ),
      // TEAM_ORG: Microsoft Teams tab configuration (hint only)
      GoRoute(
        path: '/teams-config',
        name: 'teamsConfig',
        builder: (context, state) => const TeamsConfigPage(),
      ),
      // ORG_PLANS: public plan routes (share keys, no login) + appointment deep links
      GoRoute(
        path: '/plan',
        name: 'sharedPlan',
        builder: (context, state) => SharedPlanPage(
          attendanceId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
          shareKey: state.uri.queryParameters['key'],
          editKey: state.uri.queryParameters['edit'],
        ),
      ),
      GoRoute(
        path: '/planung',
        name: 'publicPlanning',
        builder: (context, state) => const PublicPlanningPage(),
      ),
      GoRoute(
        path: '/org-plan',
        name: 'orgPlanPublic',
        builder: (context, state) => OrgPlanPublicPage(publicKey: state.uri.queryParameters['key']),
      ),
      GoRoute(
        path: '/open-attendance',
        name: 'openAttendance',
        builder: (context, state) => OpenAttendancePage(
          attendanceId: state.uri.queryParameters['id'],
          tenantId: state.uri.queryParameters['tenantId'],
        ),
      ),
      // ORG_PLANS end

      // Tenant selection
      GoRoute(
        path: '/tenants',
        name: 'tenants',
        builder: (context, state) => const TenantSelectionPage(),
        routes: [
          GoRoute(
            path: 'new',
            name: 'tenantCreate',
            builder: (context, state) => const TenantCreatePage(),
          ),
          GoRoute(
            path: ':id',
            name: 'tenantDetail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) {
                return const Scaffold(
                  body: Center(child: Text('Ungültige Instanz-ID')),
                );
              }
              return TenantDetailPage(tenantId: id);
            },
          ),
        ],
      ),

      // Main app shell with tabs
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // People/Players
          GoRoute(
            path: '/people',
            name: 'people',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const PeopleListPage(),
              state: state,
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'personCreate',
                builder: (context, state) => const PersonCreatePage(),
              ),
              GoRoute(
                path: ':id',
                name: 'personDetail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const Scaffold(
                      body: Center(child: Text('Ungültige Person-ID')),
                    );
                  }
                  return PersonDetailPage(personId: id);
                },
              ),
            ],
          ),

          // Attendance
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const AttendanceListPage(),
              state: state,
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'attendanceCreate',
                builder: (context, state) => const AttendanceCreatePage(),
              ),
              GoRoute(
                path: ':id',
                name: 'attendanceDetail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const Scaffold(
                      body: Center(child: Text('Ungültige Anwesenheits-ID')),
                    );
                  }
                  return AttendanceDetailPage(attendanceId: id);
                },
              ),
            ],
          ),

          // Self-Service Overview (for players)
          GoRoute(
            path: '/overview',
            name: 'selfServiceOverview',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const SelfServiceOverviewPage(),
              state: state,
            ),
          ),

          // ATTENDANCE_SIGNOUT: "Meine Termine" of the current tenant
          GoRoute(
            path: '/signout',
            name: 'signout',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const SignoutPage(),
              state: state,
            ),
          ),

          // Members (for players/helpers when showMembersList is enabled)
          GoRoute(
            path: '/members',
            name: 'members',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const MembersPage(),
              state: state,
            ),
          ),

          // Parents Portal (for parents to manage children's attendance)
          GoRoute(
            path: '/parents',
            name: 'parentsPortal',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const ParentsPortalPage(),
              state: state,
            ),
          ),

          // Statistics
          GoRoute(
            path: '/statistics',
            name: 'statistics',
            builder: (context, state) => const StatisticsPage(),
          ),

          // Planning
          GoRoute(
            path: '/planning',
            name: 'planning',
            builder: (context, state) {
              final attendanceId = int.tryParse(
                state.uri.queryParameters['attendanceId'] ?? '',
              );
              // ORG_PLANS: open a specific plan of a Termin with several plans
              final planIndex = int.tryParse(state.uri.queryParameters['plan'] ?? '') ?? 0;
              return PlanningPage(attendanceId: attendanceId, initialPlanIndex: planIndex);
            },
          ),

          // History
          GoRoute(
            path: '/history',
            name: 'history',
            builder: (context, state) => const HistoryPage(),
          ),

          // Export
          GoRoute(
            path: '/export',
            name: 'export',
            builder: (context, state) => const ExportPage(),
          ),

          // Settings
          // MESSAGES: Mitteilung detail (recipients + admins, Ionic /tabs/messages/:id)
          GoRoute(
            path: '/messages/:id',
            name: 'messageDetail',
            builder: (context, state) =>
                MessageDetailPage(messageId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const SettingsPage(),
              state: state,
            ),
            routes: [
              GoRoute(
                path: 'profile',
                name: 'profile',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: 'songs',
                name: 'songs',
                builder: (context, state) => const SongsListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'songCreate',
                    builder: (context, state) => const SongCreatePage(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'songDetail',
                    builder: (context, state) {
                      final id = state.pathParameters['id'];
                      if (id == null) return const SongsListPage();
                      return SongDetailPage(songId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'songEdit',
                        builder: (context, state) {
                          final id = int.tryParse(state.pathParameters['id'] ?? '');
                          if (id == null) return const SongsListPage();
                          return SongEditPage(songId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'instruments',
                name: 'instruments',
                builder: (context, state) => const InstrumentsListPage(),
              ),
              GoRoute(
                path: 'teachers',
                name: 'teachers',
                builder: (context, state) => const TeachersListPage(),
              ),
              // TEAM_ORG: Teamorganisation (replaces Besprechungen)
              GoRoute(
                path: 'meetings',
                name: 'meetings',
                redirect: (context, state) => '/settings/team-organization',
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'meetingDetail',
                    redirect: (context, state) => '/settings/team-organization',
                  ),
                ],
              ),
              // MESSAGES: Mitteilungen list (admins/responsibles, Ionic /tabs/settings/messages)
              GoRoute(
                path: 'messages',
                name: 'messages',
                builder: (context, state) => const MessageListPage(),
              ),
              GoRoute(
                path: 'team-organization',
                name: 'teamOrganization',
                builder: (context, state) => TeamOrganizationPage(
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
              GoRoute(
                path: 'tasks/:id',
                name: 'taskDetail',
                builder: (context, state) => TaskDetailPage(taskId: state.pathParameters['id'] ?? ''),
              ),
              GoRoute(
                path: 'agenda-items/:id',
                name: 'agendaItemDetail',
                builder: (context, state) => AgendaItemDetailPage(itemId: state.pathParameters['id'] ?? 'new'),
              ),
              GoRoute(
                path: 'protocol/:attendanceId',
                name: 'protocol',
                redirect: (context, state) =>
                    int.tryParse(state.pathParameters['attendanceId'] ?? '') == null
                        ? '/settings/team-organization?tab=protocols'
                        : null,
                builder: (context, state) => ProtocolPage(
                  attendanceId: int.parse(state.pathParameters['attendanceId']!),
                ),
              ),
              GoRoute(
                path: 'notifications',
                name: 'notifications',
                builder: (context, state) => const NotificationsPage(),
              ),
              GoRoute(
                path: 'general',
                name: 'general',
                builder: (context, state) => const GeneralSettingsPage(),
              ),
              GoRoute(
                path: 'users',
                name: 'users',
                builder: (context, state) => const UserManagementPage(),
              ),
              GoRoute(
                path: 'types',
                name: 'attendanceTypes',
                builder: (context, state) => const AttendanceTypesPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'attendanceTypeEdit',
                    builder: (context, state) {
                      final id = state.pathParameters['id'];
                      if (id == null) return const AttendanceTypesPage();
                      return AttendanceTypeEditPage(typeId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'pending',
                name: 'pendingPlayers',
                builder: (context, state) => const PendingPlayersPage(),
              ),
              GoRoute(
                path: 'batch-accounts',
                name: 'batchAccountCreation',
                builder: (context, state) => const BatchAccountCreationPage(),
              ),
              GoRoute(
                path: 'left',
                name: 'leftPlayers',
                builder: (context, state) => const LeftPlayersPage(),
              ),
              GoRoute(
                path: 'calendar',
                name: 'calendarSubscription',
                builder: (context, state) => const CalendarSubscriptionPage(),
              ),
              GoRoute(
                path: 'voice-leader',
                name: 'voiceLeader',
                builder: (context, state) => const VoiceLeaderPage(),
              ),
              GoRoute(
                path: 'shifts',
                name: 'shifts',
                builder: (context, state) => const ShiftsListPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'shiftDetail',
                    builder: (context, state) {
                      final id = state.pathParameters['id'];
                      if (id == null) return const ShiftsListPage();
                      return ShiftDetailPage(shiftId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'viewers',
                name: 'viewers',
                builder: (context, state) => const ViewersPage(),
              ),
              GoRoute(
                path: 'parents',
                name: 'parentsManagement',
                builder: (context, state) => const ParentsPage(),
              ),
              // ORG_PLANS: Ablaufplanung, Org-Pläne & Organisation
              GoRoute(
                path: 'planung',
                name: 'adHocPlanning',
                builder: (context, state) => const PublicPlanningPage(inApp: true),
              ),
              GoRoute(
                path: 'org-plans',
                name: 'orgPlans',
                builder: (context, state) => const OrgPlansPage(),
                routes: [
                  GoRoute(
                    path: 'planung',
                    name: 'orgPlansPlanning',
                    builder: (context, state) => const PublicPlanningPage(inApp: true, fromOrgPlans: true),
                  ),
                ],
              ),
              GoRoute(
                path: 'org-settings',
                name: 'orgSettings',
                builder: (context, state) => const OrgSettingsPage(),
                routes: [
                  GoRoute(
                    path: 'planning-templates',
                    name: 'orgPlanningTemplates',
                    builder: (context, state) => const OrgPlanningTemplatesPage(),
                  ),
                  GoRoute(
                    path: 'person-fields',
                    name: 'orgPersonFields',
                    builder: (context, state) => const OrgPersonFieldsPage(),
                  ),
                ],
              ),
              // ORG_PLANS end
              // LEGAL_HELP: help center + account deletion
              GoRoute(
                path: 'help',
                name: 'help',
                builder: (context, state) => const HelpPage(),
                routes: [
                  GoRoute(
                    path: 'article/:id',
                    name: 'helpArticle',
                    builder: (context, state) => HelpArticlePage(
                      articleId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'glossary',
                    name: 'helpGlossary',
                    builder: (context, state) => const HelpGlossaryPage(),
                  ),
                ],
              ),
              GoRoute(
                path: 'delete-account',
                name: 'deleteAccount',
                builder: (context, state) => const DeleteAccountPage(),
              ),
              // SETTINGS_EXT
              GoRoute(
                path: 'files',
                name: 'files',
                builder: (context, state) => FilesPage(
                  initialPath: state.uri.queryParameters['path'],
                  openFileName: state.uri.queryParameters['open'],
                ),
              ),
              GoRoute(
                path: 'role-permissions',
                name: 'rolePermissions',
                builder: (context, state) => const RolePermissionsPage(),
              ),
              GoRoute(
                path: 'general/extra-fields',
                name: 'extraFields',
                builder: (context, state) => const ExtraFieldsPage(),
              ),
              GoRoute(
                path: 'general/branding',
                name: 'branding',
                builder: (context, state) => const BrandingPage(),
              ),
              GoRoute(
                path: 'general/link-persons',
                name: 'linkPersons',
                builder: (context, state) => const LinkPersonsPage(),
              ),
              // END SETTINGS_EXT
              // DASHBOARD
              GoRoute(
                path: 'dashboard',
                name: 'dashboardSettings',
                builder: (context, state) => const DashboardSettingsPage(),
              ),
              GoRoute(
                path: 'administration',
                name: 'administration',
                // Ionic SuperDeveloperGuard
                redirect: (context, state) =>
                    ref.read(isSuperDeveloperProvider) ? null : '/settings',
                builder: (context, state) => const AdministrationPage(),
              ),
              // PEOPLE_IMPORT: Personenübergabe (Ionic settings/handover)
              GoRoute(
                path: 'handover',
                name: 'handover',
                builder: (context, state) => const HandoverPage(),
                routes: [
                  GoRoute(
                    path: 'detail',
                    name: 'handoverDetail',
                    builder: (context, state) => HandoverDetailPage(
                      data: state.extra is HandoverData
                          ? state.extra as HandoverData
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // DASHBOARD: home dashboard tab (Ionic /tabs/home-dashboard)
          GoRoute(
            path: '/home-dashboard',
            name: 'homeDashboard',
            pageBuilder: (context, state) => AppPageTransitions.none(
              child: const HomeDashboardPage(),
              state: state,
            ),
          ),
          // DASHBOARD: usage analytics (Ionic /tabs/dashboard, SuperDeveloperGuard)
          GoRoute(
            path: '/dashboard',
            name: 'usageDashboard',
            redirect: (context, state) =>
                ref.read(isSuperDeveloperProvider) ? null : '/settings',
            builder: (context, state) => const UsageDashboardPage(),
          ),
        ],
      ),
      // SONGS: public routes, registered last so the wildcard share link
      // routes `/:songSharingId` never shadow app routes (Ionic order).
      GoRoute(
        path: '/app',
        builder: (context, state) => const AppRedirectPage(),
      ),
      GoRoute(
        path: '/open-file',
        builder: (context, state) => OpenFilePage(
          tenantId: int.tryParse(state.uri.queryParameters['tenantId'] ?? ''),
          path: state.uri.queryParameters['path'] ?? '',
          isFolder: state.uri.queryParameters['folder'] == '1',
        ),
      ),
      GoRoute(
        path: '/:songSharingId',
        builder: (context, state) => SongsListPage(
          songSharingId: state.pathParameters['songSharingId'],
        ),
        routes: [
          GoRoute(
            path: ':songId',
            builder: (context, state) => SongDetailPage(
              songId: state.pathParameters['songId'] ?? '',
              songSharingId: state.pathParameters['songSharingId'],
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/people'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
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