part of 'plan_fields_editor.dart';

/// REDESIGN (Termin-Werkzeuge T2): [PlanFieldsEditor] in the Beta look, used
/// by the Ad-hoc-Planung, shared edit links and the planning templates.
/// Rows like the Termin's Ablauf-Editor (time, name, duration pill, drag
/// handle); a tap opens one sheet with the fields inline (saved when the
/// sheet closes) and the row actions. Same data, same [_emit].
extension _PlanFieldsEditorBeta on _PlanFieldsEditorState {
  Widget _rdBuild(BuildContext context) {
    final p = context.rd;
    if (_fields.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(widget.emptyText ?? context.l10n.planningFlutterNoItems, style: RdType.meta(p, size: 15)),
        ),
      );
    }
    final rows = _buildRows();
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: rows.length,
      onReorder: (o, n) => _onReorder(rows, o, n),
      proxyDecorator: (child, _, _) => Material(color: p.surface, elevation: 4, child: child),
      itemBuilder: (context, i) {
        final row = rows[i];
        final divider = i < rows.length - 1;
        if (row.addFor != null) {
          return _RdRowFrame(
            key: ValueKey(row.key),
            indent: true,
            divider: divider,
            onTap: () => _addSubItem(row.addFor!),
            child: Row(
              children: [
                Icon(Icons.add, color: p.link, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.planningAddSubItem, style: TextStyle(color: p.link, fontSize: 15)),
              ],
            ),
          );
        }
        return KeyedSubtree(key: ValueKey(row.key), child: _rdFieldRow(row.field!, row.index, i, divider));
      },
    );
  }

  Widget _rdFieldRow(PlanField field, int index, int rowIndex, bool divider) {
    final p = context.rd;
    final l10n = context.l10n;
    final isHead = PlanUtils.isGroupHead(field);
    final isNote = PlanUtils.isNote(field);
    final isChild = field.groupId != null;
    final isAgenda = PlanUtils.isAgendaPlaceholder(field);
    final handle = ReorderableDragStartListener(
      index: rowIndex,
      child: Semantics(
        label: l10n.redesignPlanDrag,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Icon(Icons.drag_indicator, color: p.text2),
        ),
      ),
    );
    if (isAgenda) {
      return _RdRowFrame(
        divider: divider,
        onTap: widget.onAddTopics,
        child: Row(
          children: [
            Icon(Icons.commit, color: p.text2, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.templateMode ? l10n.typeSettingsAgenda : l10n.planningAgendaInsertPos,
                style: RdType.meta(p, size: 15),
              ),
            ),
            if (widget.onAddTopics != null) Text(l10n.attendanceAddTopics, style: TextStyle(color: p.link)),
            handle,
          ],
        ),
      );
    }

    final sub = <String>[];
    if (isHead) {
      final start = _startMinutes;
      if (start != null) sub.add(PlanUtils.groupRange(start, _fields, index));
    }
    if (!isNote && (field.conductor ?? '').isNotEmpty) sub.add(field.conductor!);
    final warning = widget.fieldWarning?.call(field);
    final beamerFileOf = widget.beamerFileOf;
    final beamerMissing = beamerFileOf != null && PlanBeamer.needsBeamer(field) && beamerFileOf(field) == null;
    final minutes = PlanUtils.displayMinutes(field, _fields);
    final time = !isHead && !isNote && widget.showTimes ? _timeAt(index) : '';

    return _RdRowFrame(
      indent: isChild,
      divider: divider,
      background: isNote ? p.bg : null,
      onTap: () => isHead ? _rdGroupSheet(field) : _rdFieldSheet(index),
      child: Row(
        children: [
          if (isHead)
            IconButton(
              tooltip: _collapsed.contains(field.id) ? l10n.planningExpandBlock : l10n.planningCollapseBlock,
              color: p.link,
              icon: Icon(_collapsed.contains(field.id) ? Icons.chevron_right : Icons.expand_more),
              onPressed: () => _rdToggleCollapsed(field.id),
            )
          else if (widget.showTimes)
            SizedBox(
              width: 52,
              child: Text(time, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text2)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PlanUtils.fieldDisplayName(field, PlanUtils.topNumbers(_fields)),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isHead ? FontWeight.w700 : FontWeight.w500,
                    fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
                    color: isNote ? p.text2 : p.text,
                  ),
                ),
                if (sub.isNotEmpty) Text(sub.join(' · '), style: RdType.meta(p, size: 14)),
                if (!isNote && (field.info ?? '').isNotEmpty)
                  Text(field.info!, style: RdType.meta(p, size: 14).copyWith(fontStyle: FontStyle.italic)),
                if (warning != null && warning.isNotEmpty)
                  Text(warning, style: TextStyle(fontSize: 14, color: p.absent)),
                if (beamerMissing) Text(l10n.planningBeamerMissing, style: TextStyle(fontSize: 14, color: p.late)),
              ],
            ),
          ),
          if (!isNote)
            Padding(padding: const EdgeInsets.only(left: 8), child: RdPill(l10n.redesignPlanMinutes(minutes))),
          handle,
        ],
      ),
    );
  }

  void _rdToggleCollapsed(String id) {
    _update(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
  }

  /// One sheet per row: fields inline, then move / indent / delete.
  Future<void> _rdFieldSheet(int index) async {
    final l10n = context.l10n;
    final opened = _fields;
    final field = opened[index];
    final isNote = PlanUtils.isNote(field);
    final beamerFileOf = widget.beamerFileOf;
    final showBeamer = beamerFileOf != null && !isNote;
    final canIndent = !widget.templateMode && PlanUtils.canIndent(_fields, index);
    final start = _startMinutes;
    final at = start == null || isNote ? null : PlanUtils.startMinutesAt(start, _fields, index);
    PlanFieldInput? edit;
    final action = await showRdPlanSheet<String>(
      context,
      title: field.name.isEmpty ? l10n.planningEditField : field.name,
      subtitle:
          at == null
              ? null
              : '${PlanUtils.formatMinutes(at)}–${PlanUtils.formatMinutes(at + PlanUtils.minutesOf(field))}',
      builder:
          (ctx, pop) => [
            RdPlanFieldForm(
              labels: RdPlanFieldLabels(
                name: isNote ? l10n.planningNote : l10n.planningItem,
                nameHint: isNote ? l10n.planningEnterNote : l10n.planningEnterItem,
                infoHint: l10n.planningInfoOptionalEllipsis,
              ),
              initialName: field.name,
              initialConductor: field.conductor,
              initialInfo: field.info,
              initialMinutes: int.tryParse(field.time),
              withConductor: !isNote,
              withInfo: !isNote,
              withMinutes: !isNote,
              beamer:
                  showBeamer
                      ? PlanFieldBeamerOptions(
                        manual: field.needsBeamer,
                        songId: field.songId,
                        file: beamerFileOf(field),
                      )
                      : null,
              onChanged: (v) => edit = v,
              onSubmitted: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 16),
            RdGroupedList(
              children: [
                if (index > 0)
                  RdListRow(
                    leading: const RdRowIcon(Icons.arrow_upward),
                    title: l10n.redesignPlanMoveUp,
                    showChevron: false,
                    onTap: () => pop('up'),
                  ),
                if (index < _fields.length - 1)
                  RdListRow(
                    leading: const RdRowIcon(Icons.arrow_downward),
                    title: l10n.redesignPlanMoveDown,
                    showChevron: false,
                    onTap: () => pop('down'),
                  ),
                if (canIndent)
                  RdListRow(
                    leading: RdRowIcon(
                      field.groupId == null ? Icons.format_indent_increase : Icons.format_indent_decrease,
                    ),
                    title: field.groupId == null ? l10n.redesignPlanJoinBlock : l10n.redesignPlanLeaveBlock,
                    showChevron: false,
                    onTap: () => pop('indent'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                  title: l10n.redesignPlanDelete,
                  titleColor: ctx.rd.absent,
                  showChevron: false,
                  onTap: () => pop('delete'),
                ),
              ],
            ),
          ],
    );
    if (!mounted) return;
    // The list may have changed (Realtime) while the sheet was open.
    var i = PlanUtils.indexOfField(_fields, field, openedIn: opened);
    if (i == -1) return;
    var fields = [..._fields];
    final e = edit;
    if (e != null) {
      final base = fields[i];
      final name = e.name.isEmpty ? base.name : e.name;
      fields[i] =
          isNote
              ? base.copyWith(name: name)
              : base.copyWith(
                name: name,
                conductor: e.conductor,
                info: e.info,
                time: e.minutes?.toString() ?? base.time,
                needsBeamer: showBeamer ? e.needsBeamer : base.needsBeamer,
              );
    }
    switch (action) {
      case 'up':
      case 'down':
        final to = action == 'up' ? i - 1 : i + 1;
        if (to >= 0 && to < fields.length) {
          final tmp = fields[i];
          fields[i] = fields[to];
          fields[to] = tmp;
          // A row keeps its block only when its new neighbour belongs to it.
          fields = PlanUtils.normalizeGroups(fields);
        }
      case 'indent':
        fields = PlanUtils.toggleIndent(fields, i);
        final joined = fields[i].groupId;
        if (joined != null) _collapsed.remove(joined);
      case 'delete':
        fields.removeAt(i);
    }
    if (e != null || action != null) _emit(fields);
  }

  /// Block head: name / Ausführung inline, then Unterpunkt, Vorlage,
  /// auflösen, löschen.
  Future<void> _rdGroupSheet(PlanField head) async {
    final l10n = context.l10n;
    final children = PlanUtils.childrenOf(_fields, head.id);
    final minutes = PlanUtils.groupDuration(_fields, head.id);
    final exists = widget.blockTemplateNames.contains(head.name);
    PlanFieldInput? edit;
    final action = await showRdPlanSheet<String>(
      context,
      title: head.name,
      subtitle: l10n.planningBlockSubHeader(children.length, minutes),
      builder:
          (ctx, pop) => [
            RdPlanFieldForm(
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
                RdListRow(
                  leading: const RdRowIcon(Icons.subdirectory_arrow_right),
                  title: l10n.planningAddSubItem,
                  showChevron: false,
                  onTap: () => pop('add'),
                ),
                if (widget.onSaveBlockTemplate != null && children.isNotEmpty)
                  RdListRow(
                    leading: const RdRowIcon(Icons.bookmark_add_outlined),
                    title: exists ? l10n.planningUpdateTemplate : l10n.planningSaveAsTemplate,
                    showChevron: false,
                    onTap: () => pop('template'),
                  ),
                RdListRow(
                  leading: const RdRowIcon(Icons.call_split),
                  title: l10n.planningDissolveBlock,
                  showChevron: false,
                  onTap: () => pop('dissolve'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RdGroupedList(
              children: [
                RdListRow(
                  leading: RdRowIcon(Icons.delete_outline, color: ctx.rd.absent, background: ctx.rd.absentSoft),
                  title: l10n.planningDeleteBlockWithItems,
                  titleColor: ctx.rd.absent,
                  showChevron: false,
                  onTap: () => pop('delete'),
                ),
              ],
            ),
          ],
    );
    if (!mounted || !_fields.any((f) => f.id == head.id)) return;
    var current = head;
    var fields = _fields;
    final e = edit;
    if (e != null) {
      current = head.copyWith(name: e.name.isEmpty ? head.name : e.name, conductor: e.conductor, info: e.info);
      fields = [for (final f in _fields) f.id == head.id ? current : f];
    }
    switch (action) {
      case 'dissolve':
        _collapsed.remove(head.id);
        _emit(PlanUtils.dissolveGroup(fields, head.id));
        return;
      case 'delete' when PlanUtils.childrenOf(fields, head.id).isEmpty:
        _emit(fields.where((f) => f.id != head.id).toList());
        return;
    }
    // The rename is stored first; the dialogs below read the new list.
    if (e != null) _emit(fields);
    switch (action) {
      case 'add':
        await _addSubItem(current);
      case 'template':
        await widget.onSaveBlockTemplate?.call(current);
      case 'delete':
        await _confirmDeleteGroup(current);
    }
  }
}

/// Row frame of the Beta list: white surface, hairline, block indent line.
class _RdRowFrame extends StatelessWidget {
  const _RdRowFrame({
    super.key,
    required this.child,
    this.onTap,
    this.indent = false,
    this.divider = true,
    this.background,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool indent;
  final bool divider;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    Widget row = Material(
      color: background ?? p.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.fromLTRB(indent ? 30 : 12, 4, 4, 4),
          decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: p.line, width: 0.5)) : null),
          child: child,
        ),
      ),
    );
    if (indent) {
      row = Stack(children: [row, Positioned(left: 16, top: 0, bottom: 0, child: Container(width: 2, color: p.track))]);
    }
    return row;
  }
}
