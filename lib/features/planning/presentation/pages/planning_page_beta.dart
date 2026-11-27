part of 'planning_page.dart';

/// REDESIGN: the Ablauf editor in the Beta design (concept "Ablauf
/// bearbeiten", boards 8–13).
///
/// Only the surface is new: loading, autosave, drafts, conflicts, plan
/// operations, exports and every "+" entry are the classic editor's
/// ([_PlanningPageState]), so the stored plan is the same as in Ionic.
extension _PlanningBeta on _PlanningPageState {
  // ---------------------------------------------------------------------------
  // Page
  // ---------------------------------------------------------------------------

  Widget _rdScaffold(
    AsyncValue<List<PlanAttendance>> attendancesAsync, {
    required bool isAdmin,
    required List<PlanBlockTemplate> blockTemplates,
    required bool showBeamer,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final att = _att;
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: RdBackLink(
              // From a Termin back to it; otherwise from Verwaltung › Ablaufpläne.
              label: _rdFromTermin ? l10n.redesignPlanBack : l10n.redesignAdminTitle,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (att != null) ...[
            RdCircleButton(
              key: const Key('rd-plan-share'),
              icon: Icons.ios_share,
              label: l10n.redesignPlanShare,
              onPressed: _rdShare,
            ),
            const SizedBox(width: 8),
            RdCircleButton(
              key: const Key('rd-plan-more'),
              icon: Icons.more_horiz,
              label: l10n.redesignPlanMore,
              onPressed: _rdMore,
            ),
          ],
        ],
      ),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(l10n.redesignPlanTitle, style: RdType.title(p))),
    ];

    // Loading until `_init` chose the Termin (like the classic editor).
    if (!_started) {
      children.addAll([
        const SizedBox(height: 16),
        attendancesAsync.hasError && !_loaded
            ? RdInfoCard(
              text: l10n.planningFlutterErrorWith(friendlyErrorMessage(attendancesAsync.error!)),
              icon: Icons.error_outline,
            )
            : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      ]);
    } else if (_requestedNotFound) {
      children.addAll([
        const SizedBox(height: 16),
        RdInfoCard(text: l10n.attendanceFlutterNotFound, icon: Icons.error_outline),
      ]);
    } else if (att == null && _attendances.isNotEmpty) {
      // Ionic: without an upcoming Termin none is selected; the Termin
      // picker stays reachable (also for past Termine).
      children.addAll([
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-plan-termin'),
              leading: const RdRowIcon(Icons.event_outlined),
              title: l10n.redesignPlanPlanPick,
              onTap: _rdPickAttendance,
            ),
          ],
        ),
      ]);
    } else if (att == null) {
      children.addAll([
        const SizedBox(height: 16),
        RdInfoCard(text: l10n.planningFlutterNoEvents, icon: Icons.event_busy_outlined),
      ]);
    } else {
      children.addAll(_rdContent(att, isAdmin: isAdmin, blockTemplates: blockTemplates, showBeamer: showBeamer));
    }

    return RdPage(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.paddingOf(context).bottom),
      children: children,
    );
  }

  List<Widget> _rdContent(
    PlanAttendance att, {
    required bool isAdmin,
    required List<PlanBlockTemplate> blockTemplates,
    required bool showBeamer,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final plans = PlanUtils.allPlans(att);
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final start = PlanUtils.parseTimeToMinutes(_time);
    final total = PlanUtils.totalMinutes(_fields);
    return [
      ..._rdTerminLine(att),
      // Plans of the Termin as tabs, only with several plans; a second plan
      // is created in •••.
      if (plans.length > 1) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < plans.length; i++)
              RdChoiceChip(
                key: ValueKey('rd-plan-chip-$i'),
                label: PlanUtils.planLabel(att, i, plans),
                selected: i == _planIndex,
                onTap: () => _selectPlan(i),
              ),
            RdChoiceChip(
              key: const Key('rd-plan-add-plan'),
              label: '+',
              semanticLabel: l10n.redesignPlanAddAnother,
              selected: false,
              onTap: _addPlan,
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      _rdSummary(att, start, total),
      const SizedBox(height: 12),
      if (_fields.isEmpty) ..._rdEmpty(att) else _rdTimeline(start, showBeamer: showBeamer),
      const SizedBox(height: 12),
      RdPrimaryButton(
        key: const Key('rd-plan-add'),
        icon: Icons.add,
        label: l10n.redesignPlanAdd,
        onPressed: () => _rdAdd(),
      ),
      if (_fields.isNotEmpty && _rdHintHidden == false) ...[
        const SizedBox(height: 8),
        RdCard(
          key: const Key('rd-plan-hint'),
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Expanded(child: Text(l10n.redesignPlanHint, style: RdType.meta(p, size: 13))),
              TextButton(onPressed: _rdHideHint, child: Text(l10n.redesignPlanHintDismiss)),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      RdGroupLabel(l10n.redesignPlanSettings),
      RdGroupedList(
        children: [
          RdListRow(
            leading: const RdRowIcon(Icons.visibility_outlined),
            title: l10n.redesignEventPlanShare,
            subtitle: l10n.redesignPlanShareHint,
            showChevron: false,
            onTap: () => _rdSetShare(!_sharePlan),
            trailing: Switch.adaptive(value: _sharePlan, onChanged: _rdSetShare),
          ),
          if (org != null)
            RdListRow(
              leading: const RdRowIcon(Icons.account_balance_outlined),
              title: l10n.planningOrgPlan,
              subtitle: l10n.redesignPlanOrgHint,
              showChevron: false,
              onTap: () => _rdSetOrgPlan(!_isOrgPlan),
              trailing: Switch.adaptive(value: _isOrgPlan, onChanged: _rdSetOrgPlan),
            ),
          if ((att.notes ?? '').isNotEmpty)
            RdListRow(
              leading: const RdRowIcon(Icons.notes_outlined),
              title: l10n.redesignPlanNotes,
              subtitle: att.notes,
              showChevron: false,
            ),
        ],
      ),
    ];
  }

  /// Opened from a Termin: the Ablauf belongs to that Termin, so there is
  /// no ‹ › and no Termin choice. From Verwaltung › Ablaufpläne the Termin
  /// can be switched like in Ionic ("Vorheriger" / "Nächster").
  bool get _rdFromTermin => widget.attendanceId != null;

  List<Widget> _rdTerminLine(PlanAttendance att) {
    final p = context.rd;
    final l10n = context.l10n;
    if (_rdFromTermin) {
      return [
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                _rdAttLabel(att),
                key: const Key('rd-plan-termin-fixed'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RdType.meta(p, size: 15),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: _rdStatus()),
          ],
        ),
      ];
    }
    return [
      const SizedBox(height: 8),
      RdCard(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            _rdArrow(Icons.chevron_left, l10n.redesignPlanPrev, () => _navigate(-1)),
            Expanded(
              child: Semantics(
                button: true,
                label: '${l10n.redesignPlanPlanPick}: ${_rdAttLabel(att)}',
                excludeSemantics: true,
                child: InkWell(
                  key: const Key('rd-plan-termin'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: _rdPickAttendance,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _rdAttLabel(att),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: p.text),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: p.text2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _rdArrow(Icons.chevron_right, l10n.redesignPlanNext, () => _navigate(1)),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Align(alignment: Alignment.centerRight, child: _rdStatus()),
    ];
  }

  Widget _rdArrow(IconData icon, String label, VoidCallback onPressed) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    icon: Icon(icon, color: context.rd.link),
  );

  /// "✓ Gespeichert" / "Speichert …"; nothing for the default plan of a
  /// Termin without plan (it is stored when the editor closes, like before).
  Widget _rdStatus() {
    final p = context.rd;
    final l10n = context.l10n;
    final Widget content;
    final att = _att;
    if (!_hasPendingChanges && !_hasUserEdits && att != null && PlanUtils.allPlans(att).isEmpty) {
      // The untouched start plan of a Termin without Ablauf is not stored:
      // no "Gespeichert" for it.
      return const SizedBox(height: 18);
    } else if (!_hasPendingChanges) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: p.present),
          const SizedBox(width: 4),
          Text(l10n.redesignPlanSaved, style: TextStyle(fontSize: 13, color: p.present)),
        ],
      );
    } else if (!_hasUserEdits) {
      return const SizedBox(height: 18);
    } else if (!_validate()) {
      content = Text(l10n.redesignPlanInvalid, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: p.late));
    } else {
      content = Text(l10n.redesignPlanSaving, style: RdType.meta(p, size: 13));
    }
    return Semantics(liveRegion: true, child: content);
  }

  /// The Überschrift of the plan (in the PDF and for the members above the
  /// Ablauf); empty: the default title.
  Widget _rdHeadingField(PlanAttendance att) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.redesignPlanHeading, style: RdType.meta(p, size: 12)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (focused) {
                    if (!focused) _onTitleFocusLost();
                  },
                  child: Semantics(
                    label: l10n.redesignPlanHeading,
                    child: TextField(
                      key: const Key('rd-plan-heading'),
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
                      // Empty: the default title (Ionic "Standardtitel verwenden").
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        hintText: _defaultTitle(att),
                        hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 16, color: p.link),
            ],
          ),
        ],
      ),
    );
  }

  /// Überschrift (only for an Auftritt, see below), then
  /// Beginn ✎ · Gesamtdauer · Ende.
  Widget _rdSummary(PlanAttendance att, int? start, int total) {
    final p = context.rd;
    final l10n = context.l10n;
    final end = start == null ? '' : PlanUtils.formatMinutes(start + total);
    Widget part(String label, String value) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      style: TextStyle(fontSize: 15, color: p.text),
    );
    // A Probe needs no Überschrift: only an Auftritt (hervorgehobene
    // Terminart) has the field, and a plan whose Überschrift was changed
    // before, so it can still be put back. Once shown it stays for this
    // plan (also while it is being emptied).
    if (PlanSongHelper.isAuftritt(att, _types) || (_savedTitle.isNotEmpty && _savedTitle != _defaultTitle(att))) {
      _rdHeadingGen = _loadGen;
    }
    final withHeading = _rdHeadingGen == _loadGen;
    return RdCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (withHeading) ...[_rdHeadingField(att), Divider(height: 1, thickness: 1, color: p.line)],
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  child: InkWell(
                    key: const Key('rd-plan-start'),
                    onTap: _pickTime,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        children: [
                          Flexible(child: part(l10n.redesignPlanStart, _time)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 16, color: p.link),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Text(_rdDuration(total), style: RdType.meta(p, size: 15)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
                  child: Align(alignment: Alignment.centerRight, child: part(l10n.redesignPlanEnd, end)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rdDuration(int minutes) {
    final l10n = context.l10n;
    if (minutes < 60) return l10n.redesignPlanMinutes(minutes);
    final rest = minutes % 60;
    return rest == 0 ? l10n.redesignPlanHours(minutes ~/ 60) : l10n.redesignPlanHoursMinutes(minutes ~/ 60, rest);
  }


  // ---------------------------------------------------------------------------
  // "Teilen" and "•••": the open plan, Registerprobenplan, zurücksetzen
  // ---------------------------------------------------------------------------

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

  /// PDF or picture of the open plan (same pages as the classic sheet).
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

  // ---------------------------------------------------------------------------
  // Empty plan, Termin choice, flags
  // ---------------------------------------------------------------------------

  /// No items: how to start (the same choices as in the Reiter Programm of
  /// the Termin): with the Werke of the Termin, from a Vorlage, or like
  /// the last Termin of the same Terminart.
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

  static const _rdHintKey = 'rd_plan_hint_hidden';

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
  }

  // ---------------------------------------------------------------------------
  // Sheet frame
  // ---------------------------------------------------------------------------

  Widget _rdSheetRow(IconData icon, String title, String? subtitle, VoidCallback onTap, {Key? key}) =>
      RdListRow(key: key, leading: RdRowIcon(icon), title: title, subtitle: subtitle, showChevron: false, onTap: onTap);

  /// Bottom sheet in the Beta look (like the Werk sheet of a Termin).
  Future<T?> _rdSheet<T>({
    required String title,
    String? subtitle,
    Widget? action,
    required List<Widget> Function(BuildContext ctx, void Function(T value) pop) builder,
  }) => showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (ctx) {
      final p = ctx.rd;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Semantics(header: true, child: Text(title, style: RdType.cardTitle(p)))),
                      if (action != null) action,
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: RdType.meta(p, size: 15)),
                  ],
                  const SizedBox(height: 16),
                  ...builder(ctx, (value) => Navigator.of(ctx).pop(value)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
