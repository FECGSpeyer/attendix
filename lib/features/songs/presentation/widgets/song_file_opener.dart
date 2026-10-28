import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../utils/song_utils.dart';
import 'pdf_viewer_sheet.dart';
import '../../../../l10n/l10n.dart';

/// Open a song file: PDFs and images in the in-app viewers, everything else
/// externally (Ionic `Utils.openFileNative`).
Future<void> openSongFile(BuildContext context, SongFile file) async {
  if (file.url.isEmpty) return;
  if (SongUtils.isPdf(file)) {
    await showPdfViewerSheet(context, url: file.url, fileName: file.fileName);
  } else if (SongUtils.isImage(file)) {
    await showImageViewerSheet(context, url: file.url, fileName: file.fileName);
  } else {
    await openSongFileExternally(context, file);
  }
}

/// Open a file URL in the browser / external app
Future<void> openSongFileExternally(BuildContext context, SongFile file) async {
  final uri = Uri.tryParse(file.url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ToastHelper.showError(context, context.l10n.songsFlutterOpenFileFailed);
    }
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.songsFlutterOpenFileFailed);
  }
}
