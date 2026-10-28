import 'dart:math';

import 'package:intl/intl.dart';

import '../../data/models/plan/plan.dart';
import '../../features/team_organization/team_org_utils.dart' as team_org;
import '../../l10n/l10n.dart';

/// Helpers for Ablaufpläne, ported from Ionic `utilities/plan-days.ts` and
/// `utilities/plan-groups.ts`.
///
/// `plan.fields` stays a flat list. A Programmblock head (`isGroup`) stores
/// `time: '0'` and its Unterpunkte follow right after it with
/// `groupId` = head id. Because the head counts 0 min, everything that simply
/// sums `field.time` keeps computing the right start times.
class PlanUtils {
  PlanUtils._();

  static const String groupFieldPrefix = 'grpFld';
  static const String agendaPlaceholderId = 'agenda-items-placeholder';
  static const String songPlaceholderPrefix = 'song-placeholder-';

  static final _random = Random.secure();

  /// Short random id (Ionic: `crypto.randomUUID().replace(/-/g, '').slice(0, n)`).
  static String randomKey([int length = 8]) {
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// UUID v4 style id.
  static String uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ---------------------------------------------------------------------------
  // Field kinds
  // ---------------------------------------------------------------------------

  static bool isNote(PlanField f) => f.id.contains('noteFld') || f.isNote;
  static bool isGroupHead(PlanField? f) => f?.isGroup ?? false;
  static bool isAgendaPlaceholder(PlanField f) => f.id == agendaPlaceholderId;

  static int minutesOf(PlanField f) => int.tryParse(f.time.trim()) ?? 0;

  /// Minutes a field takes in the running total (heads take none).
  static int fieldMinutes(PlanField f) => isGroupHead(f) ? 0 : minutesOf(f);

  // ---------------------------------------------------------------------------
  // Programmblöcke
  // ---------------------------------------------------------------------------

  static PlanField newGroupHead(String name, {String? conductor, String? info}) {
    return PlanField(
      id: '$groupFieldPrefix-${uuid()}',
      name: name,
      conductor: conductor ?? '',
      info: (info == null || info.isEmpty) ? null : info,
      time: '0',
      isGroup: true,
    );
  }

  static List<PlanField> childrenOf(List<PlanField> fields, String headId) =>
      fields.where((f) => f.groupId == headId).toList();

  static int groupDuration(List<PlanField> fields, String headId) =>
      childrenOf(fields, headId).fold(0, (sum, f) => sum + minutesOf(f));

  /// Minutes shown for a field: a block head shows the sum of its Unterpunkte.
  static int displayMinutes(PlanField f, List<PlanField> fields) =>
      isGroupHead(f) ? groupDuration(fields, f.id) : minutesOf(f);

  /// Index of the last field of the block (the head itself when empty).
  static int lastIndexOfGroup(List<PlanField> fields, String headId) {
    final head = fields.indexWhere((f) => f.id == headId);
    var last = head;
    for (var i = head + 1; i < fields.length && fields[i].groupId == headId; i++) {
      last = i;
    }
    return last;
  }

  /// Restores the block invariants: heads take 0 min and have no groupId,
  /// Unterpunkte sit contiguously right after their head.
  static List<PlanField> normalizeGroups(List<PlanField> fields) {
    String? current;
    final result = <PlanField>[];
    for (var field in fields) {
      if (isGroupHead(field)) {
        field = field.copyWith(time: '0', groupId: null);
        current = field.id;
        result.add(field);
        continue;
      }
      if (field.groupId != null && field.groupId != current) {
        field = field.copyWith(groupId: null);
      }
      if (field.groupId == null) current = null;
      result.add(field);
    }
    return result;
  }

  /// Removes the head; its Unterpunkte stay as normal fields.
  static List<PlanField> dissolveGroup(List<PlanField> fields, String headId) {
    return fields
        .where((f) => f.id != headId)
        .map((f) => f.groupId == headId ? f.copyWith(groupId: null) : f)
        .toList();
  }

  /// Removes the head together with its Unterpunkte.
  static List<PlanField> deleteGroup(List<PlanField> fields, String headId) =>
      fields.where((f) => f.id != headId && f.groupId != headId).toList();

  /// Inserts a new Unterpunkt at the end of the block.
  static List<PlanField> addSubItem(List<PlanField> fields, String headId, PlanField item) {
    final at = lastIndexOfGroup(fields, headId) + 1;
    final result = [...fields];
    result.insert(at, item.copyWith(groupId: headId));
    return result;
  }

  /// Indenting needs a block right above; any Unterpunkt can be moved out.
  static bool canIndent(List<PlanField> fields, int index) {
    if (index < 0 || index >= fields.length) return false;
    final field = fields[index];
    if (isGroupHead(field) || isAgendaPlaceholder(field)) return false;
    if (field.groupId != null) return true;
    if (index == 0) return false;
    final prev = fields[index - 1];
    return isGroupHead(prev) || prev.groupId != null;
  }

  /// Ein-/Ausrücken of a field.
  static List<PlanField> toggleIndent(List<PlanField> fields, int index) {
    final result = [...fields];
    final field = result[index];
    if (field.groupId != null) {
      final groupId = field.groupId!;
      result.removeAt(index);
      result.insert(lastIndexOfGroup(result, groupId) + 1, field.copyWith(groupId: null));
    } else {
      final prev = result[index - 1];
      result[index] = field.copyWith(groupId: isGroupHead(prev) ? prev.id : prev.groupId);
    }
    return normalizeGroups(result);
  }

  /// Moves a field from [from] to [to] (indexes in the full list, `to` is the
  /// final position). A head moves together with its Unterpunkte. A normal
  /// field joins a block when dropped right below an open head or between two
  /// Unterpunkte of the same block; otherwise it becomes a normal field.
  ///
  /// With [overrideGroup] the moved (non-head) field joins [joinGroup]
  /// (or leaves any block when it is null) regardless of its neighbours.
  static List<PlanField> moveField(
    List<PlanField> fields,
    int from,
    int to, {
    bool overrideGroup = false,
    String? joinGroup,
  }) {
    if (from < 0 || from >= fields.length) return fields;
    final moved = fields[from];

    if (isGroupHead(moved)) {
      final block = [moved, ...childrenOf(fields, moved.id)];
      final rows = [...fields]..removeAt(from);
      final cut = to.clamp(0, rows.length);
      final rest = rows.where((f) => f.groupId != moved.id).toList();
      var pos = rows.sublist(0, cut).where((f) => f.groupId != moved.id).length;
      // Never land inside another block: move behind its last Unterpunkt.
      while (pos > 0 &&
          pos < rest.length &&
          rest[pos].groupId != null &&
          (rest[pos - 1].groupId == rest[pos].groupId || rest[pos - 1].id == rest[pos].groupId)) {
        pos++;
      }
      rest.insertAll(pos, block);
      return normalizeGroups(rest);
    }

    final rows = [...fields]..removeAt(from);
    final insertAt = to.clamp(0, rows.length);
    rows.insert(insertAt, moved);
    final prev = insertAt > 0 ? rows[insertAt - 1] : null;
    final next = insertAt + 1 < rows.length ? rows[insertAt + 1] : null;
    String? group;
    if (prev != null && isGroupHead(prev)) {
      group = prev.id;
    } else if (prev?.groupId != null &&
        (next?.groupId == prev!.groupId || moved.groupId == prev.groupId)) {
      group = prev.groupId;
    }
    if (overrideGroup) group = joinGroup;
    rows[insertAt] = moved.copyWith(groupId: group);
    return normalizeGroups(rows);
  }

  /// Copies a block (head + Unterpunkte) with fresh ids.
  static List<PlanField> cloneBlock(List<PlanField> fields) {
    final head = fields.where(isGroupHead).firstOrNull;
    if (head == null) return [...fields];
    final copy = newGroupHead(head.name, conductor: head.conductor, info: head.info);
    return [
      copy,
      ...fields.where((f) => f.groupId == head.id).map((f) => f.copyWith(
            // Song fields are looked up by their id (= song id), so they keep it.
            id: f.songId != null || f.id.startsWith('noteFld') ? f.id : 'fld-${uuid()}',
            groupId: copy.id,
          )),
    ];
  }

  static PlanBlockTemplate blockTemplateFrom(List<PlanField> fields, String headId) {
    final head = fields.firstWhere((f) => f.id == headId);
    final block = cloneBlock([head, ...childrenOf(fields, headId)]
        .map((f) => f.copyWith(agendaItemId: null))
        .toList());
    return PlanBlockTemplate(id: uuid(), name: head.name, fields: block);
  }

  static int templateMinutes(PlanBlockTemplate tpl) {
    final head = tpl.fields.where(isGroupHead).firstOrNull;
    return head == null ? 0 : groupDuration(tpl.fields, head.id);
  }

  // ---------------------------------------------------------------------------
  // Times
  // ---------------------------------------------------------------------------

  /// Parses `HH:mm` or an ISO string (`YYYY-MM-DDTHH:mm`) into minutes of day.
  static int? parseTimeToMinutes(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim();
    final iso = DateTime.tryParse(v);
    if (iso != null && v.contains('T')) {
      return iso.hour * 60 + iso.minute;
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(v);
    if (match != null) {
      return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    }
    return null;
  }

  static String formatMinutes(int minutes) {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// "HH:mm" of a stored time string.
  static String formatTime(String? value) {
    final m = parseTimeToMinutes(value);
    return m == null ? '' : formatMinutes(m);
  }

  /// Start minutes of the field at [index].
  static int startMinutesAt(int startMinutes, List<PlanField> fields, int index) {
    var minutes = startMinutes;
    for (var i = 0; i < index && i < fields.length; i++) {
      minutes += minutesOf(fields[i]);
    }
    return minutes;
  }

  static int totalMinutes(List<PlanField> fields) =>
      fields.fold(0, (s, f) => s + minutesOf(f));

  /// End time (HH:mm) of a plan.
  static String computeEnd(String start, List<PlanField> fields) {
    final s = parseTimeToMinutes(start);
    if (s == null) return '';
    return formatMinutes(s + totalMinutes(fields));
  }

  /// Ionic `calculateEnd`: end as "YYYY-MM-DDTHH:mm" (stored in `plan.end`).
  ///
  /// [start] is "HH:mm" (then today's date is used, like `dayjs().hour().minute()`)
  /// or an ISO date time. Readers ([parseTimeToMinutes], [formatTime]) accept both.
  static String computeEndIso(String start, List<PlanField> fields, {DateTime? now}) {
    DateTime? base;
    if (start.contains('T')) {
      final iso = DateTime.tryParse(start.trim());
      if (iso != null) base = DateTime(iso.year, iso.month, iso.day, iso.hour, iso.minute);
    }
    if (base == null) {
      final m = parseTimeToMinutes(start);
      if (m == null) return '';
      final today = now ?? DateTime.now();
      base = DateTime(today.year, today.month, today.day, m ~/ 60, m % 60);
    }
    final end = base.add(Duration(minutes: totalMinutes(fields)));
    return DateFormat("yyyy-MM-dd'T'HH:mm").format(end);
  }

  /// Ionic `planning.page validate`: a start time, at least one field and a
  /// duration on every field (`every(field => field.time)`).
  static PlanValidation validate(String time, List<PlanField> fields) {
    if (time.isEmpty || fields.isEmpty) return PlanValidation.noFields;
    if (!fields.every((f) => f.time.isNotEmpty)) return PlanValidation.missingTime;
    return PlanValidation.ok;
  }

  /// TOP numbers by field id (Ionic `topNumbers`, via team_org_utils).
  static Map<String, int> topNumbers(List<PlanField> fields) =>
      team_org.topNumbers(fields.map((f) => f.toJson()).toList());

  /// "TOP n · Titel" for agenda fields, otherwise the name (Ionic `fieldDisplayName`).
  static String fieldDisplayName(PlanField field, Map<String, int> numbers) =>
      team_org.fieldDisplayName(field.toJson(), numbers);

  /// "10:37 – 10:55" for a block head.
  static String groupRange(int startMinutes, List<PlanField> fields, int index) {
    final head = fields[index];
    final start = startMinutesAt(startMinutes, fields, index);
    return '${formatMinutes(start)} – ${formatMinutes(start + groupDuration(fields, head.id))}';
  }

  // ---------------------------------------------------------------------------
  // Several plans per Termin (plan-days.ts)
  // ---------------------------------------------------------------------------

  static List<Plan> allPlans(PlanAttendance? att) {
    if (att?.plan == null) return [];
    return [att!.plan!, ...(att.extraPlans ?? const <Plan>[])];
  }

  static bool isMultiDay(PlanAttendance? att) => (att?.durationDays ?? 1) > 1;

  static int? planDay(PlanAttendance att, List<Plan> plans, int index) {
    if (index < plans.length && plans[index].day != null) return plans[index].day;
    if (index == 0 && isMultiDay(att)) return 0;
    return null;
  }

  static DateTime? _date(String date) => DateTime.tryParse(date);

  static String dayLabel(PlanAttendance att, int day) {
    final d = _date(att.date);
    if (d == null) return l10nWithoutContext.coreFlutterPlanDayN(day + 1);
    final date = d.add(Duration(days: day));
    final String weekday;
    if (currentLanguage() == 'de') {
      const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      weekday = weekdays[date.weekday - 1];
    } else {
      final name = DateFormat('EEE', currentIntlLocale()).format(date);
      weekday = name.length > 2 ? name.substring(0, 2) : name;
    }
    return '$weekday ${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(date)}';
  }

  /// Chip label: custom label, else the day ("Sa 18.10."), else "Plan n".
  static String planLabel(PlanAttendance att, int index, [List<Plan>? plans]) {
    final list = plans ?? allPlans(att);
    final custom = index < list.length ? list[index].label?.trim() : null;
    if (custom != null && custom.isNotEmpty) return custom;
    final day = planDay(att, list, index);
    if (day != null && isMultiDay(att)) return dayLabel(att, day);
    return 'Plan ${index + 1}';
  }

  static DateTime? planDate(PlanAttendance att, int index, [List<Plan>? plans]) {
    final d = _date(att.date);
    if (d == null) return null;
    return d.add(Duration(days: planDay(att, plans ?? allPlans(att), index) ?? 0));
  }

  /// Index of the plan for today, falling back to the first plan.
  static int todayPlanIndex(PlanAttendance? att, [DateTime? now]) {
    final plans = allPlans(att);
    if (plans.length < 2 || att == null) return 0;
    final today = now ?? DateTime.now();
    for (var i = 0; i < plans.length; i++) {
      if (planDay(att, plans, i) == null) continue;
      final d = planDate(att, i, plans);
      if (d != null && d.year == today.year && d.month == today.month && d.day == today.day) {
        return i;
      }
    }
    return 0;
  }

  static List<({int day, String label})> dayOptions(PlanAttendance att) {
    if (!isMultiDay(att)) return const [];
    final count = att.durationDays ?? 1;
    return List.generate(count, (day) => (day: day, label: dayLabel(att, day)));
  }

  static int? nextFreeDay(PlanAttendance att, List<Plan> plans) {
    final used = <int?>{};
    for (var i = 0; i < plans.length; i++) {
      used.add(planDay(att, plans, i));
    }
    for (final o in dayOptions(att)) {
      if (!used.contains(o.day)) return o.day;
    }
    return null;
  }

  /// Writes each plan's day explicitly so reordering or deleting doesn't shift days.
  static List<Plan> withDays(PlanAttendance att, List<Plan> plans) {
    if (!isMultiDay(att)) return [...plans];
    return [
      for (var i = 0; i < plans.length; i++) plans[i].copyWith(day: planDay(att, plans, i)),
    ];
  }

  /// Splits a full plan list into the `plan` / `extra_plans` columns.
  static Map<String, dynamic> splitPlans(List<Plan> plans) {
    return {
      'plan': plans.isEmpty ? null : plans.first.toJson(),
      'extra_plans': plans.length > 1 ? plans.sublist(1).map((p) => p.toJson()).toList() : null,
    };
  }

  // ---------------------------------------------------------------------------
  // Live mode / countdown
  // ---------------------------------------------------------------------------

  static DateTime? planStart(DateTime? date, String time) {
    final m = parseTimeToMinutes(time);
    if (date == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, m ~/ 60, m % 60);
  }

  /// True from 5 minutes before the start until 15 minutes after the end on the plan's day.
  static bool isLiveNow(DateTime? date, String time, List<PlanField> fields, [DateTime? now]) {
    if (fields.isEmpty) return false;
    final start = planStart(date, time);
    if (start == null) return false;
    final n = now ?? DateTime.now();
    final end = start.add(Duration(minutes: totalMinutes(fields)));
    return n.isAfter(start.subtract(const Duration(minutes: 5))) &&
        n.isBefore(end.add(const Duration(minutes: 15)));
  }

  /// Index of the field running now, -1 before the start. Block heads are skipped.
  static int activeIndex(DateTime? date, String time, List<PlanField> fields, [DateTime? now]) {
    final start = planStart(date, time);
    if (start == null || fields.isEmpty) return -1;
    final n = now ?? DateTime.now();
    if (n.isBefore(start)) return -1;
    var t = start;
    for (var i = 0; i < fields.length; i++) {
      if (isGroupHead(fields[i])) continue;
      t = t.add(Duration(minutes: minutesOf(fields[i])));
      if (n.isBefore(t)) return i;
    }
    return fields.length - 1;
  }

  /// Remaining time of the active field as "mm:ss" or "h:mm:ss".
  static String activeCountdown(DateTime? date, String time, List<PlanField> fields, int activeIndex, [DateTime? now]) {
    final start = planStart(date, time);
    if (start == null || activeIndex < 0) return '';
    var t = start;
    for (var i = 0; i <= activeIndex && i < fields.length; i++) {
      t = t.add(Duration(minutes: minutesOf(fields[i])));
    }
    final remaining = max(0, t.difference(now ?? DateTime.now()).inSeconds);
    return formatDuration(remaining);
  }

  static String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// "beginnt in 4 Min." while the plan hasn't started.
  static String startCountdown(DateTime? date, String time, [DateTime? now]) {
    final start = planStart(date, time);
    if (start == null) return '';
    final remaining = start.difference(now ?? DateTime.now()).inSeconds;
    if (remaining <= 0) return '';
    final l10n = l10nWithoutContext;
    if (remaining < 60) return l10n.coreFlutterPlanStartsSoon;
    final minutes = (remaining / 60).ceil();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return l10n.coreFlutterPlanStartsInMin(m);
    return m > 0
        ? l10n.coreFlutterPlanStartsInHoursMin(h, m)
        : l10n.coreFlutterPlanStartsInHours(h);
  }

  /// "Samstag, 18.10.2025"
  static String longDate(DateTime? date) {
    if (date == null) return '';
    if (currentLanguage() != 'de') {
      return DateFormat('EEEE, ${dateFmt()}', currentIntlLocale()).format(date);
    }
    const days = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
    return '${days[date.weekday - 1]}, ${DateFormat('dd.MM.yyyy').format(date)}';
  }
}

/// Result of [PlanUtils.validate].
enum PlanValidation { ok, noFields, missingTime }
