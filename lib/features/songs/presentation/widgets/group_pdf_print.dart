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
  // Ionic loads the people for the print (not a session cache).
  ref.invalidate(playerCountByInstrumentProvider);
  final Map<int, int> counts;
  try {
    counts = await ref.read(playerCountByInstrumentProvider.future);
  } catch (_) {
    // Ionic db.getPlayers: danger toast, then the print stops.
    if (context.mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
    return;
  }
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
  // Ionic PrintService.printEntries: loading overlay while merging, then a
  // warning for no pages / skipped files.
  // Close exactly the overlay's route: a redirect may have removed it or
  // pushed something on top in the meantime.
  Route<dynamic>? overlayRoute;
  var overlay = true;
  void removeOverlay() {
    final route = overlayRoute;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  void closeOverlay() {
    if (!overlay) return;
    overlay = false;
    removeOverlay();
  }

  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      overlayRoute ??= ModalRoute.of(ctx);
      // Closed before the first frame of the dialog was built.
      if (!overlay) WidgetsBinding.instance.addPostFrameCallback((_) => removeOverlay());
      return PrintLoadingOverlay(message: context.l10n.songsCreatingPdf);
    },
  );
  SongPrintResult? result;
  try {
    result = await ref.read(songPrintServiceProvider).printEntries(
          entries,
          '${song.name.isEmpty ? 'song' : song.name}_print.pdf',
          onMerged: closeOverlay,
        );
  } finally {
    closeOverlay();
  }
  if (!context.mounted || result == null) return;
  if (result.pageCount == 0) {
    ToastHelper.showWarning(context, context.l10n.svcNoPrintableScores);
    return;
  }
  if (result.skipped > 0) {
    // A new toast replaces the previous one (md), so the summary below would
    // hide this warning right away.
    ToastHelper.showWarning(context, context.l10n.songsFlutterFilesSkipped(result.skipped));
    return;
  }
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
      // Ionic alert: message + `type: 'radio'` inputs (song.page.ts).
      content: AppAlertRadioGroup<int>(
        message: Text(l10n.songsCopiesPerGroup),
        options: [for (final o in options) AppAlertOption(o.$1, o.$2)],
        groupValue: _ratio,
        onChanged: (v) => setState(() => _ratio = v),
        beta: Column(
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

/// Ionic `Utils.getLoadingElement(…, message)`: blocking spinner with text.
class PrintLoadingOverlay extends StatelessWidget {
  const PrintLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 28, height: 28, child: AppSpinner()),
                const SizedBox(width: 16),
                Flexible(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
