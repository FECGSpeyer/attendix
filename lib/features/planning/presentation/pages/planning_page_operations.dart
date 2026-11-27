part of 'planning_page.dart';

extension _PlanningOperations on _PlanningPageState {
  // ---------------------------------------------------------------------------
  // Termin navigation
  // ---------------------------------------------------------------------------

  Future<void> _selectAttendance(int? id) async {
    if (id == null || id == _attId) return;
    // SOL_FIX23: a failed write keeps the open Termin (and its changes).
    if (!await _flushSaves()) {
      if (mounted) _rdSet(() {});
      return;
    }
    if (!mounted) return;
    final att = _attendances.where((a) => a.id == id).firstOrNull;
    if (att != null) _loadAttendance(att);
  }

  Future<void> _navigate(int direction) async {
    final i = _attendances.indexWhere((a) => a.id == _attId);
    // List is sorted newest first: "Nächste" goes to a smaller index.
    final target = i - direction;
    if (target < 0) {
      ToastHelper.showWarning(context, context.l10n.planningFirstEvent);
      return;
    }
    if (target >= _attendances.length) {
      ToastHelper.showWarning(context, context.l10n.planningLastEvent);
      return;
    }
    await _selectAttendance(_attendances[target].id);
  }

  // ---------------------------------------------------------------------------
  // Several plans
  // ---------------------------------------------------------------------------

  Future<void> _selectPlan(int index) async {
    if (_att == null || index == _planIndex) return;
    final attId = _attId!;
    // SOL_FIX30: the chosen plan by identity; the save below may adopt a
    // deletion or reorder by another editor, which shifts positions.
    final target = _refOf(_att, index);
    final loadGen = _loadGen;
    // SOL_FIX23: wait for running writes; a failed write keeps the plan open.
    if (!await _flushSaves() || !mounted) return;
    // SOL_FIX30: the open plan was replaced meanwhile (deleted by another
    // editor, the user was told): stay on what the editor shows now.
    if (_attId != attId || _att == null || loadGen != _loadGen) return;
    if (!_adoptLatest(attId)) return;
    final updated = _att!;
    final i = _indexOfRef(updated, target);
    if (i == null) {
      ToastHelper.showWarning(
          context,
          _isPositionalKey(target.key)
              ? context.l10n.planningFlutterPlanChanged
              : context.l10n.planningFlutterPlanDeleted);
      return;
    }
    if (i == _planIndex) return;
    _rdSet(() => _planIndex = i);
    _loadPlan(updated, PlanUtils.allPlans(updated)[i]);
  }

  Future<void> _addPlan() async {
    if (_att == null) {
      ToastHelper.showWarning(context, context.l10n.planningChooseEventFirst);
      return;
    }
    if (!_validate()) {
      ToastHelper.showWarning(context, context.l10n.planningCreateRunSheetFirst);
      return;
    }
    // The start plan becomes the first plan, the new one the second.
    _markStartPlanPending();
    if (!await _flushSaves() || !mounted) return;
    final att = _att!;
    final plans = PlanUtils.allPlans(att);
    final beta = await showRdNewPlanSheet(
      context,
      days: PlanUtils.dayOptions(att),
      initialDay: PlanUtils.nextFreeDay(att, plans),
      copyOf: PlanUtils.planLabel(att, _planIndex.clamp(0, plans.isEmpty ? 0 : plans.length - 1), plans),
    );
    if (beta == null || !mounted || _att == null) return;
    final attId = _attId!;
    if (!_adoptLatest(attId)) return; // SOL_FIX28 / SOL_FIX29
    final copy = beta.copy;
    final current = _att!;
    final type = _typeOf(current);
    final time = copy ? _time : PlanUtils.formatTime(type?.startTime ?? current.startTime ?? _time);
    final newPlan = Plan(
      id: PlanUtils.uuid(),
      time: time.isEmpty ? _time : time,
      // Ionic: `dayjs().hour(..).minute(..).format('YYYY-MM-DDTHH:mm')`
      end: copy ? _end : PlanUtils.computeEndIso(time.isEmpty ? _time : time, const []),
      fields: copy
          ? _fields.where((f) => f.agendaItemId == null && !PlanUtils.isAgendaPlaceholder(f)).toList()
          : const [],
      title: copy && _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
    );
    try {
      // SOL_FIX24: no edits between the write and loading the new plan.
      await _whileBusy(() async {
        // SOL_FIX29: appended to the newest stored plan list (day: the next
        // free day there).
        final open = await _writePlanOp(attId, null, (att, plans, _) {
          final day = PlanUtils.dayOptions(att).any((d) => d.day == beta.day)
              ? beta.day
              : PlanUtils.nextFreeDay(att, plans);
          final label = beta.label;
          plans.add(newPlan.copyWith(day: day, label: label.isEmpty ? null : label));
          return (plans: plans, open: plans.length - 1);
        });
        if (open == null || !mounted || _att == null) return;
        _rdSet(() => _planIndex = open);
        _loadPlan(_att!, PlanUtils.allPlans(_att)[open]);
      });
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.planningFlutterSaveFailedWith(friendlyErrorMessage(e)));
    }
  }

  /// [preset]: the action chosen in the Beta "•••" sheet (no own sheet).
  Future<void> _showPlanOptions({String? preset}) async {
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final shownIndex = _planIndex;
    final loadGen = _loadGen;
    final action = preset ?? await showPlanActionSheet<String>(
      context,
      title: context.l10n.planningPlanHeader(PlanUtils.planLabel(att, shownIndex, plans)),
      subtitle: context.l10n.planningFlutterPlanPosition(shownIndex + 1, plans.length),
      actions: [
        PlanSheetAction('rename', context.l10n.planningRename, icon: AppIcons.editOutlined),
        if (PlanUtils.dayOptions(att).isNotEmpty)
          PlanSheetAction('day', context.l10n.planningAssignOtherDay, icon: AppIcons.event),
        if (shownIndex > 0) PlanSheetAction('left', context.l10n.planningMoveLeft, icon: AppIcons.chevronLeft),
        if (shownIndex < plans.length - 1)
          PlanSheetAction('right', context.l10n.planningMoveRight, icon: AppIcons.chevronRight),
        PlanSheetAction('delete', context.l10n.planningDeletePlan, icon: AppIcons.deleteOutline, destructive: true),
      ],
    );
    if (action == null || !mounted) return;
    // SOL_FIX24: an invalid open plan does not block: rename / day / move
    // keep the editor (and its pending edits), delete removes the plan.
    if (!await _flushSaves(blockInvalid: false) || !mounted || _att == null) return;
    // SOL_FIX30: the plan the sheet was opened for is no longer open (it was
    // deleted meanwhile and the user was told): nothing to do.
    if (_attId != att.id || loadGen != _loadGen) return;
    final attId = _attId!;
    // SOL_FIX29: the plan the sheet was opened for (its id, else position).
    // SOL_FIX30: taken after the save above (the open plan as stored), so a
    // plan without id is matched against the editor's current version.
    final planKey = _refOf(_att, _planIndex);
    // SOL_FIX28: show the newest stored row in the dialogs; the open plan
    // keeps its position there. SOL_FIX29: stop when it was deleted.
    if (!_adoptLatest(attId)) return;
    final current = _att!;
    final index = _indexOfRef(current, planKey);
    if (index == null) return;
    final list = PlanUtils.withDays(current, PlanUtils.allPlans(current));
    // SOL_FIX29: every change below is applied to the newest stored row
    // INSIDE the queued write ([_writePlanOp]), so a plan another editor
    // stored while a dialog was open is never reset by this copy.
    try {
      switch (action) {
        case 'rename':
          final auto = PlanUtils.planLabel(current, index, [for (final p in list) p.copyWith(label: null)]);
          final label = await showPlanTextPrompt(
            context,
            title: context.l10n.planningRenamePlan,
            message: context.l10n.planningRenameHint,
            initialValue: list[index].label,
            hint: auto,
            allowEmpty: true,
          );
          if (label == null || !mounted) return;
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              plans[i!] = plans[i].copyWith(label: label.isEmpty ? null : label);
              return (plans: plans, open: i);
            });
            if (open != null && mounted && open != _planIndex) _rdSet(() => _planIndex = open);
          });
        case 'day':
          final options = PlanUtils.dayOptions(current);
          final day = await showPlanActionSheet<int>(
            context,
            title: context.l10n.planningAssignDay,
            actions: [
              for (final o in options)
                PlanSheetAction(
                  o.day,
                  o.label,
                  icon: o.day == list[index].day ? AppIcons.checkCircle : AppIcons.eventOutlined,
                ),
            ],
          );
          if (day == null || day == list[index].day || !mounted) return;
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              final moved = plans[i!].copyWith(day: day);
              plans[i] = moved;
              plans.sort((a, b) => (a.day ?? 0).compareTo(b.day ?? 0));
              return (plans: plans, open: plans.indexWhere((p) => identical(p, moved)));
            });
            if (open != null && mounted) _rdSet(() => _planIndex = open);
          });
        case 'left':
        case 'right':
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              final to = i! + (action == 'left' ? -1 : 1);
              if (to < 0 || to >= plans.length) return null;
              final tmp = plans[i];
              plans[i] = plans[to];
              plans[to] = tmp;
              return (plans: plans, open: to);
            });
            if (open != null && mounted) _rdSet(() => _planIndex = open);
          });
        case 'delete':
          final ok = await showPlanConfirm(
            context,
            title: context.l10n.planningDeletePlanConfirm,
            message: context.l10n.planningDeletePlanMessage(PlanUtils.planLabel(current, index, list)),
            confirmText: context.l10n.commonDelete,
            destructive: true,
          );
          if (!ok || !mounted) return;
          await _whileBusy(() async {
            final open = await _writePlanOp(attId, planKey, (att, plans, i) {
              plans.removeAt(i!);
              return (plans: plans, open: plans.isEmpty ? -1 : i.clamp(0, plans.length - 1));
            });
            if (open == null || !mounted) return;
            if (open < 0) {
              // SOL_FIX22: last plan deleted → empty editor, nothing pending.
              _clearEditor(_att ?? current);
            } else if (_att != null) {
              _rdSet(() => _planIndex = open);
              _loadPlan(_att!, PlanUtils.allPlans(_att)[open]);
            }
          });
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.planningFlutterSaveFailedWith(friendlyErrorMessage(e)));
    }
  }

  // ---------------------------------------------------------------------------
  // Adding fields
  // ---------------------------------------------------------------------------

  /// A dialog opened for the plan loaded at [loadGen] still applies: no other
  /// plan was loaded meanwhile (conflict reload, draft, other Termin).
  bool _samePlan(int loadGen) => mounted && loadGen == _loadGen;

  Future<void> _addField() async {
    final loadGen = _loadGen;
    final r = await showPlanFieldDialog(context,
        title: context.l10n.planningAddField, nameHint: context.l10n.planningEnterFreeText, initialMinutes: 20);
    if (r == null || !_samePlan(loadGen)) return;
    _rdSet(() => _fields = [
          ..._fields,
          PlanField(id: r.name, name: r.name, conductor: r.conductor, info: r.info, time: '${r.minutes ?? 20}'),
        ]);
    _changed();
  }

  Future<void> _addNote() async {
    final loadGen = _loadGen;
    final r = await showPlanFieldDialog(context,
        title: context.l10n.planningAddNoteField,
        nameLabel: context.l10n.planningNote,
        nameHint: context.l10n.planningEnterNote,
        emptyNameMessage: context.l10n.plansEnterNotePlease,
        withConductor: false,
        withInfo: false,
        withMinutes: false);
    if (r == null || !_samePlan(loadGen)) return;
    _rdSet(() => _fields = [..._fields, PlanField(id: 'noteFld ${r.name}', name: r.name, conductor: '', time: '0')]);
    _changed();
  }

  Future<void> _addGroup() async {
    final loadGen = _loadGen;
    final r = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddBlock,
      message: context.l10n.planningBlockDurationHint,
      nameLabel: context.l10n.planningName,
      nameHint: context.l10n.planningBlockNamePlaceholder,
      conductorLabel: context.l10n.planningPerformance,
      conductorHint: context.l10n.planningPerformanceOptional,
      confirmText: context.l10n.commonCreate,
      emptyNameMessage: context.l10n.planningEnterNamePlease,
      withMinutes: false,
    );
    if (r == null || !mounted || !_samePlan(loadGen)) return;
    final head = PlanUtils.newGroupHead(r.name, conductor: r.conductor, info: r.info);
    _rdSet(() => _fields = [..._fields, head]);
    _changed();
    final sub = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddSubItem,
      subtitle: head.name,
      nameHint: context.l10n.planningSubItemPlaceholder,
      infoHint: context.l10n.planningSubItemInfoPlaceholder,
      initialMinutes: 5,
    );
    // The block may be gone meanwhile (deleted, other plan loaded).
    if (sub == null || !_samePlan(loadGen) || !_fields.any((f) => f.id == head.id)) return;
    _rdSet(() => _fields = PlanUtils.addSubItem(
          _fields,
          head.id,
          PlanField(
            id: 'fld-${PlanUtils.uuid()}',
            name: sub.name,
            conductor: sub.conductor,
            info: sub.info,
            time: '${sub.minutes ?? 5}',
          ),
        ));
    _changed();
  }

  /// Ionic 4.17.25 `addCurrentSongs`: adds the current Werke missing in the
  /// open plan; when all are already there, asks whether to add them again.
  Future<void> _addCurrentSongs() async {
    final loadGen = _loadGen;
    final added = await _currentSongFieldsOrAsk();
    if (added.isEmpty || !_samePlan(loadGen)) return;
    _rdSet(() => _fields = [..._fields, ...added]);
    _changed();
  }

  /// The rows of the current Werke missing in the open plan (asks whether
  /// to add them again when all are there; empty: nothing to add).
  Future<List<PlanField>> _currentSongFieldsOrAsk() async {
    final prefix = _songPrefix(_typeOf(_att));
    const time = PlanSongHelper.betaTime;
    final all = PlanSongHelper.currentSongFields(
      const [],
      history: _history,
      songs: _songs,
      prefix: prefix,
      time: time,
    );
    if (all.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.planningNoCurrentSongs);
      return const [];
    }
    final added = PlanSongHelper.currentSongFields(
      _fields,
      history: _history,
      songs: _songs,
      prefix: prefix,
      time: time,
    );
    if (added.isNotEmpty) return added;
    final loadGen = _loadGen;
    final again = await showPlanConfirm(
      context,
      title: context.l10n.planningCurrentSongsAlreadyAddedHeader,
      message: context.l10n.planningCurrentSongsAlreadyAddedMessage,
      confirmText: context.l10n.planningAddAgain,
    );
    if (!again || !_samePlan(loadGen)) return const [];
    return all;
  }

  Future<void> _addSong() async {
    final loadGen = _loadGen;
    final field = await _pickSongField();
    if (field == null || !_samePlan(loadGen)) return;
    _rdSet(() => _fields = [..._fields, field]);
    _changed();
  }

  /// The row of a Werk picked from the list (null: none picked).
  Future<PlanField?> _pickSongField() async {
    final loadGen = _loadGen;
    final song = await showPlanSongPicker(
      context,
      _songs,
      currentIds: _history.map((h) => h.songId).whereType<int>().toSet(),
      inPlanIds: _fields.map((f) => f.songId).whereType<int>().toSet(),
    );
    if (song == null || !_samePlan(loadGen)) return null;
    return PlanSongHelper.songField(song, history: _history, prefix: _songPrefix(_typeOf(_att)));
  }

  void _insertBlockTemplate(PlanBlockTemplate tpl) {
    _rdSet(() => _fields = [..._fields, ...PlanUtils.cloneBlock(tpl.fields)]);
    _changed();
  }

  Future<void> _deleteBlockTemplate(PlanBlockTemplate tpl) async {
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.planningDeleteTemplateConfirm,
      message: context.l10n.planningDeleteTemplateMessage(tpl.name),
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    // TERMINE-22: the editor may have gone while the alert was open.
    if (!ok || !mounted) return;
    // Ionic tenant.service: a failed tenant update shows this toast (the
    // only error message here; the template simply stays otherwise).
    bool deleted;
    try {
      deleted = await ref.read(planSettingsNotifierProvider.notifier).deleteBlockTemplate(tpl.id);
    } catch (_) {
      // Reading the current templates failed (repository already reports).
      deleted = false;
    }
    if (!deleted && mounted) {
      ToastHelper.showError(context, context.l10n.svcUpdateSettingsFailed);
    }
  }

  Future<void> _saveBlockTemplate(PlanField head) async {
    final ok = await ref.read(planSettingsNotifierProvider.notifier).saveBlockAsTemplate(_fields, head.id);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.planningTemplateSaved(head.name));
    } else {
      ToastHelper.showError(context, context.l10n.planningTemplateSaveFailed);
    }
  }

  void _applyOrgTemplate(Plan tpl) {
    _rdSet(() {
      // Ionic applyTemplate resolves placeholders without the Termin type.
      _fields = PlanSongHelper.resolvePlaceholders(tpl.fields,
          history: _history, songs: _songs, prefix: _songPrefix(null));
      final t = PlanUtils.formatTime(tpl.time);
      if (t.isNotEmpty) _time = t;
    });
    _changed();
  }

  void _addOrgField(PlanField field) {
    _rdSet(() => _fields = [..._fields, field]);
    _changed();
  }

  /// Ionic `canAddTopics`: topics only live in the first plan of a protocol type.
  bool get _canAddTopics {
    final hasProtocol = ref.read(protocolTypeByIdProvider(_att?.typeId))?.enableProtocol ?? false;
    return _att?.id != null && _planIndex == 0 && hasProtocol && ref.read(isTeamLeaderProvider);
  }

  /// Runs an entry of the "+" menu.
  Future<void> _runAddAction(String action) async {
    final blockTemplates = ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[];
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    if (action.startsWith('block:')) {
      final tpl = blockTemplates.where((t) => t.id == action.substring(6)).firstOrNull;
      if (tpl != null) _insertBlockTemplate(tpl);
      return;
    }
    if (action.startsWith('delblock:')) {
      final tpl = blockTemplates.where((t) => t.id == action.substring(9)).firstOrNull;
      if (tpl != null) await _deleteBlockTemplate(tpl);
      return;
    }
    if (action.startsWith('tpl:')) {
      final i = int.parse(action.substring(4));
      if (i < orgTemplates.length) _applyOrgTemplate(orgTemplates[i]);
      return;
    }
    if (action.startsWith('orgfield:')) {
      final i = int.parse(action.substring(9));
      if (i < orgFields.length) _addOrgField(orgFields[i]);
      return;
    }
    switch (action) {
      case 'field':
        await _addField();
      case 'group':
        await _addGroup();
      case 'note':
        await _addNote();
      case 'current':
        await _addCurrentSongs();
      case 'song':
        await _addSong();
      case 'plan':
        await _addPlan();
      case 'agenda':
        _addAgendaPlaceholder();
      case 'topics':
        await _openAgendaPicker();
    }
  }

  // PROTOCOL: Ionic `addAgendaItemsPlaceholder` (the marker takes no time).
  void _addAgendaPlaceholder() {
    if (_fields.any(PlanUtils.isAgendaPlaceholder)) {
      ToastHelper.showWarning(context, context.l10n.planningAgendaExists);
      return;
    }
    _rdSet(() => _fields = [
          ..._fields,
          PlanField(id: PlanUtils.agendaPlaceholderId, name: context.l10n.planningAgenda, time: '0'),
        ]);
    _changed();
  }

  // PROTOCOL: Ionic `openAgendaPicker` — saves what is on screen first, so the
  // picker inserts into the current plan, then takes over the saved plan.
  Future<void> _openAgendaPicker() async {
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    final att = _att;
    if (att?.id == null) return;
    if (!await _flushSaves() || !mounted) return;
    // SOL_FIX31: identity of the main plan the picker inserts into (the
    // stored version after the save above).
    final mainRef = _refOf(_att, 0);
    // SOL_FIX24: no edits while the protocol row loads (the picker then
    // stores the editor state and the editor reloads the stored plan).
    var protocolAtt = await _whileBusy<ProtocolAttendance?>(() async {
      try {
        return await protocolRepo.getAttendance(att!.id!);
      } catch (_) {
        return null;
      }
    });
    if (protocolAtt == null || !mounted) return;
    final title = _titleController.text.trim();
    if (_fields.isNotEmpty) {
      protocolAtt = protocolAtt.copyWith(plan: {
        ...?protocolAtt.plan,
        'time': _time,
        'end': _end,
        'fields': _fields.map((f) => f.toJson()).toList(),
        if (title.isNotEmpty) 'title': title,
      });
    }
    final type = ref.read(protocolTypeByIdProvider(att!.typeId));
    final attId = att.id!;
    final pickerAtt = protocolAtt;
    // SOL_FIX30: the topics are written by [_saveTopics] in the write queue
    // of the Termin, on its newest stored row; that write registers the full
    // stored row (every plan), so nothing here uses the copy from before.
    final saved = await showAgendaPickerSheet(context,
        attendance: pickerAtt,
        type: type,
        save: (selections, removeIds) => _saveTopics(attId, pickerAtt, type, selections, removeIds, mainRef));
    if (saved == null || !mounted || _attId != attId) return;
    final stored = _att;
    final plans = PlanUtils.allPlans(stored);
    if (stored == null || plans.isEmpty) return;
    _rdSet(() => _planIndex = 0);
    _loadPlan(stored, plans.first);
    ref.invalidate(planAttendanceByIdProvider(attId));
  }

  /// SOL_FIX30: "Themen aufnehmen" write (Ionic `addTopicsToAttendance`): a
  /// row -> row operation INSIDE the write queue of Termin [attId] (like
  /// [_writePlanOp]): the topics are added to the main plan of the newest
  /// stored row (re-read, else the newest commit / own copy), only the
  /// `plan` column is written and the full stored row is registered as the
  /// newest commit. Returns the stored main plan.
  Future<Map<String, dynamic>> _saveTopics(int attId, ProtocolAttendance protocolAtt, ProtocolType? type,
      List<({AgendaItem item, int duration})> selections, List<String> removeIds, _PlanRef mainRef) {
    final repo = ref.read(planRepositoryWithTenantProvider);
    return _serialised(attId, () async {
      PlanAttendance? base;
      try {
        base = await repo.getPlanAttendanceById(attId);
      } catch (_) {
        base = null;
      }
      base ??=
          PlanningWriteSync.latestSince(PlanningWriteSync.keyFor(_tenantId, attId), _knownSeq[attId] ?? 0) ?? _att;
      if (base == null || base.id != attId) throw StateError('Termin $attId not found');
      final mainPlan = base.plan;
      // SOL_FIX31: the main plan the picker was opened for is gone or is no
      // longer the same plan (another editor deleted / changed plans): a
      // conflict, nothing is written (writing would restore a deleted plan).
      // The editor shows the newest row and the user is told.
      if (mainRef.json != null && _indexOfRef(base, mainRef) != 0) {
        final latest = base;
        if (mounted && _attId == attId) _reloadLatest(attId, latest);
        await _planDeletedMeanwhile(attId, mainRef.key, null);
        throw StateError('Plan of Termin $attId changed meanwhile');
      }
      // Without a main plan (none before either) the picker's row is used as
      // is: `copyWith(plan: null)` would keep its old plan.
      final current = mainPlan == null
          ? protocolAtt
          : protocolAtt.copyWith(plan: jsonDecode(jsonEncode(mainPlan.toJson())) as Map<String, dynamic>);
      final plan = planWithTopics(current, type, selections, removeIds: removeIds);
      final saved = await repo.updateAttendancePlanFields(attId, {'plan': plan});
      _markWritten(attId, saved);
      _replaceAtt(saved);
      final stored = saved.plan;
      return stored == null ? plan : jsonDecode(jsonEncode(stored.toJson())) as Map<String, dynamic>;
    });
  }

  // ---------------------------------------------------------------------------
  // Share / export
  // ---------------------------------------------------------------------------

  Future<void> _shareLink() async {
    final att = _att;
    if (att?.id == null) {
      ToastHelper.showWarning(context, context.l10n.planningChooseEventFirst);
      return;
    }
    // The shared page needs a stored plan: store the visible start plan.
    _markStartPlanPending();
    // SOL_FIX24: sharing keeps the editor, so an invalid plan does not block.
    if (!await _flushSaves(blockInvalid: false) || !mounted) return;
    final action = await showPlanActionSheet<String>(
      context,
      title: context.l10n.planningShareLink,
      actions: [
        // Ionic shareCurrentPlan: only these two (revokeSharePlan is not
        // reachable in Ionic).
        PlanSheetAction('read', context.l10n.planningReadOnlyLink),
        PlanSheetAction('edit', context.l10n.planningEditLink),
      ],
    );
    if (action == null || !mounted) return;
    try {
      final edit = action == 'edit';
      var shareKey = att!.shareKey;
      var editKey = att.shareEditKey;
      if (shareKey == null) {
        shareKey = PlanUtils.randomKey();
        editKey = PlanUtils.randomKey();
        await _updateFlags({'share_key': shareKey, 'share_edit_key': editKey});
      } else if (edit && editKey == null) {
        editKey = PlanUtils.randomKey();
        await _updateFlags({'share_edit_key': editKey});
      }
      final base = '/plan?id=${att.id}&key=$shareKey';
      final url = planPublicUrl(edit ? '$base&edit=$editKey' : base);
      if (mounted) await sharePlanLink(context, url, title: _effectiveTitle);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.planningFlutterShareFailedWith(friendlyErrorMessage(e)));
    }
  }

  String get _effectiveTitle {
    final t = _titleController.text.trim();
    return t.isNotEmpty ? t : _defaultTitle(_att);
  }

  PlanExportPage _exportPage(PlanAttendance att, int index, Plan plan) {
    final plans = PlanUtils.allPlans(att);
    final date = PlanUtils.planDate(att, index, plans.isEmpty ? [plan] : plans) ?? DateTime.tryParse(att.date);
    final label = plans.length > 1 ? ' · ${PlanUtils.planLabel(att, index, plans)}' : '';
    final title = (plan.title?.trim().isNotEmpty ?? false) ? plan.title!.trim() : _defaultTitle(att);
    return PlanExportPage(
      title: title,
      subtitle: '${PlanUtils.longDate(date)}$label',
      time: plan.time,
      end: plan.end,
      fields: plan.fields,
    );
  }

  String get _fileDate {
    final d = DateTime.tryParse(_att?.date ?? '') ?? DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}_${d.month.toString().padLeft(2, '0')}_${d.year}';
  }

  Future<void> _resetPlan() async {
    final loadGen = _loadGen;
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.planningResetPlan,
      message: context.l10n.planningResetPlanMessage,
      confirmText: context.l10n.dateDialogReset,
    );
    // Only the plan the dialog was opened for (no reload or conflict meanwhile).
    if (ok && mounted && loadGen == _loadGen && _att != null) _applyTypeDefaultPlan(_att!);
  }

  Future<void> _pickTime() async {
    final m = PlanUtils.parseTimeToMinutes(_time) ?? (17 * 60 + 50);
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    _rdSet(() => _time = PlanUtils.formatMinutes(picked.hour * 60 + picked.minute));
    _changed();
  }
}
