import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../providers/tenant_providers.dart';
import 'page_transitions.dart';
import 'tracking_observer.dart';
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
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/planning/presentation/pages/planning_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/meetings/presentation/pages/meetings_list_page.dart';
import '../../features/meetings/presentation/pages/meeting_detail_page.dart';
import '../../features/voice_leader/presentation/pages/voice_leader_page.dart';
import '../../features/members/presentation/pages/members_page.dart';
import '../../features/registration/presentation/pages/tenant_registration_page.dart';
import '../../features/parents/presentation/pages/parents_portal_page.dart';
import '../../features/shifts/presentation/pages/shifts_list_page.dart';
import '../../features/shifts/presentation/pages/shift_detail_page.dart';
// DASHBOARD
import '../providers/dashboard_providers.dart';
import '../../features/dashboard/presentation/pages/home_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_settings_page.dart';
import '../../features/dashboard/presentation/pages/administration_page.dart';
import '../../features/dashboard/presentation/pages/usage_dashboard_page.dart';

/// Listenable that notifies when auth state changes
/// Used by GoRouter to re-evaluate redirects without recreating the router
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) {
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
  '/settings/meetings': _isAdminOrResponsible,
  '/settings/shifts': _isAdminOrResponsible,
  '/settings/pending': _isAdminOrResponsible,
  '/settings/batch-accounts': _isAdmin,
  '/settings/left': _isAdminOrResponsible,

  // Conductor routes (Admin, Responsible, Viewer)
  '/settings/teachers': _isConductor,
  '/people': _canSeePeopleTab,
  // SEC-017: Analytics and export routes require conductor role
  '/statistics': _isConductor,
  '/planning': _isConductor,
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

/// Provider for the auth change notifier
final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier(ref);
});

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

      // If not logged in and not on auth route or tenant registration, redirect to login
      if (!isLoggedIn && !isAuthRoute && !isTenantRegistration) {
        return '/login';
      }

      // If logged in and on auth route, redirect to tenant selection
      if (isLoggedIn && isAuthRoute) {
        return '/tenants';
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
                return '/overview';
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
              return PlanningPage(attendanceId: attendanceId);
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
              GoRoute(
                path: 'meetings',
                name: 'meetings',
                builder: (context, state) => const MeetingsListPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'meetingDetail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const MeetingsListPage();
                      return MeetingDetailPage(meetingId: id);
                    },
                  ),
                ],
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