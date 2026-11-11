// Chat assistant: what the chat shows. Only data; the page turns it into
// text in the UI language (no model text is ever shown).

import '../../../core/constants/enums.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/player_absence/player_absence.dart';
import '../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
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

/// New Termine (package 3).
class CreatePlan {
  const CreatePlan({
    required this.type,
    required this.days,
    this.title,
    this.place,
    this.startTime,
    this.endTime,
    this.skippedExisting = const [],
    this.skippedWindow = 0,
  });

  final AttendanceType type;

  /// One Termin per day, sorted.
  final List<DateTime> days;
  final String? title;

  /// Only stored for types with a place.
  final String? place;

  /// 'HH:mm' asked in the chat; null = the type's time.
  final String? startTime;
  final String? endTime;

  /// Days that already have a Termin of the type (not created again).
  final List<DateTime> skippedExisting;

  /// Days in the past or too far ahead.
  final int skippedWindow;

  bool get needsSecondConfirm => days.length >= assistantConfirmTwiceFrom;
}

/// A Termin moved to another day and/or time.
class MovePlan {
  const MovePlan({
    required this.before,
    required this.title,
    required this.oldDay,
    required this.newDay,
    this.oldStart,
    this.oldEnd,
    this.newStart,
    this.newEnd,
  });

  /// The Termin as it was (date, deadline, checklist, times) for undo.
  final Attendance before;
  final String title;
  final DateTime oldDay;
  final DateTime newDay;
  final String? oldStart;
  final String? oldEnd;
  final String? newStart;
  final String? newEnd;

  int get attendanceId => before.id!;
  bool get movesDay => oldDay != newDay;
}

/// Rows a move changed (absence on the new day), with what they were.
typedef RestoreRow = ({String id, AttendanceStatus status, String? notes});

/// Werke of a Termin before and after.
class SongsPlan {
  const SongsPlan({
    required this.attendanceId,
    required this.title,
    required this.date,
    required this.historyDate,
    required this.before,
    required this.after,
    required this.added,
    required this.removed,
    this.notFound = const [],
  });

  final int attendanceId;
  final String title;
  final DateTime date;

  /// Date written to new history rows (the Termin's date).
  final String historyDate;
  final List<SongHistoryEntry> before;
  final List<SongHistoryEntry> after;
  final List<String> added;
  final List<String> removed;

  /// Titles without a Werk (left out).
  final List<String> notFound;
}

// ---------------------------------------------------------------------------
// Package 4.

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

/// A new task.
class TaskPlan {
  const TaskPlan({
    required this.title,
    required this.priority,
    this.personId,
    this.personName,
    this.isMe = false,
    this.dueDate,
  });

  final String title;

  /// 'low' | 'medium' | 'high'
  final String priority;
  final int? personId;
  final String? personName;
  final bool isMe;

  /// YYYY-MM-DD
  final String? dueDate;
}

/// The person takes over a duty.
class DutyPlan {
  const DutyPlan({
    required this.attendanceId,
    required this.personAttendanceId,
    required this.title,
    required this.date,
    this.startTime,
    required this.required,
    required this.occupied,
    required this.oldStatus,
    this.oldNotes,
  });

  final int attendanceId;
  final String personAttendanceId;
  final String title;
  final DateTime date;
  final String? startTime;
  final int required;
  final int occupied;

  /// Own row before (for undo).
  final AttendanceStatus oldStatus;
  final String? oldNotes;

  /// This sign-up fills the last place (undo tells the stand-ins again).
  bool get fillsLast => occupied + 1 >= required;
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

class CreatePreviewReply extends ActionPreviewReply {
  const CreatePreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final CreatePlan plan;

  @override
  CreatePreviewReply withState(ActionState state) => CreatePreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => plan.needsSecondConfirm;
}

class MovePreviewReply extends ActionPreviewReply {
  const MovePreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final MovePlan plan;

  @override
  MovePreviewReply withState(ActionState state) => MovePreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => false;
}

class SongsPreviewReply extends ActionPreviewReply {
  const SongsPreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final SongsPlan plan;

  @override
  SongsPreviewReply withState(ActionState state) => SongsPreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => false;
}

class TaskPreviewReply extends ActionPreviewReply {
  const TaskPreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final TaskPlan plan;

  @override
  TaskPreviewReply withState(ActionState state) => TaskPreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => false;
}

class DutyPreviewReply extends ActionPreviewReply {
  const DutyPreviewReply(this.plan, {ActionState state = ActionState.pending}) : super(state);
  final DutyPlan plan;

  @override
  DutyPreviewReply withState(ActionState state) => DutyPreviewReply(plan, state: state);

  @override
  bool get needsSecondConfirm => false;
}

enum UndoState { available, working, undone, failed }

/// The push to the responsible person of a new task: only when tapped.
enum NotifyState { none, available, working, sent, failed }

/// Result of a saved change with "Rückgängig".
class ActionDoneReply extends AssistantReply {
  const ActionDoneReply({
    this.statusPlan,
    this.absencePlan,
    this.absence,
    this.createPlan,
    this.createdIds = const [],
    this.movePlan,
    this.moveRestore = const [],
    this.songsPlan,
    this.taskPlan,
    this.taskId,
    this.notify = NotifyState.none,
    this.dutyPlan,
    required this.count,
    this.undo = UndoState.available,
  });

  final StatusPlan? statusPlan;
  final AbsencePlan? absencePlan;

  /// The saved absence (deleted again on undo).
  final PlayerAbsence? absence;

  final CreatePlan? createPlan;

  /// Ids of the new Termine (undo deletes exactly these).
  final List<int> createdIds;
  final MovePlan? movePlan;

  /// Rows the move changed, with their status before.
  final List<RestoreRow> moveRestore;
  final SongsPlan? songsPlan;
  final TaskPlan? taskPlan;

  /// Id of the new task (undo deletes exactly this one).
  final String? taskId;
  final NotifyState notify;
  final DutyPlan? dutyPlan;

  /// Rows changed / Termine created.
  final int count;
  final UndoState undo;

  ActionDoneReply withUndo(UndoState undo) => _copy(undo: undo);

  ActionDoneReply withNotify(NotifyState notify) => _copy(notify: notify);

  ActionDoneReply _copy({UndoState? undo, NotifyState? notify}) => ActionDoneReply(
    statusPlan: statusPlan,
    absencePlan: absencePlan,
    absence: absence,
    createPlan: createPlan,
    createdIds: createdIds,
    movePlan: movePlan,
    moveRestore: moveRestore,
    songsPlan: songsPlan,
    taskPlan: taskPlan,
    taskId: taskId,
    notify: notify ?? this.notify,
    dutyPlan: dutyPlan,
    count: count,
    undo: undo ?? this.undo,
  );
}
