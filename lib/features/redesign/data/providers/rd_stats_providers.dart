import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider, supabaseClientProvider;
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/attendance/attendance.dart';
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
final rdStatsResultProvider = Provider<RdStatsResult>((ref) {
  final attendances = ref.watch(filteredAttendancesForStatsProvider).valueOrNull;
  if (attendances == null || attendances.isEmpty) return RdStatsResult.empty;
  return rdComputeStats(
    attendances: attendances,
    personAttendances: ref.watch(allPersonAttendancesForStatsProvider).valueOrNull ?? const [],
    types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
    players: ref.watch(activePlayersForStatsProvider).valueOrNull ?? const [],
    groups: ref.watch(groupsProvider).valueOrNull ?? const [],
    filter: ref.watch(rdStatsFilterProvider),
    shiftExcusedAsPresent: ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false,
  );
});

/// REDESIGN: order of the Termine level of the Auswertung.
final rdStatsEventSortProvider = StateProvider<RdStatsEventSort>((ref) {
  ref.watch(currentTenantIdProvider);
  ref.watch(currentAuthUserIdProvider);
  return RdStatsEventSort.newest;
});

/// REDESIGN: Termine and entries of the period of the same length before
/// the chosen one ([rdStatsPreviousPeriod]), for "ggü. davor". Null when
/// there is no sensible comparison or loading failed (the comparison is
/// only extra).
final _rdStatsPreviousDataProvider =
    FutureProvider.autoDispose<(List<Attendance>, List<PersonAttendance>)?>((ref) async {
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
    return (attendances, rows);
  } catch (e) {
    debugPrint('Auswertung: comparison period not loaded: $e');
    return null;
  }
});

/// REDESIGN: the Auswertung of the period before, with the same filter.
/// Null without a comparison (also with fewer than
/// [rdStatsMinCompareEvents] Termine of the shown Terminarten).
final rdStatsPreviousResultProvider = Provider.autoDispose<RdStatsResult?>((ref) {
  final data = ref.watch(_rdStatsPreviousDataProvider).valueOrNull;
  if (data == null) return null;
  final result = rdComputeStats(
    attendances: data.$1,
    personAttendances: data.$2,
    types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
    players: ref.watch(activePlayersForStatsProvider).valueOrNull ?? const [],
    groups: ref.watch(groupsProvider).valueOrNull ?? const [],
    filter: ref.watch(rdStatsFilterProvider),
    shiftExcusedAsPresent: ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false,
  );
  return result.events.length < rdStatsMinCompareEvents ? null : result;
});
