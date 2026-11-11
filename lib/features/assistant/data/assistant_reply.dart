// Chat assistant: what the chat shows. Only data; the page turns it into
// text in the UI language (no model text is ever shown).

import 'assistant_command.dart';
import 'assistant_logic.dart';

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
}

sealed class AssistantReply {
  const AssistantReply();
}

class NoticeReply extends AssistantReply {
  const NoticeReply(this.notice, {this.subject});
  final AssistantNotice notice;
  final String? subject;
}

/// "Welchen Jonas meinst du?" — tapping an option asks again.
class ChoiceReply extends AssistantReply {
  const ChoiceReply({required this.query, required this.options});
  final String query;
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
  });

  final int attendanceId;
  final String title;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String? place;
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
