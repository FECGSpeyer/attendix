part of 'event_page.dart';

extension _RdEventPageWrites on _RdEventPageState {
  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  void _hold(int personId) => _saving[personId] = (_saving[personId] ?? 0) + 1;

  void _release(int personId) {
    final left = (_saving[personId] ?? 1) - 1;
    if (left <= 0) {
      _saving.remove(personId);
    } else {
      _saving[personId] = left;
    }
  }

  /// Writes one status; reverts and reports when it could not be saved.
  /// [writer] is bound and the change number ([rev], else taken now) is
  /// taken when the user acted: the write waits in [RdWriteQueue] behind
  /// earlier writes of the row (also of a page that was left) and still
  /// completes after this page was left.
  Future<bool> _write(
    PersonAttendanceWriter writer,
    int personId,
    AttendanceStatus status,
    AttendanceStatus previous, {
    int? rev,
    bool refresh = true,
  }) async {
    final paId = _paIds[personId];
    if (paId == null) {
      if (mounted) _update(() => _statuses[personId] = previous);
      return false;
    }
    final queue = _queue;
    final change = rev ?? queue.nextRev(paId);
    bool newest() => queue.isNewest(paId, change);
    // Back to what is stored, not to an in-between choice never written.
    void revert() {
      if (mounted && newest()) _update(() => _statuses[personId] = queue.stored(paId) ?? previous);
    }

    _hold(personId);
    try {
      final result = await queue.run(
        paId,
        // A newer change of this row follows in the queue and wins.
        () async => newest()
            ? writer.status(
                attendanceId: _id,
                personAttendanceId: paId,
                status: status,
                refresh: refresh,
              )
            : null,
      );
      if (result == null) return false;
      if (result == PersonAttendanceWrite.notAllowed) {
        revert();
        return false;
      }
      queue.markStored(paId, status);
      return true;
    } catch (e) {
      // A superseded write failing changes nothing: the newer one follows.
      if (!newest()) return false;
      revert();
      _showWriteError((l10n) => l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      return false;
    } finally {
      _release(personId);
    }
  }

  /// Error toast; after the page was left (a queued write failed) on the
  /// app's root messenger.
  void _showWriteError(String Function(AppLocalizations l10n) message) {
    if (mounted) {
      ToastHelper.showError(context, message(context.l10n));
      return;
    }
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message(l10nWithoutContext), style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Writes several statuses, a few at a time, and refreshes the list once.
  /// Bound to the moment of the tap: it finishes after the page was left.
  Future<void> _writeMany(Map<int, AttendanceStatus> targets, Map<int, AttendanceStatus> previous) async {
    final writer = PersonAttendanceWriter(ref);
    final revs = {
      for (final id in targets.keys)
        if (_paIds[id] case final paId?) id: _queue.nextRev(paId),
    };
    _update(() => _bulkWrites++);
    try {
      final entries = targets.entries.toList();
      var saved = false;
      for (var i = 0; i < entries.length; i += 6) {
        final chunk = entries.skip(i).take(6);
        final results = await Future.wait([
          for (final e in chunk)
            _write(
              writer,
              e.key,
              e.value,
              previous[e.key] ?? AttendanceStatus.neutral,
              rev: revs[e.key],
              refresh: false,
            ),
        ]);
        saved = saved || results.any((ok) => ok);
      }
      if (saved) writer.refreshStatuses(_id);
    } finally {
      if (mounted) _update(() => _bulkWrites--);
    }
  }

  void _showToast(String text, {_Undo? undo}) {
    _undoTimer?.cancel();
    _update(() {
      _toast = text;
      _undo = undo;
    });
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        _update(() {
          _toast = null;
          _undo = null;
        });
      }
    });
  }

  void _setStatus(RdMember member, AttendanceStatus status) {
    final previous = member.status;
    if (previous == status) return;
    HapticHelper.light();
    _update(() {
      _statuses[member.id] = status;
      _pinned.add(member.id);
    });
    final l10n = context.l10n;
    final text = status == AttendanceStatus.neutral
        ? l10n.redesignEventToastReset(member.name)
        : l10n.redesignEventToastSet(member.name, ionicStatusLabel(status));
    _showToast(text, undo: _Undo(text, {member.id: previous}));
    _write(PersonAttendanceWriter(ref), member.id, status, previous);
  }

  void _allOpenPresent(List<RdMember> open) {
    if (open.isEmpty) return;
    HapticHelper.light();
    final previous = {for (final m in open) m.id: m.status};
    // Not pinned: after the bulk button the list of exceptions stays short
    // (pinning only keeps a single changed row from jumping away).
    _update(() {
      for (final m in open) {
        _statuses[m.id] = AttendanceStatus.present;
      }
    });
    final text = context.l10n.redesignEventAllDone(open.length);
    _showToast(text, undo: _Undo(text, previous));
    _writeMany({for (final m in open) m.id: AttendanceStatus.present}, previous);
  }

  void _runUndo() {
    final undo = _undo;
    if (undo == null) return;
    final current = {for (final id in undo.previous.keys) id: _statuses[id] ?? AttendanceStatus.neutral};
    _update(() {
      undo.previous.forEach((id, status) => _statuses[id] = status);
    });
    _showToast(context.l10n.redesignEventUndone);
    _writeMany(undo.previous, current);
  }

  /// "Person hinzufügen"; Leitung that may create persons (Admin,
  /// Verantwortliche like "Neue Person") can also create a new one there,
  /// who is added to this Termin right away.
  Future<void> _addPersons() {
    final role = ref.read(effectiveRoleProvider);
    final canCreate = role.isAdmin || role.isResponsible;
    return addPersonsToAttendance(
      context,
      ref,
      attendanceId: _id,
      currentPersonIds: _rowPersonIds ?? const {},
      onCreateNew: canCreate ? () => createPersonForAttendance(context, ref, attendanceId: _id) : null,
    );
  }

  /// The person sheet: status, note, registration answers, "Zur Person",
  /// "Aus Termin entfernen" and who changed it last (the last two not for
  /// Helfer, like the Termin page).
  Future<void> _openStatusSheet(RdMember member, List<AttendanceStatus> available, bool canEditNote) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final isHelper = role == Role.helper;
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final result = await showRdStatusSheet(
      context,
      member: member,
      subtitle: member.groupName ?? l10n.rdWordsNoGroup(ref.read(rdGroupKindProvider)),
      available: available,
      canEditNote: canEditNote,
      registration: _registrationOf(member.id, type),
      changedInfo: isHelper ? null : _changedInfo(member),
      canOpenPerson: role.canSeePeopleTab,
      canRemove: !isHelper && canMutateAttendanceDetail(role),
    );
    if (result == null || !mounted) return;
    if (result.action == RdPersonSheetAction.remove) {
      await _removePerson(member);
      return;
    }
    if (result.status != member.status) _setStatus(member, result.status);
    final note = result.note ?? '';
    if (canEditNote && note != (member.note ?? '')) await _writeNote(member, note);
    if (result.action == RdPersonSheetAction.openPerson && mounted) {
      context.push(RedesignRoutes.person(member.id));
    }
  }

  /// Opens the person sheet for [member] as currently shown.
  void _openMember(RdMember member) {
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final typeStatuses = type?.availableStatuses;
    final available = (typeStatuses?.isNotEmpty ?? false) ? typeStatuses! : AttendanceStatus.values;
    _openStatusSheet(member, available, ref.read(canViewAttendanceNotesProvider));
  }

  /// "Mitfahrt: nein · Essen: normal" (the Termin page's registration
  /// summary); null without answers.
  String? _registrationOf(int personId, AttendanceType? type) {
    final fields = type?.registrationFields ?? const <RegistrationField>[];
    final answers = _regAnswers[personId];
    if (fields.isEmpty || answers == null || answers.isEmpty) return null;
    final parts = <String>[];
    for (final f in fields) {
      final value = answers[f.id];
      if (value == null) continue;
      final text = registrationAnswerText(f, value);
      parts.add('${f.label}: ${text.isEmpty ? '–' : text}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "Zuletzt geändert von Leon Jäger · Do 26.11., 19:41" (Ionic
  /// getModifierInfo); null while the status was never changed.
  String? _changedInfo(RdMember member) {
    final by = member.changedBy;
    if (by == null) return null;
    final l10n = context.l10n;
    final persons = ref.read(filteredPersonsForAttendanceProvider(_id)).valueOrNull ?? const <Person>[];
    final modifier = persons.where((p) => p.appId == by).firstOrNull;
    final name = modifier != null && modifier.fullName.trim().isNotEmpty ? modifier.fullName.trim() : l10n.commonUnknown;
    final at = member.changedAt == null ? null : DateTime.tryParse(member.changedAt!)?.toLocal();
    return at == null ? l10n.attendanceLastChangedBy(name) : l10n.redesignEventChangedBy(name, rdDeadlineLabel(at));
  }

  /// "Aus Termin entfernen" (Termin page `_removePersonFromAttendance`):
  /// asks, checks the row's tenant, deletes the row.
  Future<void> _removePerson(RdMember member) async {
    final l10n = context.l10n;
    // Bound before the dialog (tenant switch safety); the container
    // outlives this page.
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final container = ProviderScope.containerOf(context, listen: false);
    final paId = _paIds[member.id];
    if (paId == null) {
      ToastHelper.showError(context, l10n.attendanceFlutterNoEntry);
      return;
    }
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.attendanceRemovePerson,
      message: l10n.attendanceRemovePersonConfirm(member.name),
      confirmText: l10n.commonRemove,
      isDestructive: true,
    );
    if (!confirmed || !mounted || !session.isCurrent()) return;
    try {
      if (!repo.hasTenantId || !await repo.validatePersonAttendanceTenant(paId)) {
        if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterNoPermission);
        return;
      }
      // Account switched while the check ran: never delete for the new one.
      if (!session.isCurrent()) return;
      _ownDeletedPaIds.add(paId);
      await repo.deletePersonAttendance(paId);
    } catch (e) {
      _ownDeletedPaIds.remove(paId);
      if (mounted) ToastHelper.showError(context, l10n.attendancePersonRemoveFailed);
      return;
    }
    container.invalidate(personAttendancesForAttendanceProvider(_id));
    // The Termin list's realtime channel only sees updates, not deletes:
    // reload it so its counts and percentages drop the person too.
    container.read(attendanceRefetchCounter.notifier).state++;
    if (!mounted) return;
    _update(() {
      _rowPersonIds = {...?_rowPersonIds}..remove(member.id);
      _statuses.remove(member.id);
      _paIds.remove(member.id);
      _notes.remove(member.id);
      _pinned.remove(member.id);
    });
    ToastHelper.showSuccess(context, l10n.attendancePersonRemoved);
  }

  // ---------------------------------------------------------------------------
  // ••• menu
  // ---------------------------------------------------------------------------

  /// "•••" next to "Bearbeiten" (concept L6): Status-Übersicht,
  /// Gemeinde-Übersicht, Excel, Telegram-Karte, Archivieren. The Vorbereitung lives in the
  /// Überblick, the answers per status in the Anwesenheit.
  /// "Termin löschen" is at the bottom of "Bearbeiten".
  Future<void> _openMenu(Attendance attendance, List<RdMember> members) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final type = ref.read(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    final canArchive = canArchiveAttendance(
      date: attendance.date,
      durationDays: _effectiveDays(attendance, type),
      archived: attendance.archived,
      role: role,
    );
    final action = await showAppActionSheet<_MenuAction>(
      context,
      title: rdEventInfo(attendance, type).title,
      message: role.isAdmin || role.isResponsible ? l10n.redesignEventDeleteHint : null,
      actions: [
        // Like Ionic: offered whenever the group has the Gemeinde field.
        if (members.isNotEmpty && attendanceChurchFieldId(ref) != null)
          AppActionSheetAction(
            value: _MenuAction.church,
            icon: Icons.business_outlined,
            label: l10n.attendanceChurchOverview,
          ),
        if (members.isNotEmpty)
          AppActionSheetAction(
            value: _MenuAction.excel,
            icon: Icons.table_chart_outlined,
            label: l10n.redesignEventExportExcel,
          ),
        if (canMutateAttendanceDetail(role))
          AppActionSheetAction(
            value: _MenuAction.telegram,
            icon: Icons.send_outlined,
            label: l10n.attendanceTelegramCard,
            enabled: !_isSendingTelegramCard,
          ),
        if (canArchive)
          AppActionSheetAction(
            value: _MenuAction.archive,
            icon: attendance.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: attendance.archived ? l10n.attendanceRestore : l10n.attendanceArchive,
          ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MenuAction.church:
        await showAttendanceChurchOverview(
          context,
          ref,
          persons: [for (final m in members) m.person],
          statusOf: (person) => members.firstWhere((m) => m.id == person.id).status,
        );
      case _MenuAction.excel:
        await _exportExcel(attendance, members);
      case _MenuAction.telegram:
        await _sendTelegramCard();
      case _MenuAction.archive:
        await _toggleArchived(attendance);
    }
  }

  bool _menuHasActions(Attendance attendance, List<RdMember> members) {
    if (members.isNotEmpty) return true;
    final role = ref.watch(effectiveRoleProvider);
    if (canMutateAttendanceDetail(role)) return true;
    final type = ref.watch(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    return canArchiveAttendance(
      date: attendance.date,
      durationDays: _effectiveDays(attendance, type),
      archived: attendance.archived,
      role: role,
    );
  }

  /// Create a group-card link, then open it directly from the confirmation
  /// button so browsers retain the user gesture required for a new window.
  Future<void> _sendTelegramCard() async {
    if (_isSendingTelegramCard || !canMutateAttendanceDetail(ref.read(effectiveRoleProvider))) return;
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final attendanceId = _id;
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    bool isCurrent() => mounted && _id == attendanceId && session.isCurrent() &&
        canMutateAttendanceDetail(ref.read(effectiveRoleProvider));
    _isSendingTelegramCard = true;
    try {
      String? url;
      final loading = showIonLoading(context);
      try {
        url = await repo.createTelegramCardLink(attendanceId);
      } on DemoModeException {
        return; // The repository already showed the demo restriction.
      } catch (_) {
        url = null;
      } finally {
        loading.dismiss();
      }
      if (!mounted || !isCurrent()) return;
      if (url == null) {
        ToastHelper.showError(context, context.l10n.attendanceTelegramCardFailed);
        return;
      }
      final target = Uri.parse(url);
      await showAppDialog<void>(
        context: context,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppAlertDialog(
              title: Text(ctx.l10n.attendanceTelegramCard),
              content: Text(ctx.l10n.attendanceTelegramCardHint),
              scrollable: true,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(ctx.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (!isCurrent()) return;
                    try {
                      final opened = await launchUrl(target, mode: LaunchMode.externalApplication);
                      if (!opened && mounted && isCurrent()) {
                        ToastHelper.showError(context, context.l10n.attendanceTelegramCardFailed);
                      }
                    } catch (_) {
                      if (mounted && isCurrent()) {
                        ToastHelper.showError(context, context.l10n.attendanceTelegramCardFailed);
                      }
                    }
                  },
                  child: Text(ctx.l10n.attendanceTelegramCardOpen),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _isSendingTelegramCard = false;
    }
  }

  /// "Als Excel exportieren" with the statuses shown on this page.
  Future<void> _exportExcel(Attendance attendance, List<RdMember> members) async {
    final tenant = ref.read(currentTenantProvider);
    // Bound before the awaits (tenant switch safety).
    final profileRepo = ref.read(profileRepositoryWithTenantProvider);
    final canViewNotes = ref.read(canViewAttendanceNotesProvider);
    if (tenant == null) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterDataUnavailable);
      return;
    }
    ToastHelper.showInfo(context, context.l10n.attendanceFlutterCreatingExcel);
    try {
      final type = ref.read(attendanceTypeForAttendanceProvider(attendance.id ?? -1)).valueOrNull;
      final churchFieldId = attendanceChurchFieldId(ref);
      final churches = churchFieldId == null
          ? const <Church>[]
          : await ref.read(churchesProvider.future);
      final persons = [for (final m in members) m.person];
      // The Gemeinde can be an organisation field (shared value).
      final exported = churchFieldId == null
          ? persons
          : await profileRepo.hydrateSharedPersonFieldValues(persons);
      if (!mounted) return;
      await ExportService().exportAttendanceToExcel(
        context: context,
        attendance: attendance,
        typeName: type?.name ?? '',
        persons: exported,
        statuses: {for (final m in members) m.id: m.status},
        // Notes stay hidden for roles that may not see them in the view.
        notes: canViewNotes ? {for (final m in members) m.id: m.note} : const {},
        churches: churches,
        churchFieldId: churchFieldId,
      );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.exportFlutterFailedWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic 4.17.24 `toggleArchived` (Termin page): archiving asks first,
  /// restoring does not.
  Future<void> _toggleArchived(Attendance attendance) async {
    final l10n = context.l10n;
    final archive = !attendance.archived;
    // Read before the first await (tenant switch while the dialog is open).
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    final container = ProviderScope.containerOf(context, listen: false);
    if (archive) {
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: l10n.attendanceArchiveConfirmHeader,
        message: l10n.attendanceArchiveConfirmMessage,
        confirmText: l10n.attendanceArchive,
      );
      if (!confirmed || !mounted) return;
    }
    try {
      // Account or tenant switched while the dialog was open: no write.
      if (!repo.hasTenantId || !session.isCurrent()) return;
      // Current state right before the write (Termin page `_toggleArchived`):
      // archived or restored meanwhile (other device, second tap) → no write.
      final current = container.read(attendanceDetailProvider(_id)).valueOrNull;
      if (current == null || current.archived == archive) return;
      await repo.updateAttendance(_id, {
        'archived': archive,
        'archived_at': archive ? DateTime.now().toUtc().toIso8601String() : null,
        'archived_by': archive ? session.userId : null,
      });
      container
        ..invalidate(attendanceDetailProvider(_id))
        ..invalidate(realtimeAttendanceListProvider);
      if (mounted) ToastHelper.showSuccess(context, archive ? l10n.attendanceArchivedToast : l10n.attendanceRestoredToast);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceArchiveFailed);
    }
  }

  /// Note of one person for this Termin (same rules as the Termin page).
  Future<void> _writeNote(RdMember member, String note) async {
    final paId = _paIds[member.id];
    if (paId == null) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterNoEntry);
      return;
    }
    String? previousNote;
    var direct = false;
    final writer = PersonAttendanceWriter(ref);
    _hold(member.id);
    try {
      final result = await _queue.run(
        paId,
        () => writer.write(
          attendanceId: _id,
          personAttendanceId: paId,
          updates: {'notes': note},
          beforeWrite: () {
            direct = true;
            previousNote = _notes[member.id];
            if (mounted) _update(() => _notes[member.id] = note);
          },
        ),
      );
      if (!mounted) return;
      switch (result) {
        case PersonAttendanceWrite.queued:
          _update(() => _notes[member.id] = note);
        case PersonAttendanceWrite.notAllowed:
          ToastHelper.showError(context, context.l10n.attendanceFlutterNoPermission);
        case PersonAttendanceWrite.saved:
          ToastHelper.showSuccess(
            context,
            note.isNotEmpty ? context.l10n.attendanceNoteAdded : context.l10n.attendanceFlutterNoteDeleted,
          );
      }
    } catch (e) {
      if (direct && mounted) _update(() => _notes[member.id] = previousNote);
      _showWriteError((l10n) => l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      _release(member.id);
    }
  }
}
