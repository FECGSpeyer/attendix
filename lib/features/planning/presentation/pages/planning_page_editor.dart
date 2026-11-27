part of 'planning_page.dart';

/// Share/export menus, plan overflow actions, empty-plan starter, and Termin
/// switcher for [PlanningPage].
extension _PlanningEditor on _PlanningPageState {
  static const _rdHintKey = 'rd_plan_hint_hidden';

  /// "Teilen" at the top: the open plan as PDF or picture (both saved
  /// like any export), or its public link.
  Future<void> _rdShare() async {
    final l10n = context.l10n;
    final att = _att;
    if (att == null) return;
    final hasExports = _fields.isNotEmpty;
    final multi = PlanUtils.allPlans(att).length > 1;
    final loadGen = _loadGen;
    var action = await _rdSheet<String>(
      title: l10n.redesignPlanShare,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                if (hasExports) ...[
                  RdListRow(
                    key: const Key('rd-plan-pdf'),
                    leading: const RdRowIcon(Icons.picture_as_pdf_outlined),
                    title: l10n.planningExportPdf,
                    subtitle: multi ? l10n.redesignPlanSharePdfHintAll : l10n.redesignPlanSharePdfHint,
                    onTap: () => pop('pdf'),
                  ),
                  _rdSheetRow(
                    Icons.image_outlined,
                    l10n.redesignPlanShareImage,
                    l10n.redesignPlanShareImageHint,
                    () => pop('image'),
                    key: const Key('rd-plan-image'),
                  ),
                ],
                RdListRow(
                  key: const Key('rd-plan-link'),
                  leading: const RdRowIcon(Icons.link),
                  title: l10n.redesignPlanPublicLink,
                  subtitle: att.shareKey != null ? l10n.redesignPlanPublicLinkShared : l10n.redesignPlanPublicLinkHint,
                  onTap: () => pop('link'),
                ),
              ],
            ),
            // For the PDF and the picture; the link shows no letterhead.
            if (hasExports && ref.read(hasBrandingProvider)) ...[
              const SizedBox(height: 12),
              RdGroupedList(
                children: [
                  Consumer(
                    builder: (ctx, cref, _) {
                      final on = cref.watch(includeBrandingProvider);
                      void set(bool v) => cref.read(includeBrandingProvider.notifier).state = v;
                      return RdListRow(
                        key: const Key('rd-plan-branding'),
                        leading: const RdRowIcon(Icons.star_outline),
                        title: l10n.planningIncludeBranding,
                        subtitle: l10n.redesignPlanShareBrandingHint,
                        showChevron: false,
                        onTap: () => set(!on),
                        trailing: Switch.adaptive(value: on, activeTrackColor: ctx.rd.primary, onChanged: set),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
    );
    // Another plan or Termin was loaded meanwhile: the sheet was for the old one.
    if (action == null || !mounted || loadGen != _loadGen) return;
    if (action == 'pdf') {
      // Second step: the paper layout.
      action = await _rdSheet<String>(
        title: l10n.planningExportPdf,
        builder:
            (ctx, pop) => [
              RdGroupedList(
                children: [
                  _rdSheetRow(
                    Icons.insert_drive_file_outlined,
                    l10n.redesignPlanSharePdfNormal,
                    l10n.redesignPlanSharePdfNormalHint,
                    () => pop('pdf'),
                    key: const Key('rd-plan-pdf-normal'),
                  ),
                  _rdSheetRow(
                    Icons.content_copy_outlined,
                    l10n.redesignPlanSharePdf2x,
                    l10n.redesignPlanSharePdf2xHint,
                    () => pop('pdf2x'),
                    key: const Key('rd-plan-pdf-2x'),
                  ),
                  if (multi)
                    _rdSheetRow(
                      Icons.picture_as_pdf,
                      l10n.redesignPlanSharePdfAll,
                      l10n.redesignPlanSharePdfAllHint,
                      () => pop('all'),
                      key: const Key('rd-plan-pdf-all'),
                    ),
                ],
              ),
            ],
      );
      if (action == null || !mounted || loadGen != _loadGen) return;
    }
    if (action == 'link') {
      await _shareLink();
    } else {
      await _rdExport(action, loadGen);
    }
  }

  /// ••• at the top: the plans of the Termin and the open plan.
  Future<void> _rdMore() async {
    final l10n = context.l10n;
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final multi = plans.length > 1;
    final planName = multi ? PlanUtils.planLabel(att, _planIndex, plans) : '';
    final loadGen = _loadGen;
    // Leitung: this Ablauf as the template of the Terminart (a rare one-off
    // action, so here and not on the Termin).
    // Waits for the Terminarten on a direct entry (not loaded yet).
    var types = const <AttendanceType>[];
    // Ionic isAdmin: Admin and Verantwortliche (both edit Terminarten).
    final role = ref.read(effectiveRoleProvider);
    if (role.isAdmin || role.isResponsible) {
      try {
        types = await ref.read(attendanceTypesProvider.future);
      } catch (_) {}
      if (!mounted || loadGen != _loadGen) return;
    }
    final type = types.where((t) => t.id != null && t.id == att.typeId).firstOrNull;
    final action = await _rdSheet<String>(
      title: l10n.redesignPlanTitle,
      builder:
          (ctx, pop) => [
            RdGroupLabel(l10n.redesignPlanPlansSection),
            RdGroupedList(
              children: [
                _rdSheetRow(
                  Icons.add,
                  l10n.redesignPlanAddAnother,
                  l10n.redesignPlanAddAnotherHint,
                  () => pop('addPlan'),
                  key: const Key('rd-plan-add-plan-more'),
                ),
              ],
            ),
            if (multi) ...[
              const SizedBox(height: 20),
              RdGroupLabel(l10n.redesignPlanPlanSection(planName)),
              RdGroupedList(
                children: [
                  _rdSheetRow(Icons.edit_outlined, l10n.planningRename, null, () => pop('rename')),
                  if (PlanUtils.dayOptions(att).isNotEmpty)
                    _rdSheetRow(Icons.event, l10n.planningAssignOtherDay, null, () => pop('day')),
                  if (_planIndex > 0) _rdSheetRow(Icons.chevron_left, l10n.planningMoveLeft, null, () => pop('left')),
                  if (_planIndex < plans.length - 1)
                    _rdSheetRow(Icons.chevron_right, l10n.planningMoveRight, null, () => pop('right')),
                  RdListRow(
                    leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                    title: l10n.planningDeletePlan,
                    titleColor: ctx.rd.absent,
                    showChevron: false,
                    onTap: () => pop('delete'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            RdGroupLabel(l10n.redesignPlanOther),
            RdGroupedList(
              children: [
                if (type != null && _fields.isNotEmpty)
                  _rdSheetRow(
                    Icons.content_copy_outlined,
                    l10n.rdTypeTakeOverPlan,
                    l10n.rdTypeTakeOverPlanHint(type.name),
                    () => pop('takeOver'),
                    key: const Key('rd-plan-take-over'),
                  ),
                _rdSheetRow(Icons.restart_alt, l10n.planningResetPlan, null, () => pop('reset')),
              ],
            ),
          ],
    );
    // Another plan or Termin was loaded meanwhile: the sheet was for the old one.
    if (action == null || !mounted || loadGen != _loadGen) return;
    switch (action) {
      case 'addPlan':
        await _addPlan();
      case 'rename' || 'day' || 'left' || 'right' || 'delete':
        await _showPlanOptions(preset: action);
      case 'reset':
        await _resetPlan();
      case 'takeOver':
        if (type != null) await rdTakeOverPlanForType(context, ref, type, [for (final f in _fields) f.toJson()]);
    }
  }

  /// Exports the open plan as PDF or image.
  Future<void> _rdExport(String action, int loadGen) async {
    // Exports use the editor state, so they also work when the write failed.
    await _flushSaves(blockInvalid: false);
    // Another plan was loaded while the last change was written: the
    // choice was made for the old one.
    if (!mounted || !_samePlan(loadGen) || !_validate(showToast: true)) return;
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final current = Plan(time: _time, end: _end, fields: _fields, title: _effectiveTitle);
    final fileName = '${_effectiveTitle}_$_fileDate';
    final pages =
        action == 'all'
            ? [for (var i = 0; i < plans.length; i++) _exportPage(att, i, i == _planIndex ? current : plans[i])]
            : [_exportPage(att, _planIndex, current)];
    await runPlanExport(
      context,
      ref,
      action == 'all' ? PlanExportAction.pdf : PlanExportAction.values.byName(action),
      pages: pages,
      fileName: fileName,
      includeBranding: ref.read(includeBrandingProvider),
    );
  }

  /// No items: how to start (with the Werke of the Termin, from a Vorlage,
  /// or like the last Termin of the same Terminart).
  List<Widget> _rdEmpty(PlanAttendance att) {
    final l10n = context.l10n;
    // Rebuilds when Vorlagen or Werke arrive.
    ref.watch(currentOrganisationProvider);
    ref.watch(planBlockTemplatesProvider);
    final id = att.id;
    final general = ref.watch(currentTenantProvider)?.type == 'general';
    final works = id == null || general ? null : ref.watch(rdEventWorksProvider(id)).valueOrNull;
    final songs = {for (final s in _songs) s.id: s};
    final open = [
      for (final e in works?.entries ?? const <SongHistoryEntry>[])
        if (songs[e.songId] case final song?) song,
    ];
    final templates = _rdTemplates(att);
    final previous = rdPreviousPlan(att, _attendances);
    final type = _typeOf(att);
    final rows = <Widget>[
      if (open.isNotEmpty)
        RdListRow(
          key: const Key('rd-plan-start-works'),
          leading: const RdRowIcon(Icons.queue_music_outlined),
          title: l10n.redesignPlanStartWorks(
            rdPlanWorksKind(typeName: type?.name, highlight: PlanSongHelper.isAuftritt(att, _types)),
          ),
          subtitle: rdPlanStartWorksHint(l10n, open),
          onTap: _rdStartWorks,
        ),
      if (templates.isNotEmpty)
        RdListRow(
          key: const Key('rd-plan-start-template'),
          leading: const RdRowIcon(Icons.view_day_outlined),
          title: l10n.redesignPlanStartTemplate,
          subtitle: l10n.redesignPlanStartTemplateHint(templates.first.name),
          onTap: _rdPickTemplate,
        ),
      if (previous != null)
        RdListRow(
          key: const Key('rd-plan-copy-last'),
          leading: const RdRowIcon(Icons.copy_all_outlined),
          // Not "letzter Termin": the newest one with an Ablauf can lie ahead.
          title: l10n.rdTextPlanCopyFrom(_rdDate(previous.att)),
          subtitle: l10n.rdTextPlanCopyCount(l10n.redesignPlanItemCount(previous.plan.fields.length)),
          onTap: () => _rdCopyPrevious(previous.att, previous.plan),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [RdGroupLabel(l10n.redesignPlanEmptyTitle), RdGroupedList(children: rows)];
  }

  void _rdCopyPrevious(PlanAttendance from, Plan plan) {
    final fields = [
      for (final f in plan.fields)
        if (f.agendaItemId == null && !PlanUtils.isAgendaPlaceholder(f)) f.copyWith(uid: null, beamerFile: null),
    ];
    final t = PlanUtils.formatTime(plan.time);
    _rdSet(() {
      if (t.isNotEmpty) _time = t;
    });
    _rdApply(fields);
    ToastHelper.showSuccess(context, context.l10n.redesignPlanCopied(_rdDate(from)));
  }

  /// "Adventskonzert · So., 14. Dez. 2026 · 16:00".
  String _rdAttLabel(PlanAttendance a) {
    final type = _typeOf(a);
    final title = (a.typeInfo?.isNotEmpty ?? false) ? a.typeInfo! : (type?.name ?? '');
    final d = DateTime.tryParse(a.date);
    String date;
    try {
      date = d == null ? a.date : DateFormat('EEE, d. MMM y', currentIntlLocale()).format(d);
    } catch (_) {
      date = _rdDate(a);
    }
    final time = PlanUtils.formatTime(a.startTime);
    return [if (title.isNotEmpty) title, date, if (time.isNotEmpty) time].join(' · ');
  }

  String _rdDate(PlanAttendance a) {
    final d = DateTime.tryParse(a.date);
    return d == null ? a.date : DateFormat(dateFmt()).format(d);
  }

  Future<void> _rdPickAttendance() async {
    if (_attendances.isEmpty) return;
    final current = _attendances.indexWhere((a) => a.id == _attId);
    final id = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder:
          (ctx) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(ctx.l10n.redesignPlanPlanPick, style: RdType.cardTitle(ctx.rd)),
                  ),
                  Flexible(
                    child: ListView.builder(
                      controller: ScrollController(initialScrollOffset: current > 3 ? (current - 3) * 53.0 : 0),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: _attendances.length,
                      itemBuilder: (_, i) {
                        final a = _attendances[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: RdCard(
                            padding: EdgeInsets.zero,
                            child: RdListRow(
                              title: _rdAttLabel(a),
                              selected: a.id == _attId,
                              showChevron: false,
                              trailing: a.id == _attId ? Icon(Icons.check, color: ctx.rd.link) : null,
                              onTap: () => Navigator.of(ctx).pop(a.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (id != null && mounted) await _selectAttendance(id);
  }

  /// Called from initState: whether "Verstanden" was tapped before.
  Future<void> _rdLoadHint() async {
    var hidden = false;
    try {
      hidden = (await SharedPreferences.getInstance()).getBool(_rdHintKey) ?? false;
    } catch (_) {}
    if (mounted) _rdSet(() => _rdHintHidden = hidden);
  }

  Future<void> _rdHideHint() async {
    _rdSet(() => _rdHintHidden = true);
    try {
      await (await SharedPreferences.getInstance()).setBool(_rdHintKey, true);
    } catch (_) {}
  }

  Future<void> _rdSetShare(bool value) async {
    _rdSet(() => _sharePlan = value);
    try {
      await _updateFlags({'share_plan': value});
    } catch (_) {
      if (mounted) _rdSet(() => _sharePlan = !value);
    }
  }

  Future<void> _rdSetOrgPlan(bool value) async {
    _rdSet(() => _isOrgPlan = value);
    try {
      await _updateFlags({'is_org_plan': value});
    } catch (_) {
      if (mounted) _rdSet(() => _isOrgPlan = !value);
    }
    if (mounted) _watchOrgPlan();
  }
}
