import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';

/// Editable list of absence / late reasons (Ionic general settings
/// "Abwesenheits- & Verspätungsgründe").
class ReasonsListEditor extends StatelessWidget {
  const ReasonsListEditor({
    super.key,
    required this.title,
    required this.reasons,
    required this.defaults,
    required this.onChanged,
  });

  final String title;
  final List<String> reasons;
  final List<String> defaults;
  final ValueChanged<List<String>> onChanged;

  Future<void> _add(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.generalSettingsAddReason),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: ctx.l10n.excuseReason),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.attendanceAdd),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || reasons.contains(value)) return;
    onChanged([...reasons, value]);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        context.l10n.generalSettingsReasonsCount(reasons.length),
      ),
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            final list = [...reasons];
            if (newIndex > oldIndex) newIndex -= 1;
            list.insert(newIndex, list.removeAt(oldIndex));
            onChanged(list);
          },
          children: [
            for (var i = 0; i < reasons.length; i++)
              ListTile(
                key: ValueKey('reason-$i-${reasons[i]}'),
                contentPadding: EdgeInsets.zero,
                leading: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                title: Text(reasons[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: context.l10n.commonRemove,
                  onPressed: () => onChanged([...reasons]..removeAt(i)),
                ),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.generalSettingsAddReason),
            ),
            TextButton.icon(
              onPressed: () => onChanged([...defaults]),
              icon: const Icon(Icons.restore),
              label: Text(context.l10n.generalSettingsRestoreDefaults),
            ),
          ],
        ),
      ],
    );
  }
}
