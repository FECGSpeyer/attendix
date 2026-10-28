import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../songs_selection_sheet.dart';

/// Accordion widget for displaying songs/works in attendance
class SongsHistoryAccordion extends StatelessWidget {
  const SongsHistoryAccordion({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    this.onTap,
  });

  final List<SongHistoryEntry> entries;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  /// Tap on an entry ("Dirigent ändern" / "Zum Werk").
  final void Function(int index)? onTap;

  // UX_ATT: Ionic "Werke (n)" accordion: song (primary) + conductor,
  // close button to remove, "Werk(e) hinzufügen" row at the end.
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('Werke (${entries.length})'),
        children: [
          for (var index = 0; index < entries.length; index++)
            ListTile(
              dense: true,
              title: Text(
                entries[index].songName,
                style: const TextStyle(color: AppColors.primary, fontSize: 15),
              ),
              subtitle: Text(entries[index].displayConductor),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Entfernen',
                onPressed: () => onRemove(index),
              ),
              onTap: onTap == null ? null : () => onTap!(index),
            ),
          ListTile(
            dense: true,
            title: const Text('Werk(e) hinzufügen', style: TextStyle(color: AppColors.primary)),
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}
