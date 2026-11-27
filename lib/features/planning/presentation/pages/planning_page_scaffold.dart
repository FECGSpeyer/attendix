part of 'planning_page.dart';

/// Page scaffold, header summary, status indicator, and shared bottom sheet
/// framing for [PlanningPage].
extension _PlanningScaffold on _PlanningPageState {
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

    // Loading until `_init` chose the Termin.
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
      if (_planUnpublished) ...[
        const SizedBox(height: 16),
        RdInfoCard(
          key: const Key('rd-plan-unpublished'),
          text: l10n.planningFlutterUnpublishedHint,
          icon: Icons.visibility_off_outlined,
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
              leading: const RdRowIcon(Icons.hub_outlined),
              title: l10n.planningOrgPlan,
              subtitle: l10n.rdOrgPlanToggleHint(org.name),
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
  /// Termin without plan (it is stored when the editor closes).
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

  Widget _rdSheetRow(IconData icon, String title, String? subtitle, VoidCallback onTap, {Key? key}) =>
      RdListRow(key: key, leading: RdRowIcon(icon), title: title, subtitle: subtitle, showChevron: false, onTap: onTap);

  /// Modal bottom sheet frame used by editor actions.
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
