part of 'planning_page.dart';

/// Drag-and-drop reordering, keyboard/accessibility moves, and undo helpers
/// for the Ablauf timeline.
extension _PlanningTimelineBlocks on _PlanningPageState {
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
