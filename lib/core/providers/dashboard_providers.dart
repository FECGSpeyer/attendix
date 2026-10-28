import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/dashboard/dashboard_event.dart';
import '../../data/models/dashboard/dashboard_models.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/administration_repository.dart';
import '../../data/repositories/church_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../config/supabase_config.dart';
import '../services/tracking/tracking_event.dart';
import '../utils/dashboard_logic.dart';
import '../utils/dashboard_utils.dart';

export '../utils/dashboard_logic.dart';
import 'attendance_type_providers.dart';
import 'church_providers.dart';
import 'debug_providers.dart';
import 'team_org_providers.dart';
import 'tenant_providers.dart';

// =============================================================================
// Super-Developer
// =============================================================================

/// E-mail of the super developer (Ionic `SUPER_DEVELOPER_EMAIL`).
const String superDeveloperEmail = 'developer@attendix.de';

/// Ionic `db.isSuperDeveloper()` / `SuperDeveloperGuard`.
final isSuperDeveloperProvider = Provider<bool>((ref) {
  // Re-evaluate on auth changes (login/logout/user update).
  ref.watch(authStateProvider);
  final email = ref.watch(supabaseAuthProvider).currentUser?.email;
  return email == superDeveloperEmail;
});

// =============================================================================
// Repositories with tenant
// =============================================================================

final dashboardRepositoryWithTenantProvider = Provider<DashboardRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(dashboardRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [DashboardRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final dashboardRepositoryForTenantProvider =
    Provider.family<DashboardRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _dashboardRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _dashboardRepositoryForAccountProvider =
    Provider.family<DashboardRepository, AccountScopeKey>((ref, key) {
  final repo = DashboardRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

final administrationRepositoryWithTenantProvider = Provider<AdministrationRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(administrationRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [AdministrationRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final administrationRepositoryForTenantProvider =
    Provider.family<AdministrationRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _administrationRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _administrationRepositoryForAccountProvider =
    Provider.family<AdministrationRepository, AccountScopeKey>((ref, key) {
  final repo = AdministrationRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

// =============================================================================
// Dashboard settings (Supabase user_metadata, shared with Ionic)
// =============================================================================

/// Per-tenant dashboard preferences of the current user.
@immutable
class DashboardSettings {
  const DashboardSettings({
    this.showTab = false,
    this.cards = const [],
  });

  /// `user_metadata['showDashboardTab_<tenantId>']`
  final bool showTab;

  /// `user_metadata['dashboardCards_<tenantId>']` merged with the defaults.
  final List<DashboardCardConfig> cards;

  DashboardSettings copyWith({bool? showTab, List<DashboardCardConfig>? cards}) =>
      DashboardSettings(
        showTab: showTab ?? this.showTab,
        cards: cards ?? this.cards,
      );
}

/// Notifier for the dashboard settings of the current tenant.
class DashboardSettingsNotifier extends Notifier<DashboardSettings> {
  @override
  DashboardSettings build() {
    // SOL_FIX15: user_metadata of the signed-in account – rebuild per account.
    ref.watch(currentAuthUserIdProvider);
    final tenantId = ref.watch(currentTenantIdProvider);
    if (tenantId == null) return DashboardSettings(cards: defaultDashboardCards());
    final metadata = ref.read(supabaseAuthProvider).currentUser?.userMetadata;
    return DashboardSettings(
      showTab: metadata?['showDashboardTab_$tenantId'] == true,
      cards: mergeDashboardCardConfig(metadata?['dashboardCards_$tenantId']),
    );
  }

  int? get _tenantId => ref.read(currentTenantIdProvider);

  Future<void> _save(String key, Object value) async {
    // GoTrue merges `data` into user_metadata, so only our key is sent (like Ionic).
    await ref.read(supabaseAuthProvider).updateUser(UserAttributes(data: {key: value}));
  }

  /// Ionic `setShowDashboardTab`.
  Future<void> setShowTab(bool value) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final previous = state;
    state = state.copyWith(showTab: value);
    try {
      await _save('showDashboardTab_$tenantId', value);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  /// Ionic `setDashboardCardConfig`.
  Future<void> setCards(List<DashboardCardConfig> cards) async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final previous = state;
    state = state.copyWith(cards: cards);
    try {
      await _save(
        'dashboardCards_$tenantId',
        cards.map((c) => {'id': c.id, 'visible': c.visible}).toList(),
      );
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> setCardVisible(String id, bool visible) => setCards([
        for (final c in state.cards) c.id == id ? c.copyWith(visible: visible) : c,
      ]);

  /// Ionic `resetDashboardCardConfig`.
  Future<void> resetCards() => setCards(defaultDashboardCards());

  /// Ionic `handleReorder`: indices refer to the configurable cards and are
  /// given as `ReorderableListView.onReorder` reports them ([to] counts the
  /// moved item, so it is shifted by one when moving down).
  /// Hidden (non-configurable) cards keep their place at the end.
  Future<void> reorder(int from, int to, {required bool teamOrgEnabled}) async {
    if (from == to) return;
    final shown = configurableDashboardCards(state.cards, teamOrgEnabled: teamOrgEnabled);
    final hidden = state.cards.where((c) => !shown.contains(c)).toList();
    final moved = shown.removeAt(from);
    shown.insert((to > from ? to - 1 : to).clamp(0, shown.length), moved);
    await setCards([...shown, ...hidden]);
  }
}

final dashboardSettingsNotifierProvider =
    NotifierProvider<DashboardSettingsNotifier, DashboardSettings>(
  DashboardSettingsNotifier.new,
);

/// Teamorganisation enabled (Ionic `db.teamOrgEnabled()`): controls the
/// "Meine Aufgaben" card.
final dashboardTeamOrgEnabledProvider =
    Provider<bool>((ref) => ref.watch(teamOrgEnabledProvider));

/// Whether the dashboard tab is shown (Ionic `showDashboardTab`).
final showDashboardTabProvider = Provider<bool>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  if (!(role.isAdmin || role.isResponsible)) return false;
  return ref.watch(dashboardSettingsNotifierProvider).showTab;
});

/// Visible cards in configured order (Ionic `visibleCards`).
final visibleDashboardCardsProvider = Provider<List<DashboardCardConfig>>((ref) {
  final cards = ref.watch(dashboardSettingsNotifierProvider).cards;
  final teamOrg = ref.watch(dashboardTeamOrgEnabledProvider);
  return configurableDashboardCards(cards, teamOrgEnabled: teamOrg)
      .where((c) => c.visible)
      .toList();
});

// =============================================================================
// Card data
// =============================================================================

/// All non-pending persons incl. archived (Ionic `getPlayers(true)`).
final dashboardPersonsProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(dashboardRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getAllPersons();
});

final dashboardBirthdaysProvider = FutureProvider<List<BirthdayEntry>>((ref) async {
  final persons = await ref.watch(dashboardPersonsProvider.future);
  return DashboardUtils.birthdays(persons);
});

final dashboardMemberChangesProvider = FutureProvider<List<MemberChange>>((ref) async {
  final persons = await ref.watch(dashboardPersonsProvider.future);
  return DashboardUtils.memberChanges(persons);
});

final dashboardCriticalPersonsProvider = FutureProvider<List<Person>>((ref) async {
  final persons = await ref.watch(dashboardPersonsProvider.future);
  return persons.where((p) => p.isCritical).toList();
});

final dashboardAbsencesProvider = FutureProvider<List<AbsenceEntry>>((ref) async {
  final repo = ref.watch(dashboardRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final persons = await ref.watch(dashboardPersonsProvider.future);
  final absences = await repo.getAbsences();
  return DashboardUtils.absences(absences, persons);
});

final dashboardNextEventProvider = FutureProvider<NextEventSummary>((ref) async {
  final repo = ref.watch(dashboardRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const NextEventSummary();
  final tenant = ref.watch(currentTenantProvider);
  final results = await Future.wait([
    repo.getEventsAroundToday(seasonStart: tenant?.seasonStart),
    repo.getShiftExcusedAsPresent(),
  ]);
  return computeNextEventSummary(
    results[0] as List<DashboardEvent>,
    shiftExcusedAsPresent: results[1] as bool,
  );
});

/// Ionic `getCurrentSongs` + CurrentSongsCard: one entry per planned song.
final dashboardCurrentSongsProvider = FutureProvider<List<DashboardSongEntry>>((ref) async {
  final repo = ref.watch(dashboardRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final rows = await repo.getCurrentSongHistory();
  final types = await ref.watch(attendanceTypesProvider.future);
  return buildCurrentSongEntries(
    rows,
    typeName: (typeId) {
      final t = types.where((t) => t.id == typeId).firstOrNull;
      return t == null || t.hideName ? null : t.name;
    },
  );
});

final dashboardCurrentPlanProvider = FutureProvider<CurrentPlanData?>((ref) async {
  final repo = ref.watch(dashboardRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  final role = ref.watch(effectiveRoleProvider);
  final events = await repo.getUpcomingEventsIncludingRunning();
  return selectCurrentPlan(events, isAdmin: role.isAdmin || role.isResponsible);
});

/// Reload all cards (pull-to-refresh, Ionic `refreshAllCards`).
void refreshDashboardCards(WidgetRef ref) {
  ref.invalidate(dashboardPersonsProvider);
  ref.invalidate(dashboardAbsencesProvider);
  ref.invalidate(dashboardNextEventProvider);
  ref.invalidate(dashboardCurrentSongsProvider);
  ref.invalidate(dashboardCurrentPlanProvider);
  ref.invalidate(myTasksProvider);
}

// =============================================================================
// Super-developer: usage dashboard & administration
// =============================================================================

/// Range of the usage dashboard in days (7 / 30 / 90).
final usageDashboardRangeProvider = StateProvider<int>((ref) => 30);

/// Event names the app tracks today (Ionic `KNOWN_EVENTS`).
final List<String> knownUsageEvents =
    TrackingEvent.values.map((e) => e.wireName).toList();

final usageDashboardProvider = FutureProvider<UsageDashboardData>((ref) async {
  if (!ref.watch(isSuperDeveloperProvider)) return const UsageDashboardData();
  final days = ref.watch(usageDashboardRangeProvider);
  final repo = ref.watch(usageDashboardRepositoryProvider);
  return repo.load(
    since: DateTime.now().subtract(Duration(days: days)),
    events: knownUsageEvents,
  );
});

/// Storage quota of the current tenant: (maxBytes, usedBytes).
@immutable
class TenantStorageInfo {
  const TenantStorageInfo({this.maxBytes, this.usedBytes});
  final int? maxBytes;
  final int? usedBytes;
}

final tenantStorageInfoProvider = FutureProvider<TenantStorageInfo>((ref) async {
  final repo = ref.watch(administrationRepositoryWithTenantProvider);
  if (!repo.hasTenantId || !ref.watch(isSuperDeveloperProvider)) {
    return const TenantStorageInfo();
  }
  final maxBytes = await repo.getFilesMaxBytes();
  int? used;
  try {
    used = await repo.getFilesUsedBytes();
  } catch (_) {
    used = null; // Ionic hides "Aktuell belegt" when the RPC fails.
  }
  return TenantStorageInfo(maxBytes: maxBytes, usedBytes: used);
});

/// Mutations of the administration page.
class AdministrationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> setFilesMaxBytes(int? bytes) => _run(() async {
        await ref.read(administrationRepositoryWithTenantProvider).updateFilesMaxBytes(bytes);
        ref.invalidate(tenantStorageInfoProvider);
      });

  Future<bool> renameChurch(String id, String name) => _run(() async {
        await ref.read(churchRepositoryProvider).renameChurch(id, name);
        ref.invalidate(churchesProvider);
      });

  /// Returns the number of updated persons, or null on error.
  Future<int?> mergeChurches(List<(String target, String duplicate)> pairs) async {
    var total = 0;
    final ok = await _run(() async {
      for (final (target, duplicate) in pairs) {
        total += await ref.read(churchRepositoryProvider).mergeChurches(target, duplicate);
      }
      ref.invalidate(churchesProvider);
    });
    return ok ? total : null;
  }
}

final administrationNotifierProvider =
    NotifierProvider<AdministrationNotifier, AsyncValue<void>>(
  AdministrationNotifier.new,
);
