part of 'app_router.dart';

/// Auth, tenant selection, public registration, legal and public plan routes.
List<RouteBase> _publicAuthRoutes(Ref ref) => [
  // Auth routes
  GoRoute(
    path: '/login',
    name: 'login',
    builder: (context, state) => const LoginPage(),
  ),
  // Ionic /register = "Instanz anlegen" behind RegisterGuard: the login
  // flow decides (signed out → login, otherwise start page or the
  // selection, which shows the non-dismissable "Instanz anlegen" page
  // without any instance). The account sign-up is the login modal.
  GoRoute(
    path: '/register',
    name: 'register',
    redirect: (context, state) => '/login',
  ),
  // UX_PRELOGIN: Ionic has no reset page, only the login alert
  // "Passwort zurücksetzen" → old links open it on /login.
  GoRoute(
    path: '/forgot-password',
    name: 'forgotPassword',
    redirect: (context, state) {
      final email = state.uri.queryParameters['email'];
      return Uri(path: '/login', queryParameters: {
        'reset': '1',
        if (email != null && email.isNotEmpty) 'email': email,
      }).toString();
    },
  ),
  // AUTH: old "Neues Passwort" path (and /resetPassword links). Ionic
  // shows the alert over /login; the auth link handling opens it.
  GoRoute(
    path: '/new-password',
    name: 'newPassword',
    redirect: (context, state) => '/login',
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
  // TEAM_ORG: Microsoft Teams tab configuration (TEAMS: instance picker)
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
  // LINKS_STARTUP: tenant resolver for in-app links (?tenantId=, cold start)
  GoRoute(
    path: kOpenLinkRoute,
    builder: (context, state) => OpenLinkPage(
      target: state.uri.queryParameters[kOpenLinkTargetParam],
      tenantId: state.uri.queryParameters['tenantId'],
    ),
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
            return Scaffold(
              body: Center(child: Text(context.l10n.coreFlutterRouterInvalidTenantId)),
            );
          }
          return TenantDetailPage(tenantId: id);
        },
      ),
    ],
  ),
];

/// Public share-link routes registered last so wildcard `/:songSharingId`
/// never shadows authenticated app routes.
List<RouteBase> _publicTailRoutes(Ref ref) => [
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
    // EINST-60: an unknown single-segment address (no sharing-id UUID)
    // is no Werke link. Signed in → the start page of the open
    // instance; visitors keep the page, which shows "Link ungültig"
    // without asking the database.
    redirect: (context, state) {
      if (SongUtils.isValidSharingId(state.pathParameters['songSharingId'])) {
        return null;
      }
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.whenOrNull(
                data: (auth) => auth.session != null,
              ) ??
          _sessionRestoring(ref, authState);
      if (!isLoggedIn) return null;
      final tenantId = ref.read(currentTenantIdProvider);
      if (tenantId == null || ref.read(isRoleLoadingProvider)) return '/tenants';
      return homeRouteFor(
        ref.read(currentRoleProvider),
        tenantId,
        ref.read(supabaseClientProvider).auth.currentUser?.userMetadata,
      );
    },
    builder: (context, state) => SongsListPage(
      songSharingId: state.pathParameters['songSharingId'] ?? '',
    ),
    routes: [
      GoRoute(
        path: ':songId',
        builder: (context, state) => SongDetailPage(
          songId: state.pathParameters['songId'] ?? '',
          songSharingId: state.pathParameters['songSharingId'] ?? '',
        ),
      ),
    ],
  ),
];
