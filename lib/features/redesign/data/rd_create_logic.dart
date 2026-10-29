import '../../../core/services/holiday_service.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/person/person.dart';
import '../../../data/repositories/profile_repository.dart' show ProfileExtraField;
import 'rd_dates.dart';

/// REDESIGN: pure logic of "Termin anlegen" (canvas "TerminAnlegen").

/// How the further dates of a new Termin are chosen.
enum RdRepeat { once, weekly, biweekly, custom }

/// Abmeldeschluss options, relative to the start of each Termin.
enum RdDeadline { none, hours24, days2, week }

/// Most dates one "Anlegen" creates (guards against an endless series).
const rdMaxCreateDates = 60;

DateTime rdDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// End of a series whose first day moved from [from] to [to]: the series
/// keeps its length in calendar days (also across a DST change), and never
/// ends before [to].
DateTime rdMovedSeriesEnd(DateTime from, DateTime to, DateTime until) {
  final end = rdAddDays(rdDay(until), rdDaysBetween(from, to));
  return end.isBefore(rdDay(to)) ? rdDay(to) : end;
}

/// [start] and every [everyWeeks] weeks after it up to [until] (inclusive),
/// at most [rdMaxCreateDates] days.
List<DateTime> rdRepeatDates(DateTime start, DateTime until, {int everyWeeks = 1}) {
  final first = rdDay(start);
  final last = rdDay(until);
  final step = everyWeeks < 1 ? 1 : everyWeeks;
  final result = <DateTime>[];
  for (var i = 0; result.length < rdMaxCreateDates; i++) {
    // Calendar arithmetic (not Duration) keeps the day across DST changes.
    final d = DateTime(first.year, first.month, first.day + i * 7 * step);
    if (d.isAfter(last)) break;
    result.add(d);
  }
  return result;
}

/// Name of the public or school holiday on [day], or null.
String? rdHolidayOn(HolidayData data, DateTime day) {
  final d = rdDay(day);
  for (final h in [...data.publicHolidays, ...data.schoolHolidays]) {
    if (!d.isBefore(rdDay(h.startDate)) && !d.isAfter(rdDay(h.endDate))) return h.name;
  }
  return null;
}

/// Start of a Termin on [day] at [startTime] ('HH:mm', default 19:00).
DateTime rdStartOf(DateTime day, String? startTime) {
  final parts = (startTime ?? '').split(':');
  final h = parts.length >= 2 ? int.tryParse(parts[0]) : null;
  final m = parts.length >= 2 ? int.tryParse(parts[1]) : null;
  return DateTime(day.year, day.month, day.day, h ?? 19, m ?? 0);
}

/// Abmeldeschluss of a Termin on [day]; null for [RdDeadline.none] and for
/// a deadline that would already be over at [now] (no deadline then,
/// instead of one that blocks every signout right away).
DateTime? rdDeadlineFor(RdDeadline option, DateTime day, String? startTime, {DateTime? now}) {
  final start = rdStartOf(day, startTime);
  final DateTime deadline;
  switch (option) {
    case RdDeadline.none:
      return null;
    case RdDeadline.hours24:
      deadline = DateTime(start.year, start.month, start.day - 1, start.hour, start.minute);
    case RdDeadline.days2:
      deadline = DateTime(start.year, start.month, start.day - 2, start.hour, start.minute);
    case RdDeadline.week:
      deadline = DateTime(start.year, start.month, start.day - 7, start.hour, start.minute);
  }
  return deadline.isBefore(now ?? DateTime.now()) ? null : deadline;
}

/// Persons a new Termin of [type] is created for, like the create write
/// path: active (not left, not pending, not paused), in the type's groups
/// and matching its extra-field filter.
List<Person> rdInvitedPersons(
  List<Person> players,
  AttendanceType type,
  List<ProfileExtraField> extraFields,
) {
  final groups = type.relevantGroups;
  final filter = type.additionalFieldsFilter;
  final key = filter?['key'] as String?;
  final option = filter?['option'];
  final field = key == null ? null : extraFields.where((f) => f.id == key).firstOrNull;
  return players.where((p) {
    if (p.paused || p.pending || (p.left != null && p.left!.isNotEmpty)) return false;
    if (groups != null && groups.isNotEmpty) {
      if (p.instrument == null || !groups.contains(p.instrument)) return false;
    }
    if (key != null && option != null && field != null) {
      final value = p.additionalFields?[key] ?? field.defaultValue;
      if (value != option) return false;
    }
    return true;
  }).toList();
}

/// A "Vorlage": a kind of Termin the group created before, with its
/// title, times and place.
class RdCreateTemplate {
  const RdCreateTemplate({
    required this.type,
    required this.title,
    this.typeInfo,
    this.startTime,
    this.endTime,
    this.place,
    this.durationDays,
  });

  final AttendanceType type;

  /// Chip label: the Termin title, else the type name.
  final String title;
  final String? typeInfo;
  final String? startTime;
  final String? endTime;
  final String? place;
  final int? durationDays;

  /// A template made from the type alone (no Termin of it yet).
  factory RdCreateTemplate.ofType(AttendanceType type) => RdCreateTemplate(
        type: type,
        title: type.name,
        startTime: type.startTime,
        endTime: type.endTime,
        durationDays: type.allDay ? type.durationDays : null,
      );
}

/// Up to [limit] templates: the kinds of Termin (type + title) created most
/// often, using the newest Termin of each kind for times and place. Without
/// earlier Termine, the visible types themselves.
List<RdCreateTemplate> rdTemplates(
  List<Attendance> attendances,
  List<AttendanceType> types, {
  int limit = 4,
}) {
  final byId = {for (final t in types) if (t.id != null) t.id!: t};
  final counts = <String, int>{};
  final newest = <String, Attendance>{};
  for (final a in attendances) {
    final type = byId[a.typeId];
    if (type == null) continue;
    final info = (a.typeInfo ?? '').trim();
    final key = '${type.id}\u0000$info';
    counts[key] = (counts[key] ?? 0) + 1;
    final current = newest[key];
    if (current == null || a.date.compareTo(current.date) > 0) newest[key] = a;
  }
  if (counts.isEmpty) {
    return [for (final t in types.take(limit)) RdCreateTemplate.ofType(t)];
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : newest[b]!.date.compareTo(newest[a]!.date);
    });
  final result = <RdCreateTemplate>[];
  final titles = <String>{};
  for (final key in keys) {
    final a = newest[key]!;
    final type = byId[a.typeId]!;
    final info = (a.typeInfo ?? '').trim();
    final title = info.isNotEmpty ? info : type.name;
    // Two kinds with the same label would be indistinguishable chips.
    if (!titles.add(title.toLowerCase())) continue;
    result.add(RdCreateTemplate(
      type: type,
      title: title,
      typeInfo: info.isEmpty ? null : info,
      startTime: a.startTime ?? type.startTime,
      endTime: a.endTime ?? type.endTime,
      place: (a.place ?? '').trim().isEmpty ? null : a.place!.trim(),
      durationDays: type.allDay ? (a.durationDays ?? type.durationDays) : null,
    ));
    if (result.length >= limit) break;
  }
  return result;
}

/// Places used before, most frequent first (at most [limit]).
List<String> rdRecentPlaces(List<Attendance> attendances, {int limit = 3}) {
  final counts = <String, int>{};
  final shown = <String, String>{};
  for (final a in attendances) {
    final place = (a.place ?? '').trim();
    if (place.isEmpty) continue;
    final key = place.toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    shown.putIfAbsent(key, () => place);
  }
  final keys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return [for (final k in keys.take(limit)) shown[k]!];
}
