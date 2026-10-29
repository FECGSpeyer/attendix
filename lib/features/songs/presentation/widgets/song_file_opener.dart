import 'package:flutter/material.dart';

import '../../../../core/services/native/native_file_service.dart'; // NATIVE_MISC
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../utils/song_utils.dart';
import 'pdf_viewer_page.dart';
import '../../../../l10n/l10n.dart';

/// Open a song file: PDFs and images in the in-app viewers, everything else
/// externally (Ionic `Utils.openFileNative`).
Future<void> openSongFile(BuildContext context, SongFile file) async {
  if (file.url.isEmpty) return;
  if (SongUtils.isPdf(file)) {
    await showPdfViewer(context, url: file.url, fileName: file.fileName);
  } else if (SongUtils.isImage(file)) {
    await showImageViewerSheet(context, url: file.url, fileName: file.fileName);
  } else {
    await openSongFileExternally(context, file);
  }
}

/// Open a file URL in the browser / external app; in the native app the file
/// is downloaded and opened in the system viewer (NATIVE_MISC, Ionic
/// `Utils.openFileNative`).
Future<void> openSongFileExternally(BuildContext context, SongFile file) async {
  if (Uri.tryParse(file.url) == null) return;
  final ok = await NativeFileService.openUrl(file.url, fileName: file.fileName);
  if (!ok && context.mounted) {
    ToastHelper.showError(context, context.l10n.songsFlutterOpenFileFailed);
  }
}
