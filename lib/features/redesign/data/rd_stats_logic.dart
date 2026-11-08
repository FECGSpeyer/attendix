import 'package:flutter/foundation.dart';

import '../../../core/constants/enums.dart';
import '../../../core/utils/duty_utils.dart' show isDutyType;
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/person/person.dart';

/// Time ranges of the Auswertung (canvas "Auswertung neu gedacht"):
/// three presets and "Eigener …" (Von / Bis like the Ionic statistics).
enum RdStatsRange { season, threeMonths, twelveMonths, custom }

/// Start of [range] on [today]; the season starts at the tenant's
/// `seasonStart` (Ionic stats default), else on 1 Jan 2023 like Ionic.
/// [RdStatsRange.custom] has no start of its own; it falls back to the
/// season.
DateTime rdStatsRangeStart(RdStatsRange range, DateTime today, {String? seasonStart}) =>
    switch (range) {
      RdStatsRange.season || RdStatsRange.custom =>
        (seasonStart == null ? null : DateTime.tryParse(seasonStart)) ?? DateTime(2023, 1, 1),
      RdStatsRange.threeMonths => DateTime(today.year, today.month - 3, today.day),
      RdStatsRange.twelveMonths => DateTime(today.year - 1, today.month, today.day),
    };

/// View filter of the Auswertung. It only changes what the page shows;
/// which Terminarten count for the attendance rate everywhere is the
/// type's `include_in_average` ("Zählt zur Anwesenheitsquote").
@immutable
class RdStatsFilter {
  const RdStatsFilter({this.typeIds, this.groupIds = const {}});

  /// Chosen Terminarten; null = the ones that count for the attendance
  /// rate.
  final Set<String>? typeIds;

  /// Chosen Register; empty = all.
  final Set<int> groupIds;

  /// Number of active filters (for "Filter · N").
  int get count => (typeIds == null ? 0 : 1) + (groupIds.isEmpty ? 0 : 1);

  RdStatsFilter withTypes(Set<String>? ids) => RdStatsFilter(typeIds: ids, groupIds: groupIds);

  RdStatsFilter withGroups(Set<int> ids) => RdStatsFilter(typeIds: typeIds, groupIds: ids);

  RdStatsFilter toggleGroup(int id) =>
      withGroups(groupIds.contains(id) ? ({...groupIds}..remove(id)) : {...groupIds, id});

  @override
  bool operator ==(Object other) =>
      other is RdStatsFilter && setEquals(other.typeIds, typeIds) && setEquals(other.groupIds, groupIds);

  @override
  int get hashCode => Object.hash(
        typeIds == null ? null : Object.hashAllUnordered(typeIds!),
        Object.hashAllUnordered(groupIds),
      );
}

/// [filter] showing the Terminarten [ids]; the counted ones again mean
/// no type filter.
RdStatsFilter rdStatsFilterWithTypes(RdStatsFilter filter, Set<String> ids, List<AttendanceType> types) {
  final counted = rdCountedTypeIds(types);
  return filter.withTypes(ids.length == counted.length && ids.containsAll(counted) ? null : ids);
}

/// Terminarten that count for the attendance rate (`include_in_average`).
Set<String> rdCountedTypeIds(List<AttendanceType> types) => {
      for (final t in types)
        if (t.includeInAverage && t.id != null) t.id!,
    };

/// Terminarten shown with [filter]: the chosen ones, or the counted ones.
Set<String> rdStatsTypeIds(RdStatsFilter filter, List<AttendanceType> types) =>
    filter.typeIds ?? rdCountedTypeIds(types);

/// Register of the Auswertung: every group except the main group (the
/// Dirigent / Leitung is no Register and always near 100 %).
List<Group> rdStatsGroups(List<Group> groups) =>
    [for (final g in groups) if (g.id != null && g.maingroup != true) g];

/// How the counted entries of a Termin, a Register or a person split up.
@immutable
class RdStatsCounts {
  const RdStatsCounts({
    this.present = 0,
    this.late = 0,
    this.excused = 0,
    this.absent = 0,
    this.open = 0,
    this.attended = 0,
  });

  final int present;

  /// Verspätet and Verspätet (entschuldigt).
  final int late;
  final int excused;
  final int absent;

  /// Neutral / not recorded yet (counts like Ionic, as not attended).
  final int open;

  /// Present + late (+ work-/shift-excused when the group counts them).
  final int attended;

  int get total => present + late + excused + absent + open;

  /// Attendance rate in percent (0 without entries).
  int get percent => total == 0 ? 0 : (attended * 100 / total).round();

  RdStatsCounts add(AttendanceStatus status, {required bool attended}) => RdStatsCounts(
        present: present + (status == AttendanceStatus.present ? 1 : 0),
        late: late + (status == AttendanceStatus.late || status == AttendanceStatus.lateExcused ? 1 : 0),
        excused: excused + (status == AttendanceStatus.excused ? 1 : 0),
        absent: absent + (status == AttendanceStatus.absent ? 1 : 0),
        open: open + (status == AttendanceStatus.neutral ? 1 : 0),
        attended: this.attended + (attended ? 1 : 0),
      );
}

/// One Termin of the period.
@immutable
class RdStatsEvent {
  const RdStatsEvent({
    required this.attendance,
    required this.type,
    required this.date,
    required this.percent,
    required this.counts,
    this.rows = const [],
  });

  final Attendance attendance;
  final AttendanceType? type;
  final DateTime date;

  /// The counted entries (chosen Register; at duties only the assigned).
  final List<PersonAttendance> rows;

  /// Termin percentage over the persons of the chosen Register.
  final int percent;
  final RdStatsCounts counts;
}

/// One Register of the period.
@immutable
class RdStatsGroup {
  const RdStatsGroup({required this.group, required this.people, required this.counts, this.months = const []});

  final Group group;

  /// Active persons of the Register with counted entries.
  final int people;
  final RdStatsCounts counts;

  /// Quote per month with entries, oldest first (the curve of the
  /// Register level).
  final List<(DateTime, int)> months;

  int get percent => counts.percent;
}

/// One active person of the period.
@immutable
class RdStatsPerson {
  const RdStatsPerson({required this.person, required this.counts});

  final Person person;
  final RdStatsCounts counts;

  int get percent => counts.percent;
}

/// Everything the Auswertung shows for one period and filter.
@immutable
class RdStatsResult {
  const RdStatsResult({
    required this.events,
    required this.average,
    required this.counts,
    required this.groups,
    required this.people,
  });

  static const empty = RdStatsResult(events: [], average: 0, counts: RdStatsCounts(), groups: [], people: []);

  /// Termine of the period, oldest first.
  final List<RdStatsEvent> events;

  /// Ø Anwesenheit: mean of the Termin percentages (Ionic stats).
  final int average;

  /// All counted entries of the period.
  final RdStatsCounts counts;

  /// Register, best first.
  final List<RdStatsGroup> groups;

  /// Active persons with counted entries, by name.
  final List<RdStatsPerson> people;

  /// Persons below [threshold] percent with at least [minEvents] counted
  /// Termine (one missed rehearsal is no trend), lowest first.
  List<RdStatsPerson> low({int threshold = 50, int minEvents = 3}) =>
      [for (final p in people) if (p.counts.total >= minEvents && p.percent < threshold) p]
        ..sort((a, b) => a.percent.compareTo(b.percent));
}

/// The one way the Auswertung counts (like the Mitglieder percentages and
/// the person page, Ionic `getModifiedPlayersForList`): only Termine of the
/// shown Terminarten; at duty Termine only assigned persons; present and
/// late count as there, with [shiftExcusedAsPresent] also a work- or
/// shift-excused absence; every other entry (also "neutral") counts as not
/// there. Termine and the Ø include everybody of the chosen Register (also
/// persons who left since, like Ionic); Register and persons only the
/// active [players] (not paused, not left).
RdStatsResult rdComputeStats({
  required List<Attendance> attendances,
  required List<PersonAttendance> personAttendances,
  required List<AttendanceType> types,
  required List<Person> players,
  required List<Group> groups,
  RdStatsFilter filter = const RdStatsFilter(),
  bool shiftExcusedAsPresent = false,
}) {
  final typeIds = rdStatsTypeIds(filter, types);
  final typeById = {for (final t in types) if (t.id != null) t.id!: t};
  final register = {for (final g in rdStatsGroups(groups)) g.id!: g};
  final chosenGroups = filter.groupIds;
  final active = {
    for (final p in players)
      if (p.id != null && !p.paused && (p.left == null || p.left!.isEmpty)) p.id!: p,
  };

  final rowsOf = <int, List<PersonAttendance>>{};
  for (final pa in personAttendances) {
    final id = pa.attendanceId;
    if (id != null) rowsOf.putIfAbsent(id, () => []).add(pa);
  }

  final events = <RdStatsEvent>[];
  var total = const RdStatsCounts();
  final perGroup = <int, RdStatsCounts>{};
  final perGroupMonth = <int, Map<DateTime, RdStatsCounts>>{};
  final peopleOfGroup = <int, Set<int>>{};
  final perPerson = <int, RdStatsCounts>{};

  for (final a in attendances) {
    final id = a.id;
    final date = DateTime.tryParse(a.date)?.toLocal();
    if (id == null || date == null || a.typeId == null || !typeIds.contains(a.typeId)) continue;
    final type = typeById[a.typeId];
    final duty = isDutyType(type);
    var counts = const RdStatsCounts();
    final counted = <PersonAttendance>[];
    for (final pa in rowsOf[id] ?? const <PersonAttendance>[]) {
      // The Register of a person: the active person's group, else the
      // group stored with the entry (persons who left since).
      final person = pa.personId == null ? null : active[pa.personId];
      final groupId = person?.instrument ?? pa.instrument;
      if (chosenGroups.isNotEmpty && !chosenGroups.contains(groupId)) continue;
      if (duty && (pa.dutyState == null || pa.dutyState!.isEmpty)) continue;
      final attended = pa.status.countsAsAttended(notes: pa.notes, shiftExcusedAsPresent: shiftExcusedAsPresent);
      counted.add(pa);
      counts = counts.add(pa.status, attended: attended);
      if (person == null) continue;
      perPerson[person.id!] = (perPerson[person.id!] ?? const RdStatsCounts()).add(pa.status, attended: attended);
      if (groupId != null && register.containsKey(groupId)) {
        perGroup[groupId] = (perGroup[groupId] ?? const RdStatsCounts()).add(pa.status, attended: attended);
        final months = perGroupMonth.putIfAbsent(groupId, () => {});
        final month = DateTime(date.year, date.month);
        months[month] = (months[month] ?? const RdStatsCounts()).add(pa.status, attended: attended);
        peopleOfGroup.putIfAbsent(groupId, () => {}).add(person.id!);
      }
    }
    // Same as Ionic `Utils.getPercentage(averagePersons(…))`; a duty Termin
    // with nobody assigned counts as 0 % (stats page, Ionic).
    events.add(RdStatsEvent(attendance: a, type: type, date: date, percent: counts.percent, counts: counts, rows: counted));
    total = RdStatsCounts(
      present: total.present + counts.present,
      late: total.late + counts.late,
      excused: total.excused + counts.excused,
      absent: total.absent + counts.absent,
      open: total.open + counts.open,
      attended: total.attended + counts.attended,
    );
  }
  events.sort((a, b) => a.date.compareTo(b.date));

  final average = events.isEmpty ? 0 : (events.fold<int>(0, (s, e) => s + e.percent) / events.length).round();
  final groupStats = [
    for (final entry in perGroup.entries)
      RdStatsGroup(
        group: register[entry.key]!,
        people: peopleOfGroup[entry.key]?.length ?? 0,
        counts: entry.value,
        months: [
          for (final m in (perGroupMonth[entry.key]!.keys.toList()..sort())) (m, perGroupMonth[entry.key]![m]!.percent),
        ],
      ),
  ]..sort((a, b) => b.percent != a.percent ? b.percent.compareTo(a.percent) : a.group.name.compareTo(b.group.name));
  final people = [
    for (final entry in perPerson.entries) RdStatsPerson(person: active[entry.key]!, counts: entry.value),
  ]..sort((a, b) => rdPersonName(a.person).toLowerCase().compareTo(rdPersonName(b.person).toLowerCase()));

  return RdStatsResult(events: events, average: average, counts: total, groups: groupStats, people: people);
}

/// "Vorname Nachname" of a person.
String rdPersonName(Person p) => '${p.firstName} ${p.lastName}'.trim();

/// Order of the Termine level.
enum RdStatsEventSort { newest, oldest, weakest, best }

/// [events] in the order [sort]; same percentages stay newest first.
List<RdStatsEvent> rdSortStatsEvents(List<RdStatsEvent> events, RdStatsEventSort sort) {
  int newest(RdStatsEvent a, RdStatsEvent b) => b.date.compareTo(a.date);
  return [...events]..sort(switch (sort) {
      RdStatsEventSort.newest => newest,
      RdStatsEventSort.oldest => (a, b) => a.date.compareTo(b.date),
      RdStatsEventSort.weakest => (a, b) => a.percent != b.percent ? a.percent.compareTo(b.percent) : newest(a, b),
      RdStatsEventSort.best => (a, b) => a.percent != b.percent ? b.percent.compareTo(a.percent) : newest(a, b),
    });
}

/// One Terminart of "Termine je Art".
@immutable
class RdStatsTypeRow {
  const RdStatsTypeRow({required this.type, required this.events, required this.average});

  final AttendanceType type;
  final int events;

  /// Mean of the Termin percentages of this Terminart.
  final int average;
}

/// The Terminarten of [events], most Termine first.
List<RdStatsTypeRow> rdStatsByType(List<RdStatsEvent> events) {
  final byType = <String, List<RdStatsEvent>>{};
  final typeOf = <String, AttendanceType>{};
  for (final e in events) {
    final t = e.type;
    if (t?.id == null) continue;
    byType.putIfAbsent(t!.id!, () => []).add(e);
    typeOf[t.id!] = t;
  }
  return [
    for (final entry in byType.entries)
      RdStatsTypeRow(
        type: typeOf[entry.key]!,
        events: entry.value.length,
        average: (entry.value.fold<int>(0, (s, e) => s + e.percent) / entry.value.length).round(),
      ),
  ]..sort((a, b) => a.events != b.events ? b.events.compareTo(a.events) : a.type.name.compareTo(b.type.name));
}

/// The period of the same length right before [start]–[end] (whole days):
/// `start` inclusive, `end` exclusive. Null for less than a week or more
/// than 400 days (no sensible comparison).
({DateTime start, DateTime end})? rdStatsPreviousPeriod(DateTime start, DateTime end) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  final days = to.difference(from).inDays + 1;
  if (days < 7 || days > 400) return null;
  return (start: DateTime(from.year, from.month, from.day - days), end: from);
}

/// Fewest Termine the period before needs for a comparison.
const rdStatsMinCompareEvents = 3;

/// The Register that lost most against [before] (at least [minDrop]
/// points), with the drop. Null without a comparison.
(RdStatsGroup, int)? rdStatsBiggestDrop(RdStatsResult now, RdStatsResult? before, {int minDrop = 5}) {
  if (before == null) return null;
  final earlier = {for (final g in before.groups) g.group.id: g.percent};
  (RdStatsGroup, int)? worst;
  for (final g in now.groups) {
    final was = earlier[g.group.id];
    if (was == null) continue;
    final drop = was - g.percent;
    if (drop >= minDrop && (worst == null || drop > worst.$2)) worst = (g, drop);
  }
  return worst;
}

/// Orders of the Personen level ("Oft abwesend" and "Oft verspätet" replace
/// Ionic's "Unentschuldigt" chart and the Top 20).
enum RdStatsPersonSort { fewest, most, absent, late, name }

/// [people] in the order [sort]; ties by name.
List<RdStatsPerson> rdSortStatsPeople(List<RdStatsPerson> people, RdStatsPersonSort sort) {
  int byName(RdStatsPerson a, RdStatsPerson b) =>
      rdPersonName(a.person).toLowerCase().compareTo(rdPersonName(b.person).toLowerCase());
  int then(int c, RdStatsPerson a, RdStatsPerson b) => c != 0 ? c : byName(a, b);
  return [...people]..sort(switch (sort) {
      RdStatsPersonSort.fewest => (a, b) => then(a.percent.compareTo(b.percent), a, b),
      RdStatsPersonSort.most => (a, b) => then(b.percent.compareTo(a.percent), a, b),
      RdStatsPersonSort.absent => (a, b) => then(b.counts.absent.compareTo(a.counts.absent), a, b),
      RdStatsPersonSort.late => (a, b) => then(b.counts.late.compareTo(a.counts.late), a, b),
      RdStatsPersonSort.name => byName,
    });
}

/// The counted entries of person [personId], one per Termin, oldest first.
List<(RdStatsEvent, PersonAttendance)> rdStatsPersonEntries(RdStatsResult result, int personId) => [
      for (final e in result.events)
        for (final pa in e.rows)
          if (pa.personId == personId) (e, pa),
    ];

/// Persons with a birthday per decade of age on [today] (start of the
/// decade, count), youngest first; empty decades between stay (like
/// Ionic's age chart).
List<(int, int)> rdStatsAgeDecades(List<Person> people, DateTime today) {
  final count = <int, int>{};
  for (final p in people) {
    final b = p.birthday == null ? null : DateTime.tryParse(p.birthday!);
    if (b == null) continue;
    final age = today.year - b.year - ((today.month < b.month || (today.month == b.month && today.day < b.day)) ? 1 : 0);
    if (age < 0) continue;
    count.update(age ~/ 10 * 10, (n) => n + 1, ifAbsent: () => 1);
  }
  if (count.isEmpty) return const [];
  final first = count.keys.reduce((a, b) => a < b ? a : b);
  final last = count.keys.reduce((a, b) => a > b ? a : b);
  return [for (var d = first; d <= last; d += 10) (d, count[d] ?? 0)];
}
