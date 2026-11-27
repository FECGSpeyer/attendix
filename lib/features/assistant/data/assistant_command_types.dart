part of 'assistant_command.dart';

const int assistantMaxTextLength = 500;
const int _maxName = 80;
const int _maxCount = 36;

/// At most this many names / groups in one status command.
const int assistantMaxWho = 10;
const int _maxReason = 120;

/// At most this many new Termine in one command.
const int assistantMaxNewEvents = 20;

/// At most this many Werke in one command.
const int assistantMaxSongs = 15;

/// Title of a new task.
const int assistantMaxTaskTitle = 120;

/// Own words added to a message draft.
const int assistantMaxNote = 300;

enum TaskPriority { low, medium, high }

/// The status a [SetStatusCommand] sets.
enum AssistantStatus { present, excused, lateExcused, late, absent, neutral }

enum PeriodUnit { day, week, month, year }

enum AssistantWeekday { mon, tue, wed, thu, fri, sat, sun }

/// A time span in words ("letzte 3 Monate", "im Oktober").
sealed class AssistantPeriod {
  const AssistantPeriod();
}

/// The last [count] units up to today.
class LastPeriod extends AssistantPeriod {
  const LastPeriod(this.unit, this.count);
  final PeriodUnit unit;
  final int count;
}

/// The current week / month / year.
class ThisPeriod extends AssistantPeriod {
  const ThisPeriod(this.unit);
  final PeriodUnit unit;
}

/// The week / month / year before the current one.
class PreviousPeriod extends AssistantPeriod {
  const PreviousPeriod(this.unit);
  final PeriodUnit unit;
}

/// From today [count] units ahead.
class NextPeriod extends AssistantPeriod {
  const NextPeriod(this.unit, this.count);
  final PeriodUnit unit;
  final int count;
}

/// Since the season start of the tenant.
class SeasonPeriod extends AssistantPeriod {
  const SeasonPeriod();
}

class RangePeriod extends AssistantPeriod {
  const RangePeriod(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

/// Which Termin ("am Sonntag", "nächste Probe").
sealed class EventRef {
  const EventRef();
}

class NextEventRef extends EventRef {
  const NextEventRef();
}

class TodayEventRef extends EventRef {
  const TodayEventRef();
}

class TomorrowEventRef extends EventRef {
  const TomorrowEventRef();
}

class YesterdayEventRef extends EventRef {
  const YesterdayEventRef();
}

class WeekdayEventRef extends EventRef {
  const WeekdayEventRef(this.day);
  final AssistantWeekday day;
}

/// The last such weekday before today ("wer war am Sonntag da?").
class PastWeekdayEventRef extends EventRef {
  const PastWeekdayEventRef(this.day);
  final AssistantWeekday day;
}

class DateEventRef extends EventRef {
  const DateEventRef(this.date);
  final DateTime date;
}

/// Whose attendance rate.
sealed class RateSubject {
  const RateSubject();
}

class MeSubject extends RateSubject {
  const MeSubject();
}

class PersonSubject extends RateSubject {
  const PersonSubject(this.name);
  final String name;
}

/// A person the app already picked (after "Welchen Jonas meinst du?").
/// Never produced from a model answer.
class PersonIdSubject extends RateSubject {
  const PersonIdSubject(this.personId);
  final int personId;
}

class GroupSubject extends RateSubject {
  const GroupSubject(this.name);
  final String name;
}

class AllSubject extends RateSubject {
  const AllSubject();
}

/// "Meine Kinder" (parents, status only).
class ChildrenSubject extends RateSubject {
  const ChildrenSubject();
}

/// A short single-line text, or null.
String? cleanAssistantText(Object? value, int max) {
  if (value is! String) return null;
  final t = value.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  return t.length > max ? t.substring(0, max) : t;
}

String? _optName(Object? value) => cleanAssistantText(value, _maxName);

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// A real calendar date (2000–2100) from YYYY-MM-DD, or null.
DateTime? parseAssistantDate(Object? value) {
  if (value is! String || !_isoDate.hasMatch(value)) return null;
  final parts = value.split('-').map(int.parse).toList();
  final d = DateTime(parts[0], parts[1], parts[2]);
  if (d.year != parts[0] || d.month != parts[1] || d.day != parts[2]) return null;
  if (d.year < 2000 || d.year > 2100) return null;
  return d;
}

/// Marks an invalid time (the command fails); null means "not given".
const String _badTime = '!';

/// 'HH:mm' from "9:30" / "19:30:00", or null when it is not a time.
String? parseAssistantTime(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
}

String? _optTime(Object? v) => v == null || v == '' ? null : (parseAssistantTime(v) ?? _badTime);

/// 1..[assistantMaxNewEvents] days, sorted, without duplicates.
List<DateTime>? _dateList(Object? raw) {
  if (raw is! List || raw.isEmpty || raw.length > assistantMaxNewEvents) return null;
  final out = <DateTime>{};
  for (final v in raw) {
    final d = parseAssistantDate(v);
    if (d == null) return null;
    out.add(d);
  }
  return out.toList()..sort();
}

/// 1..[assistantMaxSongs] titles (a number is a Werk number), no duplicates.
List<String>? _titleList(Object? raw) {
  final list = raw is List ? raw : (raw == null ? const [] : [raw]);
  if (list.isEmpty || list.length > assistantMaxSongs) return null;
  final out = <String>[];
  final seen = <String>{};
  for (final v in list) {
    final t = cleanAssistantText(v is num ? '$v' : v, _maxName);
    if (t == null) return null;
    if (seen.add(t.toLowerCase())) out.add(t);
  }
  return out;
}

PeriodUnit? _unit(Object? v) => switch (v) {
  'day' => PeriodUnit.day,
  'week' => PeriodUnit.week,
  'month' => PeriodUnit.month,
  'year' => PeriodUnit.year,
  _ => null,
};

int? _count(Object? v) {
  final n = v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : int.tryParse('$v'));
  return n != null && n >= 1 && n <= _maxCount ? n : null;
}

AssistantPeriod? _period(Object? raw) {
  if (raw is! Map) return null;
  final unit = _unit(raw['unit']);
  switch (raw['type']) {
    case 'last':
    case 'next':
      final n = _count(raw['count'] ?? 1);
      if (unit == null || n == null) return null;
      return raw['type'] == 'last' ? LastPeriod(unit, n) : NextPeriod(unit, n);
    case 'this':
    case 'previous':
      if (unit == null || unit == PeriodUnit.day) return null;
      return raw['type'] == 'this' ? ThisPeriod(unit) : PreviousPeriod(unit);
    case 'season':
      return const SeasonPeriod();
    case 'range':
      final from = parseAssistantDate(raw['from']);
      final to = parseAssistantDate(raw['to']);
      if (from == null || to == null || from.isAfter(to)) return null;
      return RangePeriod(from, to);
    default:
      return null;
  }
}

EventRef? _eventRef(Object? raw) {
  if (raw is! Map) return null;
  switch (raw['type']) {
    case 'next':
      return const NextEventRef();
    case 'today':
      return const TodayEventRef();
    case 'tomorrow':
      return const TomorrowEventRef();
    case 'yesterday':
      return const YesterdayEventRef();
    case 'weekday':
    case 'past_weekday':
      for (final d in AssistantWeekday.values) {
        if (d.name == raw['day']) return raw['type'] == 'weekday' ? WeekdayEventRef(d) : PastWeekdayEventRef(d);
      }
      return null;
    case 'date':
      final date = parseAssistantDate(raw['date']);
      return date == null ? null : DateEventRef(date);
    default:
      return null;
  }
}

AssistantStatus? _status(Object? v) => switch (v) {
  'present' => AssistantStatus.present,
  'excused' => AssistantStatus.excused,
  'late_excused' => AssistantStatus.lateExcused,
  'late' => AssistantStatus.late,
  'absent' => AssistantStatus.absent,
  'neutral' => AssistantStatus.neutral,
  _ => null,
};

RateSubject? _who(Object? raw, {required bool allowGroup}) {
  if (raw is! Map) return null;
  switch (raw['kind']) {
    case 'me':
      return const MeSubject();
    case 'children':
      return allowGroup ? const ChildrenSubject() : null;
    case 'person':
      final name = _optName(raw['name']);
      return name == null ? null : PersonSubject(name);
    case 'group':
      if (!allowGroup) return null;
      final name = _optName(raw['name']);
      return name == null ? null : GroupSubject(name);
    default:
      return null;
  }
}

/// 1..[assistantMaxWho] entries without duplicates. Missing or any invalid
/// entry → null (never a silent "me").
List<RateSubject>? _whoList(Object? raw) {
  if (raw == null) return null;
  final list = raw is List ? raw : [raw];
  if (list.isEmpty || list.length > assistantMaxWho) return null;
  final out = <RateSubject>[];
  final seen = <String>{};
  for (final v in list) {
    final w = _who(v, allowGroup: true);
    if (w == null) return null;
    final key = switch (w) {
      PersonSubject(:final name) => 'p:${name.toLowerCase()}',
      GroupSubject(:final name) => 'g:${name.toLowerCase()}',
      ChildrenSubject() => 'children',
      _ => 'me',
    };
    if (seen.add(key)) out.add(w);
  }
  return out;
}

RateSubject? _subject(Object? raw) {
  if (raw is! Map) return null;
  switch (raw['kind']) {
    case 'me':
      return const MeSubject();
    case 'all':
      return const AllSubject();
    case 'person':
      final name = _optName(raw['name']);
      return name == null ? null : PersonSubject(name);
    case 'group':
      final name = _optName(raw['name']);
      return name == null ? null : GroupSubject(name);
    default:
      return null;
  }
}
