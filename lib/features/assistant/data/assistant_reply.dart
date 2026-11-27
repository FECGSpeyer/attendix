// Chat assistant: what the chat shows. Only data; the page turns it into
// text in the UI language (no model text is ever shown).

import '../../../core/constants/enums.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/player_absence/player_absence.dart';
import '../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import 'assistant_command.dart';
import 'assistant_logic.dart';

part 'assistant_reply_plans.dart';

/// Short answers without data.
enum AssistantNotice {
  /// The model did not recognise a command.
  notUnderstood,

  /// The person wants to change something (later package).
  changeLater,

  /// The role may not ask this.
  noRights,

  /// "meine Anwesenheit" without an own person in the tenant.
  noOwnPerson,

  /// The admin has not switched the assistant on.
  disabled,

  /// Daily limit reached.
  limit,

  /// Message too long.
  tooLong,

  /// Network / server error.
  failed,

  /// [AssistantReply.subject]: no person with that name.
  personNotFound,

  /// [AssistantReply.subject]: no group with that name.
  groupNotFound,

  /// No Termin found for the question.
  noEvent,

  /// No Termin in the period (rate).
  noData,

  /// [AssistantReply.subject]: no Werk with that title.
  songNotFound,

  /// [AssistantReply.subject]: nothing in the help.
  noHelp,

  /// No birthday in the period.
  noBirthdays,

  /// Members may only sign in, sign out or report being late.
  selfStatusNotAllowed,

  /// No row to change (all already set, locked or outside the limits).
  nothingToChange,

  /// More rows than [assistantMaxChanges].
  tooManyChanges,

  /// Absence starts in the past or ends too far ahead.
  absenceOutOfRange,

  /// The person may not report a planned absence.
  noAbsenceRights,

  /// No Termintyp to create (none visible).
  noType,

  /// New Termine / the new day lie in the past or more than 6 months ahead.
  dateOutOfRange,

  /// The Termin is archived or outside the limits (14 days back to 6 months
  /// ahead).
  eventLocked,

  /// All days already have a Termin of that type.
  eventsExist,

  /// The Termintyp has no Werke (manage_songs off).
  noSongsForType,

  /// [AssistantReply.subject]: none of the titles is a Werk.
  songsNotFound,

  /// Entschuldigt / Verspätung only with a reason (like the sign-out sheet).
  excuseNeedsReason,

  /// No open task of the person.
  noTasks,

  /// The Termin has no Werke yet.
  noSongsYet,

  /// Due date in the past or more than 6 months ahead.
  taskDueOutOfRange,

  /// No duty Termin found for the question.
  noDuty,

  /// The duty type does not allow signing up yourself.
  dutyNotSelf,

  /// The person is not on the duty Termin.
  dutyNotMember,

  /// The person already has this duty.
  dutyAlready,

  /// All places of the duty are taken.
  dutyFull,

  /// Nobody to write to (group empty, everyone answered).
  noRecipients,
}

sealed class AssistantReply {
  const AssistantReply();
}

class NoticeReply extends AssistantReply {
  const NoticeReply(this.notice, {this.subject, this.count});
  final AssistantNotice notice;
  final String? subject;

  /// [AssistantNotice.tooManyChanges]: how many rows were asked.
  final int? count;
}

enum ChoiceKind { person, type }

/// "Welchen Jonas meinst du?" / "Welcher Termintyp?" — tapping an option
/// asks again.
class ChoiceReply extends AssistantReply {
  const ChoiceReply({required this.query, required this.options, this.kind = ChoiceKind.person});
  final String query;
  final ChoiceKind kind;
  final List<({String label, AssistantCommand command})> options;
}

class RateReply extends AssistantReply {
  const RateReply({
    required this.subjectName,
    required this.isMe,
    required this.range,
    required this.rate,
    this.typeName,
    this.lowest = const [],
    this.personId,
  });

  /// Person or group name; null for "alle".
  final String? subjectName;
  final bool isMe;
  final DayRange range;
  final RateResult rate;
  final String? typeName;

  /// For a group or all: who came least (up to 5).
  final List<({String name, int percent})> lowest;

  /// Opens the person.
  final int? personId;
}

class EventReply extends AssistantReply {
  const EventReply({
    required this.attendanceId,
    required this.title,
    required this.date,
    this.startTime,
    required this.groups,
    required this.open,
    required this.absent,
  });

  final int attendanceId;
  final String title;
  final DateTime date;
  final String? startTime;

  /// Per group: present (incl. late), absent/excused, open.
  final List<({String name, int present, int absent, int open})> groups;

  /// Names without an answer yet.
  final List<String> open;

  /// Names signed out.
  final List<String> absent;
}

class NextEventReply extends AssistantReply {
  const NextEventReply({
    required this.attendanceId,
    required this.title,
    required this.date,
    this.startTime,
    this.endTime,
    this.place,
    this.tenantName,
  });

  final int attendanceId;
  final String title;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String? place;

  /// Set when the Termin belongs to another group of the account.
  final String? tenantName;
}

class BirthdaysReply extends AssistantReply {
  const BirthdaysReply({required this.range, required this.people});
  final DayRange range;
  final List<({String name, DateTime date, int age})> people;
}

class SongReply extends AssistantReply {
  const SongReply({required this.songId, required this.name, this.number, this.lastSung});
  final int songId;
  final String name;
  final int? number;
  final DateTime? lastSung;
}

class HelpReply extends AssistantReply {
  const HelpReply(this.articles);
  final List<({String id, String title})> articles;
}

/// "Welche Aufgaben sind bei mir offen?"
class TasksReply extends AssistantReply {
  const TasksReply(this.tasks);
  final List<({String id, String title, String? dueDate, String priority, bool inProgress})> tasks;
}

/// "Welche Werke singen wir Sonntag?"
class EventSongsReply extends AssistantReply {
  const EventSongsReply({
    required this.attendanceId,
    required this.title,
    required this.date,
    required this.songs,
    this.linkToEvent = true,
  });

  final int attendanceId;
  final String title;
  final DateTime date;
  final List<String> songs;

  /// The page of the Termin can be opened (not for members' own rows).
  final bool linkToEvent;
}

/// "Neues Mitglied Anna Müller": opens the normal form prefilled, nothing
/// is saved in the chat.
class PersonDraftReply extends AssistantReply {
  const PersonDraftReply({
    required this.firstName,
    this.lastName,
    this.groupId,
    this.groupName,
    this.missingGroup,
    this.birthday,
  });

  final String firstName;
  final String? lastName;
  final int? groupId;
  final String? groupName;

  /// Group named in the chat that does not exist (the form keeps its default).
  final String? missingGroup;
  final DateTime? birthday;
}

/// "Erinner die Tenöre an Sonntag": a draft for the normal compose page,
/// sending stays a manual step there.
class MessageDraftReply extends AssistantReply {
  const MessageDraftReply({
    required this.playerIds,
    this.groupName,
    this.onlyOpen = false,
    this.attendanceId,
    this.eventTitle,
    this.eventDate,
    this.eventTime,
    this.note,
  });

  final List<int> playerIds;

  /// Null: everyone.
  final String? groupName;
  final bool onlyOpen;
  final int? attendanceId;
  final String? eventTitle;
  final DateTime? eventDate;
  final String? eventTime;

  /// The person's own words.
  final String? note;
}
