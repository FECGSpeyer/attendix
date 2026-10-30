import 'package:flutter/foundation.dart';

import '../../data/models/attendance/attendance.dart';
import '../../data/models/church/church.dart';
import '../../data/models/dashboard/dashboard_event.dart';
import '../../data/models/dashboard/dashboard_models.dart';
import '../constants/enums.dart';
import '../router/redesign_routes.dart';
import 'attendance_percentage_utils.dart';
import 'dashboard_utils.dart';

// Pure (Riverpod-free) dashboard logic, ported from the Ionic home-dashboard
// cards, dashboard settings and administration page. Kept separate from the
// providers so it can be unit-tested without the Supabase/Riverpod stack.

/// Default card configuration (Ionic `DEFAULT_DASHBOARD_CARDS`).
List<DashboardCardConfig> defaultDashboardCards() => [
      for (final id in DashboardCardIds.all) DashboardCardConfig(id: id),
    ];

/// Ionic `getDashboardCardConfig`: keeps the stored order, appends cards that
/// were added later and drops unknown ids.
List<DashboardCardConfig> mergeDashboardCardConfig(Object? stored) {
  if (stored is! List || stored.isEmpty) return defaultDashboardCards();

  final storedCards = <DashboardCardConfig>[];
  for (final raw in stored) {
    if (raw is Map && raw['id'] is String) {
      storedCards.add(DashboardCardConfig(
        id: raw['id'] as String,
        visible: raw['visible'] != false,
      ));
    }
  }
  if (storedCards.isEmpty) return defaultDashboardCards();

  final missing = DashboardCardIds.all
      .where((id) => !storedCards.any((c) => c.id == id))
      .map((id) => DashboardCardConfig(id: id));
  return [...storedCards, ...missing]
      .where((c) => DashboardCardIds.all.contains(c.id))
      .toList();
}

/// Ionic: dashboard is the start page for Admin/Responsible with the tab on.
bool shouldUseDashboardHome(Role role, int? tenantId, Map<String, dynamic>? metadata) {
  if (tenantId == null) return false;
  if (!(role.isAdmin || role.isResponsible)) return false;
  return metadata?['showDashboardTab_$tenantId'] == true;
}

/// Start route after login / tenant selection (Ionic `LoginGuard` / `routeAfterAuth`).
///
/// REDESIGN: with the new design (Beta) switched on every role starts on
/// "Heute".
String homeRouteFor(Role role, int? tenantId, Map<String, dynamic>? metadata) =>
    RedesignRoutes.active
        ? RedesignRoutes.today
        : shouldUseDashboardHome(role, tenantId, metadata)
            ? '/home-dashboard'
            : role.defaultRoute;

/// Cards that can be configured: "Meine Aufgaben" only exists with Teamorganisation.
List<DashboardCardConfig> configurableDashboardCards(
  List<DashboardCardConfig> cards, {
  required bool teamOrgEnabled,
}) =>
    cards
        .where((c) => c.id != DashboardCardIds.myTasks || teamOrgEnabled)
        .toList();

/// Summary for the "Termine" card.
@immutable
class NextEventSummary {
  const NextEventSummary({
    this.lastEvent,
    this.nextEvent,
    this.lastPerc = 0,
    this.lastPresent = 0,
    this.lastExcused = 0,
    this.lastTotal = 0,
    this.nextPerc = 0,
    this.nextTotal = 0,
    this.nextPresent = 0,
    this.nextExcused = 0,
    this.nextShiftWorkers = 0,
    this.nextNeutral = 0,
    this.nextExcusedPersons = const [],
  });

  final DashboardEvent? lastEvent;
  final DashboardEvent? nextEvent;
  final int lastPerc;
  final int lastPresent;
  final int lastExcused;
  final int lastTotal;
  final int nextPerc;
  final int nextTotal;
  final int nextPresent;
  final int nextExcused;
  final int nextShiftWorkers;
  final int nextNeutral;
  final List<PersonAttendance> nextExcusedPersons;
}

/// Ionic NextEventCard logic, extracted for testing.
NextEventSummary computeNextEventSummary(
  List<DashboardEvent> events, {
  bool shiftExcusedAsPresent = false,
  DateTime? now,
}) {
  int dateMs(DashboardEvent e) =>
      DashboardUtils.parse(e.attendance.date)?.millisecondsSinceEpoch ?? 0;

  final seen = <int?>{};
  final unique = events.where((e) => seen.add(e.attendance.id)).toList();
  final past = unique.where((e) => DashboardUtils.hasEnded(e, now: now)).toList()
    ..sort((a, b) => dateMs(b) - dateMs(a));
  final upcoming = unique.where((e) => !DashboardUtils.hasEnded(e, now: now)).toList()
    ..sort((a, b) => dateMs(a) - dateMs(b));

  final last = past.isNotEmpty ? past.first : null;
  final next = upcoming.isNotEmpty ? upcoming.first : null;

  bool isPresent(AttendanceStatus s) =>
      s == AttendanceStatus.present || s == AttendanceStatus.late;
  bool isExcused(AttendanceStatus s) =>
      s == AttendanceStatus.excused || s == AttendanceStatus.lateExcused;

  final lp = last?.persons ?? const [];
  final np = next?.persons ?? const [];
  final excused = np.where((p) => isExcused(p.status)).toList()
    ..sort((a, b) {
      final g = (a.groupName ?? '').compareTo(b.groupName ?? '');
      return g != 0 ? g : (a.lastName ?? '').compareTo(b.lastName ?? '');
    });

  return NextEventSummary(
    lastEvent: last,
    nextEvent: next,
    lastPerc: attendancePercentage(lp, shiftExcusedAsPresent: shiftExcusedAsPresent),
    lastPresent: lp.where((p) => isPresent(p.status)).length,
    lastExcused: lp.where((p) => isExcused(p.status)).length,
    lastTotal: lp.length,
    nextPerc: attendancePercentage(np, shiftExcusedAsPresent: shiftExcusedAsPresent),
    nextTotal: np.length,
    nextPresent: np.where((p) => isPresent(p.status)).length,
    nextExcused: excused.length,
    nextShiftWorkers: excused.where((p) => isWorkExcusedNote(p.notes)).length,
    nextNeutral: np.where((p) => p.status == AttendanceStatus.neutral).length,
    nextExcusedPersons: excused,
  );
}

/// Groups history rows like Ionic `getCurrentSongs` and flattens them to one
/// entry per song (first occurrence wins).
List<DashboardSongEntry> buildCurrentSongEntries(
  List<Map<String, dynamic>> rows, {
  required String? Function(String? typeId) typeName,
}) {
  String two(int v) => v.toString().padLeft(2, '0');
  String fmt(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

  final groups = <String, List<Map<String, dynamic>>>{};
  final groupDate = <String, DateTime>{};
  final groupMaxId = <String, int>{};

  for (final his in rows) {
    final att = his['attendance_id'] is Map ? his['attendance_id'] as Map : null;
    final date = DashboardUtils.parse((att?['date'] ?? his['date'])?.toString()) ??
        DateTime.now();
    final dateStr = fmt(date);
    var key = dateStr;
    if (att != null) {
      final info = (att['typeInfo'] as String?)?.isNotEmpty == true
          ? att['typeInfo'] as String
          : typeName(att['type_id']?.toString());
      if (info != null && info.isNotEmpty) key = '$dateStr | $info';
    }
    final person = his['person_id'] is Map ? his['person_id'] as Map : null;
    groups.putIfAbsent(key, () => []).add({
      ...his,
      'conductorName': person != null
          ? '${person['firstName']} ${person['lastName']}'
          : (his['otherConductor'] ?? ''),
    });
    groupDate[key] = DashboardUtils.startOfDay(date);
    final attId = att?['id'] is num ? (att!['id'] as num).toInt() : 0;
    groupMaxId[key] = (groupMaxId[key] ?? 0) > attId ? groupMaxId[key]! : attId;
  }

  // Ionic: date descending, then attendance id descending — then reversed.
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final d = groupDate[b]!.compareTo(groupDate[a]!);
      if (d != 0) return d;
      return groupMaxId[b]! - groupMaxId[a]!;
    });
  final ordered = keys.reversed;

  final seen = <int>{};
  final result = <DashboardSongEntry>[];
  for (final key in ordered) {
    for (final h in groups[key]!) {
      final song = h['song'] is Map ? h['song'] as Map : null;
      final id = song?['id'] is num ? (song!['id'] as num).toInt() : null;
      if (id == null || !seen.add(id)) continue;
      final att = h['attendance_id'] is Map ? h['attendance_id'] as Map : null;
      final parts = key.split(' | ');
      final conductor = h['conductorName']?.toString() ?? '';
      result.add(DashboardSongEntry(
        songId: id,
        name: song!['name']?.toString() ?? '',
        number: song['number'] is num ? (song['number'] as num).toInt() : null,
        prefix: song['prefix']?.toString(),
        conductorName: conductor.isNotEmpty ? conductor : null,
        dateLabel: key,
        date: (att?['date'] ?? h['date'])?.toString(),
        typeLabel: parts.length > 1 ? parts[1] : null,
      ));
    }
  }
  return result;
}

/// The Termin whose Ablaufplan is shown in the "Aktueller Ablaufplan" card.
@immutable
class CurrentPlanData {
  const CurrentPlanData({
    required this.event,
    required this.plan,
    required this.planDay,
    required this.multiPlan,
  });

  final DashboardEvent event;
  final Map<String, dynamic> plan;
  final DateTime planDay;
  final bool multiPlan;
}

/// Ionic CurrentPlanCard.load(): first running/upcoming Termin with a filled
/// plan (shared plan for non-admins); multi-plan Termine show today's plan.
CurrentPlanData? selectCurrentPlan(
  List<DashboardEvent> events, {
  required bool isAdmin,
  DateTime? now,
}) {
  final candidates = events.where((e) => !DashboardUtils.hasEnded(e, now: now));
  for (final e in candidates) {
    final plans = DashboardUtils.allPlans(e);
    final hasFields = plans.any((p) => DashboardUtils.planFields(p).isNotEmpty);
    if (!hasFields || !(isAdmin || e.attendance.sharePlan)) continue;
    final index = DashboardUtils.todayPlanIndex(e, now: now);
    return CurrentPlanData(
      event: e,
      plan: index < plans.length ? plans[index] : plans.first,
      planDay: DashboardUtils.planDate(e, index),
      multiPlan: plans.length > 1,
    );
  }
  return null;
}

/// Ionic `Utils.getPercentage`: share of present persons (late and
/// late-excused count as present; shift-excused optionally too).
/// Thin wrapper around [attendanceRowsPercentage] (no duty filter).
int attendancePercentage(
  List<PersonAttendance> persons, {
  bool shiftExcusedAsPresent = false,
}) =>
    (attendanceRowsPercentage(
              persons.map(attendanceCountRowOf),
              null,
              shiftExcusedAsPresent: shiftExcusedAsPresent,
            ) ??
            0)
        .round();

/// Duplicate church group (same normalised name).
class ChurchDuplicateGroup {
  const ChurchDuplicateGroup(this.target, this.duplicates);
  final Church target;
  final List<Church> duplicates;
}

/// Ionic `findDuplicates`: groups churches whose normalised names match.
List<ChurchDuplicateGroup> findChurchDuplicates(List<Church> churches) {
  String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-zäöüß0-9]'), '');
  final groups = <String, List<Church>>{};
  for (final c in churches) {
    groups.putIfAbsent(normalize(c.name), () => []).add(c);
  }
  return [
    for (final g in groups.values)
      if (g.length > 1) ChurchDuplicateGroup(g.first, g.sublist(1)),
  ];
}
