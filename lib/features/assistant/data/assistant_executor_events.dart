part of 'assistant_executor.dart';

extension AssistantExecutorEvents on AssistantExecutor {
  // -------------------------------------------------------------------------
  // Package 3: Termine.



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
}

/// "HH:mm" of a time column, for comparing.
String? _hm(String? t) => t == null || t.length < 5 ? t : t.substring(0, 5);

DateTime _localDay(Attendance a) => dayOf(DateTime.parse(a.date).toLocal());
