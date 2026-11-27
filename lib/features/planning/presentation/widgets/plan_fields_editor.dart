import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import 'plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import 'rd_plan_widgets.dart';

part 'plan_fields_editor_beta.dart';

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
    this.emptyText,
    this.onAddTopics,
    this.beamerFileOf,
    this.templateMode = false,
    this.publicFieldDialog = false,
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
  final String? emptyText;

  /// "Themen aufnehmen" on the Tagesordnung insert marker (Ionic `openAgendaPicker`).
  final VoidCallback? onAddTopics;

  /// Beamer rows (Gemeinde App, Ionic 4.17.10): set only when
  /// [PlanBeamer.active]. Returns the file shown for a row (its own, else
  /// the one of its Werk). Rows needing a file get a status line and the
  /// edit dialog shows the "Beamer-Datei nötig" switch.
  final BeamerFile? Function(PlanField field)? beamerFileOf;

  /// Standard-Ablaufplan of a Termintyp (Ionic type.page): no Programmblöcke
  /// (no indent), the Tagesordnung marker as a fixed two-line row and the
  /// "Feld bearbeiten" alert without minutes (they are edited in the row).
  final bool templateMode;

  /// Ionic public-planning `editField`: the field dialog has "Löschen" /
  /// "Abbrechen" / "Speichern", no Minuten (they stay inline in the row).
  final bool publicFieldDialog;

  @override
  State<PlanFieldsEditor> createState() => _PlanFieldsEditorState();
}

class _PlanFieldsEditorState extends State<PlanFieldsEditor> {
  final Set<String> _collapsed = {};

  List<PlanField> get _fields => widget.fields;

  int? get _startMinutes => PlanUtils.parseTimeToMinutes(widget.startTime);

  /// setState for the Beta extension (part file).
  void _update(VoidCallback fn) => setState(fn);

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
      // Ids repeat (song rows, free text "Pause" twice): the row's uid keeps
      // the key stable when rows are removed or moved; the counter still
      // keeps keys unique.
      rows.add(_EditorRow.field(field, index, rowKey(field.uid ?? field.id)));
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

  Future<void> _addSubItem(PlanField head) async {
    final result = await showPlanFieldDialog(
      context,
      title: context.l10n.planningAddSubItem,
      subtitle: head.name,
      nameHint: context.l10n.planningSubItemPlaceholder,
      infoHint: context.l10n.planningSubItemInfoPlaceholder,
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

  Future<void> _confirmDeleteGroup(PlanField head) async {
    final count = PlanUtils.childrenOf(_fields, head.id).length;
    if (count == 0) {
      _emit(_fields.where((f) => f.id != head.id).toList());
      return;
    }
    final choice = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.planningDeleteBlockConfirm),
        content: Text(ctx.l10n.planningBlockHasItems(head.name, count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'dissolve'), child: Text(ctx.l10n.planningOnlyDissolve)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: Text(ctx.l10n.planningDeleteAll),
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
  Widget build(BuildContext context) => _rdBuild(context);
}

/// Inline minutes input of a plan row (Ionic `ion-input type="number"` with placeholder "min").
class _MinutesInput extends StatefulWidget {
  const _MinutesInput({required this.value, required this.onChanged});

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
        decoration: InputDecoration(
          hintText: context.l10n.planningMinPlaceholder,
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
