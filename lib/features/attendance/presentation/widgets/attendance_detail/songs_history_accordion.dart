import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';
import '../songs_selection_sheet.dart';
import 'attendance_accordion.dart';

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
    // IOS_DETAIL: shared accordion (iOS header look, Ionic state reset)
    return AttendanceAccordion(
        title: Text(context.l10n.attendanceSongsCount(entries.length)),
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
                tooltip: context.l10n.commonRemove,
                onPressed: () => onRemove(index),
              ),
              onTap: onTap == null ? null : () => onTap!(index),
            ),
          ListTile(
            dense: true,
            title: Text(context.l10n.attListAddSongs, style: const TextStyle(color: AppColors.primary)),
            onTap: onAdd,
          ),
        ],
    );
  }
}
