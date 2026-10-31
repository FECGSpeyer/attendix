import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/attendance/attendance.dart';
import 'rd_today_providers.dart';
import '../rd_dates.dart';

/// REDESIGN: data of the "Termine" tab. Only reads through the existing
/// `…RepositoryWithTenantProvider`s (no new tables, no writes).

/// Answers of all upcoming Termine of the list, loaded with one query
/// (like `attendanceListStatusCountsProvider`, but split like the cards).
final rdUpcomingCountsProvider =
    FutureProvider.autoDispose<Map<int, RdStatusCounts>>((ref) async {
  ref.watch(attendanceRefetchCounter);
  // Refetch only when the set of upcoming Termine changes.
  final key = ref.watch(realtimeAttendanceListProvider.select((v) =>
      rdUpcoming(v.valueOrNull ?? const <Attendance>[])
          .map((a) => a.id)
          .whereType<int>()
          .join(',')));
  if (key.isEmpty) return const {};
  final ids = key.split(',').map(int.parse).toList();
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
    for (final e in byAttendance.entries) e.key: RdStatusCounts.fromStatuses(e.value),
  };
});

/// Upcoming (not ended) Termine, soonest first.
List<Attendance> rdUpcoming(List<Attendance> all, {DateTime? now}) {
  final current = now ?? DateTime.now();
  DateTime keyOf(Attendance a) => rdStartOf(a.date, a.startTime) ?? DateTime(9999);
  return all
      .where((a) => !EventListUtils.hasEnded(a.date, a.durationDays, now: current))
      .toList()
    ..sort((a, b) => keyOf(a).compareTo(keyOf(b)));
}

/// Termine that ended within the last [days] days, oldest first (UX D4).
List<Attendance> rdRecentPast(List<Attendance> all, {DateTime? now, int days = 14}) {
  final current = now ?? DateTime.now();
  final from = DateTime(current.year, current.month, current.day).subtract(Duration(days: days));
  DateTime keyOf(Attendance a) => rdStartOf(a.date, a.startTime) ?? DateTime(1970);
  return all
      .where((a) => EventListUtils.hasEnded(a.date, a.durationDays, now: current) && !keyOf(a).isBefore(from))
      .toList()
    ..sort((a, b) => keyOf(a).compareTo(keyOf(b)));
}

/// Ids of [ids] (kept in order) where someone still has no status. In
/// duty Termine ([dutyIds]) stand-ins without a duty_state stay neutral on
/// purpose (see `duty_utils.dart`) and do not count.
List<int> rdUnrecordedIds(List<int> ids, Iterable<PersonAttendance> rows, {Set<int> dutyIds = const {}}) {
  final open = {
    for (final r in rows)
      if (r.status == AttendanceStatus.neutral &&
          r.attendanceId != null &&
          !(dutyIds.contains(r.attendanceId) && r.dutyState == null))
        r.attendanceId!,
  };
  return [for (final id in ids) if (open.contains(id)) id];
}

/// "Termine noch nicht erfasst" on Heute (UX D4): Termine of the last two
/// weeks that are over but still have people without a status. One query
/// for all of them, like [rdUpcomingCountsProvider].
final rdUnrecordedProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  ref.watch(attendanceRefetchCounter);
  final recent = ref.watch(realtimeAttendanceListProvider.select((v) => rdRecentPast(v.valueOrNull ?? const <Attendance>[])
      .map((a) => a.id)
      .whereType<int>()
      .join(',')));
  if (recent.isEmpty) return const [];
  final ids = recent.split(',').map(int.parse).toList();
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const [];
  final types = await ref.watch(attendanceTypesProvider.future);
  final dutyTypes = {for (final t in types) if (t.dutyMode) t.id};
  final all = ref.read(realtimeAttendanceListProvider).valueOrNull ?? const <Attendance>[];
  final dutyIds = {
    for (final a in all)
      if (a.id != null && ids.contains(a.id) && dutyTypes.contains(a.typeId)) a.id!,
  };
  return rdUnrecordedIds(ids, await repo.getPersonAttendancesForAttendances(ids), dutyIds: dutyIds);
});

/// Ended Termine, newest first.
List<Attendance> rdPast(List<Attendance> all, {DateTime? now}) {
  final current = now ?? DateTime.now();
  DateTime keyOf(Attendance a) => rdStartOf(a.date, a.startTime) ?? DateTime(1970);
  return all
      .where((a) => EventListUtils.hasEnded(a.date, a.durationDays, now: current))
      .toList()
    ..sort((a, b) => keyOf(b).compareTo(keyOf(a)));
}

/// Average attendance of [past] Termine with a percentage (Ø in the
/// "Vergangen" segment); null without any.
double? rdAveragePercentage(List<Attendance> past) {
  final values = past.map((a) => a.percentage).whereType<double>().toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Section of the Termin list: "Diese Woche" or one month.
@immutable
class RdEventSection<T> {
  const RdEventSection({required this.thisWeek, this.month, required this.items});

  /// "Diese Woche" (upcoming: the coming 7 days; past: the last 7 days).
  final bool thisWeek;

  /// First day of the month of this section (null for [thisWeek]).
  final DateTime? month;
  final List<T> items;
}

/// Groups [items] (already sorted) into "Diese Woche" and months.
List<RdEventSection<T>> rdGroupEvents<T>(
  List<T> items,
  String? Function(T) dateOf, {
  bool past = false,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final sections = <RdEventSection<T>>[];
  final week = <T>[];
  final byMonth = <DateTime, List<T>>{};
  final monthOrder = <DateTime>[];
  for (final item in items) {
    final d = EventListUtils.parse(dateOf(item));
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    final diff = rdDaysBetween(today, day);
    // Upcoming: running multi-day Termine that started earlier count as
    // this week too.
    final inWeek = past ? (diff >= -7 && diff <= 0) : diff < 7;
    if (inWeek) {
      week.add(item);
      continue;
    }
    final month = DateTime(d.year, d.month);
    if (!byMonth.containsKey(month)) monthOrder.add(month);
    byMonth.putIfAbsent(month, () => []).add(item);
  }
  if (week.isNotEmpty) sections.add(RdEventSection(thisWeek: true, items: week));
  for (final m in monthOrder) {
    sections.add(RdEventSection(thisWeek: false, month: m, items: byMonth[m]!));
  }
  return sections;
}
