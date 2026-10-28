import '../../data/models/attendance/attendance.dart';
import '../../data/models/instrument/instrument.dart';
import '../../data/models/person/person.dart';
import 'dashboard_logic.dart' show attendancePercentage;
import 'duty_utils.dart' show averagePersons;

/// Average attendance percentage over all attendances whose type has
/// `include_in_average = true`. Attendances with an unknown type are excluded
/// (Ionic: `type?.include_in_average`).
int calculateAveragePercentage(
  List<Attendance> attendances,
  List<AttendanceType> types,
) {
  final includedTypeIds = types
      .where((t) => t.includeInAverage && t.id != null)
      .map((t) => t.id!)
      .toSet();
  final relevant = attendances
      .where((a) => a.typeId != null && includedTypeIds.contains(a.typeId))
      .toList();
  if (relevant.isEmpty) return 0;
  final sum = relevant.fold<double>(0, (acc, a) => acc + (a.percentage ?? 0));
  return (sum / relevant.length).round();
}

// ---------------------------------------------------------------------------
// LOGIC_SETTINGS: Ionic stats.page.ts parity helpers
// ---------------------------------------------------------------------------

/// Ionic stats.page.ts:ngOnInit — every Termin's percentage is recomputed
/// from its person attendances via `Utils.getPercentage(averagePersons(...),
/// tenant.shift_excused_as_present)`. Ionic never writes
/// `attendance.percentage`, so the stored value must not be used.
List<Attendance> recomputeAttendancePercentages(
  List<Attendance> attendances,
  List<PersonAttendance> personAttendances,
  List<AttendanceType> types, {
  bool shiftExcusedAsPresent = false,
}) {
  final byAttendance = <int, List<PersonAttendance>>{};
  for (final pa in personAttendances) {
    final id = pa.attendanceId;
    if (id == null) continue;
    byAttendance.putIfAbsent(id, () => []).add(pa);
  }
  final typeById = {
    for (final t in types)
      if (t.id != null) t.id!: t,
  };
  return attendances.map((a) {
    final persons = averagePersons(byAttendance[a.id], typeById[a.typeId]);
    final perc = attendancePercentage(
      persons,
      shiftExcusedAsPresent: shiftExcusedAsPresent,
    );
    return a.copyWith(percentage: perc.toDouble());
  }).toList();
}

/// Ionic stats.page.ts:initInstrumentBarChart — attendance rate per group
/// (`player.instrument` → group). Only person attendances of ACTIVE people
/// (not left, not paused) whose group exists are counted; groups without
/// entries are dropped; percentage rounded; sorted descending.
List<({String name, int percentage, int total})> computeGroupAttendanceRates(
  List<PersonAttendance> personAttendances,
  List<Person> activePlayers,
  List<Group> groups,
) {
  final stats = <int, ({String name, int present, int total})>{};
  for (final g in groups) {
    if (g.id != null) stats[g.id!] = (name: g.name, present: 0, total: 0);
  }
  final playerGroup = <int, int?>{
    for (final p in activePlayers)
      if (p.id != null) p.id!: p.instrument,
  };
  for (final pa in personAttendances) {
    final pid = pa.personId;
    if (pid == null || !playerGroup.containsKey(pid)) continue;
    final gid = playerGroup[pid];
    final current = gid == null ? null : stats[gid];
    if (current == null) continue;
    stats[gid!] = (
      name: current.name,
      present: current.present + (pa.status.countsAsPresent ? 1 : 0),
      total: current.total + 1,
    );
  }
  final result = stats.values
      .where((g) => g.total > 0)
      .map((g) => (
            name: g.name,
            percentage: (g.present / g.total * 100).round(),
            total: g.total,
          ))
      .toList()
    ..sort((a, b) => b.percentage.compareTo(a.percentage));
  return result;
}

/// Full years between [birthday] and [now] (dayjs `diff(..., 'year')`).
int _statsAgeInYears(DateTime birthday, DateTime now) {
  return now.year -
      birthday.year -
      ((now.month < birthday.month ||
              (now.month == birthday.month && now.day < birthday.day))
          ? 1
          : 0);
}

/// Ionic stats.page.ts:initAvgAgePerInstrumentChart — rounded average age
/// per group of active players with birthday and an existing group;
/// sorted by average age descending.
List<({String name, int avgAge, int count})> computeAverageAgePerGroup(
  List<Person> activePlayers,
  List<Group> groups, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final ages = <int, ({String name, List<int> ages})>{};
  for (final g in groups) {
    if (g.id != null) ages[g.id!] = (name: g.name, ages: <int>[]);
  }
  for (final p in activePlayers) {
    final birthday = p.birthday == null ? null : DateTime.tryParse(p.birthday!);
    if (birthday == null || p.instrument == null) continue;
    ages[p.instrument!]?.ages.add(_statsAgeInYears(birthday, today));
  }
  final result = ages.values
      .where((g) => g.ages.isNotEmpty)
      .map((g) => (
            name: g.name,
            avgAge: (g.ages.reduce((a, b) => a + b) / g.ages.length).round(),
            count: g.ages.length,
          ))
      .toList()
    ..sort((a, b) => b.avgAge.compareTo(a.avgAge));
  return result;
}
