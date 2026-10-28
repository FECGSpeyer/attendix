import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import 'settings_list.dart';

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
    // UX_SETTINGS (WAVE 8): ion-accordion — header item (h2 + p count),
    // inset rows with a red trash button, then "+ Grund hinzufügen"
    // (primary) and, only for an empty list, "Standard wiederherstellen".
    final ios = ionIsIos(context);
    final pad = ios
        ? const EdgeInsets.only(left: IonIos.itemPaddingStart, right: IonIos.itemPaddingEnd)
        : const EdgeInsets.symmetric(horizontal: 16);
    return ExpansionTile(
      tilePadding: pad,
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: ios ? IonIos.text(context).withValues(alpha: 0.4) : null,
      collapsedIconColor: ios ? IonIos.text(context).withValues(alpha: 0.4) : null,
      title: Text(title),
      subtitle: Text(
        context.l10n.generalSettingsReasonsCount(reasons.length),
        style: ios ? TextStyle(fontSize: 14, color: IonIos.labelP(context)) : null,
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
                contentPadding: pad,
                leading: ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle, color: ios ? IonIos.note(context) : null),
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
        ListTile(
          contentPadding: pad,
          onTap: () => _add(context),
          title: Text.rich(
            TextSpan(children: [
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
              ),
              TextSpan(text: ' ${context.l10n.generalSettingsAddReason}'),
            ]),
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
        if (reasons.isEmpty)
          ListTile(
            contentPadding: pad,
            onTap: () => onChanged([...defaults]),
            title: Text(
              context.l10n.generalSettingsRestoreDefaults,
              style: const TextStyle(color: AppColors.medium),
            ),
          ),
      ],
    );
  }
}
