part of 'live_activity_service.dart';

/// [LiveActivityHost] backed by the app's providers.
class RiverpodLiveActivityHost implements LiveActivityHost {
  RiverpodLiveActivityHost(this._ref);

  final Ref _ref;

  @override
  int? get tenantId => _ref.read(currentTenantIdProvider);

  @override
  String get timezone => _ref.read(currentTenantProvider)?.timezone ?? 'Europe/Berlin';

  @override
  Role get role => _ref.read(currentRoleProvider);

  @override
  String? get userId => _ref.read(supabaseClientProvider).auth.currentUser?.id;

  @override
  String get apiUrl => SupabaseConfig.supabaseUrl;

  @override
  String get apiKey => SupabaseConfig.supabaseAnonKey;

  @override
  Future<bool> loadEnabled() async {
    final id = userId;
    if (id == null) return true;
    return _ref.read(liveActivityRepositoryWithTenantProvider).isLiveActivityEnabled(id);
  }

  @override
  Future<List<PlanAttendance>> loadAttendances(DateTime from, DateTime to) async {
    final repo = _ref.read(liveActivityRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return [];
    return repo.getPlanAttendancesBetween(from, to);
  }

  @override
  Future<Map<String, LiveTermType>> termTypes() async {
    try {
      // Ionic db.attendanceTypes() (name and colour).
      final types = await _ref.read(attendanceTypesProvider.future);
      return {
        for (final t in types)
          if (t.id != null) t.id!: (name: t.name, color: t.color),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<LiveOrgPlans?> loadOrgPlans(DateTime from, DateTime to) async {
    final org = await _ref.read(currentOrganisationProvider.future);
    final orgId = org?.id;
    if (orgId == null) return null;
    final repo = _ref.read(orgPlanRepositoryProvider);
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final results = await Future.wait([
      repo.getOrgLiveAttendancesBetween(orgId, from, to),
      repo.getAdHocOrgPlansBetween(orgId, day(from), day(to)),
    ]);
    return (
      attendances: results[0] as List<OrgLiveAttendance>,
      sharedPlans: results[1] as List<SharedPlan>,
    );
  }

  @override
  Future<void> saveToken({
    required String userId,
    required String kind,
    required String token,
    int attendanceId = 0,
    String planKey = '',
  }) {
    return _ref.read(liveActivityRepositoryWithTenantProvider).saveToken(
          userId: userId,
          kind: kind,
          token: token,
          // Ionic Capacitor.getPlatform() (DB_REVIEW_REST F2)
          platform: LiveActivityService.isAndroidPlatform ? 'android' : 'ios',
          attendanceId: attendanceId,
          planKey: planKey,
        );
  }

  @override
  Future<void> removeTokens({required String userId, required List<String> tokens}) {
    return _ref
        .read(liveActivityRepositoryWithTenantProvider)
        .removeTokens(userId: userId, tokens: tokens);
  }

  @override
  Future<void> openPlan(int attendanceId) async {
    final repo = _ref.read(planRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    var attendance = await repo.getPlanAttendanceById(attendanceId);
    // Ionic getAttendanceById has no tenant filter: a Live Activity of an
    // ORG-Plan of another choir / a Termin of another instance opens too.
    if (attendance == null) {
      // Own instances with the own role there; linked instances of the
      // organisation without a role (archived Termine stay hidden there).
      final tenantRoles = <int, Role?>{
        for (final t in await _ref.read(linkedTenantsProvider.future))
          if (t.id != null) t.id!: null,
        for (final t in await _ref.read(userTenantsProvider.future))
          if (t.id != null) t.id!: t.role == null ? null : Role.fromValue(t.role!),
      };
      attendance = await repo.getPlanAttendanceByIdInTenants(attendanceId, tenantRoles);
    }
    if (attendance?.plan == null) return;
    final context = _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showPlanViewer(context, attendance: attendance!, defaultLive: true);
  }

  @override
  Future<void> openSharedOrgPlan(String id) async {
    // Ionic reads shared_plans by id only (RLS: leader of an instance of the
    // org). The server sends the activity to admins/responsibles of every
    // instance of the org, so the currently selected instance may belong to
    // another (or no) organisation: try the current organisation first, then
    // every organisation of the user's admin/responsible instances
    // (userOrganisationsProvider). Each read stays scoped by org_id.
    final orgIds = <int>{};
    try {
      final current = (await _ref.read(currentOrganisationProvider.future))?.id;
      if (current != null) orgIds.add(current);
    } catch (_) {}
    try {
      for (final org in await _ref.read(userOrganisationsProvider.future)) {
        if (org.id != null) orgIds.add(org.id!);
      }
    } catch (_) {}
    final repo = _ref.read(orgPlanRepositoryProvider);
    SharedPlan? sp;
    for (final orgId in orgIds) {
      sp = await repo.getAdHocOrgPlan(orgId, id);
      if (sp != null) break;
    }
    if (sp == null || sp.fields.isEmpty) return;
    final entry = OrgPlanEntry.adHoc(sp);
    final context = _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await showPlanViewer(
      context,
      attendance: PlanAttendance(id: null, date: entry.date),
      plan: entry.plan,
      title: entry.title,
      defaultLive: true,
    );
  }
}

/// The app's LiveActivityService.
final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  final service = LiveActivityService(host: RiverpodLiveActivityHost(ref));
  ref.onDispose(service.dispose);
  return service;
});

/// Read once at app start (main.dart): attaches the native channel and
/// (re)initialises the service whenever the tenant changes.
final liveActivityBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(liveActivityServiceProvider);
  if (!service.hasNativePlugin) return;
  unawaited(service.attach());
  ref.listen(currentTenantUserProvider, (_, next) {
    unawaited(service.onTenantReady(
      ref.read(currentTenantIdProvider),
      hasTenantUser: next.valueOrNull != null,
      userId: ref.read(currentAuthUserIdProvider),
    ));
  }, fireImmediately: true);
  // SOL_FIX15: logout / account switch – end the activities and reset, so
  // the next account registers its own tokens (the previous account's
  // rows are removed before sign-out, see endLiveActivitiesBeforeSignOut).
  ref.listen<String?>(currentAuthUserIdProvider, (previous, next) {
    if (previous != null && previous != next) {
      unawaited(service.endSession());
    }
  });
  // Tenant cleared without a tenant-user change.
  ref.listen<int?>(currentTenantIdProvider, (previous, next) {
    if (next == null && previous != null) {
      unawaited(service.onTenantReady(null, hasTenantUser: false));
    }
  });
});

/// SOL_FIX15: ends the Live Activities and deletes this device's Live
/// Activity tokens of the signed-in account. Call before `auth.signOut()`
/// (RLS needs the session); never blocks the logout.
Future<void> endLiveActivitiesBeforeSignOut(LiveActivityService service, String? userId) async {
  try {
    await service.endSession(removeTokensOf: userId);
  } catch (_) {}
}
