part of 'planning_page.dart';

/// Template, song-list, agenda-topic, and add-action dispatching operations for
/// [PlanningPage].
extension _PlanningTemplateOps on _PlanningPageState {
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
}
