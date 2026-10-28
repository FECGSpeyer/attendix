import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/event_list_utils.dart';
import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../../data/models/attendance/attendance.dart';
import '../../data/repositories/repositories.dart';
import 'attendance_type_providers.dart';
import 'realtime_providers.dart';
import 'tenant_providers.dart';

/// Initialized attendance repository with tenant context
final attendanceRepositoryWithTenantProvider = Provider<AttendanceRepository>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final tenant = ref.watch(currentTenantIdProvider);
  
  if (tenant != null) {
    repo.setTenantId(tenant);
  }
  
  return repo;
});

/// Provider for attendance list
final attendancesProvider = FutureProvider<List<Attendance>>((ref) async {
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getAttendances();
});

/// Provider for upcoming attendances
final upcomingAttendancesProvider = FutureProvider<List<Attendance>>((ref) async {
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getUpcomingAttendances();
});

/// Provider for a single attendance by ID
final attendanceByIdProvider = FutureProvider.family<Attendance?, int>((ref, id) async {
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return null;
  
  return repo.getAttendanceById(id);
});

/// Provider for person attendances by person ID
final personAttendancesProvider = FutureProvider.family<List<PersonAttendance>, int>((ref, personId) async {
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getPersonAttendancesForPerson(personId);
});

// ATT_DETAIL
/// Termintyp filter of the attendance list (Ionic att-list `filterTypeId`).
/// `null` = "Alle anzeigen".
/// Reset on tenant switch (type ids are tenant specific).
final attendanceListTypeFilterProvider = StateProvider<String?>((ref) {
  ref.watch(currentTenantIdProvider);
  return null;
});

/// Status counts (anwesend / entschuldigt / abwesend) of one Termin, used by
/// the "Heute / Nächster Termin" card (Ionic att-list getStatusCounts).
final attendanceStatusCountsProvider =
    FutureProvider.autoDispose.family<AttendanceStatusCounts, int>((ref, attendanceId) async {
  ref.watch(attendanceRefetchCounter);
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const AttendanceStatusCounts();
  final rows = await repo.getPersonAttendancesForAttendances([attendanceId]);
  return AttendanceStatusCounts.fromStatuses(rows.map((r) => r.status));
});

/// Counts like Ionic getStatusCounts: Verspätet counts as present,
/// Verspätet entschuldigt as excused.
class AttendanceStatusCounts {
  const AttendanceStatusCounts({
    this.present = 0,
    this.excused = 0,
    this.absent = 0,
    this.total = 0,
  });

  factory AttendanceStatusCounts.fromStatuses(Iterable<AttendanceStatus> statuses) {
    var present = 0, excused = 0, absent = 0, total = 0;
    for (final s in statuses) {
      total++;
      switch (s) {
        case AttendanceStatus.present:
        case AttendanceStatus.late:
          present++;
        case AttendanceStatus.excused:
        case AttendanceStatus.lateExcused:
          excused++;
        case AttendanceStatus.absent:
          absent++;
        default:
          break;
      }
    }
    return AttendanceStatusCounts(
      present: present,
      excused: excused,
      absent: absent,
      total: total,
    );
  }

  final int present;
  final int excused;
  final int absent;

  /// All persons of the Termin (Ionic `att.persons.length`).
  final int total;
}

// UX_ATT: status counts of all Termine shown in the list, loaded with one
// query (Ionic att-list getCountText "{present} von {total} anwesend").
final attendanceListStatusCountsProvider =
    FutureProvider.autoDispose<Map<int, AttendanceStatusCounts>>((ref) async {
  // Refetch only when the Termine or their percentages change, not on every
  // realtime event (e.g. notes edits).
  final key = ref.watch(realtimeAttendanceListProvider.select((v) =>
      (v.valueOrNull ?? const <Attendance>[])
          .map((a) => '${a.id}:${a.percentage}')
          .join(',')));
  final ids = key.isEmpty
      ? const <int>[]
      : key
          .split(',')
          .map((e) => int.tryParse(e.split(':').first))
          .whereType<int>()
          .toList();
  if (ids.isEmpty) return const {};
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const {};
  final rows = await repo.getPersonAttendancesForAttendances(ids);
  final byAttendance = <int, List<AttendanceStatus>>{};
  for (final r in rows) {
    final id = r.attendanceId;
    if (id == null) continue;
    byAttendance.putIfAbsent(id, () => []).add(r.status);
  }
  return {
    for (final e in byAttendance.entries)
      e.key: AttendanceStatusCounts.fromStatuses(e.value),
  };
});
// END ATT_DETAIL

/// Data class for categorized attendances (memoized)
class CategorizedAttendances {
  final Attendance? current;
  final List<Attendance> upcoming;
  final List<Attendance> past;

  const CategorizedAttendances({
    this.current,
    required this.upcoming,
    required this.past,
  });
}

/// Provider that categorizes and sorts attendances (computed once per data change)
final categorizedAttendancesProvider = Provider<CategorizedAttendances>((ref) {
  final all = ref.watch(realtimeAttendanceListProvider).valueOrNull ?? [];
  // ATT_DETAIL: Termintyp filter of the list ("Alle anzeigen" = null)
  final typeFilter = ref.watch(attendanceListTypeFilterProvider);
  final attendances =
      typeFilter == null ? all : all.where((a) => a.typeId == typeFilter).toList();

  final now = DateTime.now();

  final upcoming = <Attendance>[];
  final past = <Attendance>[];

  for (final attendance in attendances) {
    final date = DateTime.tryParse(attendance.date);
    if (date == null) {
      past.add(attendance);
      continue;
    }
    // Multi-day Termine count as past only after their last day.
    if (EventListUtils.hasEnded(attendance.date, attendance.durationDays, now: now)) {
      past.add(attendance);
    } else {
      upcoming.add(attendance);
    }
  }

  // Sort once
  upcoming.sort((a, b) => a.date.compareTo(b.date));
  past.sort((a, b) => b.date.compareTo(a.date));

  // BL-013: Extract current without mutating the upcoming list
  Attendance? current;
  List<Attendance> remainingUpcoming;
  if (upcoming.isNotEmpty) {
    current = upcoming.first;
    remainingUpcoming = upcoming.sublist(1);
  } else {
    remainingUpcoming = [];
  }

  return CategorizedAttendances(
    current: current,
    upcoming: remainingUpcoming,
    past: past,
  );
});

/// Provider for average attendance percentage of past attendances
final averageAttendancePercentProvider = Provider<double?>((ref) {
  final categorized = ref.watch(categorizedAttendancesProvider);
  // BL-005: Include 0% attendances in average calculation (changed > 0 to != null)
  final pastAttendances = categorized.past
      .where((a) => a.percentage != null)
      .toList();

  if (pastAttendances.isEmpty) return null;

  final sum = pastAttendances.fold<double>(
    0,
    (acc, a) => acc + (a.percentage ?? 0),
  );
  return sum / pastAttendances.length;
});

/// Provider for batch attendance percentages: Map<personId, percentage>
///
/// Watches [attendanceRefetchCounter] so realtime changes to
/// person_attendances automatically trigger a refetch.
/// Uses paginated fetching to avoid the Supabase default 1000-row limit.
final playerAttendancePercentagesProvider =
    FutureProvider<Map<int, int>>((ref) async {
  ref.watch(attendanceRefetchCounter);

  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  if (tenant == null || tenant.id == null) return {};

  final now = DateTime.now().toIso8601String();
  final seasonStart = tenant.seasonStart;

  // Fetch all records using pagination to avoid the PostgREST 1000-row default limit.
  // A tenant with 50+ members and 25+ events easily exceeds 1000 person_attendances.
  const batchSize = 1000;
  final allAttendances = <dynamic>[];
  int offset = 0;

  while (true) {
    var query = supabase
        .from('person_attendances')
        .select('person_id, status, notes, attendance:attendance_id!inner(date, tenantId, type_id)')
        .eq('attendance.tenantId', tenant.id!)
        .lte('attendance.date', now);

    // Only count attendances from the current season
    if (seasonStart != null) {
      query = query.gte('attendance.date', seasonStart);
    }

    final batch = await query.range(offset, offset + batchSize - 1);

    final rows = batch as List;
    allAttendances.addAll(rows);
    if (rows.length < batchSize) break;
    offset += batchSize;
  }

  // Only attendance types with include_in_average count (Ionic
  // Utils.getModifiedPlayersForList). Unknown types are excluded.
  final types = await ref.watch(attendanceTypesProvider.future);
  final includedTypeIds = types
      .where((t) => t.includeInAverage && t.id != null)
      .map((t) => t.id!)
      .toSet();

  // Group by person_id
  final totals = <int, int>{};
  final attended = <int, int>{};

  for (final a in allAttendances) {
    final personId = a['person_id'] as int?;
    if (personId == null) continue;
    final typeId = (a['attendance'] as Map?)?['type_id']?.toString();
    if (typeId == null || !includedTypeIds.contains(typeId)) continue;
    totals[personId] = (totals[personId] ?? 0) + 1;
    final status = a['status'] as int?;
    // BL-003: Use centralized definition for which statuses count as attended
    // SETTINGS2: shift_excused_as_present (Ionic getModifiedPlayersForList)
    if (AttendanceStatus.fromValue(status ?? 0).countsAsAttended(
      notes: a['notes'] as String?,
      shiftExcusedAsPresent: tenant.shiftExcusedAsPresent,
    )) {
      attended[personId] = (attended[personId] ?? 0) + 1;
    }
  }

  return totals.map((personId, total) {
    final att = attended[personId] ?? 0;
    final pct = total > 0 ? (att / total * 100).round() : 0;
    return MapEntry(personId, pct);
  });
});

/// Notifier for attendance mutations
class AttendanceNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  AttendanceRepository get _repo => ref.read(attendanceRepositoryWithTenantProvider);

  Future<Attendance?> createAttendance(Attendance attendance) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createAttendance(attendance);
      state = const AsyncValue.data(null);
      ref.invalidate(attendancesProvider);
      ref.invalidate(upcomingAttendancesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Attendance?> updateAttendance(int id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateAttendance(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(attendancesProvider);
      ref.invalidate(attendanceByIdProvider(id));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<void> deleteAttendance(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteAttendance(id);
      state = const AsyncValue.data(null);
      ref.invalidate(attendancesProvider);
      ref.invalidate(playerAttendancePercentagesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createPersonAttendances(List<PersonAttendance> records) async {
    state = const AsyncValue.loading();
    try {
      await _repo.createPersonAttendances(records);
      state = const AsyncValue.data(null);
      // Invalidate relevant providers
      for (final record in records) {
        if (record.attendanceId != null) {
          ref.invalidate(attendanceByIdProvider(record.attendanceId!));
        }
        if (record.personId != null) {
          ref.invalidate(personAttendancesProvider(record.personId!));
        }
      }
      ref.invalidate(playerAttendancePercentagesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<PersonAttendance?> updatePersonAttendance(
    String id, 
    int attendanceId,
    int personId,
    Map<String, dynamic> updates,
  ) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updatePersonAttendance(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(attendanceByIdProvider(attendanceId));
      ref.invalidate(personAttendancesProvider(personId));
      ref.invalidate(playerAttendancePercentagesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Batch update multiple person attendances with the same status
  Future<void> batchUpdatePersonAttendances(
    List<String> personAttendanceIds,
    int attendanceId,
    AttendanceStatus newStatus,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _repo.batchUpdatePersonAttendances(personAttendanceIds, newStatus);
      state = const AsyncValue.data(null);
      ref.invalidate(attendanceByIdProvider(attendanceId));
      // LOGIC_ATT: Ionic never stores attendance.percentage (not a column in
      // the Ionic schema); the list computes it from the person rows.
      ref.invalidate(attendancesProvider);
      ref.invalidate(playerAttendancePercentagesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final attendanceNotifierProvider = NotifierProvider<AttendanceNotifier, AsyncValue<void>>(() {
  return AttendanceNotifier();
});
