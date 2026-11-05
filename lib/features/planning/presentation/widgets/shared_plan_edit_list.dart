import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../l10n/l10n.dart';
import 'plan_field_dialogs.dart';

/// Edit mode of a shared plan link (Ionic shared-plan.page.html): plain rows
/// with name, time (| Ausführender) and info, a red trash button and a
/// reorder handle. Tapping a row opens the field dialog (with Dauer), a
/// block head moves together with its Unterpunkte and deleting it turns the
/// Unterpunkte into normal fields.
class SharedPlanEditList extends StatefulWidget {
  const SharedPlanEditList({
    super.key,
    required this.fields,
    required this.startTime,
    required this.onChanged,
  });

  final List<PlanField> fields;

  /// "HH:mm".
  final String startTime;
  final ValueChanged<List<PlanField>> onChanged;

  @override
  State<SharedPlanEditList> createState() => _SharedPlanEditListState();
}

class _SharedPlanEditListState extends State<SharedPlanEditList> {
  List<PlanField> get fields => widget.fields;

  /// Ionic `calculateTime`: start + minutes of all previous rows, plus
  /// " | Ausführender".
  String _timeOf(int index) {
    final start = PlanUtils.parseTimeToMinutes(widget.startTime);
    final field = fields[index];
    final time = start == null ? '' : PlanUtils.formatMinutes(PlanUtils.startMinutesAt(start, fields, index));
    final conductor = field.conductor ?? '';
    return conductor.isNotEmpty ? '$time | $conductor' : time;
  }

  Future<void> _edit(int index) async {
    final opened = fields;
    final field = opened[index];
    final isNote = PlanUtils.isNote(field);
    final isHead = PlanUtils.isGroupHead(field);
    final r = await showPlanFieldDialog(
      context,
      title: context.l10n.planningEditField,
      nameLabel: isNote ? context.l10n.planningNote : context.l10n.planningItem,
      nameHint: isNote ? context.l10n.planningNote : context.l10n.planningItem,
      conductorHint: context.l10n.planningPerformer,
      infoHint: context.l10n.planningInfoOptional,
      confirmText: context.l10n.commonSave,
      initialName: field.name,
      initialConductor: field.conductor,
      initialInfo: field.info,
      initialMinutes: int.tryParse(field.time),
      withConductor: !isNote,
      withInfo: !isNote,
      // A block head's duration comes from its Unterpunkte.
      withMinutes: !isNote && !isHead,
    );
    if (r == null || !mounted) return;
    // A Realtime update of another editor may have arrived while the dialog
    // was open: re-find the field in the current list (uid, else a unique id)
    // instead of writing the stale one back. Gone or ambiguous -> drop the edit.
    final current = widget.fields;
    final i = PlanUtils.indexOfField(current, field, openedIn: opened);
    if (i == -1) return;
    final base = current[i];
    final updated = [...current];
    updated[i] = isNote
        ? base.copyWith(name: r.name)
        : base.copyWith(
            name: r.name,
            conductor: r.conductor,
            info: r.info,
            // Ionic: `if (evt.time) field.time = String(evt.time)`.
            time: r.minutes != null && r.minutes! > 0 ? '${r.minutes}' : base.time,
          );
    widget.onChanged(PlanUtils.normalizeGroups(updated));
  }

  void _remove(int index) => widget.onChanged(PlanUtils.normalizeGroups([...fields]..removeAt(index)));

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    widget.onChanged(PlanUtils.moveField(fields, oldIndex, newIndex));
  }

  @override
  Widget build(BuildContext context) {
    final medium = TextStyle(fontSize: 13, color: AppColors.medium);
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: _reorder,
      children: [
        for (var i = 0; i < fields.length; i++)
          _row(context, i, medium),
      ],
    );
  }

  Widget _row(BuildContext context, int i, TextStyle medium) {
    final field = fields[i];
    final isNote = PlanUtils.isNote(field);
    final isHead = PlanUtils.isGroupHead(field);
    final isChild = field.groupId != null;
    final info = field.info?.trim() ?? '';
    final tile = ListTile(
      contentPadding: EdgeInsets.only(left: isChild ? 34 : 16, right: 8),
      onTap: () => _edit(i),
      title: Text(
        field.name,
        style: isNote
            ? TextStyle(fontStyle: FontStyle.italic, color: AppColors.medium)
            : isHead
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
      ),
      subtitle: isNote
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_timeOf(i)),
                if (info.isNotEmpty) Text(info, style: medium),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.l10n.commonDelete,
            color: AppColors.danger,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _remove(i),
          ),
          ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
        ],
      ),
    );
    return KeyedSubtree(
      key: ValueKey('spe-${field.id}-$i'),
      child: isChild
          // Ionic `.plan-group-child::before`: 2px line at 20px.
          ? Stack(children: [
              tile,
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF444444)
                      : const Color(0xFFCCCCCC),
                ),
              ),
            ])
          : tile,
    );
  }
}
