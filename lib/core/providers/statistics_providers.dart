import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../../core/utils/status_utils.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../l10n/l10n.dart';
import '../utils/global_toast.dart';
import '../utils/paged_query.dart';
import 'player_providers.dart';
import 'profile_providers.dart';
import 'tenant_providers.dart';

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

  /// Reset to season start if available, otherwise 2023-01-01.
  /// P10_ATTENDANCE: Ionic stats `filterStartDate = getCurrentAttDate()`
  /// = `tenant.seasonStart || '2023-01-01'`, end = today.
  void resetToDefault({String? seasonStart}) {
    final parsed = seasonStart == null ? null : DateTime.tryParse(seasonStart);
    state = StatisticsDateRange(
      start: parsed ?? DateTime(2023, 1, 1),
      end: DateTime.now(),
    );
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
    // PARITY_A (R1): Ionic stats loads all Termine (no limit).
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
    return await loadStatsPersonAttendances(supabase, tenantId, attendanceIds);
  } catch (e, stack) {
    debugPrint('Error loading person attendances for stats: $e');
    // SEC-008: Only log stack trace in debug mode
    if (kDebugMode) {
      debugPrint('$stack');
    }
    return [];
  }
});

/// The person attendances of [attendanceIds] (tenant [tenantId]) with name,
/// group and duty state, for the statistics. Throws on failure.
Future<List<PersonAttendance>> loadStatsPersonAttendances(
  SupabaseClient supabase,
  int tenantId,
  List<int> attendanceIds,
) async {
  if (attendanceIds.isEmpty) return [];
  // SEC-003: Defense-in-Depth - add tenant filter via inner join
  // SOL_FIX1: paged (PostgREST max-rows 1000), stable order by id.
  // Chunked: a long date range has hundreds of Termine, and all their ids
  // in one URL exceed the request size limit.
  final response = await fetchInChunks<dynamic, int>(
      attendanceIds,
      (chunk) => fetchAllPages<dynamic>((from, to) async =>
          await supabase
              .from('person_attendances')
              .select(
                  '*, person:person_id(id, firstName, lastName, birthday, instrument, left, paused), attendance:attendance_id!inner(tenantId)')
              .inFilter('attendance_id', chunk)
              .eq('attendance.tenantId', tenantId)
              .order('id', ascending: true)
              .range(from, to) as List));

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
}

/// Provider for active players
final activePlayersForStatsProvider = FutureProvider<List<Person>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId == null) return [];

  // SOL_FIX1: per-tenant instance instead of mutating the shared one.
  final repo = ref.watch(playerRepositoryForTenantProvider(tenantId));
  final List<Person> players;
  try {
    players = await repo.getPlayers();
  } catch (_) {
    // Ionic db.getPlayers: red toast "Fehler beim Laden der Personen" instead
    // of empty charts without a hint (once per failed load).
    GlobalToast.error(l10nWithoutContext.dbLoadPeopleFailed);
    rethrow;
  }

  // Filter to active players only (left is null or empty = still active, not paused)
  return players.where((p) {
    final isNotLeft = p.left == null || p.left!.isEmpty;
    return isNotLeft && !p.paused;
  }).toList();
});

/// Ionic 4.17.17 stats `initFieldStats`: current (not left) people incl.
/// paused ones, with the shared organisation field values hydrated so that
/// organisation fields are analysed too. When the shared values cannot be
/// loaded the tenant values are used (Ionic only logs a warning).
final fieldStatsPersonsProvider =
    FutureProvider.autoDispose<List<Person>>((ref) async {
  final people = await ref.watch(playersProvider.future);
  final repo = ref.watch(profileRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return people;
  try {
    return await repo.hydrateSharedPersonFieldValues(people);
  } catch (e) {
    debugPrint('Shared person field values could not be loaded: $e');
    return people;
  }
});
