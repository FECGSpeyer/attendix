import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import 'plan_field_dialogs.dart';

/// A row of the editor: a field, or the "Unterpunkt hinzufügen" row closing an open block.
class _EditorRow {
  _EditorRow.field(this.field, this.index, this.key) : addFor = null;
  _EditorRow.add(this.addFor, this.key)
      : field = null,
        index = -1;

  final PlanField? field;
  final int index;
  final PlanField? addFor;
  final String key;
}

/// Reorderable editor for the fields of an Ablaufplan, including
/// Programmblöcke (heads with Unterpunkte), notes and info texts.
///
/// Used by the Termin planner, the ad-hoc planner, shared edit links and the
/// org planning templates. All changes are reported through [onChanged];
/// the list passed in stays untouched.
class PlanFieldsEditor extends StatefulWidget {
  const PlanFieldsEditor({
    super.key,
    required this.fields,
    required this.startTime,
    required this.onChanged,
    this.onSaveBlockTemplate,
    this.blockTemplateNames = const {},
    this.fieldWarning,
    this.showTimes = true,
    this.emptyText = 'Keine Programmpunkte',
    this.onAddTopics,
  });

  final List<PlanField> fields;

  /// Start time ("HH:mm" or ISO); used for the per-row times.
  final String startTime;
  final ValueChanged<List<PlanField>> onChanged;

  /// Shown in the block options for admins ("Als Vorlage speichern").
  final Future<void> Function(PlanField head)? onSaveBlockTemplate;
  final Set<String> blockTemplateNames;

  /// Optional red warning line under a field (e.g. missing instrument groups of a song).
  final String? Function(PlanField field)? fieldWarning;
  final bool showTimes;
  final String emptyText;

  /// "Themen aufnehmen" on the Tagesordnung insert marker (Ionic `openAgendaPicker`).
  final VoidCallback? onAddTopics;

  @override
  State<PlanFieldsEditor> createState() => _PlanFieldsEditorState();
}

class _PlanFieldsEditorState extends State<PlanFieldsEditor> {
  final Set<String> _collapsed = {};

  List<PlanField> get _fields => widget.fields;

  int? get _startMinutes => PlanUtils.parseTimeToMinutes(widget.startTime);

  void _emit(List<PlanField> fields) => widget.onChanged(PlanUtils.normalizeGroups(fields));

  List<_EditorRow> _buildRows() {
    final fields = _fields;
    final rows = <_EditorRow>[];
    final seen = <String, int>{};
    String rowKey(String id) {
      final n = (seen[id] ?? 0) + 1;
      seen[id] = n;
      return n > 1 ? '$id#$n' : id;
    }

    for (var index = 0; index < fields.length; index++) {
      final field = fields[index];
      if (field.groupId != null && _collapsed.contains(field.groupId)) continue;
      rows.add(_EditorRow.field(field, index, rowKey(field.id)));
      final next = index + 1 < fields.length ? fields[index + 1] : null;
      final isHead = PlanUtils.isGroupHead(field);
      final closesBlock = isHead ? next?.groupId == null : (field.groupId != null && next?.groupId != field.groupId);
      final head = isHead ? field : fields.where((f) => f.id == field.groupId).firstOrNull;
      if (closesBlock && head != null && !_collapsed.contains(head.id)) {
        rows.add(_EditorRow.add(head, 'add-${head.id}'));
      }
    }
    return rows;
  }

  void _onReorder(List<_EditorRow> rows, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = rows[oldIndex];
    final field = moved.field;
    if (field == null) return;
    final reordered = [...rows]..removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    // Dropped right above a block's add row: it belongs into that block; right below it: it doesn't.
    var hasJoin = false;
    String? join;
    if (!PlanUtils.isGroupHead(field)) {
      final after = newIndex + 1 < reordered.length ? reordered[newIndex + 1] : null;
      final before = newIndex > 0 ? reordered[newIndex - 1] : null;
      if (after?.addFor != null) {
        hasJoin = true;
        join = after!.addFor!.id;
      } else if (before?.addFor != null) {
        hasJoin = true;
        join = null;
      }
    }

    // Target position: before the next visible field row.
    PlanField? nextField;
    for (var k = newIndex + 1; k < reordered.length; k++) {
      if (reordered[k].field != null) {
        nextField = reordered[k].field;
        break;
      }
    }
    final from = moved.index;
    final rest = [..._fields]..removeAt(from);
    var to = nextField == null ? rest.length : rest.indexWhere((f) => identical(f, nextField));
    if (to < 0) to = rest.length;

    final result = PlanUtils.moveField(_fields, from, to, overrideGroup: hasJoin, joinGroup: join);
    if (hasJoin && join != null) _collapsed.remove(join);
    _emit(result);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _editField(int index) async {
    final field = _fields[index];
    if (PlanUtils.isGroupHead(field)) {
      await _showGroupOptions(field);
      return;
    }
    if (PlanUtils.isAgendaPlaceholder(field)) return;
    final isNote = PlanUtils.isNote(field);
    final result = await showPlanFieldDialog(
      context,
      title: 'Feld bearbeiten',
      nameLabel: isNote ? 'Notiz' : 'Programmpunkt',
      nameHint: isNote ? 'Notiz eingeben...' : 'Programmpunkt eingeben...',
      infoHint: 'Info-Text (optional)...',
      confirmText: 'Updaten',
      initialName: field.name,
      initialConductor: field.conductor,
      initialInfo: field.info,
      initialMinutes: int.tryParse(field.time) ?? 20,
      withConductor: !isNote,
      withInfo: !isNote,
      withMinutes: !isNote,
    );
    if (result == null) return;
    final updated = [..._fields];
    updated[index] = isNote
        ? field.copyWith(name: result.name)
        : field.copyWith(
            name: result.name,
            conductor: result.conductor,
            info: result.info,
            time: result.minutes?.toString() ?? field.time,
          );
    _emit(updated);
  }

  Future<void> _removeField(int index) async {
    final field = _fields[index];
    if (PlanUtils.isGroupHead(field)) {
      await _confirmDeleteGroup(field);
      return;
    }
    _emit([..._fields]..removeAt(index));
  }

  void _setMinutes(int index, String value) {
    final updated = [..._fields];
    updated[index] = updated[index].copyWith(time: value.trim());
    _emit(updated);
  }

  void _toggleIndent(int index) {
    final field = _fields[index];
    final result = PlanUtils.toggleIndent(_fields, index);
    if (field.groupId == null) {
      final moved = result[index];
      if (moved.groupId != null) _collapsed.remove(moved.groupId);
    }
    _emit(result);
  }

  Future<void> _addSubItem(PlanField head) async {
    final result = await showPlanFieldDialog(
      context,
      title: 'Unterpunkt hinzufügen',
      subtitle: head.name,
      nameHint: 'Programmpunkt, z. B. Gruppenlied',
      infoHint: 'Info-Text (optional), z. B. Liedtitel',
      initialMinutes: 5,
    );
    if (result == null) return;
    _collapsed.remove(head.id);
    _emit(PlanUtils.addSubItem(
      _fields,
      head.id,
      PlanField(
        id: 'fld-${PlanUtils.uuid()}',
        name: result.name,
        conductor: result.conductor,
        info: result.info,
        time: (result.minutes ?? 5).toString(),
      ),
    ));
  }

  Future<void> _showGroupOptions(PlanField head) async {
    final children = PlanUtils.childrenOf(_fields, head.id);
    final minutes = PlanUtils.groupDuration(_fields, head.id);
    final exists = widget.blockTemplateNames.contains(head.name);
    final action = await showPlanActionSheet<String>(
      context,
      title: head.name,
      subtitle: '${children.length} ${children.length == 1 ? 'Unterpunkt' : 'Unterpunkte'} · $minutes min',
      actions: [
        const PlanSheetAction('edit', 'Block bearbeiten', icon: Icons.edit_outlined),
        const PlanSheetAction('add', 'Unterpunkt hinzufügen', icon: Icons.add),
        if (widget.onSaveBlockTemplate != null && children.isNotEmpty)
          PlanSheetAction('template', exists ? 'Vorlage aktualisieren' : 'Als Vorlage speichern',
              icon: Icons.bookmark_add_outlined),
        const PlanSheetAction('dissolve', 'Block auflösen', icon: Icons.call_split),
        const PlanSheetAction('delete', 'Block mit Unterpunkten löschen', icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editGroup(head);
      case 'add':
        await _addSubItem(head);
      case 'template':
        await widget.onSaveBlockTemplate?.call(head);
      case 'dissolve':
        _collapsed.remove(head.id);
        _emit(PlanUtils.dissolveGroup(_fields, head.id));
      case 'delete':
        await _confirmDeleteGroup(head);
    }
  }

  Future<void> _editGroup(PlanField head) async {
    final result = await showPlanFieldDialog(
      context,
      title: 'Block bearbeiten',
      nameLabel: 'Name',
      nameHint: 'Name',
      conductorLabel: 'Ausführung',
      conductorHint: 'Ausführung (optional)',
      confirmText: 'Speichern',
      emptyNameMessage: 'Bitte einen Namen eingeben.',
      initialName: head.name,
      initialConductor: head.conductor,
      initialInfo: head.info,
      withMinutes: false,
    );
    if (result == null) return;
    _emit([
      for (final f in _fields)
        f.id == head.id ? f.copyWith(name: result.name, conductor: result.conductor, info: result.info) : f,
    ]);
  }

  Future<void> _confirmDeleteGroup(PlanField head) async {
    final count = PlanUtils.childrenOf(_fields, head.id).length;
    if (count == 0) {
      _emit(_fields.where((f) => f.id != head.id).toList());
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block löschen?'),
        content: Text('„${head.name}“ hat $count ${count == 1 ? 'Unterpunkt' : 'Unterpunkte'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'dissolve'), child: const Text('Nur Block auflösen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('Alles löschen'),
          ),
        ],
      ),
    );
    if (choice == 'dissolve') {
      _collapsed.remove(head.id);
      _emit(PlanUtils.dissolveGroup(_fields, head.id));
    } else if (choice == 'all') {
      _collapsed.remove(head.id);
      _emit(PlanUtils.deleteGroup(_fields, head.id));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String _timeAt(int index) {
    final start = _startMinutes;
    if (start == null) return '';
    return PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, _fields, index));
  }

  @override
  Widget build(BuildContext context) {
    if (_fields.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(widget.emptyText, style: const TextStyle(color: AppColors.medium)),
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
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row.addFor != null) {
          return _AddSubItemRow(
            key: ValueKey(row.key),
            onTap: () => _addSubItem(row.addFor!),
          );
        }
        return KeyedSubtree(
          key: ValueKey(row.key),
          child: _buildFieldRow(row.field!, row.index, i),
        );
      },
    );
  }

  Widget _buildFieldRow(PlanField field, int index, int rowIndex) {
    final theme = Theme.of(context);
    final isHead = PlanUtils.isGroupHead(field);
    final isNote = PlanUtils.isNote(field);
    final isChild = field.groupId != null;
    final dragHandle = ReorderableDragStartListener(
      index: rowIndex,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.drag_handle, color: AppColors.medium),
      ),
    );

    if (PlanUtils.isAgendaPlaceholder(field)) {
      return _slidable(
        index: index,
        canIndent: false,
        isChild: false,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.commit, color: AppColors.medium),
          title: const Text('Einfügeposition Tagesordnung', style: TextStyle(color: AppColors.medium)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.onAddTopics != null)
              TextButton(onPressed: widget.onAddTopics, child: const Text('Themen aufnehmen')),
            dragHandle,
          ]),
        ),
      );
    }

    final subtitleParts = <Widget>[];
    if (isHead) {
      final start = _startMinutes;
      final range = start == null ? '' : PlanUtils.groupRange(start, _fields, index);
      final conductor = (field.conductor ?? '').isNotEmpty ? ' | ${field.conductor}' : '';
      subtitleParts.add(Text('$range$conductor'));
    } else if (!isNote && widget.showTimes) {
      final conductor = (field.conductor ?? '').isNotEmpty ? ' | ${field.conductor}' : '';
      subtitleParts.add(Text('${_timeAt(index)}$conductor'));
    }
    final warning = widget.fieldWarning?.call(field);
    if (warning != null && warning.isNotEmpty) {
      subtitleParts.add(Text(warning, style: const TextStyle(color: AppColors.danger, fontSize: 12)));
    }
    if (!isNote && (field.info ?? '').isNotEmpty) {
      subtitleParts.add(Text(
        field.info!,
        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      ));
    }

    final canIndent = PlanUtils.canIndent(_fields, index);

    // Ionic: group heads show their summed duration as a badge, plain fields an
    // inline minutes input ("min"), notes nothing. Edit/indent/delete via tap
    // and swipe (ion-item-sliding).
    final Widget? minutesWidget = isNote
        ? null
        : isHead
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${PlanUtils.displayMinutes(field, _fields)} min', style: const TextStyle(fontSize: 12)),
              )
            : _MinutesInput(
                key: ValueKey('min-${field.id}'),
                value: field.time,
                onChanged: (v) => _setMinutes(index, v),
              );

    return _slidable(
      index: index,
      canIndent: canIndent,
      isChild: isChild,
      child: Container(
        margin: EdgeInsets.only(left: isChild ? 20 : 0),
        decoration: BoxDecoration(
          color: isNote ? AppColors.medium.withValues(alpha: 0.08) : null,
          border: Border(
            bottom: isNote ? BorderSide.none : BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            left: isChild ? BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 2) : BorderSide.none,
          ),
        ),
        child: ListTile(
          dense: isNote,
          contentPadding: EdgeInsets.only(left: isHead ? 0 : 16, right: 0),
          leading: isHead
              ? IconButton(
                  tooltip: _collapsed.contains(field.id) ? 'Block aufklappen' : 'Block einklappen',
                  icon: Icon(_collapsed.contains(field.id) ? Icons.chevron_right : Icons.expand_more),
                  onPressed: () => setState(() {
                    if (!_collapsed.remove(field.id)) _collapsed.add(field.id);
                  }),
                )
              : null,
          title: Text(
            field.name,
            style: TextStyle(
              fontWeight: isHead ? FontWeight.bold : FontWeight.w500,
              fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          subtitle: subtitleParts.isEmpty
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: subtitleParts),
          onTap: () => _editField(index),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (minutesWidget != null) minutesWidget,
              dragHandle,
            ],
          ),
        ),
      ),
    );
  }

  /// Ionic `ion-item-options`: "Einrücken"/"Ausrücken" (medium) and delete (danger).
  Widget _slidable({
    required int index,
    required bool canIndent,
    required bool isChild,
    required Widget child,
  }) {
    return Slidable(
      key: ValueKey('slide-${_fields[index].id}-$index'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: canIndent ? 0.45 : 0.2,
        children: [
          if (canIndent)
            SlidableAction(
              onPressed: (_) => _toggleIndent(index),
              backgroundColor: AppColors.medium,
              foregroundColor: Colors.white,
              label: isChild ? 'Ausrücken' : 'Einrücken',
            ),
          SlidableAction(
            onPressed: (_) => _removeField(index),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Inline minutes input of a plan row (Ionic `ion-input type="number"` with placeholder "min").
class _MinutesInput extends StatefulWidget {
  const _MinutesInput({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_MinutesInput> createState() => _MinutesInputState();
}

class _MinutesInputState extends State<_MinutesInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _MinutesInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: 'min',
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _AddSubItemRow extends StatelessWidget {
  const _AddSubItemRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary.withValues(alpha: 0.4), width: 2)),
      ),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.add, color: AppColors.primary),
        title: const Text('Unterpunkt hinzufügen', style: TextStyle(color: AppColors.primary)),
        onTap: onTap,
      ),
    );
  }
}
