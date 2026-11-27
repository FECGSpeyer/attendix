part of 'planning_page.dart';

/// Timeline rows and block framing for the Ablauf editor.
extension _PlanningTimeline on _PlanningPageState {
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
    // "Ohne Tenor" stands at the Werke of the Termin (Überblick), not here.
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
              onDone: () => _rdSet(() => _rdDurationIndex = null),
            ),
          if (divider) Divider(height: 1, thickness: 1, color: p.line),
        ],
      ),
    );
  }
}
