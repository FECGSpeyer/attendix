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

  /// A command about the person themself without an own person in the tenant.
  static bool _needsOwnPerson(AssistantCommand c) => switch (c) {
    AttendanceRateCommand(subject: MeSubject()) => true,
    // Only "me": own rows in any group, no own person here needed.
    SetStatusCommand(:final who, :final onlyMe) => !onlyMe && who.any((w) => w is MeSubject),
    PlannedAbsenceCommand(who: MeSubject()) => true,
    MyTasksCommand() => true,
    TakeDutyCommand() => true,
    CreateTaskCommand(who: MeSubject()) => true,
    _ => false,
  };

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

  static String _name(Person p) => '${p.firstName} ${p.lastName}'.trim();

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

  /// Werke for a title or a number ("Nr. 12"), best first.
  static List<Song> _matchSongs(String title, List<Song> songs) {
    final number = int.tryParse(
      RegExp(r'^(?:nr\.?|no\.?|#)?\s*(\d+)$', caseSensitive: false).firstMatch(title.trim())?.group(1) ?? '',
    );
    final byNumber = number == null ? <Song>[] : songs.where((s) => s.number == number).toList();
    return byNumber.isNotEmpty ? byNumber : bestMatches(title, songs, (s) => [s.name]);
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

  // -------------------------------------------------------------------------
  // Package 2: status and planned absence.

  bool _inDay(DateTime date, DateTime day) => dayOf(date) == dayOf(day);

  /// Own rows of upcoming Termine in ALL groups of the account (like the
  /// Übersicht), optionally only of the type named [typeName] (matched by
  /// name, the types differ per group). Unassigned duties never count.
  Future<List<CrossTenantPersonAttendance>> _ownUpcomingAcrossTenants(String? typeName) async {
    final all = await ref.read(allPersonAttendancesAcrossTenantsProvider.future);
    final now = _clock();
    var rows =
        all
            .where(
              (a) =>
                  a.isMember &&
                  a.id != null &&
                  a.attendanceId != null &&
                  !overviewHasEnded(a, now: now) &&
                  !isUnassignedDutyAttendance(a),
            )
            .toList()
          ..sort((a, b) => _when(a).compareTo(_when(b)));
    if (typeName != null) {
      final names = {
        for (final a in rows)
          if (a.attendanceType != null) a.attendanceType!.name,
      };
      final best = bestMatches(typeName, names, (n) => [n]).toSet();
      if (best.isEmpty) return const [];
      rows = rows.where((a) => best.contains(a.attendanceType?.name)).toList();
    }
    return rows;
  }

  static DateTime _when(CrossTenantPersonAttendance a) => EventListUtils.parse(a.date) ?? DateTime(1970);

  /// Own status in all groups: the rows and the rules of "Meine Termine" /
  /// the Übersicht of each group.
  Future<AssistantReply> _ownStatus(SetStatusCommand c) async {
    final target = targetStatus(c.status, self: true);
    if (target == null) return const NoticeReply(AssistantNotice.selfStatusNotAllowed);
    final now = _clock();
    var rows = await _ownUpcomingAcrossTenants(c.typeName);
    if (c.period != null) {
      final range = resolvePeriod(c.period!, now, _seasonStart);
      rows = rows.where((a) => !dayOf(_when(a)).isBefore(range.from) && !dayOf(_when(a)).isAfter(range.to)).toList();
    } else {
      final day = resolveEventDay(c.event!, now);
      rows = day == null ? rows.take(1).toList() : rows.where((a) => _inDay(_when(a), day)).toList();
    }
    if (rows.isEmpty) return const NoticeReply(AssistantNotice.noEvent);

    final own = await ref.read(currentSelfServicePlayerProvider.future);
    final name = own == null ? '' : _name(own);
    final changes = <StatusChange>[];
    var locked = 0;
    var window = 0;
    for (final a in rows) {
      if (!inChangeWindow(_when(a), now)) {
        window++;
        continue;
      }
      final offered = a.attendanceType?.availableStatuses;
      final askFor = target == AttendanceStatus.lateExcused ? AttendanceStatus.late : AttendanceStatus.excused;
      final skip = selfStatusSkip(
        current: a.status,
        target: target,
        signinOpen: EventListUtils.isSigninOpen(a.deadline),
        hasRegistrationFields: a.registrationFields.isNotEmpty,
        typeAllowsTarget: offered == null || offered.contains(askFor),
      );
      if (skip == StatusSkip.locked) locked++;
      if (skip != null) continue;
      changes.add(
        StatusChange(
          personAttendanceId: a.id!,
          attendanceId: a.attendanceId!,
          personName: name,
          title: a.eventTitle,
          date: _when(a),
          oldStatus: a.status,
          oldNotes: a.notes,
          newStatus: target,
          occupiesDuty: target != AttendanceStatus.present && a.isDutyType && occupiesDutyRaw(a.dutyState, a.status),
          tenantId: a.tenantId,
          tenantName: a.tenantName,
        ),
      );
    }
    return _statusPreview(
      StatusPlan(
        self: true,
        status: target,
        reason: c.reason,
        changes: changes,
        skippedLocked: locked,
        skippedWindow: window,
      ),
    );
  }

  /// Parents: their children's rows, with the rules and the path of the
  /// Elternportal (leaders are told like there, `isParents`).
  Future<AssistantReply> _childrenStatus(SetStatusCommand c) async {
    final target = targetStatus(c.status, self: true);
    if (target == null) return const NoticeReply(AssistantNotice.selfStatusNotAllowed);
    final children = (await ref.read(parentChildrenProvider.future)).where((p) => p.id != null).toList();
    if (children.isEmpty) return const NoticeReply(AssistantNotice.noRights);
    final ids = <int>{};
    for (var i = 0; i < c.who.length; i++) {
      final w = c.who[i];
      switch (w) {
        case ChildrenSubject():
          ids.addAll(children.map((p) => p.id!));
        case PersonIdSubject(:final personId):
          if (!children.any((p) => p.id == personId)) return const NoticeReply(AssistantNotice.personNotFound);
          ids.add(personId);
        case PersonSubject(:final name):
          final matches = bestMatches(name, children, (p) => personNames(p.firstName, p.lastName));
          if (matches.isEmpty) return NoticeReply(AssistantNotice.personNotFound, subject: name);
          if (matches.length > 1) {
            return _whoChoice(name, matches, (p) => c.withWho([...c.who]..[i] = PersonIdSubject(p.id!)));
          }
          ids.add(matches.first.id!);
        default:
          return const NoticeReply(AssistantNotice.noRights);
      }
    }
    final now = _clock();
    final types = await _types();
    final type = _type(types, c.typeName);
    if (c.typeName != null && type == null) return const NoticeReply(AssistantNotice.noEvent);
    DateTime? when(ChildPersonAttendance a) => EventListUtils.parse(a.date);
    var rows = (await ref.read(childrenAttendancesProvider.future))
        .where((a) =>
            a.id != null &&
            a.attendanceId != null &&
            ids.contains(a.childId) &&
            a.isUpcoming &&
            when(a) != null &&
            (type == null || a.typeId == type.id))
        .toList()
      ..sort((a, b) => when(a)!.compareTo(when(b)!));
    if (c.period != null) {
      final range = resolvePeriod(c.period!, now, _seasonStart);
      rows = rows.where((a) => !dayOf(when(a)!).isBefore(range.from) && !dayOf(when(a)!).isAfter(range.to)).toList();
    } else {
      final day = resolveEventDay(c.event!, now);
      // "Der nächste Termin": the next Termin with all its children's rows.
      final firstId = rows.firstOrNull?.attendanceId;
      rows = day == null ? rows.where((a) => a.attendanceId == firstId).toList() : rows.where((a) => _inDay(when(a)!, day)).toList();
    }
    if (rows.isEmpty) return const NoticeReply(AssistantNotice.noEvent);
    final names = {for (final p in children) p.id!: _name(p)};
    final changes = <StatusChange>[];
    var locked = 0;
    var window = 0;
    for (final a in rows) {
      if (!inChangeWindow(when(a)!, now)) {
        window++;
        continue;
      }
      final offered = types.where((t) => t.id == a.typeId).firstOrNull?.availableStatuses;
      final askFor = target == AttendanceStatus.lateExcused ? AttendanceStatus.late : AttendanceStatus.excused;
      final skip = selfStatusSkip(
        current: a.status,
        target: target,
        signinOpen: EventListUtils.isSigninOpen(a.deadline),
        hasRegistrationFields: false,
        typeAllowsTarget: offered == null || offered.contains(askFor),
      );
      if (skip == StatusSkip.locked) locked++;
      if (skip != null) continue;
      changes.add(
        StatusChange(
          personAttendanceId: a.id!,
          attendanceId: a.attendanceId!,
          personName: names[a.childId] ?? a.childName,
          title: a.displayTitle,
          date: when(a)!,
          oldStatus: a.status,
          oldNotes: a.notes,
          newStatus: target,
        ),
      );
    }
    return _statusPreview(
      StatusPlan(
        self: false,
        parents: true,
        status: target,
        reason: c.reason,
        changes: changes,
        skippedLocked: locked,
        skippedWindow: window,
      ),
    );
  }

  AssistantReply _statusPreview(StatusPlan plan) {
    if (plan.changes.length > assistantMaxChanges) {
      return NoticeReply(AssistantNotice.tooManyChanges, count: plan.changes.length);
    }
    if (plan.changes.isEmpty) {
      return NoticeReply(AssistantNotice.nothingToChange, count: plan.skippedLocked + plan.skippedWindow);
    }
    return StatusPreviewReply(plan);
  }

  /// "Welchen Jonas meinst du?" for one entry of a list of people.
  Future<ChoiceReply> _whoChoice(String query, List<Person> matches, AssistantCommand Function(Person) command) async {
    final groups = await ref.read(groupsProvider.future);
    String label(Person p) {
      final g = groups.where((g) => g.id == p.instrument).map((g) => g.name).firstOrNull;
      return g == null ? _name(p) : '${_name(p)} · $g';
    }

    return ChoiceReply(
      query: query,
      options: [for (final p in matches.take(6)) (label: label(p), command: command(p))],
    );
  }

  /// Status of others (leaders): the rows of the Termin page.
  Future<AssistantReply> _othersStatus(SetStatusCommand c) async {
    final target = targetStatus(c.status, self: false)!;
    final now = _clock();
    final players = await _activePlayers();
    final byId = {for (final p in players) p.id!: p};
    final ids = <int>{};
    for (var i = 0; i < c.who.length; i++) {
      final w = c.who[i];
      switch (w) {
        case MeSubject():
          final own = await ref.read(currentSelfServicePlayerProvider.future);
          if (own?.id == null) return const NoticeReply(AssistantNotice.noOwnPerson);
          ids.add(own!.id!);
        case PersonIdSubject(:final personId):
          if (!byId.containsKey(personId)) return const NoticeReply(AssistantNotice.personNotFound);
          ids.add(personId);
        case PersonSubject(:final name):
          final matches = bestMatches(name, players, (p) => personNames(p.firstName, p.lastName));
          if (matches.isEmpty) return NoticeReply(AssistantNotice.personNotFound, subject: name);
          if (matches.length > 1) {
            return _whoChoice(name, matches, (p) => c.withWho([...c.who]..[i] = PersonIdSubject(p.id!)));
          }
          ids.add(matches.first.id!);
        case GroupSubject(:final name):
          final group = _group(await ref.read(groupsProvider.future), name);
          if (group == null) return NoticeReply(AssistantNotice.groupNotFound, subject: name);
          ids.addAll(players.where((p) => p.instrument == group.id && !p.paused).map((p) => p.id!));
        case AllSubject():
        case ChildrenSubject():
          return const NoticeReply(AssistantNotice.notUnderstood);
      }
    }
    if (ids.isEmpty) return const NoticeReply(AssistantNotice.personNotFound);

    final types = await _types();
    final type = _type(types, c.typeName);
    List<StatusRow> rows;
    if (c.period != null) {
      final range = resolvePeriod(c.period!, now, _seasonStart);
      rows =
          (await _reads.getStatusRows(
            personIds: ids.toList(),
            range: range,
          )).where((r) => type == null || r.typeId == type.id).toList();
    } else {
      final event = await _findEvent(c.event!, type);
      if (event?.id == null) return const NoticeReply(AssistantNotice.noEvent);
      rows = await _reads.getStatusRows(personIds: ids.toList(), attendanceId: event!.id!);
    }
    if (rows.isEmpty) return const NoticeReply(AssistantNotice.noEvent);

    String title(StatusRow r) {
      if ((r.typeInfo ?? '').isNotEmpty) return r.typeInfo!;
      return types.where((t) => t.id == r.typeId).map((t) => t.name).firstOrNull ?? _day(r.date);
    }

    final changes = <StatusChange>[];
    var window = 0;
    for (final r in rows) {
      if (!inChangeWindow(r.date, now)) {
        window++;
        continue;
      }
      if (r.status == target) continue;
      final p = byId[r.personId];
      if (p == null) continue;
      changes.add(
        StatusChange(
          personAttendanceId: r.id,
          attendanceId: r.attendanceId,
          personName: _name(p),
          title: title(r),
          date: r.date,
          oldStatus: r.status,
          oldNotes: r.notes,
          newStatus: target,
        ),
      );
    }
    changes.sort((a, b) {
      final d = a.date.compareTo(b.date);
      return d != 0 ? d : a.personName.compareTo(b.personName);
    });
    return _statusPreview(
      StatusPlan(self: false, status: target, reason: c.reason, changes: changes, skippedWindow: window),
    );
  }

  static String _day(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _refreshStatuses({required bool self}) {
    if (self) {
      ref.invalidate(signoutDataProvider);
      ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
      ref.invalidate(upcomingDutyTermineProvider);
      ref.invalidate(dutyTermineByIdProvider);
      ref.invalidate(myDutyOverviewProvider);
    }
    ref.invalidate(realtimeAttendanceListProvider);
  }

  /// Saves a confirmed status preview. Returns the number of rows written.
  Future<int> applyStatus(StatusPlan plan) async {
    final status = plan.status;
    var count = 0;
    if (plan.parents) {
      // Like the Elternportal: sign in one by one, sign out with isParents.
      if (status == AttendanceStatus.present) {
        for (final c in plan.changes) {
          await _signs.signIn(c.personAttendanceId, SignInType.fromStatus(c.oldStatus), notes: plan.reason ?? '');
          count++;
        }
      } else {
        await _signs.signOut(
          [for (final c in plan.changes) c.personAttendanceId],
          plan.reason ?? '',
          isLateComing: status == AttendanceStatus.lateExcused,
          isParents: true,
        );
        count = plan.changes.length;
      }
      ref.invalidate(childrenAttendancesProvider);
      _refreshStatuses(self: false);
      return count;
    }
    if (plan.self) {
      // Own rows may lie in other groups (Übersicht): ownership is checked
      // per row by the account (ownAcrossTenants), like the Übersicht does.
      if (status == AttendanceStatus.present) {
        for (final c in plan.changes) {
          await _signs.signIn(
            c.personAttendanceId,
            SignInType.fromStatus(c.oldStatus),
            notes: plan.reason ?? '',
            ownAcrossTenants: true,
          );
          count++;
        }
      } else {
        // One call per group, so each group's leaders get their notification.
        final byTenant = <int?, List<StatusChange>>{};
        for (final c in plan.changes) {
          byTenant.putIfAbsent(c.tenantId, () => []).add(c);
        }
        for (final entry in byTenant.entries) {
          await _signs.signOut(
            [for (final c in entry.value) c.personAttendanceId],
            plan.reason ?? '',
            isLateComing: status == AttendanceStatus.lateExcused,
            isSelf: true,
            ownAcrossTenants: true,
          );
          count += entry.value.length;
          // Like "Meine Termine": a cancelled own duty asks for a substitute.
          final duty =
              entry.key == null || entry.key == _tenantId
                  ? _duty
                  : ref.read(dutyRepositoryForTenantProvider(entry.key));
          for (final id in {
            for (final c in entry.value)
              if (c.occupiesDuty) c.attendanceId,
          }) {
            unawaited(duty.notify(DutyNotifyType.understaffed, id));
          }
        }
      }
    } else {
      for (final c in plan.changes) {
        await _events.updatePersonAttendance(c.personAttendanceId, {
          'status': status.value,
          if (plan.reason != null) 'notes': plan.reason,
        });
        count++;
      }
    }
    _refreshStatuses(self: plan.self);
    return count;
  }

  /// "Rückgängig": every row back to its status and note before the change.
  Future<void> revertStatus(StatusPlan plan) async {
    if (plan.parents) {
      for (final c in plan.changes) {
        await _events.updatePersonAttendance(c.personAttendanceId, {
          'status': c.oldStatus.value,
          'notes': c.oldNotes ?? '',
        });
      }
      ref.invalidate(childrenAttendancesProvider);
      _refreshStatuses(self: false);
      return;
    }
    if (plan.self) {
      await _signs.restoreOwnStatuses([
        for (final c in plan.changes) (id: c.personAttendanceId, status: c.oldStatus, notes: c.oldNotes ?? ''),
      ], acrossTenants: true);
    } else {
      for (final c in plan.changes) {
        await _events.updatePersonAttendance(c.personAttendanceId, {
          'status': c.oldStatus.value,
          'notes': c.oldNotes ?? '',
        });
      }
    }
    _refreshStatuses(self: plan.self);
  }

  Future<AssistantReply> _absencePreview(PlannedAbsenceCommand c, AssistantAccess rights) async {
    final now = _clock();
    Person? person;
    final isMe = c.who is MeSubject;
    switch (c.who) {
      case MeSubject():
        person = await ref.read(currentSelfServicePlayerProvider.future);
        if (person?.id == null) return const NoticeReply(AssistantNotice.noOwnPerson);
      case PersonIdSubject(:final personId):
        person = (await _activePlayers()).where((p) => p.id == personId).firstOrNull;
        if (person == null) return const NoticeReply(AssistantNotice.personNotFound);
      case PersonSubject(:final name):
        final players = await _activePlayers();
        final matches = bestMatches(name, players, (p) => personNames(p.firstName, p.lastName));
        if (matches.isEmpty) return NoticeReply(AssistantNotice.personNotFound, subject: name);
        if (matches.length > 1) {
          return _whoChoice(name, matches, (p) => c.withWho(PersonIdSubject(p.id!)));
        }
        person = matches.first;
      default:
        return const NoticeReply(AssistantNotice.notUnderstood);
    }
    // Another person picked by name may still be the own one.
    final own = await ref.read(currentSelfServicePlayerProvider.future);
    final self = isMe || (own?.id != null && own!.id == person!.id);
    if (!self && !rights.canManageAbsences) return const NoticeReply(AssistantNotice.noAbsenceRights);
    if (!absenceInWindow(c.from, c.to, now)) return const NoticeReply(AssistantNotice.absenceOutOfRange);

    // Own absence: only the Termine "Meine Termine" lists (like the sheet).
    final onlyIds =
        self
            ? absenceCandidates(
              await ref.read(signoutDataProvider.future),
              useDutyView: false,
            ).map((a) => a.id).whereType<String>().toSet()
            : null;
    final rows = PlayerAbsenceRepository.limitToIds(
      await _absences.upcomingToExcuse(personId: person!.id!, fromDate: _iso(c.from), untilDate: _iso(c.to)),
      onlyIds,
    );
    return AbsencePreviewReply(
      AbsencePlan(
        personId: person.id!,
        personName: _name(person),
        isMe: self,
        from: c.from,
        to: c.to,
        reason: c.reason ?? l10nWithoutContext.assistantAbsenceDefaultReason,
        affected: rows.length,
        onlyIds: onlyIds,
      ),
    );
  }

  void _refreshAbsences(int personId) {
    ref.invalidate(playerAbsencesByPersonIdProvider(personId));
    ref.invalidate(playerAbsencesProvider);
    _refreshStatuses(self: true);
  }

  /// Saves a confirmed absence and excuses its Termine.
  Future<({PlayerAbsence absence, int count})> applyAbsence(AbsencePlan plan) async {
    final absence = await _absences.addAbsence(
      personId: plan.personId,
      fromDate: _iso(plan.from),
      untilDate: _iso(plan.to),
      reason: plan.reason,
    );
    final count = await _absences.excuseUpcomingAttendances(
      personId: plan.personId,
      fromDate: _iso(plan.from),
      untilDate: _iso(plan.to),
      reason: plan.reason,
      onlyIds: plan.onlyIds,
    );
    _refreshAbsences(plan.personId);
    return (absence: absence, count: count);
  }

  /// "Rückgängig": deletes the absence and resets the Termine it excused.
  Future<void> revertAbsence(PlayerAbsence absence, AbsencePlan plan) async {
    if (absence.id == null) return;
    await _absences.deleteAbsence(absence.id!);
    await _absences.resetExcusedAttendances(absence: absence, onlyIds: plan.onlyIds);
    _refreshAbsences(plan.personId);
  }

  // -------------------------------------------------------------------------
  // Package 3: Termine.

  /// "HH:mm" of a time column, for comparing.
  static String? _hm(String? t) => t == null || t.length < 5 ? t : t.substring(0, 5);

  static DateTime _localDay(Attendance a) => dayOf(DateTime.parse(a.date).toLocal());

  /// The Termin a change is about, freshly loaded (not the cached list).
  Future<Attendance?> _eventToChange(EventRef event, List<AttendanceType> types, String? typeName) async {
    final found = await _findEvent(event, _type(types, typeName));
    if (found?.id == null) return null;
    return await _events.getAttendanceById(found!.id!) ?? found;
  }

  /// Archived Termine and Termine outside the limits are never changed.
  bool _locked(Attendance a) => a.archived || !inChangeWindow(_localDay(a), _clock());

  void _refreshEvents([int? attendanceId]) {
    ref.invalidate(attendancesProvider);
    ref.invalidate(upcomingAttendancesProvider);
    ref.invalidate(realtimeAttendanceListProvider);
    if (attendanceId != null) {
      ref.invalidate(attendanceDetailProvider(attendanceId));
      ref.invalidate(personAttendancesForAttendanceProvider(attendanceId));
    }
  }

  Future<AssistantReply> _createPreview(CreateEventsCommand c) async {
    final types = (await _types()).where((t) => t.visible && t.id != null).toList();
    if (types.isEmpty) return const NoticeReply(AssistantNotice.noType);
    final type =
        c.typeId != null
            ? types.where((t) => t.id == c.typeId).firstOrNull
            : c.typeName != null
            ? _type(types, c.typeName)
            : (types.length == 1 ? types.first : null);
    if (type == null) {
      return ChoiceReply(
        kind: ChoiceKind.type,
        query: c.typeName ?? '',
        options: [for (final t in types.take(8)) (label: t.name, command: c.withType(t.id!))],
      );
    }
    final now = _clock();
    var window = 0;
    final days = <DateTime>[];
    for (final d in c.dates) {
      if (inFutureWindow(d, now)) {
        days.add(dayOf(d));
      } else {
        window++;
      }
    }
    if (days.isEmpty) return const NoticeReply(AssistantNotice.dateOutOfRange);
    // One Termin of a type per day: days that already have one are left out.
    final taken = {
      for (final a in await _events.getUpcomingAttendances())
        if (a.typeId == type.id) _localDay(a),
    };
    final free = days.where((d) => !taken.contains(d)).toList();
    if (free.isEmpty) return const NoticeReply(AssistantNotice.eventsExist);
    return CreatePreviewReply(
      CreatePlan(
        type: type,
        days: free,
        title: c.title,
        place: type.placeEnabled ? c.place : null,
        startTime: c.startTime,
        endTime: c.endTime,
        skippedExisting: days.where(taken.contains).toList(),
        skippedWindow: window,
      ),
    );
  }

  /// Creates the confirmed Termine through the shared create writer (same
  /// rows as both create pages). Returns their ids.
  Future<List<int>> applyCreate(CreatePlan plan) async {
    // Writer bound to the tenant before the first await.
    final writer = AttendanceCreateWriter.withRead(ref.read);
    if (writer.tenant?.id == null || writer.tenant!.id != _tenantId) throw StateError('Tenant changed');
    // SOL_FIX2: the create permission is checked again in the write path.
    if (!await _mayCreate()) throw StateError('No create permission');
    final ids = await writer.create(
      AttendanceCreateInput(
        type: plan.type,
        dates: plan.days,
        typeInfo: plan.title,
        startTime: plan.startTime,
        endTime: plan.endTime,
        place: plan.place,
      ),
    );
    _refreshEvents();
    return ids;
  }

  /// "Rückgängig": deletes exactly the Termine this chat created.
  Future<void> revertCreate(List<int> createdIds) async {
    for (final id in createdIds) {
      await _events.deleteAttendance(id);
    }
    _refreshEvents();
  }

  Future<AssistantReply> _movePreview(MoveEventCommand c) async {
    final types = await _types();
    final a = await _eventToChange(c.event, types, c.typeName);
    if (a?.id == null) return const NoticeReply(AssistantNotice.noEvent);
    if (_locked(a!)) return const NoticeReply(AssistantNotice.eventLocked);
    final now = _clock();
    final oldDay = _localDay(a);
    final newDay = c.toDate == null ? oldDay : dayOf(c.toDate!);
    if (c.toDate != null && !inFutureWindow(newDay, now)) return const NoticeReply(AssistantNotice.dateOutOfRange);
    final type = types.where((t) => t.id == a.typeId).firstOrNull;
    final oldStart = _hm(a.startTime ?? type?.startTime);
    final oldEnd = _hm(a.endTime ?? type?.endTime);
    final newStart = c.startTime ?? oldStart;
    final newEnd =
        c.endTime ??
        (c.startTime != null && oldStart != null ? shiftedEndTime(oldStart, oldEnd, c.startTime!) ?? oldEnd : oldEnd);
    if (newDay == oldDay && newStart == oldStart && newEnd == oldEnd) {
      return const NoticeReply(AssistantNotice.nothingToChange);
    }
    return MovePreviewReply(
      MovePlan(
        before: a,
        title: _title(a, types),
        oldDay: oldDay,
        newDay: newDay,
        oldStart: oldStart,
        oldEnd: oldEnd,
        newStart: newStart,
        newEnd: newEnd,
      ),
    );
  }

  /// Moves the Termin like "Datum ändern": deadline and checklist due dates
  /// move along, history dates follow, planned absences on the new day
  /// excuse persons still on the default status (statuses are kept
  /// otherwise), then the shift computation runs again. Returns the rows it
  /// changed with their status before (for undo).
  Future<List<RestoreRow>> applyMove(MovePlan plan) async {
    final a = plan.before;
    final id = plan.attendanceId;
    final types = await _types();
    final type = types.where((t) => t.id == a.typeId).firstOrNull;
    // SOL_FIX38: dependencies are loaded before the first write.
    final absences = plan.movesDay && type != null ? await _absences.getAbsencesForTenant() : const <PlayerAbsence>[];
    final normalized = DateTime(plan.newDay.year, plan.newDay.month, plan.newDay.day, 12);
    final iso = normalized.toUtc().toIso8601String();
    final days = calendarDayDifference(plan.oldDay, normalized);
    String? shift(String? value) {
      if (value == null || value.isEmpty) return value;
      final d = DateTime.tryParse(value);
      return d == null ? value : shiftByCalendarDays(d, days).toIso8601String();
    }

    await _events.updateAttendance(id, {
      if (plan.movesDay) 'date': iso,
      if (plan.movesDay && a.deadline != null) 'deadline': shiftDeadline(a.deadline, days),
      if (plan.movesDay && a.checklist != null)
        'checklist': [for (final item in a.checklist!) item.copyWith(dueDate: shift(item.dueDate)).toJson()],
      if (plan.newStart != plan.oldStart) 'start_time': plan.newStart,
      if (plan.newEnd != plan.oldEnd) 'end_time': plan.newEnd,
    });
    final restore = <RestoreRow>[];
    if (plan.movesDay) await _events.updateHistoryDatesForAttendance(id, iso);
    if (type != null) {
      if (plan.movesDay) {
        final rows = await _events.getPersonAttendancesForAttendances([id]);
        final before = {
          for (final r in rows)
            if (r.id != null) r.id!: r,
        };
        final updates = dateChangeStatusUpdates(
          rows: [
            for (final r in rows)
              if (r.id != null && r.personId != null)
                (id: r.id!, personId: r.personId!, status: r.status, notes: r.notes),
          ],
          absences: absences,
          newDay: normalized,
          defaultStatus: type.defaultStatus,
          resetStatuses: false,
        );
        for (final u in updates) {
          final old = before[u.id]!;
          await _events.updatePersonAttendance(u.id, {'status': u.status.value, 'notes': u.notes});
          restore.add((id: u.id, status: old.status, notes: old.notes));
        }
      }
      await _events.updateShiftAssignmentsForAttendance(id);
    }
    _refreshEvents(id);
    return restore;
  }

  /// "Rückgängig": day, times, deadline, checklist and the changed rows
  /// back to what they were.
  Future<void> revertMove(MovePlan plan, List<RestoreRow> restore) async {
    final a = plan.before;
    final id = plan.attendanceId;
    await _events.updateAttendance(id, {
      if (plan.movesDay) 'date': a.date,
      if (plan.movesDay && a.deadline != null) 'deadline': a.deadline,
      if (plan.movesDay && a.checklist != null) 'checklist': [for (final item in a.checklist!) item.toJson()],
      if (plan.newStart != plan.oldStart) 'start_time': a.startTime,
      if (plan.newEnd != plan.oldEnd) 'end_time': a.endTime,
    });
    if (plan.movesDay) await _events.updateHistoryDatesForAttendance(id, a.date);
    for (final r in restore) {
      await _events.updatePersonAttendance(r.id, {'status': r.status.value, 'notes': r.notes ?? ''});
    }
    if (a.typeId != null) await _events.updateShiftAssignmentsForAttendance(id);
    _refreshEvents(id);
  }

  Future<AssistantReply> _songsPreview(SetSongsCommand c) async {
    final types = await _types();
    final a = await _eventToChange(c.event, types, c.typeName);
    if (a?.id == null) return const NoticeReply(AssistantNotice.noEvent);
    if (_locked(a!)) return const NoticeReply(AssistantNotice.eventLocked);
    final type = types.where((t) => t.id == a.typeId).firstOrNull;
    if (!showSongsForType(type, ref.read(currentTenantProvider)?.type)) {
      return const NoticeReply(AssistantNotice.noSongsForType);
    }
    final songs = (await ref.read(songsProvider.future)).where((s) => s.id != null).toList();
    final picked = <Song>[];
    final notFound = <String>[];
    for (final title in c.titles) {
      final m = _matchSongs(title, songs);
      if (m.isEmpty) {
        notFound.add(title);
      } else if (!picked.any((p) => p.id == m.first.id)) {
        picked.add(m.first);
      }
    }
    if (picked.isEmpty) return NoticeReply(AssistantNotice.songsNotFound, subject: notFound.join(', '));
    final before =
        await loadAttendanceSongEntries(
          repo: _events,
          songsFuture: Future.value(songs),
          conductorsFuture: ref.read(conductorsProvider.future),
          attendanceId: a.id!,
        ) ??
        const <SongHistoryEntry>[];
    SongHistoryEntry entry(Song s) =>
        before.where((e) => e.songId == s.id).firstOrNull ?? SongHistoryEntry(songId: s.id!, songName: s.displayName);
    final after =
        c.replace
            ? [for (final s in picked) entry(s)]
            : [
              ...before,
              for (final s in picked)
                if (!before.any((e) => e.songId == s.id)) entry(s),
            ];
    final beforeIds = {for (final e in before) e.songId};
    final afterIds = {for (final e in after) e.songId};
    final added = [
      for (final e in after)
        if (!beforeIds.contains(e.songId)) e.songName,
    ];
    final removed = [
      for (final e in before)
        if (!afterIds.contains(e.songId)) e.songName,
    ];
    if (added.isEmpty && removed.isEmpty) return const NoticeReply(AssistantNotice.nothingToChange);
    return SongsPreviewReply(
      SongsPlan(
        attendanceId: a.id!,
        title: _title(a, types),
        date: _localDay(a),
        historyDate: a.date,
        before: before,
        after: after,
        added: added,
        removed: removed,
        notFound: notFound,
      ),
    );
  }

  void _refreshSongs(int attendanceId) {
    ref.invalidate(currentSongsProvider);
    ref.invalidate(songHistoryProvider(null));
    ref.invalidate(songsProvider);
    ref.invalidate(attendanceSongEntriesProvider(attendanceId));
  }

  /// Saves the Werke like the Termin page (history rows, tenant filtered).
  Future<void> applySongs(SongsPlan plan) async {
    await syncAttendanceSongHistory(_events, plan.attendanceId, plan.historyDate, plan.after);
    _refreshSongs(plan.attendanceId);
  }

  /// "Rückgängig": the Werke as they were.
  Future<void> revertSongs(SongsPlan plan) async {
    await syncAttendanceSongHistory(_events, plan.attendanceId, plan.historyDate, plan.before);
    _refreshSongs(plan.attendanceId);
  }

  // -------------------------------------------------------------------------
  // Package 4: tasks, Werke of a Termin, duties, drafts.

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<AssistantReply> _myTasks() async {
    final tasks =
        (await ref.read(myTasksProvider.future)).where((t) => t.id != null && t.status != 'completed').toList()..sort(
          (a, b) => compareTasksByDue((dueDate: a.dueDate, title: a.title), (dueDate: b.dueDate, title: b.title)),
        );
    if (tasks.isEmpty) return const NoticeReply(AssistantNotice.noTasks);
    return TasksReply([
      for (final t in tasks.take(10))
        (id: t.id!, title: t.title, dueDate: t.dueDate, priority: t.priority, inProgress: t.status == 'in_progress'),
    ]);
  }

  Future<AssistantReply> _eventSongs(EventSongsCommand c) async {
    final role = ref.read(currentRoleProvider);
    if (!(role.isConductor || role.isHelperRole)) {
      // Members: the Werke of their own Termine ("Aktuelle Werke").
      final day = resolveEventDay(c.event, _clock());
      final own =
          (await _ownUpcomingAcrossTenants(
            c.typeName,
          )).where((a) => a.tenantId == _tenantId && (day == null || dayOf(_when(a)) == day)).toList();
      final a = own.firstOrNull;
      if (a == null) return const NoticeReply(AssistantNotice.noEvent);
      final songs = (await ref.read(signoutAttendanceSongsProvider.future))[a.attendanceId] ?? const [];
      if (songs.isEmpty) return const NoticeReply(AssistantNotice.noSongsYet);
      return EventSongsReply(
        attendanceId: a.attendanceId!,
        title: a.eventTitle,
        date: dayOf(_when(a)),
        songs: [for (final s in songs) s.name],
        linkToEvent: false,
      );
    }
    final types = await _types();
    final a = await _findEvent(c.event, _type(types, c.typeName));
    if (a?.id == null) return const NoticeReply(AssistantNotice.noEvent);
    final entries =
        await loadAttendanceSongEntries(
          repo: _events,
          songsFuture: ref.read(songsProvider.future),
          conductorsFuture: ref.read(conductorsProvider.future),
          attendanceId: a!.id!,
        ) ??
        const <SongHistoryEntry>[];
    if (entries.isEmpty) return const NoticeReply(AssistantNotice.noSongsYet);
    return EventSongsReply(
      attendanceId: a.id!,
      title: _title(a, types),
      date: _localDay(a),
      songs: [for (final e in entries) e.songName],
    );
  }

  Future<AssistantReply> _taskPreview(CreateTaskCommand c) async {
    if (c.dueDate != null && !taskDueInWindow(c.dueDate!, _clock())) {
      return const NoticeReply(AssistantNotice.taskDueOutOfRange);
    }
    TaskPlan plan({int? id, String? name, bool isMe = false}) => TaskPlan(
      title: c.title,
      priority: (c.priority ?? TaskPriority.medium).name,
      personId: id,
      personName: name,
      isMe: isMe,
      dueDate: c.dueDate == null ? null : _isoDay(c.dueDate!),
    );
    final who = c.who;
    switch (who) {
      case null:
        return TaskPreviewReply(plan());
      case MeSubject():
        final own = await ref.read(currentSelfServicePlayerProvider.future);
        if (own?.id == null) return const NoticeReply(AssistantNotice.noOwnPerson);
        return TaskPreviewReply(plan(id: own!.id, name: _name(own), isMe: true));
      case PersonIdSubject(:final personId):
        final p = (await _activePlayers()).where((p) => p.id == personId).firstOrNull;
        if (p == null) return const NoticeReply(AssistantNotice.personNotFound);
        return TaskPreviewReply(plan(id: p.id, name: _name(p)));
      case PersonSubject(:final name):
        final matches = bestMatches(name, await _activePlayers(), (p) => personNames(p.firstName, p.lastName));
        if (matches.isEmpty) return NoticeReply(AssistantNotice.personNotFound, subject: name);
        if (matches.length > 1) {
          final groups = await ref.read(groupsProvider.future);
          String label(Person p) {
            final g = groups.where((g) => g.id == p.instrument).map((g) => g.name).firstOrNull;
            return g == null ? _name(p) : '${_name(p)} · $g';
          }

          return ChoiceReply(
            query: name,
            options: [for (final p in matches.take(6)) (label: label(p), command: c.withWho(PersonIdSubject(p.id!)))],
          );
        }
        return TaskPreviewReply(plan(id: matches.first.id, name: _name(matches.first)));
      default:
        return const NoticeReply(AssistantNotice.noRights);
    }
  }

  void _refreshTasks() {
    ref.invalidate(teamTasksProvider);
    ref.invalidate(myTasksProvider);
    ref.invalidate(rdTeamTasksProvider);
  }

  /// Creates the task like the task sheet, WITHOUT the push (it goes out
  /// only via [notifyTask]). Returns the id of the new task.
  Future<String> applyTask(TaskPlan plan) async {
    // Rights checked again in the write path (role and Teamorganisation).
    if (!ref.read(isTeamLeaderProvider) || !await _teamOrgOn()) throw StateError('No task rights');
    final created = await _tasks.createTask(
      TeamTask(
        title: plan.title,
        responsiblePersonId: plan.personId,
        dueDate: plan.dueDate,
        priority: plan.priority,
        status: 'open',
      ),
    );
    _refreshTasks();
    if (created.id == null) throw StateError('Task without id');
    return created.id!;
  }

  /// "Rückgängig": deletes exactly the task this chat created.
  Future<void> revertTask(String taskId) async {
    await _tasks.deleteTask(taskId);
    _refreshTasks();
  }

  /// "Benachrichtigen": the push of the task sheet to the responsible person.
  Future<void> notifyTask(String taskId) => _team.notifyTeam({'type': 'task_assigned', 'taskId': taskId});

  Future<AssistantReply> _dutyPreview(TakeDutyCommand c) async {
    final own = await ref.read(currentSelfServicePlayerProvider.future);
    if (own?.id == null) return const NoticeReply(AssistantNotice.noOwnPerson);
    final dutyTypes = (await _types()).where((t) => t.dutyMode && t.id != null).toList();
    if (dutyTypes.isEmpty) return const NoticeReply(AssistantNotice.noDuty);
    final asked = _type(dutyTypes, c.typeName);
    final now = _clock();
    final day = resolveEventDay(c.event, now);
    final from = day ?? dayOf(now);
    final until =
        day == null
            ? from.add(const Duration(days: assistantFutureDays))
            : DateTime(day.year, day.month, day.day, 23, 59, 59);
    var termine = await _duty.getUpcomingDutyTermine(asked == null ? dutyTypes : [asked], from: from, until: until);
    if (asked == null && c.typeName != null) {
      // "Aufbau" may be the title of a Termin, not the name of its type.
      final byTitle = bestMatches(c.typeName!, termine, (t) => [t.title]);
      if (byTitle.isNotEmpty) termine = byTitle;
    }
    termine = termine.where((t) => t.attendance.id != null && (day == null || _localDay(t.attendance) == day)).toList();
    bool mine(DutyTermin t) => t.persons.any((p) => p.personId == own!.id);
    // The next one: prefer an own Termin with a free place.
    final t =
        termine.where((t) => mine(t) && t.open > 0).firstOrNull ??
        termine.where(mine).firstOrNull ??
        termine.firstOrNull;
    if (t == null) return const NoticeReply(AssistantNotice.noDuty);
    if (_locked(t.attendance)) return const NoticeReply(AssistantNotice.eventLocked);
    final row = t.persons.where((p) => p.personId == own!.id && p.id != null).firstOrNull;
    final skip = dutySkip(
      selfSignup: t.type.dutySelfSignup,
      isMember: row != null,
      ownDutyState: row?.dutyState,
      ownStatus: row?.status ?? AttendanceStatus.neutral,
      required: t.required,
      occupied: t.occupied,
    );
    switch (skip) {
      case DutySkip.notSelf:
        return const NoticeReply(AssistantNotice.dutyNotSelf);
      case DutySkip.notMember:
        return const NoticeReply(AssistantNotice.dutyNotMember);
      case DutySkip.already:
        return const NoticeReply(AssistantNotice.dutyAlready);
      case DutySkip.full:
        return const NoticeReply(AssistantNotice.dutyFull);
      case null:
        break;
    }
    return DutyPreviewReply(
      DutyPlan(
        attendanceId: t.attendance.id!,
        personAttendanceId: row!.id!,
        title: t.title,
        date: _localDay(t.attendance),
        startTime: t.attendance.startTime ?? t.type.startTime,
        required: t.required,
        occupied: t.occupied,
        oldStatus: row.status,
        oldNotes: row.notes,
      ),
    );
  }

  void _refreshDuty(int attendanceId) {
    ref.invalidate(upcomingDutyTermineProvider);
    ref.invalidate(dutyTermineByIdProvider);
    ref.invalidate(myDutyOverviewProvider);
    ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    ref.invalidate(signoutDataProvider);
    _refreshEvents(attendanceId);
  }

  /// "Ich übernehme": the RPC `duty_take` checks membership, places and
  /// the self sign-up again on the server (first one wins).
  Future<DutyTakeResult> applyDuty(DutyPlan plan) async {
    final result = await _duty.take(plan.attendanceId);
    _refreshDuty(plan.attendanceId);
    return result;
  }

  /// "Rückgängig": the own row is free again with its status before; when
  /// the sign-up had filled the last place, the stand-ins are told again.
  Future<void> revertDuty(DutyPlan plan) async {
    await _events.updatePersonAttendance(plan.personAttendanceId, {
      'duty_state': null,
      'duty_assigned_by': null,
      'duty_assigned_at': null,
      'status': plan.oldStatus.value,
      'notes': plan.oldNotes ?? '',
    });
    if (plan.fillsLast) await _duty.notify(DutyNotifyType.understaffed, plan.attendanceId);
    _refreshDuty(plan.attendanceId);
  }

  /// Nothing is saved: the page opens "Person anlegen" with these values.
  Future<AssistantReply> _personDraft(NewPersonCommand c) async {
    Group? group;
    if (c.group != null) group = _group(await ref.read(groupsProvider.future), c.group!);
    final b = c.birthday;
    final validBirthday = b != null && b.year >= 1900 && !dayOf(b).isAfter(dayOf(_clock()));
    return PersonDraftReply(
      firstName: c.firstName,
      lastName: c.lastName,
      groupId: group?.id,
      groupName: group?.name,
      missingGroup: c.group != null && group == null ? c.group : null,
      birthday: validBirthday ? dayOf(b) : null,
    );
  }

  /// Nothing is sent: the page opens the compose page with these
  /// recipients; sending stays a manual step there.
  Future<AssistantReply> _messageDraft(DraftMessageCommand c) async {
    Group? group;
    if (c.group != null) {
      group = _group(await ref.read(groupsProvider.future), c.group!);
      if (group == null) return NoticeReply(AssistantNotice.groupNotFound, subject: c.group);
    }
    var people =
        (await _activePlayers())
            .where((p) => !p.paused && !p.pending && (group == null || p.instrument == group.id))
            .toList();
    Attendance? event;
    String? eventTitle;
    String? eventTime;
    if (c.event != null) {
      final types = await _types();
      event = await _findEvent(c.event!, _type(types, c.typeName));
      if (event?.id == null) return const NoticeReply(AssistantNotice.noEvent);
      eventTitle = _title(event!, types);
      eventTime = event.startTime ?? types.where((t) => t.id == event!.typeId).firstOrNull?.startTime;
      // Only those on the Termin; with [onlyOpen] only those without answer.
      final statuses = await _reads.getEventStatuses(event.id!);
      final onEvent = {
        for (final s in statuses)
          if (!c.onlyOpen || s.status == AttendanceStatus.neutral) s.personId,
      };
      people = people.where((p) => onEvent.contains(p.id)).toList();
    }
    if (people.isEmpty) return const NoticeReply(AssistantNotice.noRecipients);
    return MessageDraftReply(
      playerIds: [for (final p in people) p.id!],
      groupName: group?.name,
      onlyOpen: c.onlyOpen,
      attendanceId: event?.id,
      eventTitle: eventTitle,
      eventDate: event == null ? null : _localDay(event),
      eventTime: eventTime == null ? null : _hm(eventTime),
      note: c.note,
    );
  }
}
