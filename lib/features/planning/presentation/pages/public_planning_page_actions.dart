part of 'public_planning_page.dart';

/// Field-add menu, saved-plan actions, organisation linking, and export/share
/// flows for [PublicPlanningPage].
extension _PublicPlanningActions on _PublicPlanningPageState {
  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Opens the add-item sheet and appends the chosen item or template block.
  Future<void> _showAddMenu(BuildContext anchorContext) async {
    final loggedIn = _loggedIn;
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';
    final org = loggedIn ? ref.read(currentOrganisationProvider).valueOrNull : null;
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    final blockTemplates = loggedIn
        ? (ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[])
        : const <PlanBlockTemplate>[];
    final action = await _rdAddMenu(
      loggedIn: loggedIn,
      isGeneral: isGeneral,
      orgFields: orgFields,
      blockTemplates: blockTemplates,
    );
    if (action == null || !mounted) return;
    if (action.startsWith('orgfield:')) {
      // Every inserted occurrence is its own row (own uid), so editing or
      // deleting the second one does not hit the first.
      final orgField = orgFields[int.parse(action.substring(9))];
      _update(() => _fields = [..._fields, orgField.copyWith(uid: PlanUtils.uuid())]);
      _changed();
      return;
    }
    if (action.startsWith('block:')) {
      final tpl = blockTemplates.where((t) => t.id == action.substring(6)).firstOrNull;
      if (tpl == null) return;
      _update(() => _fields = [..._fields, ...PlanUtils.cloneBlock(tpl.fields)]);
      _changed();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (action) {
      case 'field':
        final r = await showPlanFieldDialog(
          context,
          title: context.l10n.planningAddField,
          conductorHint: context.l10n.plansPerformerOptional,
          withMinutes: false,
        );
        if (r == null) return;
        _update(() => _fields = [
              ..._fields,
              PlanField(id: '${r.name}-$now', name: r.name, conductor: r.conductor, info: r.info, time: '20'),
            ]);
      case 'note':
        final r = await showPlanFieldDialog(
          context,
          title: context.l10n.planningAddNoteField,
          nameLabel: context.l10n.planningNote,
          nameHint: context.l10n.planningEnterNote,
          emptyNameMessage: context.l10n.plansEnterNotePlease,
          withConductor: false,
          withInfo: false,
          withMinutes: false,
        );
        if (r == null) return;
        _update(() =>
            _fields = [..._fields, PlanField(id: 'noteFld ${r.name}-$now', name: r.name, conductor: '', time: '0')]);
      case 'group':
        await _addGroup();
        return;
      case 'current':
        final added = PlanSongHelper.currentSongFields(
          _fields,
          history: _history,
          songs: _songs,
          prefix: _numberPrefix,
        );
        _update(() => _fields = [..._fields, ...added]);
      case 'song':
        final song = await showPlanSongPicker(
          context,
          _songs,
          currentIds: _history.map((h) => h.songId).whereType<int>().toSet(),
          inPlanIds: _fields.map((f) => f.songId).whereType<int>().toSet(),
        );
        if (song == null) return;
        _update(() => _fields = [
              ..._fields,
              PlanSongHelper.songField(song, history: _history, prefix: _numberPrefix),
            ]);
    }
    _changed();
  }

  Future<void> _addGroup() async {
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
    if (r == null || !mounted) return;
    final head = PlanUtils.newGroupHead(r.name, conductor: r.conductor, info: r.info);
    _update(() => _fields = [..._fields, head]);
    _changed();
    final sub = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddSubItem,
      subtitle: head.name,
      nameHint: context.l10n.planningSubItemPlaceholder,
      infoHint: context.l10n.planningSubItemInfoPlaceholder,
      initialMinutes: 5,
    );
    if (sub == null) return;
    _update(() => _fields = PlanUtils.addSubItem(
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
  // Plans of the user / organisation
  // ---------------------------------------------------------------------------

  Future<void> _newPlan() async {
    if (_fields.isNotEmpty) {
      final ok = await showPlanConfirm(
        context,
        title: context.l10n.plansNewPlan,
        message: context.l10n.plansDiscardNew,
        confirmText: context.l10n.plansNewPlan,
      );
      if (!ok) return;
    }
    _flushPendingSave();
    _update(() {
      _planId = null;
      _editKey = null;
      _titleController.text = l10nWithoutContext.plansRunSheet;
      _date = DateTime.now();
      _time = '10:00';
      _fields = [];
      _templateId = null;
      _brandingId = 'none';
      _isOrgPlan = false;
    });
    _persistLocal();
  }

  void _loadPlan(SharedPlan plan) {
    _flushPendingSave();
    _update(() {
      _planId = plan.id;
      _editKey = plan.editKey;
      _titleController.text = (plan.planTitle?.isNotEmpty ?? false) ? plan.planTitle! : l10nWithoutContext.plansRunSheet;
      _date = DateTime.tryParse(plan.date ?? '') ?? DateTime.now();
      final t = PlanUtils.formatTime(plan.time);
      _time = t.isEmpty ? '10:00' : t;
      _fields = [...plan.fields];
      _brandingId = plan.brandingId ?? 'none';
      _isOrgPlan = plan.orgId != null;
    });
    _persistLocal();
  }

  Future<void> _openMyPlans() async {
    final plan = await _rdMyPlansSheet();
    if (plan != null && mounted) _loadPlan(plan);
  }

  Future<void> _toggleOrg() async {
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    if (org?.id == null) return;
    final repo = ref.read(planRepositoryWithTenantProvider);
    if (_isOrgPlan) {
      if (_planId == null) return;
      try {
        await repo.setMySharedPlanOrg(_planId!, null);
        if (!mounted) return; // TERMINE-22: no ref after the page is gone
        _update(() => _isOrgPlan = false);
        unawaited(_persistLocal());
        ref.invalidate(orgPlansProvider);
        if (mounted) ToastHelper.showSuccess(context, context.l10n.plansRemovedFromOrg);
      } catch (_) {
        if (mounted) ToastHelper.showError(context, context.l10n.plansRemoveOrgFailed);
      }
      return;
    }
    if (!_validate()) return;
    // SOL_FIX15: only a successfully saved plan can be added.
    if (!await _persistToDb() || _planId == null) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansSavePlanFailed);
      return;
    }
    try {
      await repo.setMySharedPlanOrg(_planId!, org!.id);
      if (!mounted) return; // TERMINE-22: no ref after the page is gone
      _update(() => _isOrgPlan = true);
      unawaited(_persistLocal());
      ref.invalidate(orgPlansProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.plansAddedToOrg(org.name));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.plansAddOrgFailed);
    }
  }

  // ---------------------------------------------------------------------------
  // Share / export
  // ---------------------------------------------------------------------------

  bool _validate() {
    if (_time.isEmpty || _fields.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.plansAddFieldMin);
      return false;
    }
    if (!_fields.every((f) => PlanUtils.isNote(f) || PlanUtils.isGroupHead(f) || f.time.trim().isNotEmpty)) {
      ToastHelper.showWarning(context, context.l10n.plansFillDurations);
      return false;
    }
    return true;
  }

  List<PlanExportPage> _pages() => [
        PlanExportPage(
          title: _title,
          subtitle: PlanUtils.longDate(_date),
          time: _time,
          end: _end,
          fields: _fields,
        ),
      ];

  String get _fileName =>
      '${_title}_${_date.day.toString().padLeft(2, '0')}_${_date.month.toString().padLeft(2, '0')}_${_date.year}';

  /// Ionic `export()`: „Titel_Wochentag, TT.MM.JJJJ“ (+ `_2x`).
  // "/" (dd/MM/yyyy languages) is not allowed in file names.
  String get _pdfFileName => '${_title}_${PlanUtils.longDate(_date)}'.replaceAll('/', '.');

  /// Ionic `exportImage()`: „Titel_JJJJ-MM-TT“.
  String get _imageFileName =>
      '${_title}_${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  /// Ionic `buildBranding()`: the chosen public branding, never the
  /// instance branding (none for „Kein Branding“).
  Future<PdfBranding?> _branding() => publicPdfBranding(_brandingId);

  Future<void> _showExportOptions() async {
    if (!_validate()) return;
    await showPlanExportSheet(
      context,
      ref,
      pages: _pages,
      fileName: _fileName,
      pdfFileName: _pdfFileName,
      imageFileName: _imageFileName,
      branding: _branding,
    );
  }

  Future<void> _shareCurrentPlan() async {
    if (!_validate()) return;
    await showPlanExportSheet(
      context,
      ref,
      title: context.l10n.plansShareExport,
      pages: _pages,
      fileName: _fileName,
      pdfFileName: _pdfFileName,
      imageFileName: _imageFileName,
      branding: _branding,
      extraActions: [
        PlanSheetAction('read', context.l10n.planningReadOnlyLink, icon: AppIcons.link),
        PlanSheetAction('edit', context.l10n.planningEditLink, icon: AppIcons.editNote),
      ],
      onExtraAction: (a) => _doShare(a == 'edit'),
    );
  }

  Future<void> _doShare(bool editLink) async {
    String id;
    String editKey;
    if (_loggedIn) {
      // SOL_FIX15: share only a plan whose current state was saved.
      if (!await _persistToDb() || _planId == null) {
        if (mounted) ToastHelper.showError(context, context.l10n.plansLinkFailed);
        return;
      }
      id = _planId!;
      editKey = _editKey!;
    } else {
      // Anonymous: one-off insert without creator.
      id = PlanUtils.randomKey();
      editKey = PlanUtils.randomKey();
      try {
        await ref.read(publicPlanRepositoryProvider).insertAnonymousSharedPlan(_currentShared(id, editKey));
      } catch (_) {
        if (mounted) ToastHelper.showError(context, context.l10n.plansLinkFailed);
        return;
      }
    }
    final base = '/plan?key=$id';
    final url = planPublicUrl(editLink ? '$base&edit=$editKey' : base);
    if (mounted) await sharePlanLink(context, url, title: _title);
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: Locale(currentLanguage()),
    );
    if (picked == null) return;
    _update(() => _date = picked);
    _changed();
  }

  Future<void> _pickTime() async {
    final m = PlanUtils.parseTimeToMinutes(_time) ?? 600;
    final picked = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    _update(() => _time = PlanUtils.formatMinutes(picked.hour * 60 + picked.minute));
    _changed();
  }
}
