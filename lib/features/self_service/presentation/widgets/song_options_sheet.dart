import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../songs/data/song_print_service.dart';
import '../../../songs/presentation/widgets/song_file_opener.dart';
import 'upcoming_songs_sheet.dart' show hasSongNotesForPlayer;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Opens the external notes link of a song (Ionic openSongLink).
Future<void> openSongLink(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  // Ionic 4.17.18 openLink: web → Utils.openInNewTab.
  final ok = uri != null && await NativeFileService.openExternal(uri);
  if (!ok && context.mounted) {
    ToastHelper.showError(context, context.l10n.signoutFlutterLinkOpenFailed);
  }
}

/// One entry of an action sheet.
class _SheetAction {
  const _SheetAction(this.label, this.onTap);

  final String label;
  final Future<void> Function() onTap;
}

/// Ionic-style action sheet: optional header, entries, "Abbrechen" (destructive).
Future<_SheetAction?> _showActionSheet(
  BuildContext context, {
  String? header,
  required List<_SheetAction> actions,
}) {
  // IOS_LOOK: adaptive ion-action-sheet
  return showAppActionSheet<_SheetAction>(
    context,
    title: header,
    cancelDestructive: true,
    actions: [
      for (final action in actions)
        AppActionSheetAction(value: action, label: action.label),
    ],
  );
}

Future<void> _chooseFile(
  BuildContext context,
  String header,
  List<SongFile> files,
  Future<void> Function(SongFile file) onPick,
) async {
  final picked = await _showActionSheet(
    context,
    header: header,
    actions: [for (final f in files) _SheetAction(f.fileName, () => onPick(f))],
  );
  await picked?.onTap();
}

// NATIVE_MISC: native app → system file viewer (Ionic Utils.openFileNative).
// Ionic 4.17.19: in an installed web app the file is shown in the app.
Future<void> _openFile(BuildContext context, SongFile file) =>
    openSongFileExternally(context, file,
        errorMessage: context.l10n.signoutFlutterFileOpenFailed);

Future<void> _downloadFile(BuildContext context, SongFile file) async {
  // Append ?download= to force Content-Disposition: attachment
  final url = file.url.contains('?') ? '${file.url}&download=' : '${file.url}?download=';
  // NATIVE_MISC: native app → cache dir + system viewer (Ionic downloadFileNative).
  final ok = await NativeFileService.openUrl(url, fileName: file.fileName);
  if (!ok && context.mounted) {
    ToastHelper.showError(context, context.l10n.signoutFlutterFileDownloadFailed);
  }
}

/// Song options (Ionic signout openSongOptions): action sheet with header
/// "Nr. Name" and – in this order – Notenlink öffnen, Noten downloaden,
/// Noten anzeigen, Noten drucken, Aufnahme anhören, Aufnahme herunterladen,
/// Liedtext ansehen, Abbrechen. With several files a second sheet asks
/// for the file.
Future<void> showSongOptionsSheet(
  BuildContext context, {
  required Song song,
  int? playerInstrumentId,
}) async {
  final l10n = context.l10n;
  final container = ProviderScope.containerOf(context);
  final isChoir = container.read(currentTenantProvider)?.type == 'choir';
  final allFiles = song.files ?? const <SongFile>[];
  final songTitle = song.fullNumber.isEmpty ? song.name : '${song.fullNumber}. ${song.name}';

  if (!hasSongNotesForPlayer(song, playerInstrumentId, isChoir: isChoir)) {
    ToastHelper.showError(context, l10n.signoutNoScoresForInstrument);
  }

  // Files for the player's instrument (choir: plus files noted "Chor")
  var files = allFiles.where((f) => f.instrumentId == playerInstrumentId).toList();
  if (isChoir) {
    files = [...files, ...allFiles.where((f) => f.note?.toLowerCase() == 'chor')];
    final seen = <String>{};
    files = files.where((f) => seen.add(f.fileName)).toList();
  }

  // Ionic hides downloads on native iOS
  final canDownload = kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> printFile(SongFile file) async {
    final result = await container
        .read(songPrintServiceProvider)
        .printEntries([SongPrintEntry(song: song, file: file)], '${song.name}.pdf');
    if (context.mounted && result != null && result.pageCount == 0) {
      ToastHelper.showWarning(context, l10n.signoutFlutterNoPrintableScores);
    }
  }

  final actions = <_SheetAction>[
    if (song.link != null && song.link!.isNotEmpty)
      _SheetAction(l10n.signoutOpenScoreLink, () => openSongLink(context, song.link!)),
  ];

  if (files.length == 1) {
    final file = files.first;
    if (canDownload) actions.add(_SheetAction(l10n.signoutDownloadScores, () => _downloadFile(context, file)));
    actions.add(_SheetAction(l10n.signoutShowScores, () => _openFile(context, file)));
    actions.add(_SheetAction(l10n.signoutPrintScores, () => printFile(file)));
  } else if (files.length > 1) {
    if (canDownload) {
      actions.add(_SheetAction(
        l10n.signoutDownloadScores,
        () => _chooseFile(context, l10n.signoutChooseScoresFor(songTitle), files,
            (f) => _downloadFile(context, f)),
      ));
    }
    actions.add(_SheetAction(
      l10n.signoutShowScores,
      () => _chooseFile(
          context, l10n.signoutChooseScoresFor(songTitle), files, (f) => _openFile(context, f)),
    ));
    actions.add(_SheetAction(
      l10n.signoutPrintScores,
      () => _chooseFile(context, l10n.signoutPrintScoresFor(songTitle), files, printFile),
    ));
  }

  final audioFile = allFiles.where((f) => f.instrumentId == 1).firstOrNull;
  if (audioFile != null) {
    actions.add(_SheetAction(
      l10n.signoutListenRecording,
      () => container
          .read(audioPlayerServiceProvider.notifier)
          .playFromUrl(audioFile.url, audioFile.fileName, '${song.fullNumber} ${song.name}'.trim()),
    ));
    actions.add(_SheetAction(l10n.signoutDownloadRecording, () => _downloadFile(context, audioFile)));
  }

  final lyrics = allFiles.where((f) => f.instrumentId == 2).toList();
  if (lyrics.length == 1) {
    actions.add(_SheetAction(l10n.signoutViewLyrics, () => _openFile(context, lyrics.first)));
  } else if (lyrics.length > 1) {
    actions.add(_SheetAction(
      l10n.signoutViewLyrics,
      () => _chooseFile(
          context, l10n.signoutChooseLyricsFor(songTitle), lyrics, (f) => _openFile(context, f)),
    ));
  }

  if (actions.isEmpty) {
    ToastHelper.showWarning(context, l10n.signoutNoSongActions);
    return;
  }

  final picked = await _showActionSheet(context, header: songTitle, actions: actions);
  if (picked == null || !context.mounted) return;
  await picked.onTap();
}
