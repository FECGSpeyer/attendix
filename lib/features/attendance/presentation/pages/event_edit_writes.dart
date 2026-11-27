part of 'event_edit_page.dart';

/// Queued writes, pickers, type switching, and deletion for [RdEventEditPage].
extension _RdEventEditWrites on _RdEventEditPageState {
  void _enqueue(Future<void> Function() save) {
    _textQueue = _textQueue.then((_) => save());
  }

  void _refresh() {
    _container
      ..invalidate(attendanceDetailProvider(_id))
      ..invalidate(attendancesProvider)
      ..invalidate(realtimeAttendanceListProvider);
  }

  /// Writes [updates]; reports a failure while the page is open.
  Future<bool> _write(Map<String, dynamic> updates) async {
    if (_deleted || !_repo.hasTenantId || !_session.isCurrent()) return false;
    try {
      await _repo.updateAttendance(_id, updates);
      _refresh();
      return true;
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      return false;
    }
  }

  void _saveTitle() {
    final value = _title.text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedTitle == null || value == _storedTitle) return;
      // Marked as stored only once written, so a failed save is tried again.
      if (await _write({'typeInfo': value.isEmpty ? null : value})) _storedTitle = value;
    });
  }

  void _savePlace() {
    final value = _place.text.trim(); // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedPlace == null || value == _storedPlace) return;
      // Marked as stored only once written, so a failed save is tried again.
      if (await _write({'place': value.isEmpty ? null : value})) {
        _storedPlace = value;
        final type = _type;
        if (value.isNotEmpty && type != null) {
          _type = await rdEnsureTypeFlags(
            _typeNotifier,
            type,
            place: true,
            onFailed: () {
              if (mounted) ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
            },
          );
        }
      }
    });
  }

  void _saveNotes() {
    final value = _notes.text; // read now: the page may be gone when it runs
    _enqueue(() async {
      if (_storedNotes == null || value == _storedNotes) return;
      // Marked as stored only once written, so a failed save is tried again.
      if (await _write({'notes': value.isEmpty ? null : value})) _storedNotes = value;
    });
  }

  /// "Termin löschen": confirm, delete, and return to the events list.
  Future<void> _delete() async {
    final l10n = context.l10n;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final confirmed = await showAppConfirm(
      context,
      title: l10n.attListRemoveConfirm,
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted || !_session.isCurrent()) return;
    final router = GoRouter.of(context);
    HapticHelper.medium();
    try {
      await _repo.deleteAttendance(_id);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
      return;
    }
    _deleted = true; // text typed last is not saved any more
    _container
      ..invalidate(attendancesProvider)
      ..invalidate(realtimeAttendanceListProvider)
      ..invalidate(playerAttendancePercentagesProvider);
    if (mounted) ToastHelper.showSuccess(context, l10n.redesignEventDeleted);
    router.go(RedesignRoutes.events);
  }

  /// Says that the Ablauf moved along to [start] and offers to put it back
  /// ([before] = the stored plan as it was).
  void _planMoved(Map<String, dynamic> before, String start) {
    if (!mounted) return;
    final l10n = context.l10n;
    ToastHelper.showSuccess(
      context,
      l10n.redesignEventPlanMoved(PlanUtils.formatTime(start)),
      duration: const Duration(seconds: 6),
      action: ToastAction(label: l10n.redesignEventUndo, onPressed: () => _write({'plan': before})),
    );
  }

  Future<void> _pickTime(Attendance att, AttendanceType? type, {required bool start}) async {
    // Shown times: the Termin's own, else its type's (like the Termin page).
    final shownStart = att.startTime ?? type?.startTime;
    final shownEnd = att.endTime ?? type?.endTime;
    final current = start ? shownStart : shownEnd;
    final parts = (current ?? '').split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (start ? 17 : 20),
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final iosLook = Theme.of(context).platform == TargetPlatform.iOS;
    var picked = await showAppTimePicker(
      context: context,
      initialTime: initial,
      helpText: start ? context.l10n.redesignCreateStart : context.l10n.redesignCreateEnd,
    );
    // The iOS wheel returns null when the shown time was confirmed unchanged:
    // with no time yet, that shown default is the choice.
    if (picked == null && iosLook && current == null) picked = initial;
    if (picked == null || !mounted) return;
    // #232: session of the acting user, captured before the first write.
    final writeSession = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    // The Ende never lies before the Beginn: a later Beginn moves the Ende
    // along, an earlier Ende is refused.
    final times = rdPickedTimes(start: shownStart, end: shownEnd, pickedStart: start, value: value);
    if (times == null) {
      ToastHelper.showError(context, context.l10n.redesignCreateEndBeforeStart);
      return;
    }
    // An Ablauf that began at the old Beginn moves along with it.
    final movedPlan = start ? rdPlanMovedWithStart(att.plan, oldStart: shownStart, newStart: times.start) : null;
    final updates = <String, dynamic>{
      if (start && times.start != att.startTime) 'start_time': times.start,
      // A Beginn change writes the Ende only when it moved along.
      if (start ? times.end != shownEnd : times.end != att.endTime) 'end_time': times.end,
      if (movedPlan != null) 'plan': movedPlan,
    };
    if (updates.isEmpty) return;
    if (!await _write(updates)) return;
    if (movedPlan != null) _planMoved(att.plan!, times.start!);
    try {
      // LOGIC_ATT: the time window moved, re-run the shift computation for
      // everyone in this Termin (Ionic onInfoChanged).
      await _repo.updateShiftAssignmentsForAttendance(
        _id,
        isSessionCurrent: writeSession.isCurrent,
        actingUserId: writeSession.userId,
      );
      _container.invalidate(personAttendancesForAttendanceProvider(_id));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Switches the attendance type for this Termin, optionally migrating
  /// participants still on the old default status and recomputing shifts.
  Future<void> _pickType(Attendance att, AttendanceType? current) async {
    // One type change at a time, including its status adoption.
    if (_typeChanging) return;
    _typeChanging = true;
    try {
      await _changeType(att, current);
    } finally {
      _typeChanging = false;
    }
  }

  Future<void> _changeType(Attendance att, AttendanceType? current) async {
    final l10n = context.l10n;
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    final all = await ref.read(attendanceTypesProvider.future).catchError((_) => const <AttendanceType>[]);
    if (!mounted) return;
    // The current type from the list itself: the row may be tapped before
    // the Termin's type finished loading.
    final currentId = att.typeId;
    current = currentId == null ? null : all.where((t) => t.id == currentId).firstOrNull;
    final types = [
      for (final t in all)
        if (t.visible == true || t.id == current?.id) t,
    ];
    if (types.isEmpty || (currentId != null && current == null)) {
      ToastHelper.showError(context, l10n.redesignTodayLoadFailed);
      return;
    }
    final picked = await showRdTypePicker(
      context,
      types: types,
      selected: current,
      // Leads: "Terminarten verwalten" (Verwaltung), the Termin stays below.
      onManage: ref.read(rdManageAccessProvider).isAdmin ? () => context.push(RedesignRoutes.attendanceTypes) : null,
    );
    if (picked == null || !mounted || picked.id == current?.id) return;
    // #232: session of the acting user, captured before the first write.
    final writeSession = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();

    Future<List<PersonAttendance>> onDefault(AttendanceStatus status) async {
      _container.invalidate(personAttendancesForAttendanceProvider(_id));
      final sub = _container.listen(personAttendancesForAttendanceProvider(_id).future, (_, __) {});
      try {
        final rows = await sub.read();
        return [
          for (final r in rows)
            if (r.id != null && r.status == status) r,
        ];
      } finally {
        sub.close();
      }
    }

    // Rows still on the old default status (never changed by anyone).
    final oldDefault = current?.defaultStatus;
    final changesDefault = oldDefault != null && oldDefault != picked.defaultStatus;
    var count = 0;
    if (changesDefault) {
      try {
        count = (await onDefault(oldDefault)).length;
      } catch (_) {
        if (mounted) ToastHelper.showError(context, l10n.dateDialogLoadFailed);
        return;
      }
      if (!mounted) return;
    }
    var adopt = false;
    String statusLabel(AttendanceStatus s) =>
        s == AttendanceStatus.neutral ? l10n.redesignStatusOpen : ionicStatusLabel(s);
    if (count > 0) {
      final choice = await showAppDialog<String>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(l10n.redesignEventEditTypeStatusTitle),
          content: Text(
            l10n.redesignEventEditTypeStatusMessage(
              count,
              statusLabel(oldDefault!),
              statusLabel(picked.defaultStatus),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(l10n.dateDialogKeep)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'adopt'),
              child: Text(l10n.redesignEventEditTypeStatusAdopt),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      adopt = choice == 'adopt';
    }

    // The Ende must not end up before the Beginn with the new type's times.
    final start = att.startTime ?? picked.startTime;
    final end = att.endTime ?? picked.endTime;
    final oldStart = att.startTime ?? current?.startTime;
    final oldEnd = att.endTime ?? current?.endTime;
    final fixEnd =
        !picked.allDay && rdEndBeforeStart(start, end)
            ? (rdEndBeforeStart(picked.startTime, picked.endTime) || picked.startTime == null || picked.endTime == null
                ? rdEndAfter(start!, from: oldStart, to: oldEnd)
                : rdEndAfter(start!, from: picked.startTime, to: picked.endTime))
            : null;
    // The Beginn may come from the type: an Ablauf tied to it moves along.
    final movedPlan = picked.allDay ? null : rdPlanMovedWithStart(att.plan, oldStart: oldStart, newStart: start);
    if (!await _write({
      'type_id': picked.id,
      if (fixEnd != null) 'end_time': fixEnd,
      if (movedPlan != null) 'plan': movedPlan,
    })) {
      return;
    }
    if (movedPlan != null && mounted) _planMoved(att.plan!, start!);
    var failed = 0;
    try {
      if (adopt) {
        List<PersonAttendance> rows;
        try {
          rows = await onDefault(oldDefault!);
        } catch (_) {
          failed = count;
          rows = const [];
        }
        for (final r in rows) {
          writeSession.ensureCurrent();
          try {
            await _repo.updatePersonAttendance(
              r.id!,
              {'status': picked.defaultStatus.value},
              isSessionCurrent: writeSession.isCurrent,
              actingUserId: writeSession.userId,
              onlyIfStatus: oldDefault,
            );
          } on PersonAttendanceStatusChangedException {
            continue; // changed meanwhile: keep that person's status
          } on OfflineSessionChangedException {
            rethrow;
          } catch (_) {
            failed++;
          }
        }
      }
      writeSession.ensureCurrent();
      // LOGIC_ATT: times and all-day may come from the new type.
      await _repo.updateShiftAssignmentsForAttendance(
        _id,
        isSessionCurrent: writeSession.isCurrent,
        actingUserId: writeSession.userId,
      );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      _container
        ..invalidate(attendanceTypeForAttendanceProvider(_id))
        ..invalidate(personAttendancesForAttendanceProvider(_id));
    }
    if (failed > 0 && mounted) {
      ToastHelper.showError(context, l10n.redesignEventEditTypeStatusFailed(failed));
    }
  }

  Future<void> _pickDeadline(Attendance att, AttendanceType? type) async {
    final l10n = context.l10n;
    final date = DateTime.tryParse(att.date);
    // From the Termin's own time (it may differ from the Art's).
    final suggested = date == null ? null : defaultDeadline(date, att.startTime ?? type?.startTime);
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(l10n.redesignCreateDeadline, style: RdType.cardTitle(ctx.rd)),
              ),
              RdGroupedList(
                children: [
                  RdListRow(
                    title: l10n.redesignCreateDeadlineNone,
                    showChevron: false,
                    selected: att.deadline == null,
                    onTap: () => Navigator.of(ctx).pop('none'),
                  ),
                  if (suggested != null)
                    RdListRow(
                      title: l10n.redesignEventEditDeadlineSuggested(rdDeadlineLabel(suggested.toLocal())),
                      showChevron: false,
                      onTap: () => Navigator.of(ctx).pop('suggested'),
                    ),
                  RdListRow(
                    title: l10n.redesignEventEditDeadlinePick,
                    onTap: () => Navigator.of(ctx).pop('pick'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Text(l10n.redesignCreateDeadlineHint, style: RdType.meta(ctx.rd, size: 13)),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'none':
        await _write({'deadline': null});
      case 'suggested':
        await _write({'deadline': EventListUtils.deadlineToStore(suggested!)});
      case 'pick':
        await _pickDeadlineDate(att);
    }
  }

  /// Day and time of the Abmeldeschluss (Termin page: from now until the Termin).
  Future<void> _pickDeadlineDate(Attendance att) async {
    final date = DateTime.tryParse(att.date);
    final current = EventListUtils.deadlineLocal(att.deadline);
    final now = DateTime.now();
    var initial = current ?? date?.subtract(const Duration(days: 1)) ?? now;
    final last = date ?? now.add(const Duration(days: 365));
    if (initial.isBefore(now)) initial = now;
    if (initial.isAfter(last)) initial = last;
    final day = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.isAfter(last) ? last : now,
      lastDate: last,
      helpText: context.l10n.attendanceFlutterChooseDeadline,
    );
    if (day == null || !mounted) return;
    final time = await showAppTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (!mounted) return;
    // The iOS wheel returns null when the shown time was confirmed unchanged.
    final t = time ?? TimeOfDay.fromDateTime(initial);
    final value = DateTime(day.year, day.month, day.day, t.hour, t.minute);
    await _write({'deadline': EventListUtils.deadlineToStore(value)});
  }

  Future<void> _pickFolder(Attendance att) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    final l10n = context.l10n;
    final current = (att.filesFolder ?? '').trim();
    if (current.isNotEmpty) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        backgroundColor: context.rd.bg,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: RdGroupedList(
              children: [
                RdListRow(title: l10n.attendanceChangeFolder, onTap: () => Navigator.of(ctx).pop('change')),
                RdListRow(
                  title: l10n.attendanceRemoveFolder,
                  titleColor: ctx.rd.absent,
                  showChevron: false,
                  onTap: () => Navigator.of(ctx).pop('remove'),
                ),
              ],
            ),
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'remove') {
        await _write({'files_folder': null});
        return;
      }
    }
    final path = await showFilesFolderPicker(context, tenantId: tenantId, initialPath: current);
    if (path == null || path.isEmpty || !mounted) return;
    await _write({'files_folder': path});
  }
}
