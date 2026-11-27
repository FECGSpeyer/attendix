// Chat assistant: the fixed commands the Edge Function `ai-assistant`
// answers with (mirror of supabase/functions/ai-assistant/intent.ts).
//
// The answer is checked here a second time: whatever arrives that is not
// exactly one of these commands becomes [UnsupportedCommand]. Package 1
// reads; package 2 adds [SetStatusCommand] and [PlannedAbsenceCommand],
// which the app only shows as a preview until the person confirms; package
// 3 adds [CreateEventsCommand], [MoveEventCommand] and [SetSongsCommand] the
// same way. Other changes are recognised (`category: change`) and answered
// with "kann ich noch nicht". Package 4 adds [MyTasksCommand],
// [EventSongsCommand] (reads), [CreateTaskCommand], [TakeDutyCommand]
// (preview / confirm / undo) and [NewPersonCommand], [DraftMessageCommand],
// which never save: the app opens the normal form prefilled.

part 'assistant_command_types.dart';

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
        return EventOverviewCommand(event: event, typeName: _optName(m['typeName']), group: _optName(m['group']));
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
      case 'create_events':
        final dates = _dateList(m['dates']);
        final start = _optTime(m['startTime']);
        final end = _optTime(m['endTime']);
        if (dates == null || start == _badTime || end == _badTime) return const UnsupportedCommand();
        return CreateEventsCommand(
          typeName: _optName(m['typeName']),
          dates: dates,
          startTime: start,
          endTime: end,
          title: _optName(m['title']),
          place: cleanAssistantText(m['place'], _maxReason),
        );
      case 'move_event':
        final event = m['event'] == null ? const NextEventRef() : _eventRef(m['event']);
        final hasDate = m['toDate'] != null && m['toDate'] != '';
        final toDate = hasDate ? parseAssistantDate(m['toDate']) : null;
        final start = _optTime(m['startTime']);
        final end = _optTime(m['endTime']);
        if (event == null || (hasDate && toDate == null) || start == _badTime || end == _badTime) {
          return const UnsupportedCommand();
        }
        if (toDate == null && start == null && end == null) return const UnsupportedCommand();
        return MoveEventCommand(
          event: event,
          typeName: _optName(m['typeName']),
          toDate: toDate,
          startTime: start,
          endTime: end,
        );
      case 'set_songs':
        final event = m['event'] == null ? const NextEventRef() : _eventRef(m['event']);
        final titles = _titleList(m['titles']);
        if (event == null || titles == null) return const UnsupportedCommand();
        return SetSongsCommand(
          event: event,
          typeName: _optName(m['typeName']),
          titles: titles,
          replace: m['mode'] == 'replace',
        );
      case 'my_tasks':
        return const MyTasksCommand();
      case 'event_songs':
        final event = m['event'] == null ? const NextEventRef() : _eventRef(m['event']);
        if (event == null) return const UnsupportedCommand();
        return EventSongsCommand(event: event, typeName: _optName(m['typeName']));
      case 'create_task':
        final title = cleanAssistantText(m['title'], assistantMaxTaskTitle);
        final hasWho = m['who'] != null;
        final who = hasWho ? _who(m['who'], allowGroup: false) : null;
        final hasDue = m['dueDate'] != null && m['dueDate'] != '';
        final due = hasDue ? parseAssistantDate(m['dueDate']) : null;
        final hasPriority = m['priority'] != null && m['priority'] != '';
        final priority = TaskPriority.values.where((p) => p.name == m['priority']).firstOrNull;
        if (title == null || (hasWho && who == null) || (hasDue && due == null) || (hasPriority && priority == null)) {
          return const UnsupportedCommand();
        }
        return CreateTaskCommand(title: title, who: who, dueDate: due, priority: priority);
      case 'take_duty':
        final event = m['event'] == null ? const NextEventRef() : _eventRef(m['event']);
        if (event == null) return const UnsupportedCommand();
        return TakeDutyCommand(event: event, typeName: _optName(m['typeName']));
      case 'new_person':
        final first = _optName(m['firstName']);
        final hasBirthday = m['birthday'] != null && m['birthday'] != '';
        final birthday = hasBirthday ? parseAssistantDate(m['birthday']) : null;
        if (first == null || (hasBirthday && birthday == null)) return const UnsupportedCommand();
        return NewPersonCommand(
          firstName: first,
          lastName: _optName(m['lastName']),
          group: _optName(m['group']),
          birthday: birthday,
        );
      case 'draft_message':
        final hasEvent = m['event'] != null;
        final event = hasEvent ? _eventRef(m['event']) : null;
        if (hasEvent && event == null) return const UnsupportedCommand();
        return DraftMessageCommand(
          group: _optName(m['group']),
          event: event,
          typeName: _optName(m['typeName']),
          note: cleanAssistantText(m['note'], assistantMaxNote),
          onlyOpen: event != null && m['onlyOpen'] == true,
        );
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
  SetStatusCommand withWho(List<RateSubject> who) =>
      SetStatusCommand(who: who, status: status, event: event, period: period, typeName: typeName, reason: reason);

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

  PlannedAbsenceCommand withWho(RateSubject who) => PlannedAbsenceCommand(who: who, from: from, to: to, reason: reason);
}

/// "Leg jeden Mittwoch im Dezember eine Probe an" (1..[assistantMaxNewEvents]
/// days, sorted). [typeId]: the type the person picked after "Welcher
/// Termintyp?" (never from a model answer).
class CreateEventsCommand extends AssistantCommand {
  const CreateEventsCommand({
    this.typeName,
    this.typeId,
    required this.dates,
    this.startTime,
    this.endTime,
    this.title,
    this.place,
  });

  final String? typeName;
  final String? typeId;
  final List<DateTime> dates;

  /// 'HH:mm'; null = the type's time.
  final String? startTime;
  final String? endTime;
  final String? title;
  final String? place;

  CreateEventsCommand withType(String typeId) => CreateEventsCommand(
    typeName: typeName,
    typeId: typeId,
    dates: dates,
    startTime: startTime,
    endTime: endTime,
    title: title,
    place: place,
  );
}

/// "Verschieb die Probe am Mittwoch auf Donnerstag" / "… beginnt um 10 Uhr".
/// At least one of [toDate], [startTime], [endTime] is set.
class MoveEventCommand extends AssistantCommand {
  const MoveEventCommand({required this.event, this.typeName, this.toDate, this.startTime, this.endTime});

  final EventRef event;
  final String? typeName;
  final DateTime? toDate;
  final String? startTime;
  final String? endTime;
}

/// "Setz 'Großer Gott' und Nr. 12 auf die Probe am Sonntag".
/// [replace]: the titles are the whole list (otherwise they are added).
class SetSongsCommand extends AssistantCommand {
  const SetSongsCommand({required this.event, this.typeName, required this.titles, this.replace = false});

  final EventRef event;
  final String? typeName;
  final List<String> titles;
  final bool replace;
}

/// "Welche Aufgaben sind bei mir offen?"
class MyTasksCommand extends AssistantCommand {
  const MyTasksCommand();
}

/// "Welche Werke singen wir Sonntag?"
class EventSongsCommand extends AssistantCommand {
  const EventSongsCommand({required this.event, this.typeName});
  final EventRef event;
  final String? typeName;
}

/// "Thomas klärt bis Freitag den Raum". [who]: [MeSubject], [PersonSubject],
/// [PersonIdSubject] (after "Welchen Thomas meinst du?") or null (nobody).
class CreateTaskCommand extends AssistantCommand {
  const CreateTaskCommand({required this.title, this.who, this.dueDate, this.priority});

  final String title;
  final RateSubject? who;
  final DateTime? dueDate;
  final TaskPriority? priority;

  CreateTaskCommand withWho(RateSubject who) =>
      CreateTaskCommand(title: title, who: who, dueDate: dueDate, priority: priority);
}

/// "Ich mache Sonntag den Aufbau": the person themself takes over a duty.
class TakeDutyCommand extends AssistantCommand {
  const TakeDutyCommand({required this.event, this.typeName});
  final EventRef event;
  final String? typeName;
}

/// "Neues Mitglied Anna Müller, Sopran, Geburtstag 3.4.2008": only fills
/// the normal "Person anlegen" form, saving stays there.
class NewPersonCommand extends AssistantCommand {
  const NewPersonCommand({required this.firstName, this.lastName, this.group, this.birthday});
  final String firstName;
  final String? lastName;
  final String? group;
  final DateTime? birthday;
}

/// "Erinner die Tenöre an Sonntag": only a draft in the normal compose
/// page, sending stays a manual step there. [group] null = everyone;
/// [onlyOpen]: only those without an answer for [event].
class DraftMessageCommand extends AssistantCommand {
  const DraftMessageCommand({this.group, this.event, this.typeName, this.note, this.onlyOpen = false});
  final String? group;
  final EventRef? event;
  final String? typeName;
  final String? note;
  final bool onlyOpen;
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
