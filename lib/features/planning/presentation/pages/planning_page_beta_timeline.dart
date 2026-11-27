part of 'planning_page.dart';

/// Timeline rows, block framing, drag-and-drop reorder, and undo helpers
/// for the Beta Ablauf editor.
extension _PlanningBetaTimeline on _PlanningPageState {
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


  void _rdRemove(List<PlanField> next, String name) =>
      _rdApplyWithUndo(next, context.l10n.redesignPlanRemoved(name));

  /// Applies [next] and offers "Rückgängig" next to [message].
  void _rdApplyWithUndo(List<PlanField> next, String message) {
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
          content: Text(message),
          duration: const Duration(seconds: 5),
          persist: false,
          // Not back to an empty Ablauf: that one cannot be stored.
          action: before.isEmpty
              ? null
              : SnackBarAction(
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
}
