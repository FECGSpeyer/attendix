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
    final draft = await showRdNewPlanSheet(
      context,
      days: PlanUtils.dayOptions(att),
      initialDay: PlanUtils.nextFreeDay(att, plans),
      copyOf: PlanUtils.planLabel(att, _planIndex.clamp(0, plans.isEmpty ? 0 : plans.length - 1), plans),
    );
    if (draft == null || !mounted || _att == null) return;
    final attId = _attId!;
    if (!_adoptLatest(attId)) return; // SOL_FIX28 / SOL_FIX29
    final copy = draft.copy;
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
          final day = PlanUtils.dayOptions(att).any((d) => d.day == draft.day)
              ? draft.day
              : PlanUtils.nextFreeDay(att, plans);
          final label = draft.label;
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

  /// [preset]: the action chosen in the overflow "•••" sheet.
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
