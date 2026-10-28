import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/event_list_utils.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/sign_in_out_repository.dart';
import 'player_providers.dart';
import 'signout_providers.dart';
import 'tenant_providers.dart';

export '../../core/constants/enums.dart' show AttendanceStatus;
export '../../data/repositories/sign_in_out_repository.dart'
    show CrossTenantPersonAttendance, SignInType;

/// Provider for all person attendances across all tenants for the current user
final allPersonAttendancesAcrossTenantsProvider =
    FutureProvider<List<CrossTenantPersonAttendance>>((ref) async {
  final repo = ref.watch(signInOutRepositoryProvider);
  return repo.getAllPersonAttendancesAcrossTenants();
});

/// IOS_ATT_PAGES: Ionic `attendanceHasEnded(att)` – only the Termin's own
/// `duration_days` counts (not the type default).
bool overviewHasEnded(CrossTenantPersonAttendance a, {DateTime? now}) =>
    EventListUtils.hasEnded(a.date, a.durationDays, now: now);

/// Data of the "Übersicht" (Ionic OverviewPage.processAttendances).
class OverviewData {
  const OverviewData({
    this.upcoming = const [],
    this.past = const [],
    this.stats = const AttendanceStats(
      percentage: 0,
      lateCount: 0,
      totalCount: 0,
      presentCount: 0,
    ),
  });

  /// Not yet ended, ascending (including the current Termin).
  final List<CrossTenantPersonAttendance> upcoming;

  /// Ended, newest first.
  final List<CrossTenantPersonAttendance> past;

  final AttendanceStats stats;
}

/// Pure calculation of the Übersicht (Ionic `processAttendances` +
/// `calculateStats`):
/// * past = ended Termine, newest first; upcoming = the rest, ascending,
/// * percentage over past Termine whose type has `include_in_average`
///   (`?? true`), attended = present / late / late excused – plus
///   work-excused absences when the current tenant has
///   `shift_excused_as_present`,
/// * late count = past Termine with status "Verspätet" (only when any
///   Termin counts for the average, else 0 like Ionic).
OverviewData buildOverviewData(
  List<CrossTenantPersonAttendance> attendances, {
  DateTime? now,
  bool shiftExcusedAsPresent = false,
}) {
  DateTime d(CrossTenantPersonAttendance a) =>
      EventListUtils.parse(a.date) ?? DateTime(1970);

  final upcoming = attendances
      .where((a) => a.date != null && !overviewHasEnded(a, now: now))
      .toList()
    ..sort((a, b) => d(a).compareTo(d(b)));
  final past = attendances
      .where((a) => a.date != null && overviewHasEnded(a, now: now))
      .toList()
    ..sort((a, b) => d(b).compareTo(d(a)));

  final relevant = past.where((a) => a.includeInAverage).toList();
  if (relevant.isEmpty) {
    return OverviewData(upcoming: upcoming, past: past);
  }
  final attended = relevant
      .where((a) => a.status.countsAsAttended(
            notes: a.notes,
            shiftExcusedAsPresent: shiftExcusedAsPresent,
          ))
      .length;
  final late = past.where((a) => a.status == AttendanceStatus.late).length;
  return OverviewData(
    upcoming: upcoming,
    past: past,
    stats: AttendanceStats(
      percentage: (attended / relevant.length * 100).round(),
      lateCount: late,
      totalCount: relevant.length,
      presentCount: attended,
    ),
  );
}

/// Ionic tenant groups of the "Nach Instanz" view: groups in order of the
/// first (date-sorted) Termin, inside upcoming first (ascending), then past
/// (descending); split by `new Date(a.date) >= now` like Ionic.
List<List<CrossTenantPersonAttendance>> groupOverviewByTenant(
  List<CrossTenantPersonAttendance> attendances, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  DateTime d(CrossTenantPersonAttendance a) =>
      EventListUtils.parse(a.date) ?? DateTime(1970);
  final groups = <int, List<CrossTenantPersonAttendance>>{};
  for (final a in attendances) {
    groups.putIfAbsent(a.tenantId, () => []).add(a);
  }
  return [
    for (final list in groups.values)
      [
        ...(list.where((a) => !d(a).isBefore(at)).toList()
          ..sort((a, b) => d(a).compareTo(d(b)))),
        ...(list.where((a) => d(a).isBefore(at)).toList()
          ..sort((a, b) => d(b).compareTo(d(a)))),
      ],
  ];
}

/// Übersicht data computed from the loaded Termine.
final overviewDataProvider = Provider<OverviewData>((ref) {
  final all = ref.watch(allPersonAttendancesAcrossTenantsProvider).valueOrNull;
  if (all == null) return const OverviewData();
  // Ionic: `this.tenant()?.shift_excused_as_present` (current tenant)
  final shift = ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false;
  return buildOverviewData(all, shiftExcusedAsPresent: shift);
});

/// Provider for upcoming attendances across all tenants
final upcomingAttendancesAcrossTenantsProvider =
    Provider<List<CrossTenantPersonAttendance>>(
        (ref) => ref.watch(overviewDataProvider).upcoming);

/// Provider for past attendances across all tenants (newest first)
final pastAttendancesAcrossTenantsProvider =
    Provider<List<CrossTenantPersonAttendance>>(
        (ref) => ref.watch(overviewDataProvider).past);

/// Provider for the next upcoming attendance (current)
final currentAttendanceProvider = Provider<CrossTenantPersonAttendance?>((ref) {
  final upcoming = ref.watch(upcomingAttendancesAcrossTenantsProvider);
  return upcoming.isNotEmpty ? upcoming.first : null;
});

/// Provider for attendance statistics of the Übersicht
final attendanceStatsProvider = Provider<AttendanceStats>(
    (ref) => ref.watch(overviewDataProvider).stats);

/// Notifier for sign in/out operations
class SignInOutNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SignInOutRepository get _repo =>
      ref.read(signInOutRepositoryWithTenantProvider);

  /// Sign in to an attendance
  Future<void> signIn(
    String personAttendanceId,
    SignInType type, {
    String notes = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signIn(personAttendanceId, type,
          notes: notes, ownAcrossTenants: true);
      state = const AsyncValue.data(null);
      ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Sign out from attendances
  Future<void> signOut(
    List<String> personAttendanceIds,
    String reason, {
    bool isLateComing = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut(personAttendanceIds, reason,
          isLateComing: isLateComing, ownAcrossTenants: true);
      state = const AsyncValue.data(null);
      ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update attendance note
  Future<void> updateNote(String personAttendanceId, String note) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateAttendanceNote(personAttendanceId, note,
          ownAcrossTenants: true);
      state = const AsyncValue.data(null);
      ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final signInOutNotifierProvider =
    NotifierProvider<SignInOutNotifier, AsyncValue<void>>(() {
  return SignInOutNotifier();
});

/// Attendance statistics
class AttendanceStats {
  final int percentage;
  final int lateCount;
  final int totalCount;
  final int presentCount;

  const AttendanceStats({
    required this.percentage,
    required this.lateCount,
    required this.totalCount,
    required this.presentCount,
  });
}

/// Provider for current player (user's linked player record for the current tenant)
/// SEC-008: Added tenantId filter to prevent cross-tenant identity confusion
final currentSelfServicePlayerProvider = FutureProvider<Person?>((ref) async {
  final authState = ref.watch(authStateProvider).valueOrNull;
  final userId = authState?.session?.user.id;
  if (userId == null) return null;

  final repo = ref.watch(playerRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;

  // SEC-008: getPlayerByAppId filters by both appId AND tenantId.
  return repo.getPlayerByAppId(userId);
});

/// Provider to check if current user is an applicant in the current tenant
final isApplicantProvider = Provider<bool>((ref) {
  final tenantUser = ref.watch(currentTenantUserProvider).valueOrNull;
  if (tenantUser == null) return false;
  return Role.fromValue(tenantUser.role).isApplicant;
});

