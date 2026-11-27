part of 'planning_page.dart';

extension _PlanningDrafts on _PlanningPageState {
  // ---------------------------------------------------------------------------
  // SOL_FIX26: local drafts of edits whose write failed after leaving
  // ---------------------------------------------------------------------------

  /// SOL_FIX27: signed-in account right now (null when signed out).
  String? _authUserId() {
    try {
      return _container.read(currentAuthUserIdProvider);
    } catch (_) {
      return null;
    }
  }







  /// SOL_FIX28: row and plan position a write of plan [planIndex] of the
  /// editor's copy [own] builds on. When an editor instance (this one
  /// excluded) stored Termin [attId] after the last commit this editor knows,
  /// the write builds on that newest stored row ([PlanningWriteSync.
  /// latestSince]): the edited plan is found there by id (else position) and
  /// only it is replaced, every other plan stays as stored. Without a newer
  /// commit the editor's own copy.
  ///
  /// SOL_FIX29: when the edited plan no longer exists in the newest stored
  /// row (another editor deleted it), the result is that row with a null
  /// index: a conflict. The caller writes nothing (the old row would restore
  /// the deleted plan and reset every other change made since) and keeps
  /// the edit as a local draft.
  ({PlanAttendance att, int? index}) _writeBase(int attId, PlanAttendance own, int planIndex) {
    final latest =
        PlanningWriteSync.latestSince(PlanningWriteSync.keyFor(_tenantId, attId), _knownSeq[attId] ?? 0);
    if (latest == null || latest.id != attId) return (att: own, index: planIndex);
    return (att: latest, index: _indexInLatest(latest, own, planIndex));
  }



  /// SOL_FIX29: takes over [latest], the newest stored row of Termin [attId]
  /// (returned by [PlanningWriteSync.latestSince] right before, so row and
  /// sequence number are adopted together), and shows one of its plans: the
  /// plan at the open position, else the last one, else the empty editor.
  /// Used when the open plan was deleted by another editor meanwhile.
  void _reloadLatest(int attId, PlanAttendance latest) {
    _knownSeq[attId] = PlanningWriteSync.seq(PlanningWriteSync.keyFor(_tenantId, attId));
    _replaceAtt(latest);
    if (!mounted || _attId != attId) return;
    final plans = PlanUtils.allPlans(latest);
    if (plans.isEmpty) {
      _clearEditor(latest);
      return;
    }
    final index = _planIndex.clamp(0, plans.length - 1);
    _rdSet(() => _planIndex = index);
    _loadPlan(latest, plans[index]);
  }

  /// SOL_FIX29: the plan [planKey] of Termin [attId] was deleted by another
  /// editor meanwhile. Keeps [draft] (the edits of that plan that could not
  /// be written, if any) as a confirmed local draft and tells the user.
  ///
  /// SOL_FIX30: a plan without id can not be told apart from a changed one
  /// ([_indexOfRef]): the "changed meanwhile" texts are shown for it.
  ///
  /// SOL_FIX31: the draft is stored as a conflict draft (with [base], the
  /// stored version it was made from): it is never restored automatically.
  Future<void> _planDeletedMeanwhile(int attId, String planKey, Map<String, dynamic>? draft,
      {String? base}) async {
    final changed = _isPositionalKey(planKey);
    if (draft == null) {
      if (mounted) {
        ToastHelper.showWarning(
            context, changed ? context.l10n.planningFlutterPlanChanged : context.l10n.planningFlutterPlanDeleted);
      }
      return;
    }
    final userId = _userId;
    final rev = await PlanningDraftStore.write(
        _draftKey(attId, planKey, userId), {...draft, 'conflict': true, 'base': base},
        allowed: () => _authUserId() == userId);
    final l10n = l10nWithoutContext;
    final saved = changed ? l10n.planningFlutterPlanChangedDraftSaved : l10n.planningFlutterPlanDeletedDraftSaved;
    final lost = changed ? l10n.planningFlutterPlanChangedDraftLost : l10n.planningFlutterPlanDeletedDraftLost;
    if (!mounted) {
      _showDetachedError(rev != null ? saved : lost);
    } else if (rev != null) {
      ToastHelper.showWarning(context, changed ? context.l10n.planningFlutterPlanChangedDraftSaved
          : context.l10n.planningFlutterPlanDeletedDraftSaved);
    } else {
      ToastHelper.showError(context, changed ? context.l10n.planningFlutterPlanChangedDraftLost
          : context.l10n.planningFlutterPlanDeletedDraftLost);
    }
  }

  /// SOL_FIX28: takes over the newest row another editor instance stored for
  /// Termin [attId] (when this editor has not seen it yet), so a plan
  /// operation (add / rename / day / move / delete), which writes the whole
  /// plan list, builds on it instead of the editor's stale copy.
  ///
  /// SOL_FIX29: false when the open plan was deleted there meanwhile: the
  /// editor then shows the newest row ([_reloadLatest]), pending edits of the
  /// deleted plan are kept as a draft and the operation must not continue.
  bool _adoptLatest(int attId) {
    final key = PlanningWriteSync.keyFor(_tenantId, attId);
    final latest = PlanningWriteSync.latestSince(key, _knownSeq[attId] ?? 0);
    if (latest == null || latest.id != attId) return true;
    final own = _att;
    final planKey = _planKeyOf(own, _planIndex);
    final index = own == null ? null : _indexOfRef(latest, _refOf(own, _planIndex));
    if (index == null && PlanUtils.allPlans(own).isNotEmpty) {
      final draft = _hasPendingChanges
          ? _draftData(time: _time, fields: _fields, title: _titleController.text.trim())
          : null;
      final base = _baseOf(own, _planIndex);
      _reloadLatest(attId, latest);
      unawaited(_planDeletedMeanwhile(attId, planKey, draft, base: base));
      return false;
    }
    _knownSeq[attId] = PlanningWriteSync.seq(key);
    _replaceAtt(latest);
    if (index != null && index != _planIndex && mounted) _rdSet(() => _planIndex = index);
    return true;
  }

  /// SOL_FIX27: draft key of the account [userId] in the editor's tenant
  /// (null without user or tenant: no draft).
  String? _draftKey(int attId, String planKey, String? userId) =>
      PlanningDraftStore.keyFor(userId: userId, tenantId: _tenantId, attId: attId, planKey: planKey);




  /// Restores the draft of the plan that was just loaded, when one exists
  /// and differs from it: the editor takes it over as a pending (dirty)
  /// change, so it is saved again by the autosave.
  ///
  /// SOL_FIX27: only the signed-in account's own draft, and only while that
  /// account is still signed in when the draft was read.
  Future<void> _restoreDraft(int attId, int planIndex) async {
    final userId = _authUserId();
    final key = _draftKey(attId, _planKeyOf(_att, planIndex), userId);
    if (key == null) return;
    final loadGen = _loadGen;
    final editGen = _editGen;
    final stored = await PlanningDraftStore.read(key);
    // Another plan was loaded or the user already edited: keep the draft.
    if (stored == null || !mounted || loadGen != _loadGen || editGen != _editGen) return;
    if (_authUserId() != userId) return;
    try {
      final draft = stored.data;
      final fields = [
        for (final f in draft['fields'] as List) PlanField.fromJson(Map<String, dynamic>.from(f as Map)),
      ];
      final t = PlanUtils.formatTime(draft['time'] as String?);
      final time = t.isNotEmpty ? t : _time;
      final title = draft['title'] as String? ?? '';
      final restored = _draftData(time: time, fields: fields, title: title);
      final loaded = _draftData(time: _time, fields: _fields, title: _titleController.text.trim());
      if (_sameDraft(restored, loaded)) {
        await PlanningDraftStore.removeIfRevision(key, stored.rev);
        return;
      }
      // SOL_FIX31: a conflict draft, or a draft whose base is no longer the
      // stored plan, is never restored (and autosaved) on its own: the user
      // decides; only "Entwurf übernehmen" loads it as a pending change.
      final conflict = draft['conflict'] == true ||
          (draft.containsKey('base') && draft['base'] != _baseOf(_att, planIndex));
      if (conflict) {
        final apply = await _askConflictDraft();
        if (!mounted || loadGen != _loadGen || editGen != _editGen || _authUserId() != userId) return;
        if (apply == false) await PlanningDraftStore.removeIfRevision(key, stored.rev);
        if (apply != true) return;
      }
      if (!mounted) return;
      _rdSet(() {
        _rdDurationIndex = null;
        _time = time;
        _fields = fields;
        _titleController.text = title;
      });
      _restoredDraft = (key: key, rev: stored.rev);
      _changed();
      ToastHelper.showInfo(context, context.l10n.planningFlutterDraftRestored);
    } catch (_) {
      await PlanningDraftStore.removeIfRevision(key, stored.rev);
    }
  }

  /// SOL_FIX31: asks what happens with a conflict draft: true takes it over,
  /// false discards it, null (dismissed) keeps it for later.
  Future<bool?> _askConflictDraft() => showAppDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(ctx.l10n.planningFlutterConflictDraftTitle),
          content: Text(ctx.l10n.planningFlutterConflictDraftMessage),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.planningFlutterConflictDraftDiscard)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.planningFlutterConflictDraftApply)),
          ],
        ),
      );

  /// Toast without a mounted page (root overlay / messenger captured while
  /// mounted), like [ToastHelper.showError].
  void _showDetachedError(String message) {
    try {
      final captured = _messenger;
      final messenger = captured != null && captured.mounted ? captured : rootScaffoldMessengerKey.currentState;
      final toastContext = messenger?.context;
      if (toastContext == null || !toastContext.mounted) return;
      ToastHelper.showError(toastContext, message);
    } catch (_) {
      // App already closed.
    }
  }


  PlanAttendance? get _att => _attendances.where((a) => a.id == _attId).firstOrNull;

  // TERMINE-22: these getters also run from writes that finish after the
  // editor was disposed (deep link / browser back while a write runs), where
  // `ref` throws "Cannot use ref after the widget was disposed". The
  // container captured in initState stays usable.
  List<PlanAttendanceType> get _types => _container.read(planAttendanceTypesProvider).valueOrNull ?? const [];

  PlanAttendanceType? _typeOf(PlanAttendance? att) =>
      att?.typeId == null ? null : _types.where((t) => t.id == att!.typeId).firstOrNull;

  /// Ionic `calculateEnd`: stored as "YYYY-MM-DDTHH:mm".
  String get _end => PlanUtils.computeEndIso(_time, _fields);
}

/// Stable part of a plan in the draft key: its id, else its position.
String _planKeyOf(PlanAttendance? att, int planIndex) {
  final plans = PlanUtils.allPlans(att);
  final id = planIndex < plans.length ? plans[planIndex].id : null;
  return (id?.isNotEmpty ?? false) ? id! : 'i$planIndex';
}

/// SOL_FIX30: [planKey] names a plan by position (the plan has no id).
bool _isPositionalKey(String planKey) => RegExp(r'^i\d+$').hasMatch(planKey);

/// SOL_FIX30: identity of plan [planIndex] of the editor's copy [att].
_PlanRef _refOf(PlanAttendance? att, int planIndex) {
  final plans = PlanUtils.allPlans(att);
  return (
    key: _planKeyOf(att, planIndex),
    count: plans.length,
    json: planIndex < plans.length ? jsonEncode(plans[planIndex].toJson()) : null,
  );
}

/// SOL_FIX30: position of the plan [ref] names in [att], or null (a
/// conflict). A plan with id is found by its id. A plan without id is only
/// taken at its position when [att] still has the same number of plans AND
/// the plan there is identical to the editor's version of it; otherwise
/// another editor deleted, moved or changed plans and the position no
/// longer proves the identity.
int? _indexOfRef(PlanAttendance att, _PlanRef ref) {
  final plans = PlanUtils.allPlans(att);
  final byId = plans.indexWhere((p) => p.id == ref.key);
  if (byId >= 0) return byId;
  final index = RegExp(r'^i(\d+)$').firstMatch(ref.key)?.group(1);
  final i = index == null ? null : int.tryParse(index);
  if (i == null || i >= plans.length || plans.length != ref.count) return null;
  return jsonEncode(plans[i].toJson()) == ref.json ? i : null;
}

/// SOL_FIX27: plan of [att] that [planKey] ([_planKeyOf]) names.
Plan? _planByKey(PlanAttendance att, String planKey) {
  final i = _indexOfPlanKey(att, planKey);
  return i == null ? null : PlanUtils.allPlans(att)[i];
}

/// SOL_FIX28: position of the plan of [att] that [planKey] names (by id,
/// else by position); null when there is none.
int? _indexOfPlanKey(PlanAttendance att, String planKey) {
  final plans = PlanUtils.allPlans(att);
  final byId = plans.indexWhere((p) => p.id == planKey);
  if (byId >= 0) return byId;
  final index = RegExp(r'^i(\d+)$').firstMatch(planKey)?.group(1);
  final i = index == null ? null : int.tryParse(index);
  return i != null && i < plans.length ? i : null;
}

/// SOL_FIX31: plan-identity check shared by [_writeBase] and the flag
/// write ([_updateFlags]): position in [latest] of plan [planIndex] of the
/// editor's copy [own] ([_indexOfRef]), 0 when neither has a plan, else
/// null (a conflict).
int? _indexInLatest(PlanAttendance latest, PlanAttendance? own, int planIndex) {
  final index = _indexOfRef(latest, _refOf(own, planIndex));
  if (index != null) return index;
  if (PlanUtils.allPlans(latest).isEmpty && PlanUtils.allPlans(own).isEmpty) return 0;
  return null;
}

/// SOL_FIX31: the stored version of plan [planIndex] of [att] (JSON), the
/// base a draft of it was made from; null when there is no such plan.
String? _baseOf(PlanAttendance? att, int planIndex) {
  final plans = PlanUtils.allPlans(att);
  return planIndex < plans.length ? jsonEncode(plans[planIndex].toJson()) : null;
}

Map<String, dynamic> _draftData(
        {required String time, required List<PlanField> fields, required String title}) =>
    jsonDecode(jsonEncode({
      'time': time,
      'title': title,
      'fields': [for (final f in fields) f.toJson()],
    })) as Map<String, dynamic>;

Map<String, dynamic> _draftOfPlan(Plan plan) =>
    _draftData(time: PlanUtils.formatTime(plan.time), fields: plan.fields, title: plan.title ?? '');

bool _sameDraft(Map<String, dynamic> a, Map<String, dynamic> b) => jsonEncode(a) == jsonEncode(b);

/// Update of the `attendance` row that stores plan [planIndex] of [att]
/// with the given editor state (Ionic `updateAttendance` /
/// `splitPlans`).
Map<String, dynamic> _planUpdate(
  PlanAttendance att,
  int planIndex, {
  required String time,
  required List<PlanField> fields,
  required String title,
}) {
  final plans = PlanUtils.allPlans(att);
  final base = planIndex < plans.length ? plans[planIndex] : const Plan();
  final current = base.copyWith(
    time: time,
    end: PlanUtils.computeEndIso(time, fields),
    fields: fields,
    title: title.isEmpty ? null : title,
  );
  if (plans.length < 2) return {'plan': current.toJson()};
  plans[planIndex] = current;
  return PlanUtils.splitPlans(plans);
}
