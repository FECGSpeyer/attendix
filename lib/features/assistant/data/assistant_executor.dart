// Chat assistant: answers a checked command with the data the app loads
// itself (same providers, rights and tenant filter as the screens).
// Read only: nothing is written in package 1.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/attendance_providers.dart';
import '../../../core/providers/attendance_type_providers.dart';
import '../../../core/providers/group_providers.dart';
import '../../../core/providers/player_providers.dart';
import '../../../core/providers/self_service_providers.dart';
import '../../../core/providers/song_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/person/person.dart';
import '../../../data/models/song/song.dart';
import '../../../data/repositories/assistant_repository.dart';
import '../../help/data/help_content_service.dart';
import 'assistant_command.dart';
import 'assistant_logic.dart';
import 'assistant_reply.dart';

class AssistantExecutor {
  AssistantExecutor(this.ref, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Ref ref;
  final DateTime Function() _clock;

  AssistantRepository get _repo =>
      ref.read(assistantRepositoryForTenantProvider(ref.read(currentTenantIdProvider)));

  Future<AssistantAccess> access() async {
    final role = ref.read(currentRoleProvider);
    Person? own;
    try {
      own = await ref.read(currentSelfServicePlayerProvider.future);
    } catch (_) {
      own = null;
    }
    return AssistantAccess(role: role, hasOwnPerson: own?.id != null);
  }

  Future<AssistantReply> run(AssistantCommand command) async {
    final rights = await access();
    if (command is AttendanceRateCommand && command.subject is MeSubject && !rights.hasOwnPerson) {
      return const NoticeReply(AssistantNotice.noOwnPerson);
    }
    if (!rights.allows(command)) return const NoticeReply(AssistantNotice.noRights);
    return switch (command) {
      AttendanceRateCommand() => _rate(command),
      EventOverviewCommand() => _eventOverview(command),
      NextEventCommand() => _nextEvent(command),
      BirthdaysCommand() => _birthdays(command),
      SongLastSungCommand() => _song(command),
      HelpCommand() => _help(command),
      UnsupportedCommand(:final isChange) =>
        NoticeReply(isChange ? AssistantNotice.changeLater : AssistantNotice.notUnderstood),
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
    final counted = askedType?.id != null
        ? {askedType!.id!}
        : {for (final t in types) if (t.includeInAverage && t.id != null) t.id!};
    final duty = {for (final t in types) if (t.dutyMode && t.id != null) t.id!};
    final shiftExcused = ref.read(currentTenantProvider)?.shiftExcusedAsPresent ?? false;

    List<Person> people;
    String? subjectName;
    int? personId;
    final subject = c.subject;
    switch (subject) {
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

          return ChoiceReply(query: name, options: [
            for (final p in matches.take(6))
              (
                label: label(p),
                command: AttendanceRateCommand(subject: PersonIdSubject(p.id!), period: c.period, typeName: c.typeName),
              ),
          ]);
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

    final rows = await _repo.getRateRows(personIds: [for (final p in people) p.id!], range: range);
    final rate = computeRate(rows,
        range: range, today: now, countedTypeIds: counted, dutyTypeIds: duty, shiftExcusedAsPresent: shiftExcused);
    if (rate.total == 0) return const NoticeReply(AssistantNotice.noData);
    final names = {for (final p in people) p.id!: _name(p)};
    final lowest = people.length > 1
        ? [
            for (final e in ratesPerPerson(rows,
                    range: range,
                    today: now,
                    countedTypeIds: counted,
                    dutyTypeIds: duty,
                    shiftExcusedAsPresent: shiftExcused)
                .take(5))
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
      return upcoming
          .where((a) => fits(a) && !dayOf(DateTime.parse(a.date).toLocal()).isBefore(today))
          .firstOrNull;
    }
    final onDay = await ref.read(attendanceRepositoryWithTenantProvider).getAttendancesByDate(day);
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
    final players = {for (final p in await ref.read(playersProvider.future)) if (p.id != null) p.id!: p};
    final statuses = await _repo.getEventStatuses(event!.id!);
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
    final number = int.tryParse(RegExp(r'^(?:nr\.?|no\.?|#)?\s*(\d+)$', caseSensitive: false)
            .firstMatch(c.title.trim())
            ?.group(1) ??
        '');
    final byNumber = number == null ? <Song>[] : songs.where((s) => s.number == number).toList();
    final matches = byNumber.isNotEmpty ? byNumber : bestMatches(c.title, songs, (s) => [s.name]);
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
