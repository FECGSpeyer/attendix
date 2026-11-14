import 'package:flutter/material.dart';

import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/services/native/native_platform.dart' show isNativeApp;
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../utils/song_utils.dart';
import 'docx_viewer_page.dart';
import 'pdf_viewer_page.dart';
import 'pdf_viewer_sheet.dart';
import '../../../../l10n/l10n.dart';

/// Files the classic native app is currently handing to the system viewer.
final _openingNatively = <String>{};

/// Open a song file (Ionic `Utils.openFileNative`).
///
/// Normal design: in the iOS / Android app the system viewer, like Ionic;
/// on the web PDFs and images in the in-app viewer sheets, everything else
/// externally.
///
/// REDESIGN: the full-screen PDF viewer (scrolling, page mode) and the Word
/// viewer belong to the new design; the normal app keeps its viewer on
/// the web.
Future<void> openSongFile(BuildContext context, SongFile file) async {
  if (file.url.isEmpty) return;
  // Normal design in the iOS / Android app: every file opens in the system
  // viewer (Quick Look, the Android viewer) like in the Ionic app
  // (`Utils.openFileNative` → `FileViewer.openDocumentFromUrl`), not in an
  // own viewer. The web keeps the in-app viewers.
  if (!RedesignRoutes.active && isNativeApp) {
    // The file is downloaded first: a second tap meanwhile must not start
    // another download.
    if (!_openingNatively.add(file.url)) return;
    try {
      await openSongFileExternally(context, file);
    } finally {
      _openingNatively.remove(file.url);
    }
    return;
  }
  if (SongUtils.isPdf(file)) {
    if (RedesignRoutes.active) {
      await showPdfViewer(context, url: file.url, fileName: file.fileName);
    } else {
      await showPdfViewerSheet(context, url: file.url, fileName: file.fileName);
    }
  } else if (RedesignRoutes.active && SongUtils.isDocx(file)) {
    // DOCX_VIEWER: Word files in the app (Beta).
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
        (RedesignRoutes.active && SongUtils.isDocx(file))) {
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
