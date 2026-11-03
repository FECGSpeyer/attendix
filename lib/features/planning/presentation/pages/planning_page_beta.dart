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
          Expanded(child: RdBackLink(label: l10n.redesignPlanBack, onTap: () => Navigator.of(context).maybePop())),
          if (att != null) ...[
            RdCircleButton(icon: Icons.link, label: l10n.planningShareLink, onPressed: _shareLink),
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

    if (!_loaded || (att == null && widget.attendanceId != null && !_requestedNotFound)) {
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
      // Termin with ‹ › (Ionic "Vorheriger" / "Nächster"); tap: choose.
      Row(
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
                  child: Text(
                    _rdAttLabel(att),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RdType.meta(p, size: 15),
                  ),
                ),
              ),
            ),
          ),
          _rdArrow(Icons.chevron_right, l10n.redesignPlanNext, () => _navigate(1)),
        ],
      ),
      _rdStatus(),
      const SizedBox(height: 12),
      // Plans of the Termin + "+ Plan".
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (plans.length > 1)
            for (var i = 0; i < plans.length; i++)
              RdChoiceChip(
                key: ValueKey('rd-plan-chip-$i'),
                label: PlanUtils.planLabel(att, i, plans),
                selected: i == _planIndex,
                onTap: () => _selectPlan(i),
              ),
          RdChoiceChip(
            key: const Key('rd-plan-add-plan'),
            label: '+ ${l10n.redesignPlanAddPlan}',
            selected: false,
            onTap: _addPlan,
          ),
        ],
      ),
      const SizedBox(height: 12),
      _rdSummary(start, total),
      const SizedBox(height: 12),
      if (_fields.isEmpty) ..._rdEmpty(att, blockTemplates) else _rdTimeline(start, showBeamer: showBeamer),
      const SizedBox(height: 12),
      RdPrimaryButton(
        key: const Key('rd-plan-add'),
        icon: Icons.add,
        label: l10n.redesignPlanAdd,
        onPressed: () => _rdAdd(),
      ),
      if (_fields.isNotEmpty) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l10n.redesignPlanHint, style: RdType.meta(p, size: 13)),
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
          RdFieldRow(
            label: l10n.redesignPlanHeading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Focus(
                  onFocusChange: (focused) {
                    if (!focused) _onTitleFocusLost();
                  },
                  child: TextField(
                    key: const Key('rd-plan-heading'),
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(fontSize: 17, color: p.text),
                    decoration: rdInputDecoration(p, l10n.planningDefaultTitle),
                  ),
                ),
                const SizedBox(height: 2),
                Text(l10n.redesignPlanTitleHint, style: RdType.meta(p, size: 12)),
              ],
            ),
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
    if (!_hasPendingChanges) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check, size: 16, color: p.present),
          const SizedBox(width: 4),
          Text(l10n.redesignPlanSaved, style: TextStyle(fontSize: 13, color: p.present)),
        ],
      );
    } else if (!_hasUserEdits) {
      return const SizedBox(height: 18);
    } else if (!_validate()) {
      content = Text(
        l10n.redesignPlanInvalid,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: p.late),
      );
    } else {
      content = Text(l10n.redesignPlanSaving, textAlign: TextAlign.center, style: RdType.meta(p, size: 13));
    }
    return Semantics(liveRegion: true, child: SizedBox(width: double.infinity, child: content));
  }

  /// Beginn ✎ · Gesamtdauer · Ende.
  Widget _rdSummary(int? start, int total) {
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
      child: Row(
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

  /// Indexes (in [_fields]) of the visible rows: Unterpunkte of collapsed
  /// blocks are hidden.
  List<int> _rdVisible() => [
    for (var i = 0; i < _fields.length; i++)
      if (_fields[i].groupId == null || !_rdCollapsed.contains(_fields[i].groupId)) i,
  ];

  Widget _rdTimeline(int? start, {required bool showBeamer}) {
    final p = context.rd;
    final visible = _rdVisible();
    final seen = <String, int>{};
    String rowKey(String id) {
      final n = (seen[id] ?? 0) + 1;
      seen[id] = n;
      return n > 1 ? '$id#$n' : id;
    }

    final numbers = PlanUtils.topNumbers(_fields);
    final keys = [for (final i in visible) rowKey(_fields[i].id)];
    return DecoratedBox(
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
          itemCount: visible.length,
          onReorderItem: (o, n) => _rdReorder(visible, o, n),
          proxyDecorator: (child, _, __) => Material(color: p.surface, elevation: 6, child: child),
          itemBuilder:
              (context, row) => KeyedSubtree(
                key: ValueKey(keys[row]),
                child: _rdRow(
                  visible[row],
                  row,
                  start,
                  numbers,
                  last: row == visible.length - 1,
                  showBeamer: showBeamer,
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
    required bool last,
    required bool showBeamer,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final field = _fields[index];
    final isHead = PlanUtils.isGroupHead(field);
    final isNote = PlanUtils.isNote(field);
    final isAgenda = PlanUtils.isAgendaPlaceholder(field);
    final isChild = field.groupId != null;
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
        if (start != null) PlanUtils.groupRange(start, _fields, index),
        if ((field.conductor ?? '').isNotEmpty) field.conductor!,
        l10n.redesignPlanItemCount(count),
        if (collapsed) l10n.redesignPlanCollapsed,
      ].join(' · ');
    } else if (!isNote && !isAgenda && (field.conductor ?? '').isNotEmpty) {
      metaLine = field.conductor;
    }
    if (metaLine != null) sub.add(Text(metaLine, style: RdType.meta(p, size: 13)));
    if (!isNote && !isAgenda && (field.info ?? '').isNotEmpty) {
      sub.add(Text(field.info!, style: RdType.meta(p, size: 13).copyWith(fontStyle: FontStyle.italic)));
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
      trailing = _RdDurationPill(label: l10n.redesignPlanMinutes(minutes), selected: false);
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
        if (isHead)
          IconButton(
            tooltip: collapsed ? l10n.redesignPlanExpand : l10n.redesignPlanCollapse,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(collapsed ? Icons.chevron_right : Icons.expand_more, color: p.link),
            onPressed:
                () => _rdSet(() {
                  if (!_rdCollapsed.remove(field.id)) _rdCollapsed.add(field.id);
                }),
          )
        else
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

    Widget content = Padding(padding: EdgeInsets.only(left: isHead ? 2 : (isChild ? 30 : 14)), child: rowBody);
    if (isChild) {
      content = Stack(
        children: [content, Positioned(left: 20, top: 0, bottom: 0, child: Container(width: 2, color: p.line))],
      );
    }
    return Material(
      color: isHead ? p.soft : p.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('rd-plan-row-$index'),
            onTap: () => isHead ? _rdBlockSheet(index) : _rdItemSheet(index),
            child: content,
          ),
          if (open)
            _RdDurationEditor(
              key: ValueKey('rd-plan-dur-editor-$index'),
              value: field.time,
              start: at,
              onChanged: (v) => _rdSetMinutes(index, v),
            ),
          if (!last) Divider(height: 1, thickness: 1, color: p.line),
        ],
      ),
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

  /// [newIndex] as `onReorderItem` reports it (already without the moved row).
  void _rdReorder(List<int> visible, int oldIndex, int newIndex) {
    final reordered = [...visible]..removeAt(oldIndex);
    final from = visible[oldIndex];
    reordered.insert(newIndex, from);
    // Target: right before the next visible row (positions without the
    // moved field, see [PlanUtils.moveField]).
    final next = newIndex + 1 < reordered.length ? reordered[newIndex + 1] : null;
    final to = next == null ? _fields.length - 1 : (next > from ? next - 1 : next);
    final result = PlanUtils.moveField(_fields, from, to);
    _rdOpenBlocksOf(result);
    _rdApply(result);
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
      result = PlanUtils.moveField(_fields, index, to);
    }
    _rdOpenBlocksOf(result);
    _rdApply(result);
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
    final before = [..._fields];
    // The plan changed while the sheet was open: add at the end.
    if (after != null && (loadGen != _loadGen || after >= before.length || !_rdSame(before[after], anchor!))) {
      after = null;
    }
    if (group != null && !before.any((f) => f.id == group)) group = null;
    await _runAddAction(action);
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
                if (!isGeneral)
                  _rdSheetRow(
                    Icons.library_music_outlined,
                    l10n.redesignPlanAddCurrent,
                    l10n.redesignPlanAddCurrentHint,
                    () => pop('current'),
                  ),
                if (!isGeneral && _songs.isNotEmpty)
                  _rdSheetRow(Icons.music_note_outlined, l10n.redesignPlanAddSong, null, () => pop('song')),
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
    final canIndent = PlanUtils.canIndent(_fields, index);
    final isAgenda = PlanUtils.isAgendaPlaceholder(field);
    final loadGen = _loadGen;
    final action = await _rdSheet<String>(
      title: isAgenda ? l10n.planningAgendaInsertPos : field.name,
      subtitle: meta.isEmpty ? null : meta,
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                if (!isAgenda) ...[
                  _rdSheetRow(
                    Icons.edit_outlined,
                    l10n.redesignPlanEdit,
                    isNote ? null : l10n.redesignPlanEditHint,
                    () => pop('edit'),
                    key: const Key('rd-plan-item-edit'),
                  ),
                  _rdSheetRow(Icons.add, l10n.redesignPlanInsertAfter, null, () => pop('insert')),
                ],
                if (index > 0) _rdSheetRow(Icons.arrow_upward, l10n.redesignPlanMoveUp, null, () => pop('up')),
                if (index < _fields.length - 1)
                  _rdSheetRow(Icons.arrow_downward, l10n.redesignPlanMoveDown, null, () => pop('down')),
                if (canIndent)
                  _rdSheetRow(
                    field.groupId == null ? Icons.format_indent_increase : Icons.format_indent_decrease,
                    field.groupId == null ? l10n.redesignPlanJoinBlock : l10n.redesignPlanLeaveBlock,
                    null,
                    () => pop('indent'),
                  ),
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
    if (action == null || !mounted || !_rdStill(loadGen, index, field)) return;
    switch (action) {
      case 'edit':
        await _rdEditField(index);
      case 'insert':
        await _rdAdd(after: index, group: field.groupId);
      case 'up':
        _rdMove(index, -1);
      case 'down':
        _rdMove(index, 1);
      case 'indent':
        final result = PlanUtils.toggleIndent(_fields, index);
        final joined = result[index].groupId;
        if (joined != null) _rdCollapsed.remove(joined);
        _rdApply(result);
      case 'delete':
        _rdRemove([..._fields]..removeAt(index), field.name);
    }
  }

  /// Classic edit dialog of an item (name, conductor, info, minutes, Beamer).
  Future<void> _rdEditField(int index) async {
    final field = _fields[index];
    final isNote = PlanUtils.isNote(field);
    final org = ref.read(currentOrganisationProvider).valueOrNull;
    final showBeamer = PlanBeamer.active(org, _isOrgPlan) && !isNote;
    final loadGen = _loadGen;
    final result = await showPlanFieldDialog(
      context,
      title: context.l10n.planningEditField,
      nameLabel: isNote ? context.l10n.planningNote : context.l10n.planningItem,
      nameHint: isNote ? context.l10n.planningEnterNote : context.l10n.planningEnterItem,
      infoHint: context.l10n.planningInfoOptionalEllipsis,
      confirmText: context.l10n.planningUpdate,
      initialName: field.name,
      initialConductor: field.conductor,
      initialInfo: field.info,
      initialMinutes: int.tryParse(field.time) ?? 20,
      withConductor: !isNote,
      withInfo: !isNote,
      withMinutes: !isNote,
      beamer:
          showBeamer
              ? PlanFieldBeamerOptions(manual: field.needsBeamer, songId: field.songId, file: _beamerFileOf(field))
              : null,
    );
    if (result == null || !mounted || !_rdStill(loadGen, index, field)) return;
    final updated = [..._fields];
    updated[index] =
        isNote
            ? field.copyWith(name: result.name)
            : field.copyWith(
              name: result.name,
              conductor: result.conductor,
              info: result.info,
              time: result.minutes?.toString() ?? field.time,
              needsBeamer: showBeamer ? result.needsBeamer : field.needsBeamer,
            );
    _rdApply(updated);
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
    final end = PlanUtils.lastIndexOfGroup(_fields, head.id);
    final loadGen = _loadGen;
    final action = await _rdSheet<String>(
      title: head.name,
      subtitle: [
        if (start != null) PlanUtils.groupRange(start, _fields, index),
        l10n.redesignPlanItemCount(children.length),
      ].join(' · '),
      builder:
          (ctx, pop) => [
            RdGroupedList(
              children: [
                _rdSheetRow(Icons.edit_outlined, l10n.planningEditBlock, null, () => pop('edit')),
                _rdSheetRow(
                  Icons.subdirectory_arrow_right,
                  l10n.planningAddSubItem,
                  null,
                  () => pop('sub'),
                  key: const Key('rd-plan-block-sub'),
                ),
                _rdSheetRow(Icons.add, l10n.redesignPlanAfterBlock, null, () => pop('insert')),
                if (index > 0) _rdSheetRow(Icons.arrow_upward, l10n.redesignPlanMoveUp, null, () => pop('up')),
                if (end < _fields.length - 1)
                  _rdSheetRow(Icons.arrow_downward, l10n.redesignPlanMoveDown, null, () => pop('down')),
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
    if (action == null || !mounted || !_rdStill(loadGen, index, head)) return;
    switch (action) {
      case 'edit':
        final r = await showPlanFieldDialog(
          context,
          title: context.l10n.planningEditBlock,
          nameLabel: context.l10n.planningName,
          nameHint: context.l10n.planningName,
          conductorLabel: context.l10n.planningPerformance,
          conductorHint: context.l10n.planningPerformanceOptional,
          confirmText: context.l10n.commonSave,
          emptyNameMessage: context.l10n.planningEnterNamePlease,
          initialName: head.name,
          initialConductor: head.conductor,
          initialInfo: head.info,
          withMinutes: false,
        );
        if (r == null || !mounted || !_rdStill(loadGen, index, head)) return;
        _rdApply([
          for (final f in _fields) f.id == head.id ? f.copyWith(name: r.name, conductor: r.conductor, info: r.info) : f,
        ]);
      case 'sub':
        final r = await showPlanFieldDialog(
          context,
          title: context.l10n.planningAddSubItem,
          subtitle: head.name,
          nameHint: context.l10n.planningSubItemPlaceholder,
          infoHint: context.l10n.planningSubItemInfoPlaceholder,
          initialMinutes: 5,
        );
        if (r == null || !mounted || !_rdStill(loadGen, index, head)) return;
        _rdCollapsed.remove(head.id);
        _rdApply(
          PlanUtils.addSubItem(
            _fields,
            head.id,
            PlanField(
              id: 'fld-${PlanUtils.uuid()}',
              name: r.name,
              conductor: r.conductor,
              info: r.info,
              time: '${r.minutes ?? 5}',
            ),
          ),
        );
      case 'insert':
        await _rdAdd(after: PlanUtils.lastIndexOfGroup(_fields, head.id));
      case 'up':
        _rdMove(index, -1);
      case 'down':
        _rdMove(index, 1);
      case 'template':
        await _saveBlockTemplate(head);
      case 'dissolve':
        _rdCollapsed.remove(head.id);
        _rdApply(PlanUtils.dissolveGroup(_fields, head.id));
      case 'delete':
        if (children.isEmpty) {
          _rdRemove(_fields.where((f) => f.id != head.id).toList(), head.name);
          return;
        }
        final choice = await showAppDialog<String>(
          context: context,
          builder:
              (ctx) => AppAlertDialog(
                title: Text(ctx.l10n.planningDeleteBlockConfirm),
                content: Text(ctx.l10n.planningBlockHasItems(head.name, children.length)),
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
        if (!mounted || !_rdStill(loadGen, index, head)) return;
        _rdCollapsed.remove(head.id);
        if (choice == 'dissolve') {
          _rdApply(PlanUtils.dissolveGroup(_fields, head.id));
        } else if (choice == 'all') {
          _rdRemove(PlanUtils.deleteGroup(_fields, head.id), head.name);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // "•••": Teilen & Export, the open plan, Registerprobenplan, zurücksetzen
  // ---------------------------------------------------------------------------

  Future<void> _rdMore() async {
    final l10n = context.l10n;
    final att = _att;
    if (att == null) return;
    final plans = PlanUtils.allPlans(att);
    final tenant = ref.read(currentTenantProvider);
    final showSectional = tenant?.type == 'choir' || tenant?.type == 'orchestra';
    final chatId = planTelegramChatId(ref);
    final hasExports = _fields.isNotEmpty;
    final multi = plans.length > 1;
    final planName = multi ? PlanUtils.planLabel(att, _planIndex, plans) : '';
    final loadGen = _loadGen;
    final action = await _rdSheet<String>(
      title: l10n.redesignPlanTitle,
      builder:
          (ctx, pop) => [
            RdGroupLabel(l10n.redesignPlanShareExport),
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
                if (showSectional)
                  _rdSheetRow(Icons.groups_outlined, l10n.planningCreateSectionalPlan, null, () => pop('sectional')),
                _rdSheetRow(Icons.restart_alt, l10n.planningResetPlan, null, () => pop('reset')),
              ],
            ),
          ],
    );
    // Another plan or Termin was loaded meanwhile: the sheet was for the old one.
    if (action == null || !mounted || loadGen != _loadGen) return;
    switch (action) {
      case 'link':
        await _shareLink();
      case 'rename' || 'day' || 'left' || 'right' || 'delete':
        await _showPlanOptions(preset: action);
      case 'sectional':
        await showRegisterPlanSheet(context, attendanceDate: DateTime.tryParse(_att?.date ?? ''));
      case 'reset':
        await _resetPlan();
      default:
        await _rdExport(action);
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
    final rows = <Widget>[
      if (previous != null)
        RdListRow(
          key: const Key('rd-plan-copy-last'),
          leading: const RdRowIcon(Icons.copy_all_outlined),
          title: l10n.redesignPlanEmptyCopy,
          subtitle: l10n.redesignPlanEmptyCopyHint(
            _rdDate(previous.att),
            l10n.redesignPlanItemCount(previous.plan.fields.length),
          ),
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
    required List<Widget> Function(BuildContext ctx, void Function(T value) pop) builder,
  }) => showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (ctx) {
      final p = ctx.rd;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(title, style: RdType.cardTitle(p))),
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
