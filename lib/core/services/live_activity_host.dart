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
  Future<bool> loadOrgPlansEnabled() => loadLiveActivityOrgPlansEnabled();

  @override
  Future<List<PlanAttendance>> loadAttendances(DateTime from, DateTime to) async {
    final repo = _ref.read(liveActivityRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return [];
    return repo.getPlanAttendancesBetween(from, to);
  }

  @override
  Future<Set<int>?> loadVisiblePlayerAttendanceIds(List<int> attendanceIds) async {
    if (role.canSeeAttendanceTab) return null;
    final repo = _ref.read(liveActivityRepositoryWithTenantProvider);
    if (!repo.hasTenantId || attendanceIds.isEmpty) return const {};
    try {
      final player = await _ref.read(currentSelfServicePlayerProvider.future);
      final playerId = player?.id;
      if (playerId == null) return const {};
      final showAll = _ref.read(currentTenantProvider)?.showAllAttendances ?? false;
      return await repo.getPlayerVisibleAttendanceIds(
        playerId,
        attendanceIds,
        showAllAttendances: showAll,
      );
    } catch (_) {
      // On transient errors keep existing behaviour instead of flapping.
      return null;
    }
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
  Future<bool> isActivityStillValid(LiveActivityTarget target) async {
    final planRepo = _ref.read(planRepositoryWithTenantProvider);
    final orgPlanRepo = _ref.read(orgPlanRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final tz = timezone.isNotEmpty ? timezone : 'Europe/Berlin';
    try {
      // Ad-hoc ORG plan (`attendanceId == 0`, `planKey == 'org-<id>'`).
      if (target.attendanceId == 0 && target.planKey.startsWith('org-')) {
        if (!await loadOrgPlansEnabled()) return false;
        final id = target.planKey.substring(4);
        if (id.isEmpty) return false;
        final orgIds = await _userOrgIds();
        for (final orgId in orgIds) {
          final sp = await orgPlanRepo.getAdHocOrgPlan(orgId, id);
          if (sp == null) continue;
          if (!isPlanPublished(sp)) return false;
          final date = sp.date ?? '';
          final time = sp.time ?? '';
          if (date.isEmpty || time.isEmpty || sp.fields.isEmpty) return false;
          final state = liveStateAt(
            buildSchedule(date: date, planTime: time, fields: sp.fields, timezone: tz),
            now,
          );
          return state != null && state.phase != 'ended';
        }
        return false;
      }

      if (target.attendanceId <= 0) return false;
      if (!planRepo.hasTenantId) return false;
      final orgPlansEnabled = await loadOrgPlansEnabled();
      final ownTenants = await _ref.read(userTenantsProvider.future);
      final linkedTenants = orgPlansEnabled && (role.isAdmin || role.isResponsible)
          ? await _ref.read(linkedTenantsProvider.future)
          : const <Tenant>[];
      final tenantRoles = <int, Role?>{
        for (final t in linkedTenants)
          if (t.id != null) t.id!: null,
        for (final t in ownTenants)
          if (t.id != null) t.id!: t.role == null ? null : Role.fromValue(t.role!),
      };
      final att = await planRepo.getPlanAttendanceById(target.attendanceId, includeArchived: false) ??
          await planRepo.getPlanAttendanceByIdInTenants(target.attendanceId, tenantRoles);
      if (att == null) return false;
      // If it belongs to a linked org tenant (not own tenant) and ORG plans are
      // disabled or is_org_plan was turned off, end it.
      final isOwnTenant = ownTenants.any((t) => t.id == att.tenantId);
      if (!isOwnTenant && (!orgPlansEnabled || !att.isOrgPlan)) return false;
      final plans = PlanUtils.allPlans(att);
      for (var i = 0; i < plans.length; i++) {
        if (livePlanKey(plans[i]) != target.planKey) continue;
        if (!isPlanPublished(plans[i])) return false;
        final state = liveStateAt(liveSchedule(att, i, tz, plans), now);
        return state != null && state.phase != 'ended';
      }
      return false;
    } catch (_) {
      // Transient network error: leave valid activities alone until next sync.
      return true;
    }
  }

  Future<Set<int>> _userOrgIds() async {
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
    return orgIds;
  }

  @override
  Future<void> openPlan(int attendanceId, {String planKey = ''}) async {
    final repo = _ref.read(planRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    final currentId = tenantId;
    var attendance = await repo.getPlanAttendanceById(attendanceId);
    List<Tenant> ownTenants = const [];
    List<Tenant> linkedTenants = const [];
    // Ionic getAttendanceById has no tenant filter: a Live Activity of an
    // ORG-Plan of another choir / a Termin of another instance opens too.
    if (attendance == null) {
      ownTenants = await _ref.read(userTenantsProvider.future).catchError((_) => const <Tenant>[]);
      linkedTenants = await _ref.read(linkedTenantsProvider.future).catchError((_) => const <Tenant>[]);
      // Own instances with the own role there; linked instances of the
      // organisation without a role (archived Termine stay hidden there).
      final tenantRoles = <int, Role?>{
        for (final t in linkedTenants)
          if (t.id != null) t.id!: null,
        for (final t in ownTenants)
          if (t.id != null) t.id!: t.role == null ? null : Role.fromValue(t.role!),
      };
      attendance = await repo.getPlanAttendanceByIdInTenants(attendanceId, tenantRoles);
    }
    if (attendance?.plan == null) return;
    final context = _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = context.l10n;

    final att = attendance!;
    final isOtherTenant = att.tenantId != null && att.tenantId != currentId;
    String? originBadge;
    String? originHint;
    ({String label, VoidCallback onTap})? openInGroupAction;

    if (isOtherTenant) {
      final ownMatch = ownTenants.where((t) => t.id == att.tenantId).firstOrNull;
      final linkedMatch = linkedTenants.where((t) => t.id == att.tenantId).firstOrNull;
      final match = ownMatch ?? linkedMatch;
      final groupName = (match?.longName.isNotEmpty == true ? match!.longName : match?.shortName) ?? '';
      if (att.isOrgPlan) {
        originBadge = groupName.isNotEmpty ? l10n.rdOrgBadgeGroup(groupName) : l10n.rdOrgBadge;
      } else if (groupName.isNotEmpty) {
        originBadge = groupName;
      }
      if (ownMatch != null && ownMatch.id != null) {
        final target = ownMatch;
        final targetRole = target.role == null ? Role.none : Role.fromValue(target.role!);
        final labelName = target.shortName.isNotEmpty ? target.shortName : target.longName;
        openInGroupAction = (
          label: l10n.rdOrgPlanSwitchGroup(labelName),
          onTap: () => _switchToTenantEvent(context, target, attendanceId, targetRole),
        );
      }
    } else if (att.isOrgPlan) {
      originBadge = l10n.rdOrgBadge;
      final orgName = _ref.read(currentOrganisationProvider).valueOrNull?.name;
      if (orgName != null && orgName.isNotEmpty) originHint = orgName;
    }

    await showPlanViewer(
      context,
      attendance: att,
      defaultLive: true,
      initialPlanKey: planKey.isEmpty ? null : planKey,
      backLabel: l10n.rdOrgPlanBackClose,
      originBadge: originBadge,
      originHint: originHint,
      openInGroupAction: openInGroupAction,
    );
  }

  Future<void> _switchToTenantEvent(
    BuildContext context,
    Tenant target,
    int attendanceId,
    Role targetRole,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = _ref.read(routerProvider);
    Navigator.of(context, rootNavigator: true).maybePop();
    try {
      await container.read(currentTenantProvider.notifier).setTenantLocal(target);
      await container.read(currentTenantUserProvider.future);
      container.read(userPreferencesNotifierProvider.notifier).updateCurrentTenantId(target.id!);
      if (targetRole.canAddAttendance) {
        router.go(RedesignRoutes.event(attendanceId));
      } else {
        router.go(RedesignRoutes.events);
      }
    } catch (_) {}
  }

  @override
  Future<void> openSharedOrgPlan(String id) async {
    // Ionic reads shared_plans by id only (RLS: leader of an instance of the
    // org). The server sends the activity to admins/responsibles of every
    // instance of the org, so the currently selected instance may belong to
    // another (or no) organisation: try the current organisation first, then
    // every organisation of the user's admin/responsible instances
    // (userOrganisationsProvider). Each read stays scoped by org_id.
    final orgNames = <int, String>{};
    try {
      final current = await _ref.read(currentOrganisationProvider.future);
      if (current?.id != null) orgNames[current!.id!] = current.name;
    } catch (_) {}
    try {
      for (final org in await _ref.read(userOrganisationsProvider.future)) {
        if (org.id != null) orgNames[org.id!] = org.name;
      }
    } catch (_) {}
    final repo = _ref.read(orgPlanRepositoryProvider);
    SharedPlan? sp;
    String? orgName;
    for (final entry in orgNames.entries) {
      sp = await repo.getAdHocOrgPlan(entry.key, id);
      if (sp != null) {
        orgName = entry.value;
        break;
      }
    }
    if (sp == null || sp.fields.isEmpty) return;
    final entry = OrgPlanEntry.adHoc(sp);
    final context = _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = context.l10n;
    await showPlanViewer(
      context,
      attendance: PlanAttendance(id: null, date: entry.date),
      plan: entry.plan,
      title: entry.title,
      defaultLive: true,
      backLabel: l10n.rdOrgPlanBackClose,
      originBadge: l10n.rdOrgBadgeAdHoc,
      originHint: [
        l10n.rdOrgPlanAdHocMeta,
        if (orgName != null && orgName.isNotEmpty) orgName,
      ].join(' · '),
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
