part of 'planning_page.dart';

/// Preset durations of the inline duration field (concept board 12): one
/// tap also for long items such as a Predigt.
const _rdDurationPresets = [5, 10, 15, 20, 30, 40, 45, 60];

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
      if (_fields.isEmpty) ..._rdEmpty(att, blockTemplates) else _rdTimeline(start, showBeamer: showBeamer),
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
            _rdStatus(),
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
      content = Text(l10n.redesignPlanInvalid, style: TextStyle(fontSize: 13, color: p.late));
    } else {
      content = Text(l10n.redesignPlanSaving, style: RdType.meta(p, size: 13));
    }
    return Semantics(liveRegion: true, child: content);
  }

  /// Überschrift (in the PDF and for the members above the Ablauf), then
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
    return RdCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
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
          ),
          Divider(height: 1, thickness: 1, color: p.line),
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
  // Timeline
  // ---------------------------------------------------------------------------

  /// The visible rows: fields (Unterpunkte of collapsed blocks are hidden)
  /// and, after the last row of every open block, its "+ Punkt in „…“"
  /// row. That row is the block's end: an item dropped above it lands in
  /// the block, below it behind the block.
  List<_RdSlot> _rdSlots() {
    final slots = <_RdSlot>[];
    for (var i = 0; i < _fields.length; i++) {
      final f = _fields[i];
      if (f.groupId != null && _rdCollapsed.contains(f.groupId)) continue;
      slots.add(_RdSlot(i));
      final block = PlanUtils.isGroupHead(f) ? f.id : f.groupId;
      if (block == null || _rdCollapsed.contains(block)) continue;
      final head = _fields.indexWhere((x) => x.id == block);
      if (head >= 0 && PlanUtils.lastIndexOfGroup(_fields, block) == i) slots.add(_RdSlot(head, footer: block));
    }
    return slots;
  }

  /// The block a row belongs to (its head, Unterpunkt or end row).
  String? _rdBlockOf(_RdSlot s) {
    if (s.isFooter) return s.footer;
    final f = _fields[s.index];
    return PlanUtils.isGroupHead(f) ? f.id : f.groupId;
  }

  _RdPart _rdPartOf(_RdSlot s) {
    if (s.isFooter) return _RdPart.bottom;
    final f = _fields[s.index];
    if (PlanUtils.isGroupHead(f)) return _rdCollapsed.contains(f.id) ? _RdPart.single : _RdPart.top;
    return f.groupId != null ? _RdPart.middle : _RdPart.none;
  }

  Widget _rdTimeline(int? start, {required bool showBeamer}) {
    final p = context.rd;
    final slots = _rdSlots();
    final seen = <String, int>{};
    String rowKey(String id) {
      final n = (seen[id] ?? 0) + 1;
      seen[id] = n;
      return n > 1 ? '$id#$n' : id;
    }

    final numbers = PlanUtils.topNumbers(_fields);
    final keys = [for (final s in slots) s.isFooter ? 'end:${s.footer}' : rowKey(_fields[s.index].id)];
    _rdSlotOrder = [for (final k in keys) _rdSlotKeys.putIfAbsent(k, GlobalKey.new)];
    return Listener(
      onPointerDown: (e) => _rdPointerDown = e.localPosition,
      onPointerMove: (e) => _rdDragHover(slots, e.localPosition.dy),
      onPointerUp: (_) => _rdDragCancel(later: true),
      onPointerCancel: (_) => _rdDragCancel(),
      child: DecoratedBox(
        key: _rdListKey,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(p.listRadius),
          boxShadow: p.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(p.listRadius),
          clipBehavior: Clip.antiAlias,
          child: ReorderableListView.builder(
            key: const Key('rd-plan-timeline'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: slots.length,
            onReorderStart: (row) => _rdDragStart(slots, row),
            onReorderEnd: (row) => _rdDragEnd(slots, row),
            onReorderItem: (o, n) => _rdReorder(slots, o, n),
            proxyDecorator:
                (child, row, _) => _rdDragProxy(
                  slots,
                  row,
                  child,
                  () => _rdRow(slots[row].index, row, start, numbers, divider: false, showBeamer: showBeamer, proxy: true),
                ),
            itemBuilder: (context, row) {
              final s = slots[row];
              final block = _rdBlockOf(s);
              // Unterpunkte and the end row of the dragged block fold into
              // its head (the row count stays the same: a changed count
              // cancels the drag).
              final folded =
                  _rdDragBlock != null && block == _rdDragBlock && (s.isFooter || _fields[s.index].id != block);
              final next = row + 1 < slots.length ? slots[row + 1] : null;
              final part = _rdPartOf(s);
              // A line between two rows of the same block or two rows
              // outside of blocks; blocks are set off by their frame.
              final divider = next != null && part != _RdPart.single && !s.isFooter && _rdBlockOf(next) == block;
              final Widget body =
                  s.isFooter
                      ? _rdBlockEnd(s)
                      : _rdRow(s.index, row, start, numbers, divider: divider, showBeamer: showBeamer);
              return KeyedSubtree(
                key: ValueKey(keys[row]),
                child: KeyedSubtree(
                  key: _rdSlotOrder[row],
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child:
                        folded
                            ? const SizedBox(width: double.infinity)
                            : _rdFramed(body, part, hot: block != null && block == _rdHotBlock),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The frame of a block around its rows: a rounded box drawn in parts
  /// (head = top, Unterpunkte = sides, end row = bottom), highlighted while
  /// a dragged item would land in it. Only colours change while dragging,
  /// so the rows keep their size.
  Widget _rdFramed(Widget child, _RdPart part, {required bool hot}) {
    if (part == _RdPart.none) return child;
    final p = context.rd;
    const r = Radius.circular(12);
    final top = part == _RdPart.top || part == _RdPart.single;
    final bottom = part == _RdPart.bottom || part == _RdPart.single;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, top ? 6 : 0, 6, bottom ? 6 : 0),
      child: CustomPaint(
        foregroundPainter: _RdBlockFramePainter(part: part, color: hot ? p.link : p.line, width: hot ? 2.5 : 1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: top ? r : Radius.zero, bottom: bottom ? r : Radius.zero),
          child: hot ? ColoredBox(color: p.soft.withValues(alpha: 0.35), child: child) : child,
        ),
      ),
    );
  }

  /// "+ Punkt in „Block“": the end of an open block and the way to add
  /// several items into it.
  Widget _rdBlockEnd(_RdSlot s) {
    final p = context.rd;
    final l10n = context.l10n;
    final head = _fields[s.index];
    final register = head.registerPlan != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('rd-plan-block-add-${s.footer}'),
        onTap: () => register ? _rdChangeRegister(head.id) : _rdQuickAdd(group: s.footer),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 10, 14, 10),
            child: Row(
              children: [
                Icon(register ? Icons.groups_outlined : Icons.add, size: 18, color: p.link),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    register ? l10n.redesignPlanRegisterChange : l10n.redesignPlanAddInBlock(head.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.link),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rdRow(
    int index,
    int row,
    int? start,
    Map<String, int> numbers, {
    required bool divider,
    required bool showBeamer,
    bool proxy = false,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final field = _fields[index];
    final isHead = PlanUtils.isGroupHead(field);
    final isNote = PlanUtils.isNote(field);
    final isAgenda = PlanUtils.isAgendaPlaceholder(field);
    // The card under the finger is indented while it would land in a block.
    final isChild = proxy ? _rdHotBlock != null : field.groupId != null;
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, index);
    final collapsed = isHead && _rdCollapsed.contains(field.id);

    final grip = ReorderableDragStartListener(
      index: row,
      child: Semantics(
        label: l10n.redesignPlanDrag,
        child: SizedBox(width: 44, height: 44, child: Icon(Icons.drag_indicator, color: p.text2)),
      ),
    );

    final sub = <Widget>[];
    String? metaLine;
    if (isHead) {
      final count = PlanUtils.childrenOf(_fields, field.id).length;
      metaLine = [
        if (at != null)
          l10n.redesignPlanUntil(PlanUtils.formatMinutes(at + PlanUtils.groupDuration(_fields, field.id))),
        if ((field.conductor ?? '').isNotEmpty) field.conductor!,
        l10n.redesignPlanItemCount(count),
        if (collapsed) l10n.redesignPlanCollapsed,
      ].join(' · ');
    } else if (!isNote && !isAgenda && (field.conductor ?? '').isNotEmpty) {
      metaLine = field.conductor;
    }
    if (metaLine != null) sub.add(Text(metaLine, style: RdType.meta(p, size: 13)));
    if (!isNote && !isAgenda && (field.info ?? '').isNotEmpty) {
      // A Registerprobe round: one line per group ("Streicher: Anna").
      final round =
          field.groupId != null && _fields.any((f) => f.id == field.groupId && f.registerPlan != null);
      if (round) {
        for (final line in field.info!.split(' · ')) {
          sub.add(Text(line, style: RdType.meta(p, size: 13)));
        }
      } else {
        sub.add(Text(field.info!, style: RdType.meta(p, size: 13).copyWith(fontStyle: FontStyle.italic)));
      }
    }
    final warning = isHead || isNote ? null : _missingGroups(field);
    if (warning != null && warning.isNotEmpty) {
      sub.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(alignment: Alignment.centerLeft, child: RdPill(warning, tone: RdTone.late)),
        ),
      );
    }
    if (showBeamer && !isHead && !isNote && !isAgenda && PlanBeamer.needsBeamer(field)) {
      final file = _beamerFileOf(field);
      sub.add(
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Icon(Icons.tv_outlined, size: 14, color: file == null ? p.late : p.text2),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  file?.name ?? l10n.planningBeamerMissing,
                  style: TextStyle(fontSize: 12, color: file == null ? p.late : p.text2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final minutes = PlanUtils.displayMinutes(field, _fields);
    final open = _rdDurationIndex == index;
    Widget? trailing;
    if (isAgenda && _canAddTopics) {
      sub.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _openAgendaPicker, child: Text(l10n.attendanceAddTopics)),
        ),
      );
    }
    if (isHead) {
      // The block's length (sum of its Unterpunkte) and, next to it, open /
      // close: the time column on the left stays the same for every row.
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.redesignPlanMinutes(minutes),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.softText),
          ),
          IconButton(
            key: ValueKey('rd-plan-toggle-$index'),
            tooltip: collapsed ? l10n.redesignPlanExpand : l10n.redesignPlanCollapse,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            padding: EdgeInsets.zero,
            icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less, color: p.link),
            onPressed:
                () => _rdSet(() {
                  if (!_rdCollapsed.remove(field.id)) _rdCollapsed.add(field.id);
                }),
          ),
        ],
      );
    } else if (!isNote && !isAgenda) {
      trailing = Semantics(
        button: true,
        label: l10n.redesignPlanDurationLabel(
          PlanUtils.fieldDisplayName(field, numbers),
          field.time.trim().isEmpty ? '–' : field.time.trim(),
        ),
        excludeSemantics: true,
        child: _RdDurationPill(
          key: ValueKey('rd-plan-dur-$index'),
          label: field.time.trim().isEmpty ? '–' : l10n.redesignPlanMinutes(field.time.trim()),
          selected: open,
          onTap: () => _rdSet(() => _rdDurationIndex = open ? null : index),
        ),
      );
    }

    final title = isAgenda ? l10n.planningAgendaInsertPos : PlanUtils.fieldDisplayName(field, numbers);
    final rowBody = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            isNote || isAgenda || at == null ? '' : PlanUtils.formatMinutes(at),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.softText),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isHead ? FontWeight.w700 : FontWeight.w500,
                    fontStyle: isNote || isAgenda ? FontStyle.italic : FontStyle.normal,
                    color: isNote || isAgenda ? p.text2 : p.text,
                  ),
                ),
                ...sub,
              ],
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
        grip,
      ],
    );

    final Widget content = Padding(padding: EdgeInsets.only(left: isChild ? 30 : 14), child: rowBody);
    return Material(
      color: isHead ? p.soft : (proxy ? p.surface : Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Nach oben" / "Nach unten" stay for screen readers (no buttons:
          // sighted users drag).
          Semantics(
            customSemanticsActions: {
              if (index > 0) CustomSemanticsAction(label: l10n.redesignPlanMoveUp): () => _rdMove(index, -1),
              if (index < _fields.length - 1)
                CustomSemanticsAction(label: l10n.redesignPlanMoveDown): () => _rdMove(index, 1),
            },
            child: InkWell(
              key: proxy ? null : ValueKey('rd-plan-row-$index'),
              onTap: proxy ? null : () => isHead ? _rdBlockSheet(index) : _rdItemSheet(index),
              child: content,
            ),
          ),
          if (open && !proxy)
            _RdDurationEditor(
              key: ValueKey('rd-plan-dur-editor-$index'),
              value: field.time,
              start: at,
              onChanged: (v) => _rdSetMinutes(index, v),
            ),
          if (divider) Divider(height: 1, thickness: 1, color: p.line),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dragging
  // ---------------------------------------------------------------------------

  /// Remembers where the rows are, for the live drop target. An open block
  /// with Unterpunkte is dragged as one card: they fold into the head while
  /// the finger moves and unfold at the new place.
  void _rdDragStart(List<_RdSlot> slots, int row) {
    if (row >= slots.length) return;
    _rdDragGen++;
    _rdDragFrom = row;
    _rdDragInsert = row;
    _rdHotBlock = null;
    _rdDragRects = _rdMeasure(slots.length);
    final rects = _rdDragRects;
    final down = _rdPointerDown;
    _rdDragOffset = rects != null && down != null ? down.dy - rects[row].top : 0;
    final s = slots[row];
    if (s.isFooter) return;
    final field = _fields[s.index];
    if (!PlanUtils.isGroupHead(field) || _rdCollapsed.contains(field.id)) return;
    if (PlanUtils.childrenOf(_fields, field.id).isEmpty) return;
    _rdSet(() => _rdDragBlock = field.id);
  }

  /// The rows' rectangles in the coordinates of the list (null when one is
  /// not laid out).
  List<Rect>? _rdMeasure(int count) {
    final list = _rdListKey.currentContext?.findRenderObject();
    if (list is! RenderBox || !list.hasSize || _rdSlotOrder.length != count) return null;
    final rects = <Rect>[];
    for (final key in _rdSlotOrder) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return null;
      rects.add(list.globalToLocal(box.localToGlobal(Offset.zero)) & box.size);
    }
    return rects;
  }

  /// Follows the finger like the list does (same gap rule as
  /// `SliverReorderableList._dragUpdateItems`) and lights up the block the
  /// dragged item would land in. Blocks and the Tagesordnung marker never
  /// join a block, so nothing lights up for them.
  void _rdDragHover(List<_RdSlot> slots, double y) {
    final from = _rdDragFrom;
    final rects = _rdDragRects;
    if (from == null || rects == null || rects.length != slots.length || from >= slots.length) return;
    final moved = slots[from];
    if (moved.isFooter) return;
    final field = _fields[moved.index];
    if (PlanUtils.isGroupHead(field) || PlanUtils.isAgendaPlaceholder(field)) return;
    final gap = rects[from].height;
    final proxyStart = y - _rdDragOffset;
    final proxyEnd = proxyStart + gap;
    final current = _rdDragInsert;
    var insert = current;
    for (var i = 0; i < slots.length; i++) {
      var shift = 0.0;
      if (i != from) {
        if (current < from && i < from && i >= current) {
          shift = gap;
        } else if (current > from && i > from && i < current) {
          shift = -gap;
        }
      }
      final top = rects[i].top + shift;
      final end = top + rects[i].height;
      final middle = top + rects[i].height / 2;
      if (i == from) {
        if (middle <= proxyEnd && proxyEnd <= end) insert = from;
      } else if (top <= proxyStart && proxyStart <= middle) {
        insert = i;
        break;
      } else if (middle <= proxyEnd && proxyEnd <= end) {
        insert = i + 1;
        break;
      } else if (end < proxyStart && insert < i + 1) {
        insert = i + 1;
      } else if (proxyEnd < top && insert > i) {
        insert = i;
      }
    }
    _rdDragInsert = insert;
    final rest = [...slots]..removeAt(from);
    final target = _rdDropTarget(rest, insert > from ? insert - 1 : insert, moved: field);
    if (target.group != _rdHotBlock) _rdSet(() => _rdHotBlock = target.group);
  }

  /// Where a row dropped at [at] (index in [rest], the rows without the
  /// dragged one) goes: behind [anchor] (null: first), in block [group].
  /// Right below a head or below an Unterpunkt is inside the block, below
  /// its "+ Punkt in" row (or a collapsed block) is behind it.
  ({PlanField? anchor, String? group}) _rdDropTarget(List<_RdSlot> rest, int at, {PlanField? moved}) {
    if (at <= 0 || rest.isEmpty) return (anchor: null, group: null);
    final prev = rest[(at - 1).clamp(0, rest.length - 1)];
    if (prev.isFooter) return (anchor: _rdLastOfBlock(prev.footer!, moved), group: null);
    final f = _fields[prev.index];
    if (PlanUtils.isGroupHead(f)) {
      if (_rdCollapsed.contains(f.id)) return (anchor: _rdLastOfBlock(f.id, moved), group: null);
      return (anchor: f, group: f.id);
    }
    return (anchor: f, group: f.groupId);
  }

  /// The last row of [block] other than [moved] (the head when it has no
  /// other row): what goes behind the block goes behind this one.
  PlanField _rdLastOfBlock(String block, [PlanField? moved]) {
    var i = PlanUtils.lastIndexOfGroup(_fields, block);
    while (i > 0 && identical(_fields[i], moved)) {
      i--;
    }
    return _fields[i];
  }

  /// Dropped where it was: no reorder follows, so unfold here. A real move
  /// unfolds in [_rdReorder], together with the new order, so the
  /// Unterpunkte never show up at the old place during the drop.
  void _rdDragEnd(List<_RdSlot> slots, int row) {
    final hot = _rdHotBlock != null;
    _rdDragFrom = null;
    _rdDragRects = null;
    _rdHotBlock = null;
    if (_rdDragBlock == null) {
      if (hot) _rdSet(() {});
      return;
    }
    final from = slots.indexWhere((s) => !s.isFooter && _fields[s.index].id == _rdDragBlock);
    if (from < 0 || row == from || row == from + 1) _rdSet(() => _rdDragBlock = null);
  }

  /// A cancelled drag (no end, no reorder) unfolds too. [later]: after the
  /// finger lifted, once the drop animation (250 ms) is over; normally the
  /// end or the reorder unfolded already, this only catches a drag the list
  /// cancelled itself (e.g. the plan changed meanwhile).
  void _rdDragCancel({bool later = false}) {
    if (_rdDragBlock == null && _rdHotBlock == null && _rdDragFrom == null) return;
    if (!later) {
      _rdSet(() {
        _rdDragBlock = null;
        _rdHotBlock = null;
        _rdDragFrom = null;
      });
      return;
    }
    // Only this drag: a new one started meanwhile (even of the same block)
    // keeps its folded Unterpunkte.
    final gen = _rdDragGen;
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || _rdDragGen != gen) return;
      if (_rdDragBlock != null || _rdHotBlock != null) {
        _rdSet(() {
          _rdDragBlock = null;
          _rdHotBlock = null;
        });
      }
      _rdDragFrom = null;
    });
  }

  /// The card under the finger: the row on its own (no block frame),
  /// indented while it would land in a block.
  Widget _rdDragProxy(List<_RdSlot> slots, int row, Widget child, Widget Function() bare) {
    final p = context.rd;
    if (row >= slots.length || slots[row].isFooter) return child;
    final card = Material(
      color: p.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: bare(),
    );
    final isBlock = _rdDragBlock != null && _fields[slots[row].index].id == _rdDragBlock;
    if (!isBlock) return card;
    // Folded cards along the bottom edge: the Unterpunkte travel with it
    // (inside the head's size, the proxy keeps the dragged row's extent).
    return Stack(
      children: [
        card,
        for (final (inset, height) in [(16.0, 6.0), (28.0, 3.0)])
          Positioned(
            left: inset,
            right: inset,
            bottom: 0,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.line,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Changes
  // ---------------------------------------------------------------------------

  /// Takes over [fields] as the editor's plan (autosaved like every edit).
  void _rdApply(List<PlanField> fields) {
    _rdSet(() {
      _fields = fields;
      _rdDurationIndex = null;
    });
    _changed();
  }

  void _rdSetMinutes(int index, String value) {
    if (index >= _fields.length) return;
    final updated = [..._fields];
    updated[index] = updated[index].copyWith(time: value.trim());
    _rdSet(() => _fields = updated);
    _changed();
  }

  /// [newIndex] as `onReorderItem` reports it (already without the moved
  /// row). An item takes the block of its new place ([_rdDropTarget]); a
  /// block moves with its Unterpunkte and never lands inside another one.
  void _rdReorder(List<_RdSlot> slots, int oldIndex, int newIndex) {
    _rdDragBlock = null; // unfolds with the new order (same frame)
    _rdHotBlock = null;
    _rdDragFrom = null;
    _rdDragRects = null;
    final moved = slots[oldIndex];
    if (moved.isFooter) return _rdSet(() {});
    final field = _fields[moved.index];
    final isHead = PlanUtils.isGroupHead(field);
    final rest = [...slots]..removeAt(oldIndex);
    var at = newIndex;
    // The dragged block's own (folded) rows are no place for it.
    while (isHead && at > 0 && _rdBlockOf(rest[at - 1]) == field.id) {
      at--;
    }
    var (:anchor, :group) = _rdDropTarget(rest, at, moved: field);
    if (group != null && (isHead || PlanUtils.isAgendaPlaceholder(field))) {
      anchor = _rdLastOfBlock(group, field);
      group = null;
    }
    final moving = isHead ? [field, ..._fields.where((f) => f.groupId == field.id)] : [field];
    final result = _rdPlace(moving, anchor, group, keepGroups: isHead);
    _rdOpenBlocksOf(result);
    _rdApply(result);
  }

  /// [moving] behind [anchor] (null: at the start); items take [group]
  /// unless [keepGroups] (a whole block).
  List<PlanField> _rdPlace(List<PlanField> moving, PlanField? anchor, String? group, {bool keepGroups = false}) {
    final rows = [
      for (final f in _fields)
        if (!moving.any((m) => identical(m, f))) f,
    ];
    var at = anchor == null ? 0 : rows.indexWhere((f) => identical(f, anchor)) + 1;
    if (anchor != null && at == 0) at = rows.length;
    rows.insertAll(at, keepGroups ? moving : [for (final m in moving) m.copyWith(groupId: group)]);
    return PlanUtils.normalizeGroups(rows);
  }

  /// A field that lands in a collapsed block opens it, so it stays visible.
  void _rdOpenBlocksOf(List<PlanField> result) {
    for (final f in result) {
      if (f.groupId != null && _rdCollapsed.contains(f.groupId)) {
        final before = _fields.where((o) => o.id == f.id && o.groupId == f.groupId);
        if (before.isEmpty) _rdCollapsed.remove(f.groupId);
      }
    }
  }

  /// "Nach oben" / "Nach unten" without dragging (also for screen readers).
  /// A block moves with its Unterpunkte past the neighbouring item or block.
  void _rdMove(int index, int direction) {
    final field = _fields[index];
    List<PlanField> result;
    if (PlanUtils.isGroupHead(field)) {
      if (direction < 0) {
        if (index == 0) return;
        final prev = _fields[index - 1];
        final target = prev.groupId == null ? index - 1 : _fields.indexWhere((f) => f.id == prev.groupId);
        result = PlanUtils.moveField(_fields, index, target);
      } else {
        final end = PlanUtils.lastIndexOfGroup(_fields, field.id);
        if (end >= _fields.length - 1) return;
        final next = _fields[end + 1];
        final nextEnd = PlanUtils.isGroupHead(next) ? PlanUtils.lastIndexOfGroup(_fields, next.id) : end + 1;
        result = PlanUtils.moveField(_fields, index, nextEnd);
      }
    } else {
      var to = index + direction;
      if (to < 0 || to >= _fields.length) return;
      // A collapsed block is passed as a whole (its Unterpunkte are hidden).
      final neighbour = _fields[to];
      final block = PlanUtils.isGroupHead(neighbour) ? neighbour.id : neighbour.groupId;
      if (block != null && block != field.groupId && _rdCollapsed.contains(block)) {
        to = direction > 0 ? PlanUtils.lastIndexOfGroup(_fields, block) : _fields.indexWhere((f) => f.id == block);
      }
      result = _rdMoveField(index, to);
    }
    _rdOpenBlocksOf(result);
    _rdApply(result);
  }

  /// [PlanUtils.moveField] for one item. The Tagesordnung marker never joins
  /// a block: it passes a block as a whole (behind it going down, before its
  /// head going up).
  List<PlanField> _rdMoveField(int from, int to) {
    final moved = _fields[from];
    if (!PlanUtils.isAgendaPlaceholder(moved)) return PlanUtils.moveField(_fields, from, to);
    final rows = [..._fields]..removeAt(from);
    var at = to.clamp(0, rows.length);
    final block = at < rows.length ? rows[at].groupId : null;
    if (block != null) {
      at = to >= from ? PlanUtils.lastIndexOfGroup(rows, block) + 1 : rows.indexWhere((f) => f.id == block);
    }
    rows.insert(at, moved.copyWith(groupId: null));
    return PlanUtils.normalizeGroups(rows);
  }

  /// Removes fields with "Rückgängig" in the SnackBar (like "Werk entfernen").
  /// The sheet / dialog opened for row [index] ([field]) still applies: the
  /// same plan is loaded (no reload, conflict or draft meanwhile) and the
  /// row is unchanged.
  bool _rdStill(int loadGen, int index, PlanField field) =>
      mounted && loadGen == _loadGen && index < _fields.length && _rdSame(_fields[index], field);

  /// Same row; the Gemeinde App uid a write may add meanwhile does not count.
  static bool _rdSame(PlanField a, PlanField b) => a.copyWith(uid: null) == b.copyWith(uid: null);

  void _rdRemove(List<PlanField> next, String name) {
    final before = _fields;
    final loadGen = _loadGen;
    _rdApply(next);
    final editGen = _editGen;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l10n = context.l10n;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.redesignPlanRemoved(name)),
          duration: const Duration(seconds: 5),
          persist: false,
          action: SnackBarAction(
            label: l10n.redesignPlanUndo,
            onPressed: () {
              // Only while nothing else changed the plan meanwhile.
              if (!mounted || loadGen != _loadGen || editGen != _editGen) return;
              _rdApply(before);
            },
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Adding
  // ---------------------------------------------------------------------------

  /// "+ Punkt hinzufügen" (at the end) or "Punkt danach einfügen" ([after]:
  /// position in [_fields]; [group]: the block the new item joins).
  /// Every entry runs the classic action, which appends; the new rows are
  /// then moved to the chosen place.
  Future<void> _rdAdd({int? after, String? group}) async {
    final l10n = context.l10n;
    if (after != null && after >= _fields.length) after = null;
    final anchor = after == null ? null : _fields[after];
    final loadGen = _loadGen;
    final subtitle = anchor == null ? l10n.redesignPlanAddEnd : l10n.redesignPlanAddAfter(anchor.name);
    final action = await _rdAddSheet(subtitle);
    if (action == null || !mounted) return;
    // Another plan was loaded meanwhile (conflict, draft, other Termin): the
    // choice was made for the old one, so nothing is added or replaced.
    if (loadGen != _loadGen) return;
    final before = [..._fields];
    // The plan changed while the sheet was open: add at the end.
    if (after != null && (after >= before.length || !_rdSame(before[after], anchor!))) {
      after = null;
    }
    if (group != null && !before.any((f) => f.id == group)) group = null;
    // Punkt, Notiz and Block: one sheet that stays open for several entries.
    if (action == 'field' || action == 'note' || action == 'group') {
      await _rdQuickAdd(kind: action, group: action == 'group' ? null : group, after: after == null ? null : before[after]);
      return;
    }
    if (action == 'register') {
      await _rdInsertRegister(after: after == null ? null : before[after]);
      return;
    }
    if (action == 'works' || action == 'eventworks') {
      final rows = action == 'works' ? await _rdPickWorksFields() : await _rdPickEventWorksFields(subtitle);
      if (rows.isEmpty || !_samePlan(loadGen)) return;
      _rdApply([..._fields, ...rows]);
    } else {
      await _runAddAction(action);
    }
    if (!mounted || after == null || loadGen != _loadGen) return;
    final now = _fields;
    if (now.length <= before.length) return;
    for (var i = 0; i < before.length; i++) {
      if (!_rdSame(now[i], before[i])) return; // replaced (Vorlage): nothing to move
    }
    var tail = now.sublist(before.length);
    var pos = (after + 1).clamp(0, before.length);
    var join = group;
    // Blocks and the Tagesordnung marker never sit inside a block.
    if (join != null && tail.any((f) => PlanUtils.isGroupHead(f) || PlanUtils.isAgendaPlaceholder(f))) {
      // Blocks are never nested: behind the whole block.
      pos = PlanUtils.lastIndexOfGroup(before, join) + 1;
      join = null;
    }
    if (join != null) {
      tail = [
        for (final f in tail)
          // The Tagesordnung marker never sits inside a block.
          PlanUtils.isGroupHead(f) || PlanUtils.isAgendaPlaceholder(f) || f.groupId != null
              ? f
              : f.copyWith(groupId: join),
      ];
      _rdCollapsed.remove(join);
    }
    _rdApply([...now.sublist(0, pos), ...tail, ...now.sublist(pos, before.length)]);
  }

  /// "Werke": one picker for a Werk from the list or "Alle aktuellen
  /// Werke" (the rows to add; empty: nothing).
  Future<List<PlanField>> _rdPickWorksFields() async {
    final loadGen = _loadGen;
    final pick = await showPlanWorksPicker(
      context,
      _songs,
      currentIds: _history.map((h) => h.songId).whereType<int>().toSet(),
      inPlanIds: _fields.map((f) => f.songId).whereType<int>().toSet(),
      offerAllCurrent: true,
    );
    if (pick == null || !_samePlan(loadGen)) return const [];
    if (pick.allCurrent) return _currentSongFieldsOrAsk();
    final song = pick.song;
    if (song == null) return const [];
    return [PlanSongHelper.songField(song, history: _history, prefix: _songPrefix(_typeOf(_att)))];
  }

  // ---------------------------------------------------------------------------
  // "Werke vom … übernehmen": the Werke planned for the next Auftritt
  // ---------------------------------------------------------------------------

  /// The Termine whose planned Werke the open Ablauf can take over: the
  /// Termin itself, then the Auftritte after it (see
  /// [PlanSongHelper.eventWorks]).
  List<PlanEventWorks> _rdEventWorks() {
    final att = _att;
    if (att == null || _songs.isEmpty || ref.read(currentTenantProvider)?.type == 'general') return const [];
    return PlanSongHelper.eventWorks(att, attendances: _attendances, types: _types, history: _history, songs: _songs);
  }

  /// "Adventskonzert": the Termin's own title, else its Terminart.
  String _rdAttName(PlanAttendance a) => (a.typeInfo?.isNotEmpty ?? false) ? a.typeInfo! : (_typeOf(a)?.name ?? '');

  /// The entry "Werke vom 14.12.2026" / "Adventskonzert · 6 Werke" for the
  /// nearest of [sources] (empty state and "Hinzufügen").
  Widget _rdEventWorksRow(List<PlanEventWorks> sources, VoidCallback onTap, {required bool chevron}) {
    final l10n = context.l10n;
    final first = sources.first;
    final name = first.own ? '' : _rdAttName(first.att);
    return RdListRow(
      key: const Key('rd-plan-event-works'),
      leading: const RdRowIcon(Icons.queue_music_outlined),
      title: first.own ? l10n.redesignPlanEventWorksOwn : l10n.redesignPlanEventWorksFrom(_rdDate(first.att)),
      subtitle: [if (name.isNotEmpty) name, l10n.redesignPlanEventWorksCount(first.works.length)].join(' · '),
      showChevron: chevron,
      onTap: onTap,
    );
  }

  /// "Werke übernehmen": the Werke of the Termine as a checklist (the
  /// nearest one ticked); the rows of the chosen ones, each with the
  /// conductor planned there (empty: nothing chosen).
  Future<List<PlanField>> _rdPickEventWorksFields(String? subtitle) async {
    final l10n = context.l10n;
    final sources = _rdEventWorks();
    if (sources.isEmpty) return const [];
    final loadGen = _loadGen;
    String label(PlanEventWorks s) {
      if (s.own) return l10n.redesignPlanEventWorksThis;
      final d = DateTime.tryParse(s.att.date);
      String date;
      try {
        date = d == null ? s.att.date : DateFormat('EEE, d. MMM', currentIntlLocale()).format(d);
      } catch (_) {
        date = _rdDate(s.att);
      }
      final name = _rdAttName(s.att);
      return [if (name.isNotEmpty) name, date].join(' · ');
    }

    final chosen = await showRdEventWorksSheet(
      context,
      groups: [for (final s in sources) (label: label(s), works: s.works)],
      inPlanIds: _fields.map((f) => f.songId).whereType<int>().toSet(),
      subtitle: subtitle,
    );
    if (chosen == null || chosen.isEmpty || !_samePlan(loadGen)) return const [];
    final prefix = _songPrefix(_typeOf(_att));
    return [
      for (final w in chosen)
        PlanSongHelper.songField(
          w.song,
          history: [SongHistory(songId: w.song.id, conductorName: w.conductor)],
          prefix: prefix,
        ),
    ];
  }

  /// Empty Ablauf: the chosen Werke are its first rows.
  Future<void> _rdTakeEventWorks() async {
    final loadGen = _loadGen;
    final rows = await _rdPickEventWorksFields(null);
    if (rows.isEmpty || !_samePlan(loadGen)) return;
    _rdApply([..._fields, ...rows]);
  }

  // ---------------------------------------------------------------------------
  // Registerprobe (a block whose rounds are Unterpunkte)
  // ---------------------------------------------------------------------------

  /// "Registerprobe": the calculator with a preview, then a block with one
  /// Unterpunkt per round behind [after] (behind its whole block when it
  /// is in one) or at the end.
  Future<void> _rdInsertRegister({PlanField? after}) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    int pos() {
      if (after == null) return _fields.length;
      final i = _fields.indexWhere((f) => _rdSame(f, after));
      if (i < 0) return _fields.length;
      final block = PlanUtils.isGroupHead(after) ? after.id : after.groupId;
      return block == null ? i + 1 : PlanUtils.lastIndexOfGroup(_fields, block) + 1;
    }

    final start = PlanUtils.parseTimeToMinutes(_time);
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, pos());
    final choice = await showRegisterPlanInsertSheet(
      context,
      startMinutes: at,
      subtitle: at == null ? null : l10n.redesignPlanRegisterStarts(PlanUtils.formatMinutes(at)),
    );
    if (choice == null || !mounted || loadGen != _loadGen) return;
    final rows = RegisterPlanService.blockFields(
      name: l10n.redesignPlanRegister,
      roundName: (n) => l10n.redesignPlanRegisterRound(n),
      groups: choice.groups,
      conductors: choice.conductors,
      totalMinutes: choice.minutes,
      empty: l10n.redesignPlanRegisterSelf,
    );
    final i = pos();
    _rdApply([..._fields.sublist(0, i), ...rows, ..._fields.sublist(i)]);
  }

  /// "Gruppen und Dirigenten ändern": the same sheet with the block's
  /// groups, order and minutes; the rounds are built again.
  Future<void> _rdChangeRegister(String headId) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    final index = _fields.indexWhere((f) => f.id == headId);
    if (index < 0) return;
    final head = _fields[index];
    final settings = head.registerPlan;
    if (settings == null) return;
    final start = PlanUtils.parseTimeToMinutes(_time);
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, index);
    final choice = await showRegisterPlanInsertSheet(
      context,
      initial: settings,
      initialMinutes: PlanUtils.groupDuration(_fields, head.id),
      startMinutes: at,
      subtitle: at == null ? null : l10n.redesignPlanRegisterStarts(PlanUtils.formatMinutes(at)),
    );
    if (choice == null || !mounted || !_rdStill(loadGen, index, head)) return;
    final rows = RegisterPlanService.blockFields(
      name: head.name,
      roundName: (n) => l10n.redesignPlanRegisterRound(n),
      groups: choice.groups,
      conductors: choice.conductors,
      totalMinutes: choice.minutes,
      empty: l10n.redesignPlanRegisterSelf,
    );
    final newHead = head.copyWith(registerPlan: rows.first.registerPlan);
    final rounds = [for (final r in rows.skip(1)) r.copyWith(groupId: head.id)];
    final rest = [for (final f in _fields) if (f.groupId != head.id) f];
    final at2 = rest.indexWhere((f) => f.id == head.id);
    _rdCollapsed.remove(head.id);
    _rdApply([...rest.sublist(0, at2), newHead, ...rounds, ...rest.sublist(at2 + 1)]);
  }

  /// "Als Tabelle teilen": the old Registerprobenplan (PDF, Telegram) with
  /// the rounds' clock times.
  Future<void> _rdShareRegister(String headId) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    var index = _fields.indexWhere((f) => f.id == headId);
    if (index < 0 || _fields[index].registerPlan == null) return;
    var head = _fields[index];
    final chatId = planTelegramChatId(ref);
    var how = 'pdf';
    if (chatId != null) {
      final picked = await _rdSheet<String>(
        title: l10n.redesignPlanRegisterShare,
        subtitle: head.name,
        builder:
            (ctx, pop) => [
              RdGroupedList(
                children: [
                  _rdSheetRow(Icons.description_outlined, l10n.planningExport, null, () => pop('pdf')),
                  _rdSheetRow(Icons.send_outlined, l10n.planningTelegramPdfShort, null, () => pop('tg')),
                  _rdSheetRow(Icons.image_outlined, l10n.planningTelegramImageShort, null, () => pop('img')),
                ],
              ),
            ],
      );
      // Another plan was loaded or the block is gone: nothing to share.
      if (picked == null || !mounted || loadGen != _loadGen) return;
      index = _fields.indexWhere((f) => f.id == headId);
      if (index < 0 || _fields[index].registerPlan == null) return;
      head = _fields[index];
      how = picked;
    }
    // The rounds as they are now (moved, deleted, edited), with clock
    // times, or minutes from the block's start without a start time.
    final start = PlanUtils.parseTimeToMinutes(_time);
    final blockStart = PlanUtils.startMinutesAt(0, _fields, index);
    final rounds = <({String start, String? info})>[
      for (var i = index + 1; i < _fields.length; i++)
        if (_fields[i].groupId == head.id)
          (
            start:
                start == null
                    ? '${PlanUtils.startMinutesAt(0, _fields, i) - blockStart}'
                    : PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, _fields, i)),
            info: _fields[i].info,
          ),
    ];
    final plan = RegisterPlanService.tableOf(head.registerPlan!.groups, rounds);
    await exportRegisterPlan(
      context,
      ref,
      plan,
      attendanceDate: DateTime.tryParse(_att?.date ?? ''),
      timeLabel: start == null ? null : l10n.redesignPlanRegisterTime,
      perTelegram: how != 'pdf',
      asImage: how == 'img',
    );
  }

  /// Adds several entries in a row: Punkt or Notiz (form), Werke (one
  /// picker: a Werk or all current ones). [group]: into that block (at its end, or behind
  /// [after] when it is inside); [kind] `group`: a new block, its name at
  /// the top and its Unterpunkte right below. Every entry is stored at
  /// once (autosave), the sheet stays open until "Fertig".
  Future<void> _rdQuickAdd({String kind = 'field', String? group, PlanField? after}) async {
    final l10n = context.l10n;
    final loadGen = _loadGen;
    final newBlock = kind == 'group';
    var join = group;
    // Where the next entry goes: behind this row. A position, not the row
    // itself: autosave may replace rows by copies (UIDs of the Gemeinde-App)
    // while the sheet is open; the rows only move by these inserts.
    int? lastAt;
    if (after != null) {
      final i = _fields.indexWhere((f) => identical(f, after));
      if (i >= 0) {
        lastAt = i;
        // A new block never sits inside another one: behind the whole block.
        final block = PlanUtils.isGroupHead(after) ? after.id : after.groupId;
        if (newBlock && block != null) lastAt = PlanUtils.lastIndexOfGroup(_fields, block);
      }
    }
    // A block of its own: still there after the plan changed meanwhile.
    bool alive() => mounted && loadGen == _loadGen && (join == null || _fields.any((f) => f.id == join));

    void insert(List<PlanField> rows) {
      final anchor = lastAt ?? -1;
      final int at;
      if (anchor >= 0 && anchor < _fields.length) {
        at = anchor + 1;
      } else if (join != null) {
        at = PlanUtils.lastIndexOfGroup(_fields, join!) + 1;
      } else {
        at = _fields.length;
      }
      final placed = [
        for (final r in rows)
          PlanUtils.isGroupHead(r) || PlanUtils.isAgendaPlaceholder(r) ? r : r.copyWith(groupId: join),
      ];
      if (join != null) _rdCollapsed.remove(join);
      _rdApply(PlanUtils.normalizeGroups([..._fields]..insertAll(at, placed)));
      lastAt = (at + placed.length - 1).clamp(0, _fields.length - 1);
    }

    String blockName = '';
    String? headId;
    // The block itself is created with its first entry (or on "Fertig").
    bool ensureBlock() {
      if (!newBlock || headId != null) return true;
      if (blockName.trim().isEmpty) return false;
      final h = PlanUtils.newGroupHead(blockName.trim());
      join = null;
      insert([h]);
      headId = h.id;
      join = h.id;
      return true;
    }

    String? headTitle() => join == null ? null : _fields.where((f) => f.id == join).firstOrNull?.name;
    final title =
        newBlock ? l10n.redesignPlanNewBlock : (headTitle() != null ? l10n.redesignPlanQuickAddInBlock(headTitle()!) : l10n.redesignPlanAddTitle);
    final subtitle =
        newBlock
            ? null
            : join != null && after == null
            ? l10n.redesignPlanQuickAddInBlockHint
            : after != null
            ? l10n.redesignPlanAddAfter(after.name)
            : l10n.redesignPlanAddEnd;
    final isGeneral = ref.read(currentTenantProvider)?.type == 'general';

    await _rdSheet<void>(
      title: title,
      subtitle: subtitle,
      action: Builder(
        builder:
            (ctx) => TextButton(
              key: const Key('rd-plan-quick-done'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.redesignCommonDone),
            ),
      ),
      builder:
          (ctx, pop) => [
            _RdQuickAddBody(
              newBlock: newBlock,
              initialKind: kind == 'note' ? 'note' : 'field',
              initialMinutes: join != null || newBlock ? 5 : 20,
              withWorks: !isGeneral && _songs.isNotEmpty,
              onBlockName: (v) {
                blockName = v;
                final id = headId;
                if (id == null || !alive() || v.trim().isEmpty) return;
                // By the block's id: every change copies the head.
                final i = _fields.indexWhere((f) => f.id == id);
                if (i < 0) return;
                _rdApply([..._fields]..[i] = _fields[i].copyWith(name: v.trim()));
              },
              onAdd: (kind, input) async {
                if (!alive()) return null;
                if (!ensureBlock()) return null;
                final PlanField row;
                if (kind == 'note') {
                  row = PlanField(id: 'noteFld ${input.name}', name: input.name, conductor: '', time: '0');
                } else {
                  row = PlanField(
                    id: 'fld-${PlanUtils.uuid()}',
                    name: input.name,
                    conductor: input.conductor,
                    info: input.info,
                    time: '${input.minutes ?? 0}',
                  );
                }
                insert([row]);
                return [row.name];
              },
              onWorks: () async {
                if (!alive()) return null;
                final rows = await _rdPickWorksFields();
                if (rows.isEmpty || !alive() || !ensureBlock()) return null;
                insert(rows);
                return [for (final r in rows) r.name];
              },
            ),
          ],
    );
    // "Fertig" with a name and nothing in it yet: the block on its own.
    if (newBlock && headId == null && alive()) ensureBlock();
  }

  /// "Block: …" in the item sheet: the block it belongs to, from a list.
  Future<void> _rdPickBlock(int index) async {
    final l10n = context.l10n;
    final field = _fields[index];
    final heads = _fields.where(PlanUtils.isGroupHead).toList();
    final loadGen = _loadGen;
    final choice = await _rdSheet<String>(
      title: l10n.redesignPlanPickBlock,
      subtitle: field.name,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                for (final (id, name) in [('', l10n.redesignPlanNoBlock), for (final h in heads) (h.id, h.name)])
                  RdListRow(
                    key: ValueKey('rd-plan-pick-block-$id'),
                    title: name,
                    showChevron: false,
                    onTap: () => pop(id),
                    trailing: Icon(
                      (field.groupId ?? '') == id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: (field.groupId ?? '') == id ? ctx.rd.link : ctx.rd.text2,
                    ),
                  ),
              ],
            ),
          ],
    );
    if (choice == null || !_rdStill(loadGen, index, field) || choice == (field.groupId ?? '')) return;
    final PlanField? anchor;
    final String? group;
    if (choice.isEmpty) {
      // Out of the block: right behind it.
      anchor = _fields[PlanUtils.lastIndexOfGroup(_fields, field.groupId!)];
      group = null;
    } else {
      if (!_fields.any((f) => f.id == choice)) return;
      anchor = _fields[PlanUtils.lastIndexOfGroup(_fields, choice)];
      group = choice;
      _rdCollapsed.remove(choice);
    }
    // The item itself may be the anchor (last of its block): stays in place.
    final result =
        identical(anchor, field)
            ? PlanUtils.normalizeGroups([..._fields]..[index] = field.copyWith(groupId: group))
            : _rdPlace([field], anchor, group);
    _rdApply(result);
  }

  Future<String?> _rdAddSheet(String subtitle) {
    final l10n = context.l10n;
    final tenant = ref.read(currentTenantProvider);
    final isGeneral = tenant?.type == 'general';
    final isAdmin = ref.read(effectiveRoleProvider).isAdmin;
    final blockTemplates = ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[];
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];
    final orgFields = org?.defaultFields ?? const <PlanField>[];
    final hasProtocol = ref.read(protocolTypeByIdProvider(_att?.typeId))?.enableProtocol ?? false;
    final canInsertAgenda = hasProtocol && _planIndex == 0 && !_fields.any(PlanUtils.isAgendaPlaceholder);
    final canAddTopics = _canAddTopics;
    final canRegister = tenant?.type == 'choir' || tenant?.type == 'orchestra';
    final eventWorks = _rdEventWorks();
    return _rdSheet<String>(
      title: l10n.redesignPlanAddTitle,
      subtitle: subtitle,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                _rdSheetRow(
                  Icons.add,
                  l10n.redesignPlanAddItem,
                  l10n.redesignPlanAddItemHint,
                  () => pop('field'),
                  key: const Key('rd-plan-add-field'),
                ),
                _rdSheetRow(
                  Icons.view_agenda_outlined,
                  l10n.redesignPlanAddBlock,
                  l10n.redesignPlanAddBlockHint,
                  () => pop('group'),
                ),
                _rdSheetRow(
                  Icons.sticky_note_2_outlined,
                  l10n.redesignPlanAddNote,
                  l10n.redesignPlanAddNoteHint,
                  () => pop('note'),
                ),
                if (!isGeneral && _songs.isNotEmpty)
                  _rdSheetRow(
                    Icons.library_music_outlined,
                    l10n.redesignPlanAddWorks,
                    l10n.redesignPlanAddWorksHint,
                    () => pop('works'),
                    key: const Key('rd-plan-add-works'),
                  ),
                if (eventWorks.isNotEmpty) _rdEventWorksRow(eventWorks, () => pop('eventworks'), chevron: false),
                if (canRegister)
                  _rdSheetRow(
                    Icons.groups_outlined,
                    l10n.redesignPlanRegister,
                    l10n.redesignPlanRegisterHint,
                    () => pop('register'),
                    key: const Key('rd-plan-add-register'),
                  ),
                if (canAddTopics)
                  _rdSheetRow(Icons.playlist_add_circle_outlined, l10n.attendanceAddTopics, null, () => pop('topics')),
                if (canInsertAgenda) _rdSheetRow(Icons.commit, l10n.planningInsertAgenda, null, () => pop('agenda')),
              ],
            ),
            if (blockTemplates.isNotEmpty || orgTemplates.isNotEmpty || orgFields.isNotEmpty) ...[
              const SizedBox(height: 20),
              RdGroupLabel(l10n.planningTemplates),
              RdGroupedList(
                children: [
                  for (final tpl in blockTemplates)
                    RdListRow(
                      leading: const RdRowIcon(Icons.view_agenda_outlined),
                      title: tpl.name,
                      subtitle: l10n.redesignPlanBlockTemplateHint(PlanUtils.templateMinutes(tpl)),
                      showChevron: false,
                      onTap: () => pop('block:${tpl.id}'),
                      trailing:
                          isAdmin
                              ? IconButton(
                                tooltip: l10n.redesignPlanTemplateDelete,
                                icon: Icon(Icons.delete_outline, color: ctx.rd.text2),
                                onPressed: () => pop('delblock:${tpl.id}'),
                              )
                              : null,
                    ),
                  for (var i = 0; i < orgTemplates.length; i++)
                    _rdSheetRow(
                      Icons.account_balance_outlined,
                      orgTemplates[i].title ?? '',
                      l10n.redesignPlanOrgTemplateHint,
                      () => pop('tpl:$i'),
                    ),
                  for (var i = 0; i < orgFields.length; i++)
                    _rdSheetRow(
                      Icons.account_balance_outlined,
                      orgFields[i].name,
                      l10n.redesignPlanOrgFieldHint(orgFields[i].time),
                      () => pop('orgfield:$i'),
                    ),
                ],
              ),
            ],
          ],
    );
  }

  // ---------------------------------------------------------------------------
  // Item and block sheets
  // ---------------------------------------------------------------------------

  /// Tap on an item: Bearbeiten, Punkt danach einfügen, Nach oben / unten,
  /// in den Block / aus dem Block, Löschen.
  Future<void> _rdItemSheet(int index) async {
    final l10n = context.l10n;
    final field = _fields[index];
    final start = PlanUtils.parseTimeToMinutes(_time);
    final isNote = PlanUtils.isNote(field);
    final head = field.groupId == null ? null : _fields.where((f) => f.id == field.groupId).firstOrNull;
    final at = start == null ? null : PlanUtils.startMinutesAt(start, _fields, index);
    final meta = [
      if (at != null && !isNote)
        '${PlanUtils.formatMinutes(at)}–${PlanUtils.formatMinutes(at + PlanUtils.minutesOf(field))}',
      if (head != null) l10n.redesignPlanInBlock(head.name),
    ].join(' · ');
    final isAgenda = PlanUtils.isAgendaPlaceholder(field);
    // "Block: …" picks the block from a list (also far away ones); the
    // Tagesordnung marker never joins a block.
    final hasBlocks = !isAgenda && _fields.any(PlanUtils.isGroupHead);
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final showBeamer = PlanBeamer.active(org, _isOrgPlan) && !isNote;
    final loadGen = _loadGen;
    // Fields are edited right in the sheet (no second dialog) and saved when
    // the sheet closes.
    PlanFieldInput? edit;
    final action = await _rdSheet<String>(
      title: isAgenda ? l10n.planningAgendaInsertPos : field.name,
      subtitle: meta.isEmpty ? null : meta,
      builder:
          (ctx, pop) => [
            if (!isAgenda) ...[
              RdPlanFieldForm(
                key: const Key('rd-plan-item-form'),
                labels: RdPlanFieldLabels(
                  name: isNote ? l10n.planningNote : l10n.planningItem,
                  nameHint: isNote ? l10n.planningEnterNote : l10n.planningEnterItem,
                  infoHint: l10n.planningInfoOptionalEllipsis,
                ),
                initialName: field.name,
                initialConductor: field.conductor,
                initialInfo: field.info,
                initialMinutes: int.tryParse(field.time) ?? 20,
                withConductor: !isNote,
                withInfo: !isNote,
                withMinutes: !isNote,
                beamer:
                    showBeamer
                        ? PlanFieldBeamerOptions(
                          manual: field.needsBeamer,
                          songId: field.songId,
                          file: _beamerFileOf(field),
                        )
                        : null,
                onChanged: (v) => edit = v,
                onSubmitted: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 16),
            ],
            RdGroupedList(
              children: [
                if (hasBlocks)
                  RdListRow(
                    key: const Key('rd-plan-item-block'),
                    leading: const RdRowIcon(Icons.view_agenda_outlined),
                    title: l10n.redesignPlanBlockRow,
                    subtitle: head?.name ?? l10n.redesignPlanNoBlock,
                    onTap: () => pop('block'),
                  ),
                if (!isAgenda) _rdSheetRow(Icons.add, l10n.redesignPlanInsertAfter, null, () => pop('insert')),
                // Without any other entry the Tagesordnung marker can still move.
                if (isAgenda && index > 0)
                  _rdSheetRow(Icons.arrow_upward, l10n.redesignPlanMoveUp, null, () => pop('up')),
                if (isAgenda && index < _fields.length - 1)
                  _rdSheetRow(Icons.arrow_downward, l10n.redesignPlanMoveDown, null, () => pop('down')),
              ],
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  key: const Key('rd-plan-item-delete'),
                  leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                  title: l10n.redesignPlanDelete,
                  titleColor: ctx.rd.absent,
                  subtitle: l10n.redesignPlanDeleteHint,
                  showChevron: false,
                  onTap: () => pop('delete'),
                ),
              ],
            ),
          ],
    );
    // The plan may have changed meanwhile (draft restored, reload).
    if (!mounted || !_rdStill(loadGen, index, field)) return;
    var current = field;
    if (edit != null) {
      final e = edit!;
      final name = e.name.isEmpty ? field.name : e.name;
      final updated =
          isNote
              ? field.copyWith(name: name)
              : field.copyWith(
                name: name,
                conductor: e.conductor,
                info: e.info,
                time: e.minutes?.toString() ?? field.time,
                needsBeamer: showBeamer ? e.needsBeamer : field.needsBeamer,
              );
      if (!_rdSame(updated, field)) {
        _rdApply([..._fields]..[index] = updated);
        current = updated;
      }
    }
    if (action == null || !_rdStill(loadGen, index, current)) return;
    switch (action) {
      case 'insert':
        await _rdAdd(after: index, group: current.groupId);
      case 'up':
        _rdMove(index, -1);
      case 'down':
        _rdMove(index, 1);
      case 'block':
        await _rdPickBlock(index);
      case 'delete':
        _rdRemove([..._fields]..removeAt(index), current.name);
    }
  }

  /// Tap on a block: bearbeiten, Unterpunkt, Vorlage (Admins), Punkt
  /// danach, Nach oben / unten, auflösen, löschen.
  Future<void> _rdBlockSheet(int index) async {
    final l10n = context.l10n;
    final head = _fields[index];
    final start = PlanUtils.parseTimeToMinutes(_time);
    final children = PlanUtils.childrenOf(_fields, head.id);
    final isAdmin = ref.read(effectiveRoleProvider).isAdmin;
    final exists = (ref.read(planBlockTemplatesProvider).valueOrNull ?? const <PlanBlockTemplate>[]).any(
      (t) => t.name == head.name,
    );
    final loadGen = _loadGen;
    PlanFieldInput? edit;
    final action = await _rdSheet<String>(
      title: head.name,
      subtitle: [
        if (start != null) PlanUtils.groupRange(start, _fields, index),
        l10n.redesignPlanItemCount(children.length),
      ].join(' · '),
      builder:
          (ctx, pop) => [
            RdPlanFieldForm(
              key: const Key('rd-plan-block-form'),
              labels: RdPlanFieldLabels(
                name: l10n.planningName,
                nameHint: l10n.planningName,
                conductor: l10n.planningPerformance,
                conductorHint: l10n.planningPerformanceOptional,
              ),
              initialName: head.name,
              initialConductor: head.conductor,
              initialInfo: head.info,
              withMinutes: false,
              onChanged: (v) => edit = v,
              onSubmitted: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 16),
            RdGroupedList(
              children: [
                if (head.registerPlan != null) ...[
                  _rdSheetRow(
                    Icons.groups_outlined,
                    l10n.redesignPlanRegisterChange,
                    l10n.redesignPlanRegisterChangeHint,
                    () => pop('register'),
                    key: const Key('rd-plan-block-register'),
                  ),
                  _rdSheetRow(
                    Icons.ios_share,
                    l10n.redesignPlanRegisterShare,
                    l10n.redesignPlanRegisterShareHint,
                    () => pop('share'),
                    key: const Key('rd-plan-block-share'),
                  ),
                ] else
                  _rdSheetRow(
                    Icons.subdirectory_arrow_right,
                    l10n.planningAddSubItem,
                    null,
                    () => pop('sub'),
                    key: const Key('rd-plan-block-sub'),
                  ),
                _rdSheetRow(Icons.add, l10n.redesignPlanAfterBlock, null, () => pop('insert')),
                if (isAdmin && children.isNotEmpty)
                  _rdSheetRow(
                    Icons.bookmark_add_outlined,
                    exists ? l10n.planningUpdateTemplate : l10n.planningSaveAsTemplate,
                    null,
                    () => pop('template'),
                  ),
                _rdSheetRow(Icons.call_split, l10n.planningDissolveBlock, null, () => pop('dissolve')),
              ],
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                  title: l10n.redesignPlanDelete,
                  titleColor: ctx.rd.absent,
                  subtitle: l10n.redesignPlanDeleteHint,
                  showChevron: false,
                  onTap: () => pop('delete'),
                ),
              ],
            ),
          ],
    );
    if (!mounted || !_rdStill(loadGen, index, head)) return;
    var current = head;
    if (edit != null) {
      final e = edit!;
      final updated = head.copyWith(name: e.name.isEmpty ? head.name : e.name, conductor: e.conductor, info: e.info);
      if (!_rdSame(updated, head)) {
        _rdApply([for (final f in _fields) f.id == head.id ? updated : f]);
        current = updated;
      }
    }
    if (action == null || !_rdStill(loadGen, index, current)) return;
    switch (action) {
      case 'sub':
        await _rdQuickAdd(group: head.id);
      case 'register':
        await _rdChangeRegister(head.id);
      case 'share':
        await _rdShareRegister(head.id);
      case 'insert':
        await _rdAdd(after: PlanUtils.lastIndexOfGroup(_fields, head.id));
      case 'template':
        await _saveBlockTemplate(head);
      case 'dissolve':
        _rdCollapsed.remove(head.id);
        _rdApply(PlanUtils.dissolveGroup(_fields, head.id));
      case 'delete':
        if (children.isEmpty) {
          _rdRemove(_fields.where((f) => f.id != head.id).toList(), current.name);
          return;
        }
        final choice = await showAppDialog<String>(
          context: context,
          builder:
              (ctx) => AppAlertDialog(
                title: Text(ctx.l10n.planningDeleteBlockConfirm),
                content: Text(ctx.l10n.planningBlockHasItems(current.name, children.length)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'dissolve'),
                    child: Text(ctx.l10n.planningOnlyDissolve),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: ctx.rd.absent, foregroundColor: ctx.rd.onStatus),
                    onPressed: () => Navigator.pop(ctx, 'all'),
                    child: Text(ctx.l10n.planningDeleteAll),
                  ),
                ],
              ),
        );
        if (!mounted || !_rdStill(loadGen, index, current)) return;
        _rdCollapsed.remove(head.id);
        if (choice == 'dissolve') {
          _rdApply(PlanUtils.dissolveGroup(_fields, head.id));
        } else if (choice == 'all') {
          _rdRemove(PlanUtils.deleteGroup(_fields, head.id), current.name);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // "•••": Teilen & Export, the open plan, Registerprobenplan, zurücksetzen
  // ---------------------------------------------------------------------------

  /// "Teilen" at the top: PDF, Telegram and the public link of the open plan.
  Future<void> _rdShare() async {
    final l10n = context.l10n;
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final chatId = planTelegramChatId(ref);
    final hasExports = _fields.isNotEmpty;
    final multi = plans.length > 1;
    final loadGen = _loadGen;
    final action = await _rdSheet<String>(
      title: l10n.redesignPlanShareExport,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                if (hasExports) ...[
                  _rdSheetRow(
                    Icons.picture_as_pdf_outlined,
                    l10n.planningExportPdf,
                    null,
                    () => pop('pdf'),
                    key: const Key('rd-plan-pdf'),
                  ),
                  _rdSheetRow(Icons.content_copy_outlined, l10n.planningExportPdfA5, null, () => pop('pdf2x')),
                  if (multi) _rdSheetRow(Icons.picture_as_pdf, l10n.planningExportPdfAll, null, () => pop('all')),
                  if (chatId != null) ...[
                    _rdSheetRow(Icons.send_outlined, l10n.attendanceTelegramPdf, null, () => pop('telegram')),
                    _rdSheetRow(Icons.send_outlined, l10n.planningFlutterTelegramPdf2x, null, () => pop('telegram2x')),
                    _rdSheetRow(Icons.send_outlined, l10n.attendanceTelegramImage, null, () => pop('telegramImage')),
                  ],
                ],
                _rdSheetRow(
                  Icons.link,
                  l10n.redesignPlanPublicLink,
                  att.shareKey != null ? l10n.redesignPlanPublicLinkShared : l10n.redesignPlanPublicLinkHint,
                  () => pop('link'),
                  key: const Key('rd-plan-link'),
                ),
                if (ref.read(hasBrandingProvider))
                  Consumer(
                    builder: (ctx, cref, _) {
                      final on = cref.watch(includeBrandingProvider);
                      void set(bool v) => cref.read(includeBrandingProvider.notifier).state = v;
                      return RdListRow(
                        leading: const RdRowIcon(Icons.star_outline),
                        title: l10n.planningIncludeBranding,
                        showChevron: false,
                        onTap: () => set(!on),
                        trailing: Switch.adaptive(value: on, onChanged: set),
                      );
                    },
                  ),
              ],
            ),
          ],
    );
    // Another plan or Termin was loaded meanwhile: the sheet was for the old one.
    if (action == null || !mounted || loadGen != _loadGen) return;
    if (action == 'link') {
      await _shareLink();
    } else {
      await _rdExport(action);
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

  /// PDF / Telegram of the open plan (same pages as the classic sheet).
  Future<void> _rdExport(String action) async {
    // Exports use the editor state, so they also work when the write failed.
    await _flushSaves(blockInvalid: false);
    if (!mounted || !_validate(showToast: true)) return;
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

  /// No items: offer templates and the plan of the last Termin of the same
  /// type instead of only an empty card.
  List<Widget> _rdEmpty(PlanAttendance att, List<PlanBlockTemplate> blockTemplates) {
    final l10n = context.l10n;
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final orgTemplates = org?.planningTemplates ?? const <Plan>[];
    final previous = _rdPreviousPlan(att);
    final eventWorks = _rdEventWorks();
    final rows = <Widget>[
      // The Werke of the next Auftritt: what a Probe mostly starts with.
      if (eventWorks.isNotEmpty) _rdEventWorksRow(eventWorks, _rdTakeEventWorks, chevron: true),
      if (previous != null)
        RdListRow(
          key: const Key('rd-plan-copy-last'),
          leading: const RdRowIcon(Icons.copy_all_outlined),
          // Not "letzter Termin": the newest one with an Ablauf can lie ahead.
          title: l10n.rdTextPlanCopyFrom(_rdDate(previous.att)),
          subtitle: l10n.rdTextPlanCopyCount(l10n.redesignPlanItemCount(previous.plan.fields.length)),
          onTap: () => _rdCopyPrevious(previous.att, previous.plan),
        ),
      for (var i = 0; i < orgTemplates.length; i++)
        RdListRow(
          leading: const RdRowIcon(Icons.account_balance_outlined),
          title: orgTemplates[i].title ?? '',
          subtitle: l10n.redesignPlanEmptyTemplate,
          onTap: () => _runAddAction('tpl:$i'),
        ),
      for (final tpl in blockTemplates)
        RdListRow(
          leading: const RdRowIcon(Icons.view_agenda_outlined),
          title: tpl.name,
          subtitle: l10n.redesignPlanBlockTemplateHint(PlanUtils.templateMinutes(tpl)),
          onTap: () => _runAddAction('block:${tpl.id}'),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [RdGroupLabel(l10n.redesignPlanEmptyTitle), RdGroupedList(children: rows)];
  }

  /// Main plan of the newest earlier Termin of the same type with items.
  ({PlanAttendance att, Plan plan})? _rdPreviousPlan(PlanAttendance att) {
    final date = DateTime.tryParse(att.date);
    if (date == null) return null;
    for (final a in _attendances) {
      final d = DateTime.tryParse(a.date);
      if (a.id == att.id || d == null || !d.isBefore(date) || a.typeId != att.typeId) continue;
      final plan = a.plan;
      if (plan != null && plan.fields.any((f) => f.agendaItemId == null && !PlanUtils.isAgendaPlaceholder(f))) {
        return (att: a, plan: plan);
      }
    }
    return null;
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

/// Duration pill at the end of a row ("20 Min"); tap opens the field.
class _RdDurationPill extends StatelessWidget {
  const _RdDurationPill({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: selected ? p.primary : p.soft, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? p.onPrimary : p.softText),
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }
}

/// Inline duration field under a row (concept board 12): typical
/// durations as chips, a number field for anything else, −/+ in steps of
/// five and "bis HH:MM".
class _RdDurationEditor extends StatefulWidget {
  const _RdDurationEditor({super.key, required this.value, required this.start, required this.onChanged});

  /// Stored minutes ("20"; may be empty while typing).
  final String value;

  /// Start of the item (minutes of the day), for "bis HH:MM".
  final int? start;
  final ValueChanged<String> onChanged;

  @override
  State<_RdDurationEditor> createState() => _RdDurationEditorState();
}

class _RdDurationEditorState extends State<_RdDurationEditor> {
  late final TextEditingController _controller = TextEditingController(text: widget.value.trim());
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _RdDurationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value.trim() != _controller.text) _controller.text = widget.value.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _minutes => int.tryParse(widget.value.trim()) ?? 0;

  void _set(int minutes) {
    final m = minutes.clamp(0, 999);
    _controller.text = '$m';
    widget.onChanged('$m');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final m = _minutes;
    final start = widget.start;
    Widget step(IconData icon, String label, int to) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _set(to),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: p.softText)),
        ),
      ),
    );
    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l10n.redesignPlanDuration} · ${l10n.redesignPlanDurationHint}', style: RdType.meta(p, size: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _rdDurationPresets)
                RdChoiceChip(
                  key: ValueKey('rd-plan-preset-$v'),
                  label: '$v',
                  selected: v == m && widget.value.trim().isNotEmpty,
                  onTap: () => _set(v),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              step(Icons.remove, l10n.redesignPlanLess, m % 5 == 0 ? m - 5 : m - m % 5),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('rd-plan-dur-input'),
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: p.surface,
                    suffixText: l10n.redesignPlanMinUnit,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              const SizedBox(width: 8),
              step(Icons.add, l10n.redesignPlanMore5, m + (5 - m % 5)),
            ],
          ),
          if (start != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.redesignPlanUntil(PlanUtils.formatMinutes(start + m)),
              textAlign: TextAlign.center,
              style: RdType.meta(p, size: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of the Beta timeline: a field ([index] in the plan) or the
/// "+ Punkt in „…“" end row of the open block [footer] ([index]: its head).
class _RdSlot {
  const _RdSlot(this.index, {this.footer});

  final int index;
  final String? footer;

  bool get isFooter => footer != null;
}

/// Which part of a block's frame a row draws.
enum _RdPart { none, top, middle, bottom, single }

/// The frame of a block, drawn row by row (see `_rdFramed`).
class _RdBlockFramePainter extends CustomPainter {
  const _RdBlockFramePainter({required this.part, required this.color, required this.width});

  final _RdPart part;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width;
    final h = width / 2;
    final left = h;
    final right = size.width - h;
    final top = h;
    final bottom = size.height - h;
    const r = 12.0;
    const radius = Radius.circular(r);
    switch (part) {
      case _RdPart.none:
        return;
      case _RdPart.single:
        canvas.drawRRect(RRect.fromLTRBR(left, top, right, bottom, radius), paint);
      case _RdPart.top:
        canvas.drawPath(
          Path()
            ..moveTo(left, size.height)
            ..lineTo(left, top + r)
            ..arcToPoint(Offset(left + r, top), radius: radius)
            ..lineTo(right - r, top)
            ..arcToPoint(Offset(right, top + r), radius: radius)
            ..lineTo(right, size.height),
          paint,
        );
      case _RdPart.middle:
        canvas
          ..drawLine(Offset(left, 0), Offset(left, size.height), paint)
          ..drawLine(Offset(right, 0), Offset(right, size.height), paint);
      case _RdPart.bottom:
        canvas.drawPath(
          Path()
            ..moveTo(left, 0)
            ..lineTo(left, bottom - r)
            ..arcToPoint(Offset(left + r, bottom), radius: radius, clockwise: false)
            ..lineTo(right - r, bottom)
            ..arcToPoint(Offset(right, bottom - r), radius: radius, clockwise: false)
            ..lineTo(right, 0),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_RdBlockFramePainter old) => old.part != part || old.color != color || old.width != width;
}

/// Content of the "Hinzufügen" sheet that stays open (see `_rdQuickAdd`):
/// optional block name, what was added so far, the kind (Punkt, Notiz,
/// Werke), the form and one "Hinzufügen".
class _RdQuickAddBody extends StatefulWidget {
  const _RdQuickAddBody({
    required this.newBlock,
    required this.initialKind,
    required this.initialMinutes,
    required this.withWorks,
    required this.onBlockName,
    required this.onAdd,
    required this.onWorks,
  });

  final bool newBlock;
  final String initialKind;
  final int initialMinutes;
  final bool withWorks;
  final ValueChanged<String> onBlockName;

  /// The names of what was added; null when nothing was.
  final Future<List<String>?> Function(String kind, PlanFieldInput input) onAdd;
  final Future<List<String>?> Function() onWorks;

  @override
  State<_RdQuickAddBody> createState() => _RdQuickAddBodyState();
}

class _RdQuickAddBodyState extends State<_RdQuickAddBody> {
  late String _kind = widget.initialKind;
  late int _minutes = widget.initialMinutes;
  final _name = TextEditingController();
  final _added = <String>[];
  PlanFieldInput? _input;
  String? _error;
  int _gen = 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _nameMissing() {
    if (!widget.newBlock || _name.text.trim().isNotEmpty) return false;
    setState(() => _error = context.l10n.planningEnterNamePlease);
    return true;
  }

  Future<void> _submit() async {
    if (_nameMissing()) return;
    final input = _input;
    if (input == null || input.name.isEmpty) {
      setState(
        () => _error = _kind == 'note' ? context.l10n.plansEnterNotePlease : context.l10n.planningEnterNamePlease,
      );
      return;
    }
    await _run(() => widget.onAdd(_kind, input), minutes: input.minutes);
  }

  Future<void> _run(Future<List<String>?> Function() add, {int? minutes}) async {
    if (_busy || _nameMissing()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final labels = await add();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (labels == null) return;
      _added.addAll(labels);
      // The next Punkt starts with the same length.
      if (minutes != null) _minutes = minutes;
      _input = null;
      _gen++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final note = _kind == 'note';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.newBlock) ...[
          RdGroupedList(
            children: [
              RdFieldRow(
                label: l10n.redesignPlanBlockName,
                child: TextField(
                  key: const Key('rd-plan-quick-block-name'),
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 17, color: p.text),
                  decoration: rdInputDecoration(p, l10n.planningBlockNamePlaceholder),
                  onChanged: widget.onBlockName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPlanBlockItems),
        ] else if (_added.isNotEmpty)
          RdGroupLabel(l10n.redesignPlanQuickAddAdded),
        if (_added.isNotEmpty) ...[
          RdGroupedList(
            children: [
              for (final (i, label) in _added.indexed)
                RdListRow(
                  key: ValueKey('rd-plan-quick-added-$i'),
                  leading: RdRowIcon(Icons.check, color: p.present, background: p.presentSoft),
                  title: label,
                  showChevron: false,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RdChoiceChip(
              key: const Key('rd-plan-quick-kind-field'),
              label: l10n.redesignPlanAddItem,
              selected: !note,
              onTap: () => setState(() {
                if (_kind == 'field') return;
                // A new form: the old entry is gone with it.
                _kind = 'field';
                _input = null;
                _error = null;
              }),
            ),
            RdChoiceChip(
              key: const Key('rd-plan-quick-kind-note'),
              label: l10n.redesignPlanAddNote,
              selected: note,
              onTap: () => setState(() {
                if (_kind == 'note') return;
                _kind = 'note';
                _input = null;
                _error = null;
              }),
            ),
            if (widget.withWorks)
              RdChoiceChip(
                key: const Key('rd-plan-quick-works'),
                label: l10n.redesignPlanAddWorks,
                icon: Icons.add,
                selected: false,
                onTap: () => _run(widget.onWorks),
              ),
          ],
        ),
        const SizedBox(height: 12),
        RdPlanFieldForm(
          key: ValueKey('rd-plan-quick-form-$_kind-$_gen'),
          labels:
              note
                  ? RdPlanFieldLabels(name: l10n.planningNote, nameHint: l10n.planningEnterNote)
                  : RdPlanFieldLabels(infoHint: l10n.planningInfoOptionalEllipsis),
          initialMinutes: note ? null : _minutes,
          withConductor: !note,
          withInfo: !note,
          withMinutes: !note,
          // A new block starts in its name; afterwards the cursor waits in
          // the next item's name.
          autofocus: !widget.newBlock || _gen > 0,
          singleLineName: true,
          onChanged: (v) => _input = v,
          onSubmitted: _submit,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 14, color: p.absent)),
        ],
        const SizedBox(height: 16),
        RdPrimaryButton(
          key: const Key('rd-plan-quick-add'),
          icon: Icons.add,
          label: l10n.redesignPlanQuickAddButton,
          loading: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: 8),
        Text(l10n.redesignPlanQuickAddHint, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
      ],
    );
  }
}
