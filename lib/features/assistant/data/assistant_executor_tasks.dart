part of 'assistant_executor.dart';

extension AssistantExecutorTasks on AssistantExecutor {
  // -------------------------------------------------------------------------
  // Package 4: tasks, Werke of a Termin, duties, drafts.


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

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
