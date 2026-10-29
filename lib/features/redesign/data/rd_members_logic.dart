import '../../../core/constants/enums.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/player_absence/player_absence.dart';
import '../../attendance/presentation/widgets/attendance_detail/attendance_grid.dart'
    show sortPersonsByGroup, mainGroupIdOf;
import 'rd_dates.dart';

/// REDESIGN: pure logic of the Mitglieder tab (canvas "Menschen",
/// "PersonDetail").

/// The three lists of the tab.
enum RdMembersFilter { active, paused, pending }

/// One section of the list: a register (group category) or, without
/// categories, a group.
class RdMemberSection {
  const RdMemberSection({
    required this.title,
    required this.people,
    this.average,
    this.isRegister = false,
  });

  final String title;
  final List<Person> people;

  /// Ø attendance of the section's persons that have a percentage.
  final int? average;

  /// The section is a register (group category): rows show the group.
  final bool isRegister;
}

/// Persons in group order, split into registers (group categories) or,
/// without categories, groups. Leaders first like the old list.
List<RdMemberSection> rdMemberSections(
  List<Person> persons, {
  required List<Group> groups,
  required Map<int, int> percentages,
  required String noGroupLabel,
}) {
  final byId = {for (final g in groups) g.id: g};
  final sorted = sortPersonsByGroup(
    persons,
    groups: groups,
    mainGroupId: mainGroupIdOf(groups),
  );
  final useRegisters = groups.any((g) => g.categoryData != null);

  final keys = <String>[];
  final titles = <String, String>{};
  final members = <String, List<Person>>{};
  for (final p in sorted) {
    final group = byId[p.instrument];
    final category = useRegisters ? group?.categoryData : null;
    final key = category != null ? 'c${category.id}' : 'g${p.instrument}';
    final title = category?.name ?? p.groupName ?? group?.name ?? noGroupLabel;
    if (!members.containsKey(key)) {
      keys.add(key);
      titles[key] = title;
      members[key] = [];
    }
    members[key]!.add(p);
  }

  return [
    for (final key in keys)
      RdMemberSection(
        title: titles[key]!,
        people: _leadersFirst(members[key]!),
        average: rdAveragePercent(members[key]!, percentages),
        isRegister: key.startsWith('c'),
      ),
  ];
}

/// Leaders on top, otherwise the given order (stable).
List<Person> _leadersFirst(List<Person> people) => [
      ...people.where((p) => p.isLeader),
      ...people.where((p) => !p.isLeader),
    ];

int? rdAveragePercent(List<Person> people, Map<int, int> percentages) {
  final values = [
    for (final p in people)
      if (p.id != null && percentages[p.id] != null) percentages[p.id]!,
  ];
  if (values.isEmpty) return null;
  return (values.reduce((a, b) => a + b) / values.length).round();
}

/// Search over name, group and register.
bool rdPersonMatches(Person p, String query, {String? register}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = [p.firstName, p.lastName, '${p.firstName} ${p.lastName}', p.groupName ?? '', register ?? '']
      .join(' ')
      .toLowerCase();
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Days until the next birthday (0 = today), or null without a birthday.
int? rdDaysToBirthday(String? birthday, {DateTime? now}) {
  final b = DateTime.tryParse(birthday ?? '');
  if (b == null) return null;
  final today = _day(now ?? DateTime.now());
  var next = DateTime(today.year, b.month, b.day);
  // 29 February in other years: 1 March (DateTime rolls over).
  if (next.isBefore(today)) next = DateTime(today.year + 1, b.month, b.day);
  return rdDaysBetween(today, next);
}

/// The planned absence of [personId] running today, else the next one
/// starting within [aheadDays].
PlayerAbsence? rdCurrentAbsence(
  List<PlayerAbsence> absences,
  int personId, {
  DateTime? now,
  int aheadDays = 7,
}) {
  final today = _key(_day(now ?? DateTime.now()));
  final limit = _key(rdAddDays(now ?? DateTime.now(), aheadDays));
  PlayerAbsence? next;
  for (final a in absences) {
    if (a.personId != personId) continue;
    final from = a.fromDate.length >= 10 ? a.fromDate.substring(0, 10) : a.fromDate;
    final until = a.untilDate.length >= 10 ? a.untilDate.substring(0, 10) : a.untilDate;
    if (from.compareTo(today) <= 0 && until.compareTo(today) >= 0) return a;
    if (from.compareTo(today) > 0 && from.compareTo(limit) <= 0) {
      if (next == null || from.compareTo(next.fromDate) < 0) next = a;
    }
  }
  return next;
}

/// Statuses of the last [count] past Termine from the person history rows
/// (newest first, as personHistoryProvider returns them), oldest first.
List<AttendanceStatus> rdLastStatuses(List<Map<String, dynamic>> history, {int count = 10}) {
  final rows = history.where((h) => h['status'] is int).take(count).toList();
  return [for (final h in rows.reversed) AttendanceStatus.fromValue(h['status'] as int)];
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
