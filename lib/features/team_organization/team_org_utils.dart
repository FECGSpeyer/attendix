/// Pure helpers of the Teamorganisation (port of Ionic team-org.utils.ts,
/// tasks-tab.utils.ts, topics-tab.utils.ts, agenda-plan.helpers.ts and parts
/// of protocol.helpers.ts).
library;

import 'package:intl/intl.dart';

import '../../core/constants/enums.dart';
import '../../data/models/team_org/team_org.dart';

/// Plan field ids of agenda items are derived from the topic.
const String agendaFieldPrefix = 'agenda-';

/// Completed tasks stay in the normal lists for this many days.
const int completedTaskVisibleDays = 30;

/// Minutes per topic when neither the topic nor the type says otherwise.
const int fallbackTopicDuration = 10;

typedef PlanField = Map<String, dynamic>;

// ── Labels ─────────────────────────────────────────────────

const Map<String, String> outcomeLabels = {
  'discussed': 'Besprochen',
  'decided': 'Beschlossen',
  'postponed': 'Vertagt',
};

const Map<String, String> taskStatusLabels = {
  'open': 'Offen',
  'in_progress': 'In Arbeit',
  'completed': 'Erledigt',
};

const Map<String, String> priorityLabels = {
  'high': 'Hoch',
  'medium': 'Mittel',
  'low': 'Niedrig',
};

const Map<String, String> topicStatusLabels = {
  'open': 'Offen',
  'completed': 'Erledigt',
  'dropped': 'Verworfen',
};

// ── Roles / circle ─────────────────────────────────────────

/// The whole feature is only visible once at least one attendance type has it enabled.
bool isTeamOrgEnabled(List<ProtocolType>? types) =>
    (types ?? const []).any((t) => t.enableProtocol);

bool isTeamLeaderRole(Role? role) => role == Role.admin || role == Role.responsible;

/// Mirrors SQL in_protocol_circle: leadership always, parents and applicants
/// never, everyone else if in one of the type's groups or the type has none.
bool isInTypeCircle(ProtocolType type, Role? role, int? groupId) {
  if (!type.enableProtocol || role == null) return false;
  if (isTeamLeaderRole(role)) return true;
  if (role == Role.parent || role == Role.applicant) return false;
  final groups = type.relevantGroups ?? const [];
  return groups.isEmpty || (groupId != null && groups.contains(groupId));
}

bool isInAnyCircle(List<ProtocolType>? types, Role? role, int? groupId) =>
    (types ?? const []).any((t) => isInTypeCircle(t, role, groupId));

// ── Plan fields / TOPs ─────────────────────────────────────

String agendaFieldId(String agendaItemId) => '$agendaFieldPrefix$agendaItemId';

String? fieldAgendaItemId(PlanField f) {
  final v = f['agendaItemId'];
  return (v == null || v.toString().isEmpty) ? null : v.toString();
}

String fieldId(PlanField f) => (f['id'] ?? '').toString();
String fieldName(PlanField f) => (f['name'] ?? '').toString();
int fieldMinutes(PlanField f) => int.tryParse((f['time'] ?? '').toString()) ?? 0;
String? fieldConductor(PlanField f) {
  final c = f['conductor']?.toString();
  return (c == null || c.isEmpty) ? null : c;
}

/// Builds the plan field (TOP) for a topic.
PlanField buildAgendaField(AgendaItem item, int durationMinutes) {
  final field = <String, dynamic>{
    'id': agendaFieldId(item.id!),
    'name': item.title,
    'time': '${durationMinutes < 1 ? 1 : durationMinutes}',
    'agendaItemId': item.id,
  };
  final responsible = item.responsiblePerson.fullName;
  if (responsible.isNotEmpty) field['conductor'] = responsible;
  return field;
}

/// Inserts TOP fields at the marker (placeholder) if there is one, otherwise
/// at the end. Topics already in the plan are skipped.
List<PlanField> insertAgendaFields(List<PlanField> fields, List<PlanField> newFields) {
  final existing = fields.map(fieldAgendaItemId).whereType<String>().toSet();
  final toAdd = newFields.where((f) => !existing.contains(fieldAgendaItemId(f))).toList();
  if (toAdd.isEmpty) return [...fields];
  final markerIndex = fields.indexWhere((f) => fieldId(f) == agendaItemsPlaceholderId);
  if (markerIndex == -1) return [...fields, ...toAdd];
  return [...fields.sublist(0, markerIndex), ...toAdd, ...fields.sublist(markerIndex)];
}

/// Fields that get a section in the protocol: every plan field except the marker.
List<PlanField> protocolSections(List<PlanField>? fields) =>
    (fields ?? const []).where((f) => fieldId(f) != agendaItemsPlaceholderId).toList();

/// TOP numbers by field id, counting only agenda fields in plan order.
Map<String, int> topNumbers(List<PlanField>? fields) {
  final result = <String, int>{};
  var n = 0;
  for (final f in fields ?? const <PlanField>[]) {
    if (fieldAgendaItemId(f) != null) result[fieldId(f)] = ++n;
  }
  return result;
}

String fieldDisplayName(PlanField field, Map<String, int> numbers) {
  final n = numbers[fieldId(field)];
  return n != null ? 'TOP $n · ${fieldName(field)}' : fieldName(field);
}

/// Parses "HH:mm" or an ISO date time into a DateTime (only the time matters).
DateTime? parsePlanTime(String? start, {DateTime? day}) {
  if (start == null || start.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(start);
  if (m != null && !start.contains('T')) {
    final base = day ?? DateTime.now();
    return DateTime(base.year, base.month, base.day, int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
  return DateTime.tryParse(start)?.toLocal();
}

/// Start time (HH:mm) of every field, by field id. The marker takes no time.
Map<String, String> fieldStartTimes(String? start, List<PlanField>? fields) {
  final result = <String, String>{};
  var current = parsePlanTime(start);
  if (current == null) return result;
  final fmt = DateFormat('HH:mm');
  for (final f in fields ?? const <PlanField>[]) {
    result[fieldId(f)] = fmt.format(current!);
    if (fieldId(f) != agendaItemsPlaceholderId) {
      current = current.add(Duration(minutes: fieldMinutes(f)));
    }
  }
  return result;
}

/// End of a plan in the plan editor's format ("YYYY-MM-DDTHH:mm").
String computePlanEnd(String time, List<PlanField> fields) {
  var current = parsePlanTime(time) ?? DateTime.now();
  for (final f in fields) {
    if (fieldId(f) == agendaItemsPlaceholderId) continue;
    current = current.add(Duration(minutes: fieldMinutes(f)));
  }
  return DateFormat("yyyy-MM-dd'T'HH:mm").format(current);
}

/// Duration a topic gets in a plan: topic default → type default → 10 min.
int defaultTopicDuration(AgendaItem? item, ProtocolType? type) {
  final d = item?.defaultDuration;
  if (d != null && d > 0) return d;
  final t = type?.agendaDefaultDuration;
  if (t != null && t > 0) return t;
  return fallbackTopicDuration;
}

/// Base plan for a Termin without plan: type default plan without song placeholders.
Map<String, dynamic> initialPlan(ProtocolAttendance attendance, ProtocolType? type) {
  final defaultFields = (type?.defaultPlan?['fields'] as List?) ?? const [];
  final fields = defaultFields
      .whereType<Map>()
      .map((f) => Map<String, dynamic>.from(f))
      .where((f) => !fieldId(f).startsWith('song-placeholder-'))
      .toList();
  final planTime = type?.defaultPlan?['time']?.toString();
  final time = (planTime != null && planTime.isNotEmpty)
      ? planTime
      : (type?.startTime?.isNotEmpty == true
          ? type!.startTime!
          : (attendance.startTime?.isNotEmpty == true ? attendance.startTime! : '19:00'));
  return {'time': time, 'fields': fields, 'end': computePlanEnd(time, fields)};
}

/// Plan with the selected topics inserted (and TOPs of [removeIds] removed).
Map<String, dynamic> planWithTopics(
  ProtocolAttendance attendance,
  ProtocolType? type,
  List<({AgendaItem item, int duration})> selections, {
  List<String> removeIds = const [],
}) {
  final hasPlan = attendance.plan != null && attendance.plan!['fields'] is List;
  final base = hasPlan
      ? <String, dynamic>{...attendance.plan!, 'fields': attendance.fields}
      : initialPlan(attendance, type);
  final remove = removeIds.toSet();
  final kept = (base['fields'] as List)
      .cast<PlanField>()
      .where((f) => fieldAgendaItemId(f) == null || !remove.contains(fieldAgendaItemId(f)))
      .toList();
  final fields = insertAgendaFields(
    kept,
    selections.map((s) => buildAgendaField(s.item, s.duration)).toList(),
  );
  final time = (base['time'] ?? '19:00').toString();
  return {...base, 'fields': fields, 'end': computePlanEnd(time, fields)};
}

/// Name of the field after which new topics will be inserted (null = at the start).
String? insertAfterName(List<PlanField>? fields) {
  final list = fields ?? const <PlanField>[];
  final markerIndex = list.indexWhere((f) => fieldId(f) == agendaItemsPlaceholderId);
  final before = markerIndex == -1 ? list : list.sublist(0, markerIndex);
  for (final f in before.reversed) {
    if (!fieldId(f).contains('noteFld')) return fieldName(f);
  }
  return null;
}

/// Upcoming Termine of protocol-enabled types, soonest first.
List<ProtocolAttendance> upcomingProtocolAttendances(
  List<ProtocolAttendance>? attendances,
  List<ProtocolType>? types, {
  DateTime? now,
}) {
  final enabled = (types ?? const []).where((t) => t.enableProtocol).map((t) => t.id).toSet();
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final list = (attendances ?? const <ProtocolAttendance>[])
      .where((a) => enabled.contains(a.typeId))
      .where((a) {
        final d = DateTime.tryParse(a.date)?.toLocal();
        return d != null && !d.isBefore(today);
      })
      .toList();
  list.sort((a, b) => (DateTime.tryParse(a.date) ?? n).compareTo(DateTime.tryParse(b.date) ?? n));
  return list;
}

/// Agenda fields (TOPs) of a plan with their total duration in minutes.
({List<PlanField> tops, int minutes}) planTops(List<PlanField>? fields) {
  final tops = (fields ?? const <PlanField>[]).where((f) => fieldAgendaItemId(f) != null).toList();
  return (tops: tops, minutes: tops.fold(0, (s, f) => s + fieldMinutes(f)));
}

// ── Topics ─────────────────────────────────────────────────

/// Topic ids whose most recent result in a protocol was "postponed".
/// Protocols must be sorted newest first.
Set<String> postponedAgendaItemIds(List<Protocol> protocols) {
  final latest = <String, String>{};
  for (final p in protocols) {
    for (final entry in p.outcomes.entries) {
      if (!entry.key.startsWith(agendaFieldPrefix)) continue;
      final id = entry.key.substring(agendaFieldPrefix.length);
      latest.putIfAbsent(id, () => entry.value.toString());
    }
  }
  return latest.entries.where((e) => e.value == 'postponed').map((e) => e.key).toSet();
}

const Map<String, int> _prio = {'high': 0, 'medium': 1, 'low': 2};

/// Open topics, postponed first, then by priority. Pending/rejected suggestions excluded.
List<AgendaItem> sortTopicsForPlanning(List<AgendaItem> items, Set<String> postponed) {
  final list = items
      .where((i) => i.status == 'open' && (i.proposalStatus == null || i.proposalStatus == 'accepted'))
      .toList();
  list.sort((a, b) {
    final pa = postponed.contains(a.id) ? 0 : 1;
    final pb = postponed.contains(b.id) ? 0 : 1;
    if (pa != pb) return pa - pb;
    final pr = (_prio[a.priority] ?? 1) - (_prio[b.priority] ?? 1);
    if (pr != 0) return pr;
    return a.title.compareTo(b.title);
  });
  return list;
}

/// Leadership's topic buckets. Rejected suggestions are left out.
({List<AgendaItem> pending, List<AgendaItem> open, List<AgendaItem> done}) splitTopics(
    List<AgendaItem>? items) {
  final pending = <AgendaItem>[];
  final open = <AgendaItem>[];
  final done = <AgendaItem>[];
  for (final item in items ?? const <AgendaItem>[]) {
    if (item.proposalStatus == 'pending') {
      pending.add(item);
    } else if (item.proposalStatus == 'rejected') {
      continue;
    } else if (item.status == 'open') {
      open.add(item);
    } else {
      done.add(item);
    }
  }
  pending.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
  done.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
  return (pending: pending, open: open, done: done);
}

/// Label of a member's own suggestion.
String suggestionStatusLabel(AgendaItem item) {
  switch (item.proposalStatus) {
    case 'accepted':
      return 'Übernommen';
    case 'rejected':
      return 'Abgelehnt';
    default:
      return 'Wartet';
  }
}

/// "heute", "gestern", "vor 3 Tagen" – or the date for anything older than two weeks.
String relativeDay(String? date, {DateTime? now}) {
  if (date == null) return '';
  final d = DateTime.tryParse(date)?.toLocal();
  if (d == null) return '';
  final n = now ?? DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days <= 0) return 'heute';
  if (days == 1) return 'gestern';
  if (days < 14) return 'vor $days Tagen';
  return DateFormat('dd.MM.yyyy').format(d);
}

// ── Tasks ──────────────────────────────────────────────────

/// Today as YYYY-MM-DD in local time.
String localToday([DateTime? now]) => DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());

bool isTaskOverdue(TeamTask task, String today) =>
    task.status != 'completed' && task.dueDate != null && task.dueDate!.compareTo(today) < 0;

bool isCompletedTaskArchived(TeamTask task, {DateTime? now}) {
  if (task.status != 'completed') return false;
  final doneAt = DateTime.tryParse(task.completedAt ?? task.updatedAt ?? '');
  if (doneAt == null) return false;
  return (now ?? DateTime.now()).difference(doneAt).inDays >= completedTaskVisibleDays;
}

class TaskGroup {
  TaskGroup(this.key, this.label, this.tasks);
  final String key;
  final String label;
  final List<TeamTask> tasks;
}

const Map<String, String> _taskGroupLabels = {
  'overdue': 'Überfällig',
  'week': 'Diese Woche',
  'later': 'Später',
  'none': 'Ohne Datum',
  'done': 'Erledigt',
};

/// Groups tasks: overdue, next 7 days, later, without date, completed.
List<TaskGroup> groupTasksByDue(List<TeamTask> tasks, String today,
    {bool includeArchived = false, DateTime? now}) {
  final todayDate = DateTime.parse(today);
  final weekEnd = localToday(todayDate.add(const Duration(days: 7)));
  final buckets = <String, List<TeamTask>>{
    'overdue': [], 'week': [], 'later': [], 'none': [], 'done': [],
  };
  for (final t in tasks) {
    if (t.status == 'completed') {
      if (includeArchived || !isCompletedTaskArchived(t, now: now)) buckets['done']!.add(t);
    } else if (t.dueDate == null) {
      buckets['none']!.add(t);
    } else if (t.dueDate!.compareTo(today) < 0) {
      buckets['overdue']!.add(t);
    } else if (t.dueDate!.compareTo(weekEnd) <= 0) {
      buckets['week']!.add(t);
    } else {
      buckets['later']!.add(t);
    }
  }
  int byDue(TeamTask a, TeamTask b) {
    final c = (a.dueDate ?? '').compareTo(b.dueDate ?? '');
    return c != 0 ? c : a.title.compareTo(b.title);
  }

  buckets['overdue']!.sort(byDue);
  buckets['week']!.sort(byDue);
  buckets['later']!.sort(byDue);
  buckets['none']!.sort((a, b) => a.title.compareTo(b.title));
  buckets['done']!.sort((a, b) =>
      (b.completedAt ?? b.updatedAt ?? '').compareTo(a.completedAt ?? a.updatedAt ?? ''));
  return buckets.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => TaskGroup(e.key, _taskGroupLabels[e.key]!, e.value))
      .toList();
}

class TaskPersonChip {
  TaskPersonChip({required this.personId, required this.name, required this.label, required this.openCount});
  final int personId;
  final String name;
  final String label;
  final int openCount;
}

/// One chip per person with open tasks, sorted by name.
List<TaskPersonChip> taskPersonChips(List<TeamTask> tasks) {
  final byId = <int, ({String name, String first, String last, int count})>{};
  for (final t in tasks) {
    final pid = t.responsiblePersonId;
    if (t.status == 'completed' || pid == null) continue;
    final existing = byId[pid];
    if (existing != null) {
      byId[pid] = (name: existing.name, first: existing.first, last: existing.last, count: existing.count + 1);
      continue;
    }
    final p = t.responsiblePerson;
    final name = p.fullName.isNotEmpty ? p.fullName : 'Unbekannt';
    final first = (p?.firstName?.trim().isNotEmpty ?? false) ? p!.firstName!.trim() : name;
    byId[pid] = (name: name, first: first, last: p?.lastName?.trim() ?? '', count: 1);
  }
  final firstCount = <String, int>{};
  for (final c in byId.values) {
    firstCount[c.first] = (firstCount[c.first] ?? 0) + 1;
  }
  final chips = byId.entries.map((e) {
    final c = e.value;
    final label = (firstCount[c.first] ?? 0) > 1 && c.last.isNotEmpty ? '${c.first} ${c.last[0]}.' : c.first;
    return TaskPersonChip(personId: e.key, name: c.name, label: label, openCount: c.count);
  }).toList();
  chips.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return chips;
}

/// Filter: 'all', 'mine' or a person id (int).
List<TeamTask> filterTasks(List<TeamTask> tasks, Object filter, int? myPersonId) {
  if (filter == 'all') return tasks;
  final personId = filter == 'mine' ? myPersonId : filter as int?;
  if (personId == null) return [];
  return tasks.where((t) => t.responsiblePersonId == personId).toList();
}

const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// "Di, 28.10." / "seit 12.10." / "Heute" / "Morgen".
String formatTaskDue(TeamTask task, String today) {
  final due = task.dueDate;
  if (due == null) return '';
  final date = DateTime.tryParse(due);
  if (date == null) return due;
  final sameYear = due.substring(0, 4) == today.substring(0, 4);
  final dayMonth =
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${sameYear ? '' : date.year}';
  if (task.status != 'completed' && due.compareTo(today) < 0) return 'seit $dayMonth';
  if (due == today) return 'Heute';
  final tomorrow = localToday(DateTime.parse(today).add(const Duration(days: 1)));
  if (due == tomorrow) return 'Morgen';
  return '${_weekdays[date.weekday - 1]}, $dayMonth';
}

/// "Do, 30.10.2026".
String formatLongDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';
  final d = DateTime.tryParse(isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate);
  if (d == null) return isoDate;
  return '${_weekdays[d.weekday - 1]}, ${DateFormat('dd.MM.yyyy').format(d)}';
}

/// "Di, 21.10." for an attendance date.
String formatShortWeekdayDate(String? isoDate) {
  final d = DateTime.tryParse(isoDate ?? '')?.toLocal();
  if (d == null) return '';
  return '${_weekdays[d.weekday - 1]}, ${DateFormat('dd.MM.').format(d)}';
}

String toggledStatus(String status) => status == 'completed' ? 'open' : 'completed';

/// Whether the (new) responsible person must be notified.
bool needsAssignmentNotice(int? before, int? after) => after != null && after != before;

/// True when a published protocol was changed afterwards.
bool isEditedAfterPublish(Protocol? p) {
  if (p == null || p.status != 'published' || p.publishedAt == null || p.updatedAt == null) return false;
  final pub = DateTime.tryParse(p.publishedAt!);
  final upd = DateTime.tryParse(p.updatedAt!);
  if (pub == null || upd == null) return false;
  return upd.difference(pub).inSeconds > 60;
}

/// Title of an attendance: typeInfo, otherwise the type name, otherwise "Termin".
String attendanceTitle(String? typeInfo, ProtocolType? type) {
  if (typeInfo != null && typeInfo.trim().isNotEmpty) return typeInfo;
  if (type != null && type.name.isNotEmpty) return type.name;
  return 'Termin';
}

// ── Protocol helpers ───────────────────────────────────────

bool isPresentStatus(int status) =>
    status == AttendanceStatus.present.value ||
    status == AttendanceStatus.late.value ||
    status == AttendanceStatus.lateExcused.value;

class PublishSummary {
  final List<String> decided = [];
  final List<String> discussed = [];
  final List<String> postponed = [];
  final List<String> withoutOutcome = [];
  final List<String> withoutNotes = [];
  int taskCount = 0;
  List<String> taskOwners = [];
  int recipientCount = 0;
}

/// Open topics decided/discussed in this protocol (offered to be closed on publish).
class TopicClosure {
  TopicClosure({required this.agendaItemId, required this.title, required this.outcome, required this.close});
  final String agendaItemId;
  final String title;
  final String outcome;
  bool close;
}

List<TopicClosure> topicClosureCandidates(
  List<({String id, String name, String? agendaItemId})> sections,
  Map<String, dynamic> outcomes,
  List<AgendaItem> items,
) {
  final open = items.where((i) => i.status == 'open').map((i) => i.id).toSet();
  final result = <TopicClosure>[];
  for (final s in sections) {
    final outcome = outcomes[s.id]?.toString();
    if (s.agendaItemId == null || !open.contains(s.agendaItemId)) continue;
    if (outcome != 'decided' && outcome != 'discussed') continue;
    if (result.any((r) => r.agendaItemId == s.agendaItemId)) continue;
    result.add(TopicClosure(
      agendaItemId: s.agendaItemId!,
      title: s.name,
      outcome: outcome!,
      close: outcome == 'decided',
    ));
  }
  return result;
}

/// "Anna", "Anna und Jonas", "Anna, Jonas und Paul".
String joinNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  return '${names.sublist(0, names.length - 1).join(', ')} und ${names.last}';
}

/// Case-insensitive search; every word of the query must match.
bool matchesSearch(String query, List<String?> texts) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final haystack = texts.whereType<String>().join(' ').toLowerCase();
  return words.every(haystack.contains);
}

const _months = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// Groups items (already sorted) by month of their date, keeping the order.
List<({String key, String label, List<T> items})> groupByMonth<T>(
    List<T> items, String? Function(T) dateOf) {
  final groups = <({String key, String label, List<T> items})>[];
  for (final item in items) {
    final d = DateTime.tryParse(dateOf(item) ?? '')?.toLocal();
    final key = d == null ? 'none' : '${d.year}-${d.month}';
    var idx = groups.indexWhere((g) => g.key == key);
    if (idx == -1) {
      groups.add((key: key, label: d == null ? 'Ohne Datum' : monthLabel(d), items: <T>[]));
      idx = groups.length - 1;
    }
    groups[idx].items.add(item);
  }
  return groups;
}

/// Running section of a plan at [now] (null before start / after end).
({String fieldId, int remainingMinutes})? liveSection(
    List<PlanField> fields, DateTime? start, DateTime now) {
  if (start == null || fields.isEmpty || now.isBefore(start)) return null;
  var end = start;
  for (final f in fields) {
    if (fieldId(f) == agendaItemsPlaceholderId) continue;
    final minutes = fieldMinutes(f);
    if (minutes <= 0) continue;
    end = end.add(Duration(minutes: minutes));
    if (now.isBefore(end)) {
      final remaining = (end.difference(now).inSeconds / 60).ceil();
      return (fieldId: fieldId(f), remainingMinutes: remaining < 1 ? 1 : remaining);
    }
  }
  return null;
}
