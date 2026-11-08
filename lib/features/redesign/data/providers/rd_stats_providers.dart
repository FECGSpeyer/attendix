import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider, supabaseClientProvider;
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/attendance_repository.dart' show attendanceRepositoryForTenantProvider;
import '../rd_stats_logic.dart';

/// REDESIGN: chosen period of the Auswertung. The dates themselves live in
/// [statisticsDateRangeProvider] (shared with the old statistics page);
/// this is the chip that is selected. Another group or account starts with
/// the season.
final rdStatsRangeProvider = StateProvider<RdStatsRange>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return RdStatsRange.season;
});

/// REDESIGN: "Filter" of the Auswertung (Terminarten, Register). Kept while
/// the app runs; another group or account starts unfiltered.
final rdStatsFilterProvider = StateProvider<RdStatsFilter>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return const RdStatsFilter();
});

/// REDESIGN: the Auswertung for the chosen period and filter, counted one
/// way for the Ø, the Termine, the Register and the persons
/// ([rdComputeStats]). Empty while the Termine are loading.
///
/// Riverpod keeps the old value while a provider reloads, also after a
/// group or account change. The data is therefore keyed by the group:
/// Termine or persons of another group give an empty result instead of
/// mixing in (the page shows loading meanwhile). Entries are matched to the
/// Termine by their id.
final rdStatsResultProvider = Provider<RdStatsResult>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  final attendances = ref.watch(filteredAttendancesForStatsProvider).valueOrNull;
  if (tenantId == null || attendances == null || attendances.isEmpty) return RdStatsResult.empty;
  if (!rdStatsOfTenant(attendances.map((a) => a.tenantId), tenantId)) return RdStatsResult.empty;
  final players = ref.watch(activePlayersForStatsProvider).valueOrNull ?? const <Person>[];
  return rdComputeStats(
    attendances: attendances,
    personAttendances: ref.watch(allPersonAttendancesForStatsProvider).valueOrNull ?? const [],
    types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
    players: rdStatsOfTenant(players.map((p) => p.tenantId), tenantId) ? players : const [],
    groups: ref.watch(groupsProvider).valueOrNull ?? const [],
    filter: ref.watch(rdStatsFilterProvider),
    shiftExcusedAsPresent: ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false,
  );
});

/// Whether loaded rows with these tenant ids belong to [tenantId] (rows
/// without one are taken as such).
bool rdStatsOfTenant(Iterable<int?> tenantIds, int tenantId) => tenantIds.every((id) => id == null || id == tenantId);

/// The Terminarten of [async] that belong to [tenantId] (none of the group
/// before while the list reloads after a group change).
List<AttendanceType> rdStatsTypesOf(AsyncValue<List<AttendanceType>> async, int? tenantId) => [
  for (final t in async.valueOrNull ?? const <AttendanceType>[])
    if (tenantId != null && (t.tenantId == null || t.tenantId == tenantId)) t,
];

/// The Register of [async] that belong to [tenantId], like [rdStatsTypesOf].
List<Group> rdStatsGroupsOf(AsyncValue<List<Group>> async, int? tenantId) => [
  for (final g in async.valueOrNull ?? const <Group>[])
    if (tenantId != null && (g.tenantId == null || g.tenantId == tenantId)) g,
];

/// The persons of [async] when they belong to [tenantId], else none (the
/// list of the group before while it reloads after a group change).
List<Person> rdStatsPeopleOf(AsyncValue<List<Person>> async, int? tenantId) {
  final people = async.valueOrNull;
  if (tenantId == null || people == null) return const [];
  return rdStatsOfTenant(people.map((p) => p.tenantId), tenantId) ? people : const [];
}

/// REDESIGN: order of the Termine level of the Auswertung.
final rdStatsEventSortProvider = StateProvider<RdStatsEventSort>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return RdStatsEventSort.newest;
});

/// REDESIGN: order of the Personen level of the Auswertung.
final rdStatsPersonSortProvider = StateProvider<RdStatsPersonSort>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return RdStatsPersonSort.fewest;
});

/// REDESIGN: Termine and entries of the period of the same length before
/// the chosen one ([rdStatsPreviousPeriod]), for "ggü. davor", with the
/// group they were loaded for. Null when there is no sensible comparison or
/// loading failed (the comparison is only extra). The page invalidates it
/// together with the Auswertung when pulled to refresh.
final rdStatsPreviousDataProvider =
    FutureProvider.autoDispose<(int, List<Attendance>, List<PersonAttendance>)?>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  final range = ref.watch(statisticsDateRangeProvider);
  if (tenantId == null) return null;
  final period = rdStatsPreviousPeriod(range.start, range.end);
  if (period == null) return null;
  try {
    final repo = ref.watch(attendanceRepositoryForTenantProvider(tenantId));
    // `since` is exclusive: one day earlier, the exact days are cut below.
    final all = await repo.getAttendances(since: period.start.subtract(const Duration(days: 1)));
    final attendances = [
      for (final a in all)
        if (DateTime.tryParse(a.date)?.toLocal() case final d?)
          if (!d.isBefore(period.start) && d.isBefore(period.end)) a,
    ];
    if (attendances.length < rdStatsMinCompareEvents) return null;
    final rows = await loadStatsPersonAttendances(
      ref.read(supabaseClientProvider),
      tenantId,
      [for (final a in attendances) if (a.id != null) a.id!],
    );
    return (tenantId, attendances, rows);
  } catch (e) {
    debugPrint('Auswertung: comparison period not loaded: $e');
    return null;
  }
});

/// REDESIGN: the Auswertung of the period before, with the same filter.
/// Null without a comparison (also with fewer than
/// [rdStatsMinCompareEvents] Termine of the shown Terminarten), while it
/// reloads for another period or group, and for data of another group.
final rdStatsPreviousResultProvider = Provider.autoDispose<RdStatsResult?>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  final async = ref.watch(rdStatsPreviousDataProvider);
  final data = async.isReloading ? null : async.valueOrNull;
  if (data == null || data.$1 != tenantId) return null;
  final players = ref.watch(activePlayersForStatsProvider).valueOrNull ?? const <Person>[];
  final result = rdComputeStats(
    attendances: data.$2,
    personAttendances: data.$3,
    types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
    players: rdStatsOfTenant(players.map((p) => p.tenantId), data.$1) ? players : const [],
    groups: ref.watch(groupsProvider).valueOrNull ?? const [],
    filter: ref.watch(rdStatsFilterProvider),
    shiftExcusedAsPresent: ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false,
  );
  return result.events.length < rdStatsMinCompareEvents ? null : result;
});
