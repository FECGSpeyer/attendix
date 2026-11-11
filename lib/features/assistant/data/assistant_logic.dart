// Chat assistant: the pure part of answering a command (dates, names,
// rates, rights). No Supabase, no Riverpod, so it is tested directly
// (test/features/assistant/assistant_logic_test.dart).
//
// The model only says WHAT is asked; every date, name and number is worked
// out here from the data the app loads with the person's own rights.

import '../../../core/constants/enums.dart';
import '../../../core/utils/person_matcher.dart' show normalizeName, levenshtein;
import 'assistant_command.dart';

/// Inclusive day range (times are ignored).
typedef DayRange = ({DateTime from, DateTime to});

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addMonths(DateTime d, int months) {
  final m = d.month - 1 + months;
  final year = d.year + (m >= 0 ? m ~/ 12 : (m - 11) ~/ 12);
  final month = m % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

DateTime _shift(DateTime d, PeriodUnit unit, int n) => switch (unit) {
  PeriodUnit.day => DateTime(d.year, d.month, d.day + n),
  PeriodUnit.week => DateTime(d.year, d.month, d.day + 7 * n),
  PeriodUnit.month => _addMonths(d, n),
  PeriodUnit.year => _addMonths(d, 12 * n),
};

DayRange _unitAround(DateTime day, PeriodUnit unit) => switch (unit) {
  PeriodUnit.day => (from: day, to: day),
  PeriodUnit.week => (
    from: DateTime(day.year, day.month, day.day - (day.weekday - 1)),
    to: DateTime(day.year, day.month, day.day + (7 - day.weekday)),
  ),
  PeriodUnit.month => (from: DateTime(day.year, day.month, 1), to: DateTime(day.year, day.month + 1, 0)),
  PeriodUnit.year => (from: DateTime(day.year, 1, 1), to: DateTime(day.year, 12, 31)),
};

/// The days of [period], seen from [today]. "Letzte 3 Monate" on 11.11. is
/// 11.8. to 11.11.; "diesen Monat" the whole month.
DayRange resolvePeriod(AssistantPeriod period, DateTime today, DateTime seasonStart) {
  final t = dayOf(today);
  return switch (period) {
    LastPeriod(:final unit, :final count) => (from: _shift(t, unit, -count), to: t),
    ThisPeriod(:final unit) => _unitAround(t, unit),
    PreviousPeriod(:final unit) => _unitAround(_shift(t, unit, -1), unit),
    NextPeriod(:final unit, :final count) => (from: t, to: _shift(t, unit, count)),
    SeasonPeriod() => (from: dayOf(seasonStart).isAfter(t) ? t : dayOf(seasonStart), to: t),
    RangePeriod(:final from, :final to) => (from: dayOf(from), to: dayOf(to)),
  };
}

/// The day an [EventRef] points at; null for "der nächste Termin".
/// A weekday is the next such day, today included; a past weekday the
/// last such day before today.
DateTime? resolveEventDay(EventRef ref, DateTime today) {
  final t = dayOf(today);
  return switch (ref) {
    NextEventRef() => null,
    TodayEventRef() => t,
    TomorrowEventRef() => DateTime(t.year, t.month, t.day + 1),
    YesterdayEventRef() => DateTime(t.year, t.month, t.day - 1),
    WeekdayEventRef(:final day) => DateTime(t.year, t.month, t.day + ((day.index + 1 - t.weekday) % 7)),
    PastWeekdayEventRef(:final day) => DateTime(
      t.year,
      t.month,
      t.day - (((t.weekday - (day.index + 1)) % 7) == 0 ? 7 : (t.weekday - (day.index + 1)) % 7),
    ),
    DateEventRef(:final date) => dayOf(date),
  };
}

/// How well [query] fits one of [names] (0 = not at all).
double nameScore(String query, Iterable<String> names) {
  final q = normalizeName(query);
  if (q.isEmpty) return 0;
  var best = 0.0;
  for (final raw in names) {
    final n = normalizeName(raw);
    if (n.isEmpty) continue;
    double s;
    if (n == q) {
      s = 1;
    } else if (n.startsWith(q) && q.length >= 3) {
      s = 0.8;
    } else if (q.length >= 4 && levenshtein(q, n) <= (q.length >= 7 ? 2 : 1)) {
      s = 0.7;
    } else {
      s = 0;
    }
    if (s > best) best = s;
  }
  return best;
}

/// The best fitting items for [query]: all items with the highest score
/// (more than one = ambiguous, the app asks), empty when none fits.
List<T> bestMatches<T>(String query, Iterable<T> items, Iterable<String> Function(T) namesOf) {
  var best = 0.0;
  var result = <T>[];
  for (final item in items) {
    final s = nameScore(query, namesOf(item));
    if (s <= 0) continue;
    if (s > best) {
      best = s;
      result = [item];
    } else if (s == best) {
      result.add(item);
    }
  }
  return result;
}

/// Names a person can be called by: first name, last name, both in either
/// order. "Jonas", "Müller", "Jonas Müller", "Müller Jonas".
Iterable<String> personNames(String firstName, String lastName) sync* {
  yield '$firstName $lastName';
  yield '$lastName $firstName';
  yield firstName;
  yield lastName;
}

/// One person_attendances row as the rate needs it.
typedef RateRow =
    ({int personId, DateTime date, String? typeId, AttendanceStatus status, String? notes, String? dutyState});

typedef RateResult = ({int attended, int total, int? percent});

/// Attendance rate like the people list (`playerAttendancePercentagesProvider`):
/// only Termine up to today, only types that count for the average (or the
/// asked type), duty Termine only where the person was assigned.
RateResult computeRate(
  Iterable<RateRow> rows, {
  required DayRange range,
  required DateTime today,
  required Set<String> countedTypeIds,
  required Set<String> dutyTypeIds,
  bool shiftExcusedAsPresent = false,
}) {
  final last = dayOf(today).isBefore(range.to) ? dayOf(today) : range.to;
  var total = 0;
  var attended = 0;
  for (final r in rows) {
    final d = dayOf(r.date);
    if (d.isBefore(range.from) || d.isAfter(last)) continue;
    if (r.typeId == null || !countedTypeIds.contains(r.typeId)) continue;
    if (dutyTypeIds.contains(r.typeId) && (r.dutyState == null || r.dutyState!.isEmpty)) continue;
    total++;
    if (r.status.countsAsAttended(notes: r.notes, shiftExcusedAsPresent: shiftExcusedAsPresent)) {
      attended++;
    }
  }
  return (attended: attended, total: total, percent: total == 0 ? null : (attended / total * 100).round());
}

/// Rate per person, lowest first (for a group: who comes least).
List<({int personId, RateResult rate})> ratesPerPerson(
  Iterable<RateRow> rows, {
  required DayRange range,
  required DateTime today,
  required Set<String> countedTypeIds,
  required Set<String> dutyTypeIds,
  bool shiftExcusedAsPresent = false,
}) {
  final byPerson = <int, List<RateRow>>{};
  for (final r in rows) {
    byPerson.putIfAbsent(r.personId, () => []).add(r);
  }
  final result =
      [
          for (final e in byPerson.entries)
            (
              personId: e.key,
              rate: computeRate(
                e.value,
                range: range,
                today: today,
                countedTypeIds: countedTypeIds,
                dutyTypeIds: dutyTypeIds,
                shiftExcusedAsPresent: shiftExcusedAsPresent,
              ),
            ),
        ].where((e) => e.rate.total > 0).toList()
        ..sort((a, b) => a.rate.percent!.compareTo(b.rate.percent!));
  return result;
}

/// The next birthday of [birthday] inside [range], or null.
DateTime? birthdayIn(String? birthday, DayRange range) {
  final b = birthday == null ? null : DateTime.tryParse(birthday);
  if (b == null) return null;
  for (var year = range.from.year; year <= range.to.year; year++) {
    // 29.2. in a common year: 28.2.
    final lastDay = DateTime(year, b.month + 1, 0).day;
    final d = DateTime(year, b.month, b.day > lastDay ? lastDay : b.day);
    if (!d.isBefore(range.from) && !d.isAfter(range.to)) return d;
  }
  return null;
}

/// Age reached on [day].
int ageOn(String birthday, DateTime day) {
  final b = DateTime.parse(birthday);
  var age = day.year - b.year;
  if (day.month < b.month || (day.month == b.month && day.day < b.day)) age--;
  return age;
}

/// What a role may ask the assistant. Same rules as the screens it stands
/// for: other people's rates, who comes, birthdays only for those who see
/// the people or manage the attendance; the own rate only with an own
/// person; everything else for every member.
class AssistantAccess {
  const AssistantAccess({
    required this.role,
    required this.hasOwnPerson,
    this.canManageAbsences = false,
    this.canSelfReportAbsence = false,
    this.canCreateEvents = false,
    this.teamOrgEnabled = false,
    this.isTeamLeader = false,
  });

  final Role role;
  final bool hasOwnPerson;

  /// Planned absences of others (Admin, Verantwortliche or the role's
  /// permission `player_planned_absence`).
  final bool canManageAbsences;

  /// Own planned absence (permission of the own role).
  final bool canSelfReportAbsence;

  /// New Termine: the freshly loaded create permission
  /// (`canCreateAttendanceConfirmedProvider`, like both create pages).
  final bool canCreateEvents;

  /// Teamorganisation is switched on for the tenant (tasks).
  final bool teamOrgEnabled;

  /// Admin / Verantwortlicher (`isTeamLeaderProvider`): creates tasks.
  final bool isTeamLeader;

  /// "Person anlegen" and Mitteilungen: Admin and Verantwortliche, like the
  /// people list and `/settings/messages`.
  bool get managesPeople => role.isAdmin || role.isResponsible;

  /// Move a Termin and set its Werke: the roles that edit Termine on the
  /// Termin page (not Viewer, not members).
  bool get editsEvents => role.canEdit;

  bool get seesOthers => role.isConductor || role.isHelperRole;

  /// Status of others: the roles that may record attendance (not Viewer).
  bool get changesOthers => role.canAddAttendance;

  bool get canUse => role.canView;

  bool allows(AssistantCommand command) {
    if (!canUse) return false;
    return switch (command) {
      AttendanceRateCommand(subject: MeSubject()) => hasOwnPerson,
      AttendanceRateCommand() => seesOthers,
      EventOverviewCommand() => seesOthers,
      BirthdaysCommand() => seesOthers,
      NextEventCommand() => true,
      SongLastSungCommand() => true,
      HelpCommand() => true,
      // Own rows of all groups of the account (like the Übersicht); the rows
      // themselves are checked against the account when saving.
      SetStatusCommand(onlyMe: true) => true,
      SetStatusCommand() => changesOthers,
      PlannedAbsenceCommand(who: MeSubject()) => hasOwnPerson && (canSelfReportAbsence || canManageAbsences),
      PlannedAbsenceCommand() => canManageAbsences,
      CreateEventsCommand() => canCreateEvents,
      MoveEventCommand() => editsEvents,
      SetSongsCommand() => editsEvents,
      MyTasksCommand() => teamOrgEnabled && hasOwnPerson,
      EventSongsCommand() => true,
      CreateTaskCommand() => teamOrgEnabled && isTeamLeader,
      TakeDutyCommand() => hasOwnPerson,
      NewPersonCommand() => managesPeople,
      DraftMessageCommand() => managesPeople,
      UnsupportedCommand() => true,
    };
  }
}

// ---------------------------------------------------------------------------
// Package 2: limits of the changes (Schutzgrenzen, concept section 12).

/// At most this many status rows in one chat command.
const int assistantMaxChanges = 30;

/// From this many rows on the person confirms twice.
const int assistantConfirmTwiceFrom = 11;

/// Termine older than this many days are not changed by the chat.
const int assistantPastDays = 14;

/// Termine / absences further ahead than this are not changed (≈ 6 months).
const int assistantFutureDays = 183;

/// One person_attendances row a status change may touch.
typedef StatusRow =
    ({
      String id,
      int personId,
      int attendanceId,
      DateTime date,
      String? typeId,
      String? typeInfo,
      String? startTime,
      AttendanceStatus status,
      String? notes,
    });

/// The status that is written. Members only sign in, sign out or report
/// being late (like "Meine Termine"): "zu spät" becomes Verspätung gemeldet
/// and the leader statuses are refused (null).
AttendanceStatus? targetStatus(AssistantStatus s, {required bool self}) => switch (s) {
  AssistantStatus.present => AttendanceStatus.present,
  AssistantStatus.excused => AttendanceStatus.excused,
  AssistantStatus.lateExcused => AttendanceStatus.lateExcused,
  AssistantStatus.late => self ? AttendanceStatus.lateExcused : AttendanceStatus.late,
  AssistantStatus.absent => self ? null : AttendanceStatus.absent,
  AssistantStatus.neutral => self ? null : AttendanceStatus.neutral,
};

/// Whether a Termin on [date] may be changed by the chat today.
bool inChangeWindow(DateTime date, DateTime now) {
  final day = dayOf(date);
  final today = dayOf(now);
  return !day.isBefore(today.subtract(const Duration(days: assistantPastDays))) &&
      !day.isAfter(today.add(const Duration(days: assistantFutureDays)));
}

/// Why a row is left out of a change.
enum StatusSkip {
  /// Already has the status.
  same,

  /// Not allowed for this Termin (deadline over, registration fields,
  /// status not offered by the type, already signed out / marked absent).
  locked,

  /// Older than [assistantPastDays] days or further ahead than
  /// [assistantFutureDays].
  window,
}

/// Own row: the same rules as the buttons of "Meine Termine"
/// (self_service_event_actions.dart `quickActions`).
StatusSkip? selfStatusSkip({
  required AttendanceStatus current,
  required AttendanceStatus target,
  required bool signinOpen,
  required bool hasRegistrationFields,
  required bool typeAllowsTarget,
}) {
  if (current == target) return StatusSkip.same;
  if (target == AttendanceStatus.present) {
    // Zusagen: open deadline; registration fields need the form.
    return signinOpen && !hasRegistrationFields ? null : StatusSkip.locked;
  }
  // Absagen / Verspätung: blocked once signed out or marked absent.
  final blocked =
      current == AttendanceStatus.excused ||
      current == AttendanceStatus.lateExcused ||
      current == AttendanceStatus.absent;
  return blocked || !typeAllowsTarget ? StatusSkip.locked : null;
}

/// Whether an absence from [from] to [to] fits the limits: starts today at
/// the earliest and ends within [assistantFutureDays].
bool absenceInWindow(DateTime from, DateTime to, DateTime now) {
  final today = dayOf(now);
  return !dayOf(from).isBefore(today) &&
      !dayOf(to).isBefore(dayOf(from)) &&
      !dayOf(to).isAfter(today.add(const Duration(days: assistantFutureDays)));
}

/// New Termine and the new day of a moved Termin: from today up to
/// [assistantFutureDays] ahead.
bool inFutureWindow(DateTime day, DateTime now) {
  final d = dayOf(day);
  final today = dayOf(now);
  return !d.isBefore(today) && !d.isAfter(today.add(const Duration(days: assistantFutureDays)));
}

/// End time of a Termin whose start moves from [oldStart] to [newStart]:
/// keeps the length ("19:00–21:00" to 20:00 → 22:00). Null when there was
/// no end or a time does not parse.
String? shiftedEndTime(String? oldStart, String? oldEnd, String newStart) {
  int? minutes(String? t) {
    if (t == null || t.length < 5) return null;
    final h = int.tryParse(t.substring(0, 2));
    final m = int.tryParse(t.substring(3, 5));
    return h == null || m == null ? null : h * 60 + m;
  }

  final a = minutes(oldStart);
  final b = minutes(oldEnd);
  final c = minutes(newStart);
  if (a == null || b == null || c == null) return null;
  final end = (c + (b - a)) % (24 * 60);
  final e = end < 0 ? end + 24 * 60 : end;
  return '${(e ~/ 60).toString().padLeft(2, '0')}:${(e % 60).toString().padLeft(2, '0')}';
}

/// Entschuldigt and Verspätung need a reason, like the sign-out sheet of the
/// app (Matthias, 11.11.2026). Without one the chat asks for it.
bool statusNeedsReason(SetStatusCommand c) =>
    (c.status == AssistantStatus.excused || c.status == AssistantStatus.lateExcused) && c.reason == null;

// ---------------------------------------------------------------------------
// Package 4.

/// Due date of a task: from today up to [assistantFutureDays] ahead.
bool taskDueInWindow(DateTime due, DateTime now) => inFutureWindow(due, now);

/// Open tasks first by due date (without date last), then by title.
int compareTasksByDue(({String? dueDate, String title}) a, ({String? dueDate, String title}) b) {
  final da = a.dueDate;
  final db = b.dueDate;
  if (da != db) {
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Why the person cannot take over a duty (null: they can).
enum DutySkip {
  /// The type does not allow signing up yourself.
  notSelf,

  /// The person is not on this Termin.
  notMember,

  /// Already assigned / signed up.
  already,

  /// All places are taken.
  full,
}

DutySkip? dutySkip({
  required bool selfSignup,
  required bool isMember,
  required String? ownDutyState,
  required AttendanceStatus ownStatus,
  required int required,
  required int occupied,
}) {
  if (!selfSignup) return DutySkip.notSelf;
  if (!isMember) return DutySkip.notMember;
  final signedOut =
      ownStatus == AttendanceStatus.excused ||
      ownStatus == AttendanceStatus.lateExcused ||
      ownStatus == AttendanceStatus.absent;
  if (ownDutyState != null && ownDutyState.isNotEmpty && !signedOut) return DutySkip.already;
  if (occupied >= required) return DutySkip.full;
  return null;
}
