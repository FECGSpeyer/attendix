// Chat assistant: what the chat shows. Only data; the page turns it into
// text in the UI language (no model text is ever shown).

import '../../../core/constants/enums.dart';
import '../../../data/models/player_absence/player_absence.dart';
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

// ---------------------------------------------------------------------------
// Package 2: changes. Nothing is saved before the person confirms the
// preview; every saved change can be undone from the chat.

/// Where a preview card stands.
enum ActionState {
  /// Waiting for "Speichern" / "Abbrechen".
  pending,

  /// Many rows: "Speichern" was tapped once, a second tap saves.
  confirmAgain,

  /// Saving.
  saving,

  /// Abgebrochen, nothing saved.
  cancelled,

  /// Saved (the result follows as an [ActionDoneReply]).
  done,
}

/// One row of a status change, with what it was before (for undo).
class StatusChange {
  const StatusChange({
    required this.personAttendanceId,
    required this.attendanceId,
    required this.personName,
    required this.title,
    required this.date,
    required this.oldStatus,
    required this.oldNotes,
    required this.newStatus,
    this.occupiesDuty = false,
    this.tenantId,
    this.tenantName,
  });

  final String personAttendanceId;
  final int attendanceId;
  final String personName;
  final String title;
  final DateTime date;
  final AttendanceStatus oldStatus;
  final String? oldNotes;
  final AttendanceStatus newStatus;

  /// Own assigned duty that a sign-out leaves open (duty-notify).
  final bool occupiesDuty;

  /// Group of the Termin (own changes can span all groups of the account).
  final int? tenantId;
  final String? tenantName;
}

class StatusPlan {
  const StatusPlan({
    required this.self,
    required this.status,
    required this.reason,
    required this.changes,
    this.skippedLocked = 0,
    this.skippedWindow = 0,
  });

  /// Own rows through the "Meine Termine" path (notifies the leaders);
  /// otherwise rows of others through the Termin page path.
  final bool self;
  final AttendanceStatus status;

  /// Note written with the status (null: notes stay as they are).
  final String? reason;
  final List<StatusChange> changes;
  final int skippedLocked;
  final int skippedWindow;

  bool get needsSecondConfirm => changes.length >= assistantConfirmTwiceFrom;

  /// Rows of more than one group: the preview names the group.
  bool get spansGroups => {for (final c in changes) c.tenantId}.length > 1;
}

class AbsencePlan {
  const AbsencePlan({
    required this.personId,
    required this.personName,
    required this.isMe,
    required this.from,
    required this.to,
    required this.reason,
    required this.affected,
    this.onlyIds,
  });

  final int personId;
  final String personName;
  final bool isMe;
  final DateTime from;
  final DateTime to;
  final String reason;

  /// Termine that will be set to Entschuldigt.
  final int affected;

  /// Own absence: only the rows "Meine Termine" lists.
  final Set<String>? onlyIds;
}

/// Preview of a change with "Speichern" / "Abbrechen".
sealed class ActionPreviewReply extends AssistantReply {
  const ActionPreviewReply(this.state);
  final ActionState state;
  ActionPreviewReply withState(ActionState state);
  bool get needsSecondConfirm;
}

class StatusPreviewReply extends ActionPreviewReply {
  const StatusPreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final StatusPlan plan;

  @override
  StatusPreviewReply withState(ActionState state) => StatusPreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => plan.needsSecondConfirm;
}

class AbsencePreviewReply extends ActionPreviewReply {
  const AbsencePreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final AbsencePlan plan;

  @override
  AbsencePreviewReply withState(ActionState state) => AbsencePreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => false;
}

enum UndoState { available, working, undone, failed }

/// Result of a saved change with "Rückgängig".
class ActionDoneReply extends AssistantReply {
  const ActionDoneReply({
    this.statusPlan,
    this.absencePlan,
    this.absence,
    required this.count,
    this.undo = UndoState.available,
  });

  final StatusPlan? statusPlan;
  final AbsencePlan? absencePlan;

  /// The saved absence (deleted again on undo).
  final PlayerAbsence? absence;

  /// Rows changed.
  final int count;
  final UndoState undo;

  ActionDoneReply withUndo(UndoState undo) => ActionDoneReply(
        statusPlan: statusPlan,
        absencePlan: absencePlan,
        absence: absence,
        count: count,
        undo: undo,
      );
}
