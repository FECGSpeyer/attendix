import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/player_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';

/// Ionic `printSongFiles`: group PDFs with copies per player count. Used by
/// the song page ("Bearbeiten") and the Beta work page.
Future<void> printGroupPdfs({
  required BuildContext context,
  required WidgetRef ref,
  required Song song,
  required List<SongFile> files,
  required List<Group> groups,
}) async {
  final groupPdfs = files
      .where((f) => f.instrumentId != null && f.instrumentId! > 2 && SongUtils.isPdf(f))
      .toList();
  if (groupPdfs.isEmpty) {
    ToastHelper.showWarning(context, context.l10n.songsNoGroupPdfs);
    return;
  }
  final counts = await ref.read(playerCountByInstrumentProvider.future);
  if (!context.mounted) return;
  final withPlayers =
      groupPdfs.where((f) => (counts[f.instrumentId] ?? 0) > 0).toList();
  if (withPlayers.isEmpty) {
    ToastHelper.showWarning(context, context.l10n.songsNoGroupsWithPeople);
    return;
  }

  final ratio = await showAppDialog<int>(
    context: context,
    builder: (ctx) => const GroupPdfRatioDialog(),
  );
  if (ratio == null || !context.mounted) return;

  final entries = [
    for (final f in withPlayers)
      SongPrintEntry(
        song: song,
        file: f,
        copies: ratio == 0 ? 1 : ((counts[f.instrumentId] ?? 0) / ratio).ceil(),
      ),
  ];
  final result = await ref
      .read(songPrintServiceProvider)
      .printEntries(entries, '${song.name.isEmpty ? 'song' : song.name}_print.pdf');
  if (!context.mounted || result == null || result.pageCount == 0) return;
  final summary = entries
      .where((e) => e.copies > 0)
      .map((e) => '${SongUtils.fileLabel(e.file, groups)}: ${e.copies}x')
      .join(', ');
  ToastHelper.showSuccess(context, context.l10n.songsPrintPrepared(summary));
}

/// Whether [files] hold a group PDF that [printGroupPdfs] can print.
bool hasGroupPdfs(List<SongFile> files) =>
    files.any((f) => f.instrumentId != null && f.instrumentId! > 2 && SongUtils.isPdf(f));

/// Copies per group: per person, every 2nd/3rd/4th, or one per group (0).
class GroupPdfRatioDialog extends StatefulWidget {
  const GroupPdfRatioDialog({super.key});

  @override
  State<GroupPdfRatioDialog> createState() => _GroupPdfRatioDialogState();
}

class _GroupPdfRatioDialogState extends State<GroupPdfRatioDialog> {
  int _ratio = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      (1, l10n.songsPerPerson),
      (2, l10n.songsEvery2),
      (3, l10n.songsEvery3),
      (4, l10n.songsEvery4),
      (0, l10n.songsPerGroup),
    ];
    return AppAlertDialog(
      title: Text(l10n.songsPrintOptions),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.songsCopiesPerGroup),
          for (final o in options)
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              value: o.$1,
              groupValue: _ratio,
              title: Text(o.$2),
              onChanged: (v) => setState(() => _ratio = v ?? 1),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ratio),
          child: Text(l10n.songsPrint),
        ),
      ],
    );
  }
}
