import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

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
        title: const Text('Grund hinzufügen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Grund'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Hinzufügen'),
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
        reasons.length == 1 ? '1 Grund konfiguriert' : '${reasons.length} Gründe konfiguriert',
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
                  tooltip: 'Entfernen',
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
              label: const Text('Grund hinzufügen'),
            ),
            TextButton.icon(
              onPressed: () => onChanged([...defaults]),
              icon: const Icon(Icons.restore),
              label: const Text('Standardwerte wiederherstellen'),
            ),
          ],
        ),
      ],
    );
  }
}
