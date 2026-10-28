import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/statistics_utils.dart';
import '../../core/utils/status_utils.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/player_repository.dart';
import 'attendance_type_providers.dart';
import 'group_providers.dart'; // LOGIC_SETTINGS
import 'tenant_providers.dart';
import '../utils/paged_query.dart'; // SOL_FIX1

/// Date range for statistics filtering
class StatisticsDateRange {
  final DateTime start;
  final DateTime end;

  const StatisticsDateRange({required this.start, required this.end});

  /// Default: Last 6 months
  factory StatisticsDateRange.defaultRange() {
    final now = DateTime.now();
    return StatisticsDateRange(
      start: now.subtract(const Duration(days: 180)),
      end: now,
    );
  }
}

/// State notifier for date range
class StatisticsDateRangeNotifier extends StateNotifier<StatisticsDateRange> {
  StatisticsDateRangeNotifier() : super(StatisticsDateRange.defaultRange());

  void setRange(DateTime start, DateTime end) {
    state = StatisticsDateRange(start: start, end: end);
  }

  void setFromDateTimeRange(DateTimeRange range) {
    state = StatisticsDateRange(start: range.start, end: range.end);
  }

  /// Reset to season start if available, otherwise 180 days
  void resetToDefault({String? seasonStart}) {
    if (seasonStart != null) {
      final parsed = DateTime.tryParse(seasonStart);
      if (parsed != null) {
        state = StatisticsDateRange(start: parsed, end: DateTime.now());
        return;
      }
    }
    state = StatisticsDateRange.defaultRange();
  }
}

final statisticsDateRangeProvider =
    StateNotifierProvider<StatisticsDateRangeNotifier, StatisticsDateRange>(
  (ref) => StatisticsDateRangeNotifier(),
);

/// Provider for filtered attendances within date range
final filteredAttendancesForStatsProvider =
    FutureProvider<List<Attendance>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  final dateRange = ref.watch(statisticsDateRangeProvider);

  if (tenantId == null) return [];

  // SOL_FIX1: per-tenant instance instead of mutating the shared one.
  final repo = ref.watch(attendanceRepositoryForTenantProvider(tenantId));

  // Get all attendances in range
  final attendances = await repo.getAttendances(
    since: dateRange.start,
    withPersonAttendances: false,
    limit: 500, // Higher limit for statistics
  );

  // Filter to only include dates within the range
  // LOGIC_SETTINGS: Ionic stats only uses Termine before tomorrow
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return attendances.where((a) {
    final date = DateTime.tryParse(a.date);
    if (date == null) return false;
    if (!date.isBefore(tomorrow)) return false;
    return date.isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
        date.isBefore(dateRange.end.add(const Duration(days: 1)));
  }).toList();
});

/// Provider for all person attendances for statistics
final allPersonAttendancesForStatsProvider =
    FutureProvider<List<PersonAttendance>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId == null) return [];

  // Get all attendances first
  final attendances = await ref.watch(filteredAttendancesForStatsProvider.future);

  if (attendances.isEmpty) return [];

  // Query all person_attendances for these attendance IDs
  final attendanceIds = attendances.map((a) => a.id).whereType<int>().toList();

  if (attendanceIds.isEmpty) return [];

  try {
    // SEC-003: Defense-in-Depth - add tenant filter via inner join
    // SOL_FIX1: paged (PostgREST max-rows 1000), stable order by id.
    final response = await fetchAllPages<dynamic>((from, to) async =>
        await supabase
            .from('person_attendances')
            .select(
                '*, person:person_id(id, firstName, lastName, birthday, instrument, left, paused), attendance:attendance_id!inner(tenantId)')
            .inFilter('attendance_id', attendanceIds)
            .eq('attendance.tenantId', tenantId)
            .order('id', ascending: true)
            .range(from, to) as List);

    return response.map((e) {
      final personData = e['person'] as Map<String, dynamic>?;
      return PersonAttendance(
        id: e['id']?.toString(),
        attendanceId: e['attendance_id'],
        personId: e['person_id'],
        status: parseAttendanceStatus(e['status']),
        notes: e['notes'],
        firstName: personData?['firstName'],
        lastName: personData?['lastName'],
        instrument: personData?['instrument'],
        groupName: null, // We'll get group name from players
        // LOGIC_SETTINGS: needed for Ionic averagePersons (duty Termine)
        dutyState: e['duty_state']?.toString(),
      );
    }).toList();
  } catch (e, stack) {
    debugPrint('Error loading person attendances for stats: $e');
    // SEC-008: Only log stack trace in debug mode
    if (kDebugMode) {
      debugPrint('$stack');
    }
    return [];
  }
});

// BL-010: Removed local _parseStatus - now using central parseAttendanceStatus from status_utils.dart

/// Provider for active players
final activePlayersForStatsProvider = FutureProvider<List<Person>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId == null) return [];

  // SOL_FIX1: per-tenant instance instead of mutating the shared one.
  final repo = ref.watch(playerRepositoryForTenantProvider(tenantId));
  final players = await repo.getPlayers();

  // Filter to active players only (left is null or empty = still active, not paused)
  return players.where((p) {
    final isNotLeft = p.left == null || p.left!.isEmpty;
    return isNotLeft && !p.paused;
  }).toList();
});

/// LOGIC_SETTINGS: attendances of the period with the percentage recomputed
/// like Ionic stats.page.ts (Utils.getPercentage(averagePersons(...),
/// shift_excused_as_present)) instead of the stored `attendance.percentage`,
/// which Ionic never writes.
final statsAttendancesProvider = Provider<List<Attendance>>((ref) {
  final attendances =
      ref.watch(filteredAttendancesForStatsProvider).valueOrNull ?? const [];
  final personAttendances =
      ref.watch(allPersonAttendancesForStatsProvider).valueOrNull ?? const [];
  final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
  final shiftExcused =
      ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false;
  return recomputeAttendancePercentages(
    attendances,
    personAttendances,
    types,
    shiftExcusedAsPresent: shiftExcused,
  );
});

/// Computed statistics from attendances
class AttendanceStatistics {
  final int totalAttendances;
  final int averagePercentage;
  final Attendance? bestAttendance;
  final Attendance? worstAttendance;
  final Map<AttendanceStatus, int> statusDistribution;
  final int presentCount;
  final int excusedCount;
  final int lateCount;
  final int absentCount;

  const AttendanceStatistics({
    required this.totalAttendances,
    required this.averagePercentage,
    this.bestAttendance,
    this.worstAttendance,
    required this.statusDistribution,
    required this.presentCount,
    required this.excusedCount,
    required this.lateCount,
    required this.absentCount,
  });

  factory AttendanceStatistics.empty() => const AttendanceStatistics(
        totalAttendances: 0,
        averagePercentage: 0,
        statusDistribution: {},
        presentCount: 0,
        excusedCount: 0,
        lateCount: 0,
        absentCount: 0,
      );
}

/// Provider for computed statistics
final attendanceStatisticsProvider = Provider<AttendanceStatistics>((ref) {
  // LOGIC_SETTINGS: recomputed percentages (Ionic parity)
  final attendances = ref.watch(statsAttendancesProvider);
  final personAttendancesAsync = ref.watch(allPersonAttendancesForStatsProvider);
  final personAttendances = personAttendancesAsync.valueOrNull ?? [];

  if (attendances.isEmpty) {
    return AttendanceStatistics.empty();
  }

  // Sort by percentage for best/worst
  final sorted = [...attendances]
    ..sort((a, b) => (a.percentage ?? 0).compareTo(b.percentage ?? 0));

  // Calculate average percentage — only attendance types with
  // include_in_average=true count (Ionic stats.page.ts applyDateFilter)
  final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
  final avgPercentage = calculateAveragePercentage(attendances, types);

  // Aggregate status counts
  int presentCount = 0;
  int excusedCount = 0;
  int lateCount = 0;
  int absentCount = 0;

  for (final pa in personAttendances) {
    switch (pa.status) {
      case AttendanceStatus.present:
        presentCount++;
        break;
      case AttendanceStatus.excused:
        excusedCount++;
        break;
      case AttendanceStatus.late:
      case AttendanceStatus.lateExcused:
        lateCount++;
        break;
      case AttendanceStatus.absent:
        absentCount++;
        break;
      case AttendanceStatus.neutral:
        break;
    }
  }

  return AttendanceStatistics(
    totalAttendances: attendances.length,
    averagePercentage: avgPercentage,
    bestAttendance: sorted.isNotEmpty ? sorted.last : null,
    worstAttendance: sorted.isNotEmpty ? sorted.first : null,
    statusDistribution: {
      AttendanceStatus.present: presentCount,
      AttendanceStatus.excused: excusedCount,
      AttendanceStatus.late: lateCount,
      AttendanceStatus.absent: absentCount,
    },
    presentCount: presentCount,
    excusedCount: excusedCount,
    lateCount: lateCount,
    absentCount: absentCount,
  );
});

/// Data for attendance trend chart (last N attendances)
class TrendChartData {
  final List<String> labels;
  final List<double> values;

  const TrendChartData({required this.labels, required this.values});
}

final trendChartDataProvider = Provider<TrendChartData>((ref) {
  // LOGIC_SETTINGS: recomputed percentages (Ionic parity)
  final attendances = ref.watch(statsAttendancesProvider);
  if (attendances.isEmpty) {
    return const TrendChartData(labels: [], values: []);
  }

  // Sort by date and take last 20
  final sorted = [...attendances]..sort((a, b) => a.date.compareTo(b.date));
  final last20 =
      sorted.length > 20 ? sorted.sublist(sorted.length - 20) : sorted;

  return TrendChartData(
    labels: last20.map((a) {
      final date = DateTime.tryParse(a.date);
      if (date == null) return '';
      return '${date.day}.${date.month}';
    }).toList(),
    values: last20.map((a) => a.percentage ?? 0.0).toList(),
  );
});

/// Data for group/instrument bar chart
class GroupChartData {
  final String name;
  final double percentage;
  final int count;

  const GroupChartData({
    required this.name,
    required this.percentage,
    required this.count,
  });
}

final groupChartDataProvider = Provider<List<GroupChartData>>((ref) {
  final personAttendances =
      ref.watch(allPersonAttendancesForStatsProvider).valueOrNull ?? [];
  final players = ref.watch(activePlayersForStatsProvider).valueOrNull ?? [];
  final groups = ref.watch(groupsProvider).valueOrNull ?? const [];

  if (personAttendances.isEmpty || players.isEmpty) return [];

  // LOGIC_SETTINGS: Ionic initInstrumentBarChart — group via
  // player.instrument, only active people (left/paused are skipped).
  return computeGroupAttendanceRates(personAttendances, players, groups)
      .map((g) => GroupChartData(
            name: g.name,
            percentage: g.percentage.toDouble(),
            count: g.total,
          ))
      .toList();
});

/// Data for top players chart
class PlayerChartData {
  final String name;
  final double percentage;
  final int attendanceCount;

  const PlayerChartData({
    required this.name,
    required this.percentage,
    required this.attendanceCount,
  });
}

final topPlayersChartDataProvider = Provider<List<PlayerChartData>>((ref) {
  final personAttendancesAsync = ref.watch(allPersonAttendancesForStatsProvider);
  final playersAsync = ref.watch(activePlayersForStatsProvider);

  final personAttendances = personAttendancesAsync.valueOrNull ?? [];
  final players = playersAsync.valueOrNull ?? [];

  if (personAttendances.isEmpty || players.isEmpty) return [];

  // Calculate stats per player
  final Map<int, ({String name, int present, int total})> playerStats = {};

  for (final player in players) {
    if (player.id != null) {
      final lastName = player.lastName;
      final lastInitial = lastName.isNotEmpty ? '${lastName[0]}.' : '';
      playerStats[player.id!] = (
        name: '${player.firstName} $lastInitial',
        present: 0,
        total: 0,
      );
    }
  }

  for (final pa in personAttendances) {
    if (pa.personId != null && playerStats.containsKey(pa.personId)) {
      final current = playerStats[pa.personId]!;
      final isPresent = pa.status.countsAsPresent;

      playerStats[pa.personId!] = (
        name: current.name,
        present: current.present + (isPresent ? 1 : 0),
        total: current.total + 1,
      );
    }
  }

  // Convert and sort by percentage (top 20)
  final result = playerStats.values
      .where((e) => e.total > 0)
      .map((e) => PlayerChartData(
            name: e.name,
            percentage: e.present / e.total * 100,
            attendanceCount: e.total,
          ))
      .toList()
    ..sort((a, b) => b.percentage.compareTo(a.percentage));

  return result.take(20).toList();
});

/// Data for "diva index" - unexcused absences
final divaIndexChartDataProvider = Provider<List<PlayerChartData>>((ref) {
  final personAttendancesAsync = ref.watch(allPersonAttendancesForStatsProvider);
  final playersAsync = ref.watch(activePlayersForStatsProvider);

  final personAttendances = personAttendancesAsync.valueOrNull ?? [];
  final players = playersAsync.valueOrNull ?? [];

  if (personAttendances.isEmpty || players.isEmpty) return [];

  // Count unexcused absences per player
  final Map<int, ({String name, int absences})> absenceStats = {};

  for (final player in players) {
    if (player.id != null) {
      final lastName = player.lastName;
      final lastInitial = lastName.isNotEmpty ? '${lastName[0]}.' : '';
      absenceStats[player.id!] = (
        name: '${player.firstName} $lastInitial',
        absences: 0,
      );
    }
  }

  for (final pa in personAttendances) {
    if (pa.personId != null &&
        pa.status == AttendanceStatus.absent &&
        absenceStats.containsKey(pa.personId)) {
      final current = absenceStats[pa.personId]!;
      absenceStats[pa.personId!] = (
        name: current.name,
        absences: current.absences + 1,
      );
    }
  }

  // Convert and sort by absences (top 15)
  final result = absenceStats.values
      .where((e) => e.absences > 0)
      .map((e) => PlayerChartData(
            name: e.name,
            percentage: e.absences.toDouble(),
            attendanceCount: e.absences,
          ))
      .toList()
    ..sort((a, b) => b.percentage.compareTo(a.percentage));

  return result.take(15).toList();
});

/// Age distribution data
class AgeDistributionData {
  final String label;
  final int count;

  const AgeDistributionData({required this.label, required this.count});
}

final ageDistributionProvider = Provider<List<AgeDistributionData>>((ref) {
  final playersAsync = ref.watch(activePlayersForStatsProvider);
  final players = playersAsync.valueOrNull ?? [];

  if (players.isEmpty) return [];

  // Calculate ages
  final now = DateTime.now();
  final ages = <int>[];

  for (final player in players) {
    if (player.birthday != null) {
      final birthday = DateTime.tryParse(player.birthday!);
      if (birthday != null) {
        final age = now.year -
            birthday.year -
            ((now.month < birthday.month ||
                    (now.month == birthday.month && now.day < birthday.day))
                ? 1
                : 0);
        ages.add(age);
      }
    }
  }

  if (ages.isEmpty) return [];

  // Create 3-year buckets
  final minAge = ages.reduce((a, b) => a < b ? a : b);
  final maxAge = ages.reduce((a, b) => a > b ? a : b);

  final bucketStart = (minAge ~/ 3) * 3;
  final bucketEnd = ((maxAge ~/ 3) + 1) * 3;

  final List<AgeDistributionData> result = [];

  for (int i = bucketStart; i < bucketEnd; i += 3) {
    final count = ages.where((a) => a >= i && a < i + 3).length;
    if (count > 0) {
      result.add(AgeDistributionData(
        label: '$i-${i + 2}',
        count: count,
      ));
    }
  }

  return result;
});

/// Average age per instrument
final avgAgePerInstrumentProvider = Provider<List<GroupChartData>>((ref) {
  final players = ref.watch(activePlayersForStatsProvider).valueOrNull ?? [];
  final groups = ref.watch(groupsProvider).valueOrNull ?? const [];

  if (players.isEmpty) return [];

  // LOGIC_SETTINGS: Ionic initAvgAgePerInstrumentChart — group via
  // player.instrument (groupName is never filled on Person).
  return computeAverageAgePerGroup(players, groups)
      .map((g) => GroupChartData(
            name: '${g.name} (${g.count})',
            percentage: g.avgAge.toDouble(),
            count: g.count,
          ))
      .toList();
});
