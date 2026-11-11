// Chat assistant: the fixed commands the Edge Function `ai-assistant`
// answers with (mirror of supabase/functions/ai-assistant/intent.ts).
//
// The answer is checked here a second time: whatever arrives that is not
// exactly one of these commands becomes [UnsupportedCommand]. Package 1
// reads; package 2 adds [SetStatusCommand] and [PlannedAbsenceCommand],
// which the app only shows as a preview until the person confirms. Other
// changes are recognised (`category: change`) and answered with "kann ich
// noch nicht".

const int assistantMaxTextLength = 500;
const int _maxName = 80;
const int _maxCount = 36;

/// At most this many names / groups in one status command.
const int assistantMaxWho = 10;
const int _maxReason = 120;

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

sealed class AssistantCommand {
  const AssistantCommand();

  /// Checks one answer of the Edge Function (`{"command": {...}}` already
  /// unwrapped). Never throws: everything unknown is [UnsupportedCommand].
  static AssistantCommand fromJson(Object? raw) {
    if (raw is! Map) return const UnsupportedCommand();
    final m = raw.cast<Object?, Object?>();
    switch (m['command']) {
      case 'attendance_rate':
        final subject = _subject(m['subject']);
        final period = m['period'] == null ? const SeasonPeriod() : _period(m['period']);
        if (subject == null || period == null) return const UnsupportedCommand();
        return AttendanceRateCommand(subject: subject, period: period, typeName: _optName(m['typeName']));
      case 'event_overview':
        final event = m['event'] == null ? const NextEventRef() : _eventRef(m['event']);
        if (event == null) return const UnsupportedCommand();
        return EventOverviewCommand(
          event: event,
          typeName: _optName(m['typeName']),
          group: _optName(m['group']),
        );
      case 'next_event':
        return NextEventCommand(typeName: _optName(m['typeName']));
      case 'birthdays':
        final period = m['period'] == null ? const ThisPeriod(PeriodUnit.month) : _period(m['period']);
        return period == null ? const UnsupportedCommand() : BirthdaysCommand(period);
      case 'song_last_sung':
        final title = cleanAssistantText(m['title'], _maxName);
        return title == null ? const UnsupportedCommand() : SongLastSungCommand(title);
      case 'help':
        final query = cleanAssistantText(m['query'], _maxName);
        return query == null ? const UnsupportedCommand() : HelpCommand(query);
      case 'set_status':
        final who = _whoList(m['who']);
        final status = _status(m['status']);
        if (who == null || status == null) return const UnsupportedCommand();
        final hasPeriod = m['period'] != null;
        final period = hasPeriod ? _period(m['period']) : null;
        if (hasPeriod && period == null) return const UnsupportedCommand();
        final event = period != null ? null : (m['event'] == null ? const NextEventRef() : _eventRef(m['event']));
        if (period == null && event == null) return const UnsupportedCommand();
        return SetStatusCommand(
          who: who,
          status: status,
          event: event,
          period: period,
          typeName: _optName(m['typeName']),
          reason: cleanAssistantText(m['reason'], _maxReason),
        );
      case 'planned_absence':
        final who = _who(m['who'], allowGroup: false);
        final from = parseAssistantDate(m['from']);
        final to = parseAssistantDate(m['to']);
        if (who == null || from == null || to == null || from.isAfter(to)) return const UnsupportedCommand();
        return PlannedAbsenceCommand(who: who, from: from, to: to, reason: cleanAssistantText(m['reason'], _maxReason));
      case 'unsupported':
        return UnsupportedCommand(isChange: m['category'] == 'change');
      default:
        return const UnsupportedCommand();
    }
  }
}

/// "Melde mich Sonntag ab", "Jonas und Marie waren am Mittwoch da".
/// [who]: [MeSubject], [PersonSubject], [PersonIdSubject] or [GroupSubject].
/// Exactly one of [event] and [period] is set.
class SetStatusCommand extends AssistantCommand {
  const SetStatusCommand({
    required this.who,
    required this.status,
    this.event,
    this.period,
    this.typeName,
    this.reason,
  });

  final List<RateSubject> who;
  final AssistantStatus status;
  final EventRef? event;
  final AssistantPeriod? period;
  final String? typeName;
  final String? reason;

  /// Same command with [who] (after "Welchen Jonas meinst du?").
  SetStatusCommand withWho(List<RateSubject> who) => SetStatusCommand(
        who: who,
        status: status,
        event: event,
        period: period,
        typeName: typeName,
        reason: reason,
      );

  bool get onlyMe => who.every((w) => w is MeSubject);
}

/// "Lena ist bis Ende Januar im Ausland".
/// [who]: [MeSubject], [PersonSubject] or [PersonIdSubject].
class PlannedAbsenceCommand extends AssistantCommand {
  const PlannedAbsenceCommand({required this.who, required this.from, required this.to, this.reason});

  final RateSubject who;
  final DateTime from;
  final DateTime to;
  final String? reason;

  PlannedAbsenceCommand withWho(RateSubject who) =>
      PlannedAbsenceCommand(who: who, from: from, to: to, reason: reason);
}

/// "Wie war die Anwesenheit von Jonas in den letzten 3 Monaten?"
class AttendanceRateCommand extends AssistantCommand {
  const AttendanceRateCommand({required this.subject, required this.period, this.typeName});
  final RateSubject subject;
  final AssistantPeriod period;
  final String? typeName;
}

/// "Wer kommt am Sonntag?" / "Wer hat sich für Mittwoch noch nicht gemeldet?"
class EventOverviewCommand extends AssistantCommand {
  const EventOverviewCommand({required this.event, this.typeName, this.group});
  final EventRef event;
  final String? typeName;
  final String? group;
}

/// "Wann ist die nächste Probe?"
class NextEventCommand extends AssistantCommand {
  const NextEventCommand({this.typeName});
  final String? typeName;
}

/// "Wer hat diesen Monat Geburtstag?"
class BirthdaysCommand extends AssistantCommand {
  const BirthdaysCommand(this.period);
  final AssistantPeriod period;
}

/// "Wann haben wir 'Großer Gott' zuletzt gesungen?"
class SongLastSungCommand extends AssistantCommand {
  const SongLastSungCommand(this.title);
  final String title;
}

/// "Wie lege ich eine Schicht an?"
class HelpCommand extends AssistantCommand {
  const HelpCommand(this.query);
  final String query;
}

/// Anything else. [isChange]: the person wanted to change something
/// (comes in a later package).
class UnsupportedCommand extends AssistantCommand {
  const UnsupportedCommand({this.isChange = false});
  final bool isChange;
}

/// A short single-line text, or null.
String? cleanAssistantText(Object? value, int max) {
  if (value is! String) return null;
  final t = value
      .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
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
