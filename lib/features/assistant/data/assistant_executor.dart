// Chat assistant: answers a checked command with the data the app loads
// itself (same providers, rights and tenant filter as the screens).
//
// Package 2 changes (status, planned absence) are two steps: [run] only
// builds a preview (nothing is written), [applyStatus] / [applyAbsence]
// save after the person confirmed it, through the same repositories as
// "Meine Termine", the Termin page and the absence sheets. Every saved
// change can be undone ([revertStatus], [revertAbsence]).
//
// Package 3 (Termine) works the same way: create through the shared create
// writer of both create pages, move like "Datum ändern", Werke through the
// history sync of the Termin page. Undo of a creation deletes exactly the
// Termine the chat created; nothing else is ever deleted.
//
// Package 4: a new task is created like the task sheet (undo deletes
// exactly that task; the push to the responsible person goes out only when
// tapped), a duty is taken over through `duty_take` like "Ich übernehme"
// (undo frees the own row again). A new person and a message are never
// saved here: the page opens the normal form / compose page prefilled.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/attendance_detail_providers.dart';
import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/attendance_type_providers.dart';
import '../../../core/providers/duty_providers.dart';
import '../../../core/providers/group_providers.dart';
import '../../../core/providers/player_absence_providers.dart';
import '../../../core/providers/conductor_providers.dart';
import '../../../core/providers/player_providers.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../core/providers/role_permission_providers.dart';
import '../../../core/providers/self_service_providers.dart';
import '../../../core/providers/signout_providers.dart';
import '../../../core/providers/song_providers.dart';
import '../../../core/providers/team_org_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/utils/attendance_logic_utils.dart' show dateChangeStatusUpdates, showSongsForType;
import '../../../core/utils/duty_utils.dart' show occupiesDutyRaw;
import '../../../core/utils/event_list_utils.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/player_absence/player_absence.dart';
import '../../../data/models/song/song.dart';
import '../../../data/models/team_org/team_org.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../../data/repositories/attendance_repository.dart' show AttendanceRepository;
import '../../../data/repositories/duty_repository.dart' show DutyRepository, DutyNotifyType, DutyTakeResult;
import '../../../data/repositories/player_absence_repository.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/sign_in_out_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../l10n/l10n.dart';
import '../../attendance/presentation/attendance_create_writes.dart';
import '../../attendance/presentation/attendance_song_history.dart';
import '../../attendance/presentation/widgets/attendance_date_change.dart'
    show calendarDayDifference, shiftByCalendarDays, shiftDeadline;
import '../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import '../../help/data/help_content_service.dart';
import '../../parents/data/providers/parents_providers.dart'
    show ChildPersonAttendance, childrenAttendancesProvider, parentChildrenProvider;
import '../../self_service/data/providers/upcoming_songs_provider.dart' show signoutAttendanceSongsProvider;
import '../../team_organization/team_org_utils.dart' show isTeamOrgEnabled;
import 'assistant_command.dart';
import 'assistant_logic.dart';
import 'assistant_reply.dart';

part 'assistant_executor_status.dart';
part 'assistant_executor_events.dart';
part 'assistant_executor_tasks.dart';

class AssistantExecutor {
  /// The repositories are bound to the tenant here, before the first await
  /// (a tenant switch while the answer loads never reads another tenant).
  AssistantExecutor(this.ref, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _tenantId = ref.read(currentTenantIdProvider),
      _reads = ref.read(assistantRepositoryForTenantProvider(ref.read(currentTenantIdProvider))),
      _events = ref.read(attendanceRepositoryWithTenantProvider),
      _signs = ref.read(signInOutRepositoryForTenantProvider(ref.read(currentTenantIdProvider))),
      _absences = ref.read(playerAbsenceRepositoryForTenantProvider(ref.read(currentTenantIdProvider))),
      _duty = ref.read(dutyRepositoryForTenantProvider(ref.read(currentTenantIdProvider))),
      _tasks = ref.read(taskRepositoryForTenantProvider(ref.read(currentTenantIdProvider))),
      _team = ref.read(protocolRepositoryForTenantProvider(ref.read(currentTenantIdProvider)));

  final Ref ref;
  final DateTime Function() _clock;
  final int? _tenantId;

  final AssistantRepository _reads;
  final AttendanceRepository _events;
  final SignInOutRepository _signs;
  final PlayerAbsenceRepository _absences;
  final DutyRepository _duty;
  final TaskRepository _tasks;
  final ProtocolRepository _team;

  /// [create]: also load the create permission (a fetch for helpers).
  /// [team]: also load whether the Teamorganisation is on (tasks).
  Future<AssistantAccess> access({bool create = false, bool team = false}) async {
    final role = ref.read(currentRoleProvider);
    Person? own;
    try {
      own = await ref.read(currentSelfServicePlayerProvider.future);
    } catch (_) {
      own = null;
    }
    return AssistantAccess(
      role: role,
      hasOwnPerson: own?.id != null,
      canManageAbsences: ref.read(canManagePlannedAbsencesProvider),
      canSelfReportAbsence: ref.read(canSelfReportAbsenceProvider),
      canCreateEvents: create && await _mayCreate(),
      childCount: role.isParent ? await _childCount() : 0,
      teamOrgEnabled: team && await _teamOrgOn(),
      isTeamLeader: ref.read(isTeamLeaderProvider),
    );
  }

  /// Children of a parent account (Elternportal); any error counts as none.
  Future<int> _childCount() async {
    try {
      return (await ref.read(parentChildrenProvider.future)).where((p) => p.id != null).length;
    } catch (_) {
      return 0;
    }
  }

  /// Freshly loaded protocol types; any error counts as off.
  Future<bool> _teamOrgOn() async {
    try {
      return isTeamOrgEnabled(await ref.read(protocolTypesProvider.future));
    } catch (_) {
      return false;
    }
  }

  /// SOL_FIX2: the freshly loaded create permission; any error denies.
  Future<bool> _mayCreate() => confirmCanCreateAttendance(() => ref.read(canCreateAttendanceConfirmedProvider.future));


  Future<AssistantReply> run(AssistantCommand command) async {
    final rights = await access(
      create: command is CreateEventsCommand,
      team: command is MyTasksCommand || command is CreateTaskCommand,
    );
    if (_needsOwnPerson(command) && !rights.hasOwnPerson) {
      return const NoticeReply(AssistantNotice.noOwnPerson);
    }
    if (!rights.allows(command)) {
      return NoticeReply(command is PlannedAbsenceCommand ? AssistantNotice.noAbsenceRights : AssistantNotice.noRights);
    }
    if (command is SetStatusCommand && statusNeedsReason(command)) {
      return const NoticeReply(AssistantNotice.excuseNeedsReason);
    }
    return switch (command) {
      AttendanceRateCommand() => _rate(command),
      EventOverviewCommand() => _eventOverview(command),
      NextEventCommand() => _nextEvent(command),
      BirthdaysCommand() => _birthdays(command),
      SongLastSungCommand() => _song(command),
      HelpCommand() => _help(command),
      SetStatusCommand() => command.onlyMe
          ? _ownStatus(command)
          : rights.forChildren(command)
              ? _childrenStatus(command)
              : _othersStatus(command),
      PlannedAbsenceCommand() => _absencePreview(command, rights),
      CreateEventsCommand() => _createPreview(command),
      MoveEventCommand() => _movePreview(command),
      SetSongsCommand() => _songsPreview(command),
      MyTasksCommand() => _myTasks(),
      EventSongsCommand() => _eventSongs(command),
      CreateTaskCommand() => _taskPreview(command),
      TakeDutyCommand() => _dutyPreview(command),
      NewPersonCommand() => _personDraft(command),
      DraftMessageCommand() => _messageDraft(command),
      UnsupportedCommand(:final isChange) => NoticeReply(
        isChange ? AssistantNotice.changeLater : AssistantNotice.notUnderstood,
      ),
    };
  }

  DateTime get _seasonStart {
    final s = ref.read(currentTenantProvider)?.seasonStart;
    return (s == null ? null : DateTime.tryParse(s)) ?? DateTime(2023, 1, 1);
  }

  Future<List<AttendanceType>> _types() => ref.read(attendanceTypesProvider.future);

  AttendanceType? _type(List<AttendanceType> types, String? name) {
    if (name == null) return null;
    final m = bestMatches(name, types, (t) => [t.name]);
    return m.isEmpty ? null : m.first;
  }

  Future<List<Person>> _activePlayers() async =>
      (await ref.read(playersProvider.future)).where((p) => p.left == null && p.id != null).toList();

  Group? _group(List<Group> groups, String name) {
    final m = bestMatches(name, groups, (g) => [g.name, if (g.shortName != null) g.shortName!]);
    return m.isEmpty ? null : m.first;
  }


  Future<AssistantReply> _rate(AttendanceRateCommand c) async {
    final now = _clock();
    final range = resolvePeriod(c.period, now, _seasonStart);
    final types = await _types();
    final askedType = _type(types, c.typeName);
    final counted =
        askedType?.id != null
            ? {askedType!.id!}
            : {
              for (final t in types)
                if (t.includeInAverage && t.id != null) t.id!,
            };
    final duty = {
      for (final t in types)
        if (t.dutyMode && t.id != null) t.id!,
    };
    final shiftExcused = ref.read(currentTenantProvider)?.shiftExcusedAsPresent ?? false;

    List<Person> people;
    String? subjectName;
    int? personId;
    final subject = c.subject;
    switch (subject) {
      case ChildrenSubject():
        return const NoticeReply(AssistantNotice.notUnderstood);
      case MeSubject():
        final own = await ref.read(currentSelfServicePlayerProvider.future);
        if (own?.id == null) return const NoticeReply(AssistantNotice.noOwnPerson);
        people = [own!];
        personId = own.id;
      case PersonIdSubject(personId: final id):
        final p = (await _activePlayers()).where((p) => p.id == id).toList();
        if (p.isEmpty) return const NoticeReply(AssistantNotice.personNotFound);
        people = p;
        subjectName = _name(p.first);
        personId = id;
      case PersonSubject(:final name):
        final players = await _activePlayers();
        final matches = bestMatches(name, players, (p) => personNames(p.firstName, p.lastName));
        if (matches.isEmpty) return NoticeReply(AssistantNotice.personNotFound, subject: name);
        if (matches.length > 1) {
          final groups = await ref.read(groupsProvider.future);
          String label(Person p) {
            final g = groups.where((g) => g.id == p.instrument).map((g) => g.name).firstOrNull;
            return g == null ? _name(p) : '${_name(p)} · $g';
          }

          return ChoiceReply(
            query: name,
            options: [
              for (final p in matches.take(6))
                (
                  label: label(p),
                  command: AttendanceRateCommand(
                    subject: PersonIdSubject(p.id!),
                    period: c.period,
                    typeName: c.typeName,
                  ),
                ),
            ],
          );
        }
        people = matches;
        subjectName = _name(matches.first);
        personId = matches.first.id;
      case GroupSubject(:final name):
        final group = _group(await ref.read(groupsProvider.future), name);
        if (group == null) return NoticeReply(AssistantNotice.groupNotFound, subject: name);
        people = (await _activePlayers()).where((p) => p.instrument == group.id && !p.paused).toList();
        subjectName = group.name;
      case AllSubject():
        people = (await _activePlayers()).where((p) => !p.paused).toList();
    }

    final rows = await _reads.getRateRows(personIds: [for (final p in people) p.id!], range: range);
    final rate = computeRate(
      rows,
      range: range,
      today: now,
      countedTypeIds: counted,
      dutyTypeIds: duty,
      shiftExcusedAsPresent: shiftExcused,
    );
    if (rate.total == 0) return const NoticeReply(AssistantNotice.noData);
    final names = {for (final p in people) p.id!: _name(p)};
    final lowest =
        people.length > 1
            ? [
              for (final e in ratesPerPerson(
                rows,
                range: range,
                today: now,
                countedTypeIds: counted,
                dutyTypeIds: duty,
                shiftExcusedAsPresent: shiftExcused,
              ).take(5))
                if (names[e.personId] != null) (name: names[e.personId]!, percent: e.rate.percent!),
            ]
            : const <({String name, int percent})>[];
    return RateReply(
      subjectName: subjectName,
      isMe: subject is MeSubject,
      range: range,
      rate: rate,
      typeName: askedType?.name,
      lowest: lowest,
      personId: personId,
    );
  }

  String _title(Attendance a, List<AttendanceType> types) {
    if ((a.typeInfo ?? '').isNotEmpty) return a.typeInfo!;
    final t = types.where((t) => t.id == a.typeId).map((t) => t.name).firstOrNull;
    return t ?? a.displayTitle;
  }

  Future<Attendance?> _findEvent(EventRef event, AttendanceType? type) async {
    final day = resolveEventDay(event, _clock());
    bool fits(Attendance a) => type == null || a.typeId == type.id;
    if (day == null) {
      final today = dayOf(_clock());
      final upcoming = await ref.read(upcomingAttendancesProvider.future);
      return upcoming.where((a) => fits(a) && !dayOf(DateTime.parse(a.date).toLocal()).isBefore(today)).firstOrNull;
    }
    final onDay = await _events.getAttendancesByDate(day);
    return onDay.where(fits).firstOrNull;
  }

  Future<AssistantReply> _eventOverview(EventOverviewCommand c) async {
    final types = await _types();
    final event = await _findEvent(c.event, _type(types, c.typeName));
    if (event?.id == null) return const NoticeReply(AssistantNotice.noEvent);
    final groups = await ref.read(groupsProvider.future);
    Group? onlyGroup;
    if (c.group != null) {
      onlyGroup = _group(groups, c.group!);
      if (onlyGroup == null) return NoticeReply(AssistantNotice.groupNotFound, subject: c.group);
    }
    final players = {
      for (final p in await ref.read(playersProvider.future))
        if (p.id != null) p.id!: p,
    };
    final statuses = await _reads.getEventStatuses(event!.id!);
    final counts = <int?, ({int present, int absent, int open})>{};
    final open = <String>[];
    final absent = <String>[];
    for (final s in statuses) {
      final person = players[s.personId];
      if (person == null) continue;
      if (onlyGroup != null && person.instrument != onlyGroup.id) continue;
      final c0 = counts[person.instrument] ?? (present: 0, absent: 0, open: 0);
      switch (s.status) {
        case AttendanceStatus.present:
        case AttendanceStatus.late:
        case AttendanceStatus.lateExcused:
          counts[person.instrument] = (present: c0.present + 1, absent: c0.absent, open: c0.open);
        case AttendanceStatus.excused:
        case AttendanceStatus.absent:
          counts[person.instrument] = (present: c0.present, absent: c0.absent + 1, open: c0.open);
          absent.add(_name(person));
        case AttendanceStatus.neutral:
          counts[person.instrument] = (present: c0.present, absent: c0.absent, open: c0.open + 1);
          open.add(_name(person));
      }
    }
    final groupNames = {for (final g in groups) g.id: g.name};
    final order = {for (var i = 0; i < groups.length; i++) groups[i].id: i};
    final keys = counts.keys.toList()..sort((a, b) => (order[a] ?? 999).compareTo(order[b] ?? 999));
    return EventReply(
      attendanceId: event.id!,
      title: _title(event, types),
      date: DateTime.parse(event.date).toLocal(),
      startTime: event.startTime,
      groups: [
        for (final k in keys)
          (name: groupNames[k] ?? '–', present: counts[k]!.present, absent: counts[k]!.absent, open: counts[k]!.open),
      ],
      open: open..sort(),
      absent: absent..sort(),
    );
  }

  Future<AssistantReply> _nextEvent(NextEventCommand c) async {
    // Members: the next own Termin in any group (like the Übersicht).
    final role = ref.read(currentRoleProvider);
    if (role.isParent) {
      // Parents: the next Termin of their children (Elternportal).
      final types = await _types();
      final type = _type(types, c.typeName);
      final next = (await ref.read(childrenAttendancesProvider.future))
          .where((a) => a.attendanceId != null && a.isUpcoming && EventListUtils.parse(a.date) != null)
          .where((a) => type == null || a.typeId == type.id)
          .toList()
        ..sort((a, b) => EventListUtils.parse(a.date)!.compareTo(EventListUtils.parse(b.date)!));
      if (next.isNotEmpty) {
        final a = next.first;
        return NextEventReply(
          attendanceId: a.attendanceId!,
          title: a.displayTitle,
          date: EventListUtils.parse(a.date)!,
          startTime: a.startTime,
          endTime: a.endTime,
          place: a.place,
        );
      }
    }
    if (!(role.isConductor || role.isHelperRole)) {
      final own = await _ownUpcomingAcrossTenants(c.typeName);
      if (own.isEmpty) return const NoticeReply(AssistantNotice.noEvent);
      final a = own.first;
      return NextEventReply(
        attendanceId: a.attendanceId!,
        title: a.eventTitle,
        date: _when(a),
        startTime: a.startTime ?? a.attendanceType?.startTime,
        endTime: a.endTime ?? a.attendanceType?.endTime,
        place: a.place,
        tenantName: a.tenantId == _tenantId ? null : a.tenantName,
      );
    }
    final types = await _types();
    final event = await _findEvent(const NextEventRef(), _type(types, c.typeName));
    if (event?.id == null) return const NoticeReply(AssistantNotice.noEvent);
    return NextEventReply(
      attendanceId: event!.id!,
      title: _title(event, types),
      date: DateTime.parse(event.date).toLocal(),
      startTime: event.startTime,
      endTime: event.endTime,
      place: event.place,
    );
  }

  Future<AssistantReply> _birthdays(BirthdaysCommand c) async {
    final now = _clock();
    final range = resolvePeriod(c.period, now, _seasonStart);
    final people = <({String name, DateTime date, int age})>[];
    for (final p in await _activePlayers()) {
      final d = birthdayIn(p.birthday, range);
      if (d != null) people.add((name: _name(p), date: d, age: ageOn(p.birthday!, d)));
    }
    if (people.isEmpty) return const NoticeReply(AssistantNotice.noBirthdays);
    people.sort((a, b) => a.date.compareTo(b.date));
    return BirthdaysReply(range: range, people: people);
  }


  Future<AssistantReply> _song(SongLastSungCommand c) async {
    final songs = (await ref.read(songsProvider.future)).where((s) => s.id != null).toList();
    final matches = _matchSongs(c.title, songs);
    if (matches.isEmpty) return NoticeReply(AssistantNotice.songNotFound, subject: c.title);
    final song = matches.first;
    final last = song.lastSung == null ? null : DateTime.tryParse(song.lastSung!)?.toLocal();
    return SongReply(songId: song.id!, name: song.name, number: song.number, lastSung: last);
  }

  Future<AssistantReply> _help(HelpCommand c) async {
    final found = ref.read(helpContentServiceProvider).search(c.query).articles.take(3).toList();
    if (found.isEmpty) return NoticeReply(AssistantNotice.noHelp, subject: c.query);
    return HelpReply([for (final a in found) (id: a.id, title: a.title)]);
  }
}

/// A command about the person themself without an own person in the tenant.
bool _needsOwnPerson(AssistantCommand c) => switch (c) {
  AttendanceRateCommand(subject: MeSubject()) => true,
  // Only "me": own rows in any group, no own person here needed.
  SetStatusCommand(:final who, :final onlyMe) => !onlyMe && who.any((w) => w is MeSubject),
  PlannedAbsenceCommand(who: MeSubject()) => true,
  MyTasksCommand() => true,
  TakeDutyCommand() => true,
  CreateTaskCommand(who: MeSubject()) => true,
  _ => false,
};

String _name(Person p) => '${p.firstName} ${p.lastName}'.trim();

/// Werke for a title or a number ("Nr. 12"), best first.
List<Song> _matchSongs(String title, List<Song> songs) {
  final number = int.tryParse(
    RegExp(r'^(?:nr\.?|no\.?|#)?\s*(\d+)$', caseSensitive: false).firstMatch(title.trim())?.group(1) ?? '',
  );
  final byNumber = number == null ? <Song>[] : songs.where((s) => s.number == number).toList();
  return byNumber.isNotEmpty ? byNumber : bestMatches(title, songs, (s) => [s.name]);
}
