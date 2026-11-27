part of 'assistant_executor.dart';

extension AssistantExecutorStatus on AssistantExecutor {
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
}

DateTime _when(CrossTenantPersonAttendance a) => EventListUtils.parse(a.date) ?? DateTime(1970);

String _day(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
