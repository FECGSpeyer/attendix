import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.music_note, color: AppColors.primary),
        title: Row(
          children: [
            const Text('Werke'),
            const SizedBox(width: 8),
            if (entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        children: [
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingM),
              child: Text(
                'Keine Werke ausgewählt',
                style: TextStyle(color: AppColors.medium),
              ),
            )
          else
            ...entries.asMap().entries.map((entry) {
              final index = entry.key;
              final songEntry = entry.value;

              return Slidable(
                key: ValueKey('${songEntry.songId}-$index'),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) => onRemove(index),
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Entfernen',
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(songEntry.songName),
                  subtitle: Text(songEntry.displayConductor),
                  dense: true,
                  onTap: onTap == null ? null : () => onTap!(index),
                ),
              );
            }),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Werk(e) hinzufügen'),
            ),
          ),
        ],
      ),
    );
  }
}
