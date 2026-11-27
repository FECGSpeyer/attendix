part of 'planning_page.dart';

extension _PlanningPersistence on _PlanningPageState {
  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> _init(List<PlanAttendance> attendances) async {
    _loaded = true;
    _attendances = [...attendances];
    // SOL_FIX25: the repository (tenant) the Termine were loaded with.
    _disposeRepo = ref.read(planRepositoryWithTenantProvider);
    _tenantId = ref.read(currentTenantIdProvider);
    _userId = ref.read(currentAuthUserIdProvider);
    // SOL_FIX29: the cached rows hold the commits up to the last cache
    // refresh; newer commits are adopted when a Termin is loaded.
    for (final a in _attendances) {
      if (a.id != null) _knownSeq[a.id!] = PlanningWriteSync.refreshedSeq(PlanningWriteSync.keyFor(_tenantId, a.id!));
    }
    PlanAttendance? att;
    final requestedId = widget.attendanceId;
    if (requestedId != null) {
      att = _attendances.where((a) => a.id == requestedId).firstOrNull;
      // SOL_FIX2: a Termin outside the loaded season is loaded by id
      // (tenant-filtered); never edit another Termin instead.
      if (att == null) {
        // SOL_FIX29: fetched now, so it holds every commit made before.
        final seqBefore = PlanningWriteSync.seq(PlanningWriteSync.keyFor(_tenantId, requestedId));
        att = await _loadRequestedAttendance(requestedId);
        if (att != null) _knownSeq[requestedId] = seqBefore;
      }
      if (!mounted) return;
      if (att == null) {
        _rdSet(() {
          _requestedNotFound = true;
          _started = true;
        });
        return;
      }
      if (!_attendances.any((a) => a.id == att!.id)) {
        _attendances = [..._attendances, att]..sort((a, b) => b.date.compareTo(a.date));
      }
      _started = true;
      _loadAttendance(att, planIndex: widget.initialPlanIndex);
      // What was chosen on the Termin page, taken once.
      final pending = ref.read(rdPlanStartProvider);
      if (pending != null) ref.read(rdPlanStartProvider.notifier).state = null;
      final start = pending?.attendanceId == att.id ? pending?.action : null;
      if (start != null) {
        // A new Ablauf starts with that, not with the start field "Wort"
        // or the Vorlage of the Terminart.
        if (PlanUtils.allPlans(_att).isEmpty) {
          _rdSet(() => _fields = []);
          _dirty = false;
        }
        unawaited(_rdStart(start));
      }
      return;
    }
    // No Termin requested: first upcoming Termin (list is sorted newest first).
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming = _attendances.where((a) {
      final d = DateTime.tryParse(a.date);
      return d != null && !DateTime(d.year, d.month, d.day).isBefore(todayDate);
    }).toList();
    // Ionic: without an upcoming Termin none is selected.
    att = upcoming.isNotEmpty ? upcoming.last : null;
    _started = true;
    if (att != null) {
      _loadAttendance(att);
    } else {
      // Ionic keeps its start field `{ id: '', name: 'Wort ', time: '10' }`.
      _rdSet(() => _fields = [PlanField(id: '', name: context.l10n.planningDefaultWord, time: '10')]);
    }
  }

  /// Requested Termin by id, scoped to the current tenant; null when it does
  /// not exist, belongs to another tenant or could not be loaded.
  Future<PlanAttendance?> _loadRequestedAttendance(int id) async {
    try {
      final repo = ref.read(planRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return null;
      // Ionic: only Termine of the role-filtered list can be opened.
      return await repo.getPlanAttendanceById(id,
          includeArchived: canSeeArchivedAttendances(ref.read(currentRoleProvider)));
    } catch (_) {
      return null;
    }
  }

  /// Ionic `Utils.getPlanningTitle`.
  String _defaultTitle(PlanAttendance? att) {
    final type = _typeOf(att);
    final info = att?.typeInfo ?? '';
    final pt = type?.planningTitle ?? '';
    if (pt.isNotEmpty && info.isNotEmpty) return '$pt ($info)';
    if (pt.isNotEmpty) return pt;
    if (info.isNotEmpty) return info;
    if ((type?.name ?? '').isNotEmpty) return type!.name;
    return context.l10n.defaultsTypesRehearsalPlan;
  }

  /// Ionic `resolveOrgPlan`: stored flag once a plan exists, otherwise the type default.
  bool _resolveOrgPlan(PlanAttendance att) {
    if (att.plan != null) return att.isOrgPlan;
    return _typeOf(att)?.isDefaultOrgPlan ?? false;
  }

  void _loadAttendance(PlanAttendance loaded, {int? planIndex}) {
    // SOL_FIX27: the commits this editor has seen of the Termin.
    // SOL_FIX29: row and sequence number are adopted together: when another
    // editor instance stored the Termin after the commit this editor's copy
    // holds (e.g. while another Termin was open), the newest stored row is
    // loaded and only then its sequence number recorded. A stale copy is
    // never marked as current.
    var att = loaded;
    final attId = att.id;
    if (attId != null) {
      final key = PlanningWriteSync.keyFor(_tenantId, attId);
      final latest = PlanningWriteSync.latestSince(key, _knownSeq[attId] ?? 0);
      if (latest != null && latest.id == attId) {
        att = latest;
        _knownSeq[attId] = PlanningWriteSync.seq(key);
        _attendances = [for (final a in _attendances) a.id == attId ? latest : a];
      } else {
        _knownSeq[attId] ??= PlanningWriteSync.seq(key);
      }
    }
    final plans = PlanUtils.allPlans(att);
    // SOL_FIX22: `?plan=-1` (or too large) falls back to the first plan.
    final index = PlanUtils.validPlanIndex(planIndex, plans.length) ?? 0;
    _rdSet(() {
      _attId = att.id;
      _planIndex = index;
      _sharePlan = att.sharePlan;
      _isOrgPlan = _resolveOrgPlan(att);
    });
    if (plans.isNotEmpty) {
      _loadPlan(att, plans[index]);
    } else {
      _loadGen++;
      _loadEditGen = _editGen;
      final tenant = ref.read(currentTenantProvider);
      final isPractice = att.type == 'uebung';
      final start = (att.startTime?.isNotEmpty ?? false)
          ? att.startTime!
          : (isPractice ? (tenant?.practiceStart ?? '17:50') : '10:00');
      final formatted = PlanUtils.formatTime(start);
      _rdSet(() {
        _rdDurationIndex = null;
        _time = formatted.isEmpty ? '17:50' : formatted;
        _titleController.text = _defaultTitle(att);
        // Ionic start field `{ id: '', name: 'Wort ', time: '10' }`.
        _fields = [PlanField(id: '', name: context.l10n.planningDefaultWord, time: '10')];
      });
      // Ionic `onAttChange` applies the type template (or an empty list) only
      // when there is Werke history; then `calculateEnd` → `updateAttendance`
      // stores it (validate: at least one field). Without history the start
      // field stays and nothing is written until the user edits the plan.
      if (_history.isNotEmpty) {
        _applyTypeDefaultPlan(att, save: false, clearWithoutTemplate: true);
        _dirty = _fields.isNotEmpty;
      } else {
        _dirty = false;
      }
      _savedTitle = _titleController.text.trim();
      _restoredDraft = null;
      if (att.id != null) unawaited(_restoreDraft(att.id!, index));
    }
  }

  void _loadPlan(PlanAttendance att, Plan plan) {
    final history = _history;
    _saveTimer?.cancel();
    _loadGen++;
    _loadEditGen = _editGen;
    _dirty = false;
    _restoredDraft = null;
    _rdSet(() {
      _rdDurationIndex = null;
      _titleController.text = plan.title ?? _defaultTitle(att);
      final t = PlanUtils.formatTime(plan.time);
      if (t.isNotEmpty) _time = t;
      _fields = plan.fields.map((f) {
        var field = f;
        if ((field.conductor ?? '').isEmpty) {
          final h = history.where((h) => h.songId?.toString() == field.id).firstOrNull;
          if (h?.conductorName != null) field = field.copyWith(conductor: h!.conductorName);
        }
        if (PlanUtils.isAgendaPlaceholder(field)) field = field.copyWith(time: '0');
        return field;
      }).toList();
    });
    _savedTitle = _titleController.text.trim();
    if (att.id != null) unawaited(_restoreDraft(att.id!, _planIndex));
  }

  /// SOL_FIX22 / Ionic `deletePlan` → `loadPlan(att, undefined)`: after the
  /// last plan is deleted the editor is empty (default title, no fields, time
  /// kept) and holds no pending change, so closing writes nothing back.
  void _clearEditor(PlanAttendance att) {
    _saveTimer?.cancel();
    _loadGen++;
    _loadEditGen = _editGen;
    _dirty = false;
    _restoredDraft = null;
    _rdSet(() {
      _planIndex = 0;
      _rdDurationIndex = null;
      _titleController.text = _defaultTitle(att);
      _fields = [];
    });
    _savedTitle = _titleController.text.trim();
  }

  List<SongHistory> get _history =>
      (_container.read(currentSongsProvider).valueOrNull ?? const []).expand((e) => e.history).toList();

  List<Song> get _songs => _container.read(planSongsProvider).valueOrNull ?? const [];

  /// Ionic 4.17.10: unique row uids for the Gemeinde App (linked orgs only).
  List<PlanField> _withFieldUids(List<PlanField> fields) =>
      _gemeindeAppLinked ? PlanBeamer.ensureFieldUids(fields) : fields;

  /// Ionic 4.17.11 `beamerFileOf`: the row's file, otherwise its Werk's.
  BeamerFile? _beamerFileOf(PlanField field) => PlanBeamer.fileOf(
      field, (songId) => _songs.where((s) => s.id == songId).firstOrNull?.beamerFile);

  /// Ionic `onAttChange` without plan / "Plan zurücksetzen".
  void _applyTypeDefaultPlan(PlanAttendance att, {bool save = true, bool clearWithoutTemplate = false}) {
    final type = _typeOf(att);
    final defaults = type?.defaultPlan?.fields ?? const <PlanField>[];
    _rdDurationIndex = null;
    if (defaults.isNotEmpty) {
      _rdSet(() {
        final t = PlanUtils.formatTime(type?.startTime);
        if (t.isNotEmpty) _time = t;
        _fields = PlanSongHelper.resolvePlaceholders(
          defaults,
          history: _history,
          songs: _songs,
          prefix: _songPrefix(type),
        );
      });
    } else if (save || clearWithoutTemplate) {
      _rdSet(() => _fields = []);
    }
    if (save) _changed();
  }

  String Function(Song song) _songPrefix(PlanAttendanceType? type) {
    final tenant = ref.read(currentTenantProvider);
    return (song) =>
        type?.planningPrefixInstanceName == true ? '${tenant?.longName ?? ''}: ' : '${song.number ?? ''}. ';
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------


  void _changed() {
    _fields = PlanUtils.normalizeGroups(_fields);
    _hasChanges = true;
    _dirty = true;
    _editGen++;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  /// Ionic `validate`: start time, at least one field, a duration on every field.
  bool _validate({bool showToast = false}) {
    switch (PlanUtils.validate(_time, _fields)) {
      case PlanValidation.ok:
        return true;
      case PlanValidation.noFields:
        if (showToast) ToastHelper.showWarning(context, context.l10n.planningChooseFieldMin);
        return false;
      case PlanValidation.missingTime:
        if (showToast) ToastHelper.showWarning(context, context.l10n.planningFillRequired);
        return false;
    }
  }

  /// Title field lost focus: only a real edit counts as a change.
  void _onTitleFocusLost() {
    if (_titleController.text.trim() != _savedTitle) _changed();
  }

  /// SOL_FIX22: true while the editor holds changes that are not stored yet.
  bool get _hasPendingChanges => _dirty || _titleController.text.trim() != _savedTitle;

  /// SOL_FIX23: runs [task] after every write queued before it. Errors
  /// reach the caller, never the chain.
  /// SOL_FIX27: on the process-wide chain of Termin [attId], shared with
  /// every other editor instance (e.g. one that was just left and still
  /// writes).
  Future<T> _serialised<T>(int attId, Future<T> Function() task) =>
      PlanningWriteSync.run(PlanningWriteSync.keyFor(_tenantId, attId), task);

  /// Ionic `saveOpenPlan`: queues a write of the open plan (when it holds
  /// valid pending changes) behind all running writes.
  ///
  /// SOL_FIX23: false only when the write failed; the editor then keeps its
  /// changes and dirty state and the Ionic error toast is shown.
  Future<bool> _save() {
    _saveTimer?.cancel();
    final attId = _attId;
    if (attId == null) return Future.value(true);
    return _serialised(attId, () => _writeOpenPlan(attId));
  }

  /// SOL_FIX24: the user edited the open plan since it was loaded.
  bool get _hasUserEdits => _editGen != _loadEditGen || _titleController.text.trim() != _savedTitle;

  /// SOL_FIX23: waits for running writes and stores everything still pending
  /// (also edits made while a write ran). Plan / Termin switches and close
  /// only continue when this returns true.
  ///
  /// SOL_FIX24: Ionic only stores a valid plan (`saveOpenPlan` → `validate`)
  /// and never coerces an empty minutes field, so invalid edits would be
  /// dropped silently on leaving. With [blockInvalid] an invalid plan with
  /// user edits shows the Ionic validation toast and returns false, so the
  /// user can fix it first.
  Future<bool> _flushSaves({bool blockInvalid = true}) async {
    while (true) {
      if (!await _save()) return false;
      if (!mounted) return true;
      if (!_hasPendingChanges || _att?.id == null) return true;
      if (!_validate()) {
        if (!blockInvalid || !_hasUserEdits) return true;
        _validate(showToast: true);
        return false;
      }
    }
  }

  /// The visible start plan of a Termin without stored plan is not written
  /// on opening (Ionic). An explicit action that needs a stored plan (share
  /// link, another plan) marks it as pending first, so the following
  /// [_flushSaves] stores it.
  void _markStartPlanPending() {
    final att = _att;
    if (att == null || _dirty || _fields.isEmpty || PlanUtils.allPlans(att).isNotEmpty) return;
    _dirty = true;
  }

  /// SOL_FIX24: runs [task] with the page blocked (overlay, no focus, no
  /// close) so the editor cannot change while [task] writes and reloads it.
  Future<T> _whileBusy<T>(Future<T> Function() task) async {
    _saveTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    _rdSet(() => _busy = true);
    try {
      return await task();
    } finally {
      if (mounted) _rdSet(() => _busy = false);
    }
  }

  Future<bool> _writeOpenPlan(int attId) async {
    if (!mounted || !_hasPendingChanges) return true;
    // SOL_FIX29: read before the first await (tenant of this editor).
    final repo = ref.read(planRepositoryWithTenantProvider);
    // Built when the write starts: `_att` is the latest persisted row (it is
    // replaced after every write), plus the current editor state.
    final att = _att;
    // SOL_FIX27: queued on the chain of [attId]; another Termin opened
    // meanwhile is written by its own queued save.
    if (att?.id != attId || !_validate()) return true;
    final loadGen = _loadGen;
    final editGen = _editGen;
    final title = _titleController.text.trim();
    // SOL_FIX28: built on the newest stored row of the Termin (another
    // editor instance may have stored another plan meanwhile): only the open
    // plan is replaced.
    final base = _writeBase(attId, att!, _planIndex);
    final baseIndex = base.index;
    if (baseIndex == null) {
      // SOL_FIX29: the open plan was deleted by another editor meanwhile:
      // nothing is written, the edit is kept as a local draft and the editor
      // shows the newest stored row.
      final planKey = _planKeyOf(att, _planIndex);
      final draft = _draftData(time: _time, fields: _fields, title: title);
      final draftBase = _baseOf(att, _planIndex);
      _reloadLatest(attId, base.att);
      await _planDeletedMeanwhile(attId, planKey, draft, base: draftBase);
      return true;
    }
    // Ionic 4.17.10 `ensureFieldUids`: the editor keeps the uids it stored.
    // (setState: the fields editor must emit its next change with the uids.)
    final withUids = _withFieldUids(_fields);
    if (!identical(withUids, _fields)) _rdSet(() => _fields = withUids);
    final update = _planUpdate(base.att, baseIndex, time: _time, fields: _fields, title: title);
    try {
      final saved = await repo.updateAttendancePlanFields(att.id!, update);
      // SOL_FIX23: every successful write is a change (caches on close).
      _markWritten(att.id!, saved);
      _replaceAtt(saved);
      // Baseline / dirty only for the snapshot that was really stored.
      if (loadGen == _loadGen) {
        // SOL_FIX28: the open plan's position in the stored row.
        if (mounted && baseIndex != _planIndex) _rdSet(() => _planIndex = baseIndex);
        _savedTitle = title;
        if (editGen == _editGen) _dirty = false;
        // REDESIGN: the Beta editor shows "Gespeichert".
        if (mounted) _rdSet(() {});
        // SOL_FIX26: the restored draft is stored now.
        // SOL_FIX27: removed only while it still holds the restored revision.
        final draft = _restoredDraft;
        if (draft != null) {
          _restoredDraft = null;
          await PlanningDraftStore.removeIfRevision(draft.key, draft.rev);
        }
      }
      return true;
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcUpdateAttendanceFailed);
      return false;
    }
  }

  /// SOL_FIX29: runs the plan list operation [op] (add / rename / day / move
  /// / delete) INSIDE the queued write step of Termin [attId], applied to the
  /// newest stored row at that moment (another editor instance may have
  /// stored the Termin while this editor's dialog was open), and stores the
  /// resulting plan list. [planKey] names the plan the operation acts on (by
  /// id, else position, see [_planKeyOf]); null for adding a plan.
  ///
  /// Returns the position of the plan to open in the stored row, or null when
  /// nothing was written: [op] made no change, or the plan [planKey] was
  /// deleted meanwhile (the editor then shows the newest row and the user is
  /// told, see [_planDeletedMeanwhile]).
  ///
  /// SOL_FIX30: [planRef] names the plan ([_refOf], matched by
  /// [_indexOfRef]); a plan without id that no longer matches is a conflict.
  Future<int?> _writePlanOp(int attId, _PlanRef? planRef, _PlanListOp op) {
    // TERMINE-22: read while mounted; the queued task may run after dispose.
    final repo = ref.read(planRepositoryWithTenantProvider);
    return _serialised(attId, () async {
        final latest =
            PlanningWriteSync.latestSince(PlanningWriteSync.keyFor(_tenantId, attId), _knownSeq[attId] ?? 0);
        final own = _att;
        final base = latest != null && latest.id == attId ? latest : own;
        if (base == null || base.id != attId) return null;
        int? index;
        if (planRef != null) {
          index = _indexOfRef(base, planRef);
          if (index == null) {
            final draft =
                mounted && _attId == attId && _hasPendingChanges && _planKeyOf(own, _planIndex) == planRef.key
                    ? _draftData(time: _time, fields: _fields, title: _titleController.text.trim())
                    : null;
            _reloadLatest(attId, base);
            await _planDeletedMeanwhile(attId, planRef.key, draft, base: planRef.json);
            return null;
          }
        }
        final result = op(base, PlanUtils.withDays(base, PlanUtils.allPlans(base)), index);
        if (result == null) return null;
        final saved = await repo.updateAttendancePlanFields(attId, PlanUtils.splitPlans(result.plans));
        _markWritten(attId, saved);
        _replaceAtt(saved);
        return result.open;
      });
  }

  void _replaceAtt(PlanAttendance saved) {
    final updated = [for (final a in _attendances) a.id == saved.id ? saved : a];
    // SOL_FIX25: also after dispose, so a write queued by [dispose] is built
    // from the latest persisted row.
    if (!mounted) {
      _attendances = updated;
      return;
    }
    _rdSet(() => _attendances = updated);
  }

  Future<void> _updateFlags(Map<String, dynamic> updates) async {
    final att = _att;
    if (att?.id == null) return;
    final attId = att!.id!;
    final repo = ref.read(planRepositoryWithTenantProvider);
    await _serialised(attId, () async {
      final saved = await repo.updateAttendancePlanFields(attId, updates);
      // SOL_FIX31: the stored row may hold plans another editor changed
      // meanwhile. Before it becomes the editor's baseline, the open plan is
      // checked like a plan write ([_writeBase]): when it is gone or no
      // longer the same plan, the edits are kept as a draft and the editor
      // shows the stored row (it never writes its old plan over another).
      final own = _att;
      final planIndex = _planIndex;
      final index = own?.id == attId ? _indexInLatest(saved, own, planIndex) : planIndex;
      _markWritten(attId, saved);
      if (index == null) {
        final planKey = _planKeyOf(own, planIndex);
        final draft = mounted && _attId == attId && _hasPendingChanges
            ? _draftData(time: _time, fields: _fields, title: _titleController.text.trim())
            : null;
        final base = _baseOf(own, planIndex);
        _reloadLatest(attId, saved);
        await _planDeletedMeanwhile(attId, planKey, draft, base: base);
        return;
      }
      _replaceAtt(saved);
      if (index != planIndex && mounted && _attId == attId) _rdSet(() => _planIndex = index);
    });
  }

  /// SOL_FIX26: a write of Termin [attId] succeeded.
  /// SOL_FIX27: [saved] (the stored row) is recorded as a commit of this
  /// editor on the process-wide chain ([PlanningWriteSync]).
  void _markWritten(int attId, PlanAttendance saved) {
    _hasChanges = true;
    _needsInvalidate = true;
    _writtenAttIds.add(attId);
    _knownSeq[attId] = PlanningWriteSync.commit(PlanningWriteSync.keyFor(_tenantId, attId), _instanceNo, saved);
  }

  /// SOL_FIX26: refreshes the caches of every Termin written since the last
  /// call. Runs on every exit path (close, leave guard and, via the write
  /// chain, after [dispose]), so also autosaved changes are never shown
  /// stale. Uses the container captured while mounted.
  void _invalidateCaches() {
    if (!_needsInvalidate) return;
    _needsInvalidate = false;
    final ids = [..._writtenAttIds];
    _writtenAttIds.clear();
    try {
      _container.invalidate(planAttendancesProvider);
      for (final id in ids) {
        _container.invalidate(attendanceDetailProvider(id));
        _container.invalidate(planAttendanceByIdProvider(id));
      }
      _container.invalidate(orgPlansProvider);
      // SOL_FIX29: rows loaded from the caches from now on hold every commit.
      PlanningWriteSync.markCachesRefreshed();
      // A Werk in the Ablauf belongs to the Werke of its Termin.
      for (final id in ids) {
        unawaited(rdSyncPlanWorks(_container, id));
      }
    } catch (_) {
      // Container already disposed (app closed): nothing to refresh.
    }
  }
}
