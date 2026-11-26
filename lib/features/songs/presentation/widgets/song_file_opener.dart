import 'package:flutter/material.dart';

import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../utils/song_utils.dart';
import 'docx_viewer_page.dart';
import 'pdf_viewer_page.dart';
import '../../../../l10n/l10n.dart';

/// Opens a song file inside the app viewer or delegates to the system opener.
Future<void> openSongFile(BuildContext context, SongFile file) async {
  if (file.url.isEmpty) return;
  if (SongUtils.isPdf(file)) {
    await showPdfViewer(context, url: file.url, fileName: file.fileName);
  } else if (SongUtils.isDocx(file)) {
    await showDocxViewer(context, url: file.url, fileName: file.fileName);
  } else if (SongUtils.isImage(file)) {
    await showImageViewerSheet(context, url: file.url, fileName: file.fileName);
  } else {
    await openSongFileExternally(context, file);
  }
}

/// Open a file URL in the browser / external app; in the native app the file
/// is downloaded and opened in the system viewer (NATIVE_MISC, Ionic
/// `Utils.openFileNative`).
///
/// Ionic 4.17.19: an installed web app (Safari "Zum Dock hinzufügen" …)
/// blocks new windows, so there PDFs and images open in the in-app viewers
/// and other files get a download hint ([showFileNoPreviewDialog]).
Future<void> openSongFileExternally(
  BuildContext context,
  SongFile file, {
  String? errorMessage,
}) async {
  if (Uri.tryParse(file.url) == null) return;
  if (NativeFileService.isInstalledWebApp) {
    if (SongUtils.isPdf(file) ||
        SongUtils.isImage(file) ||
        SongUtils.isDocx(file)) {
      await openSongFile(context, file);
    } else {
      await showFileNoPreviewDialog(context,
          url: file.url, fileName: file.fileName);
    }
    return;
  }
  final ok = await NativeFileService.openUrl(file.url, fileName: file.fileName);
  if (!ok && context.mounted) {
    ToastHelper.showError(
        context, errorMessage ?? context.l10n.songsFlutterOpenFileFailed);
  }
}

/// Ionic 4.17.19 in-app file viewer for files without preview: the file name,
/// "Für diese Datei gibt es keine Vorschau …", "Datei herunterladen" and
/// "Schließen".
Future<void> showFileNoPreviewDialog(
  BuildContext context, {
  required String url,
  required String fileName,
}) async {
  final l10n = context.l10n;
  final download = await showAppConfirm(
    context,
    title: fileName.isEmpty ? NativeFileService.fileNameFromUrl(url) : fileName,
    message: l10n.fileViewerNoPreview,
    confirmText: l10n.songsDownloadFile,
    cancelText: l10n.commonClose,
  );
  if (!download) return;
  final ok = await NativeFileService.downloadInBrowser(url, fileName);
  if (!ok && context.mounted) {
    ToastHelper.showError(context, l10n.fileViewerDownloadFailed);
  }
}
