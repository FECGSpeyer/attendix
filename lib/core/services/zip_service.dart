import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/models/song/song.dart';
import 'zip_service_stub.dart'
    if (dart.library.io) 'zip_service_io.dart'
    if (dart.library.html) 'zip_service_web.dart' as platform;
import '../../l10n/l10n.dart';

/// Service for creating and sharing ZIP archives
class ZipService {
  /// Download all song files as a ZIP archive
  Future<void> downloadSongFilesAsZip({
    required List<SongFile> files,
    required String songName,
  }) async {
    if (files.isEmpty) {
      throw Exception(l10nWithoutContext.coreFlutterNoFilesToDownload);
    }

    // Create archive
    final archive = Archive();

    // Download each file and add to archive (equal names get " (2)" etc.)
    final used = <String>{};
    for (final file in files) {
      if (file.url.isEmpty) continue;

      try {
        final response = await http.get(Uri.parse(file.url));
        if (response.statusCode == 200) {
          archive.addFile(ArchiveFile(
            uniqueArchiveName(file.fileName, used),
            response.bodyBytes.length,
            response.bodyBytes,
          ));
        }
      } catch (e) {
        // Skip files that fail to download
        debugPrint('Failed to download ${file.fileName}: $e');
      }
    }

    if (archive.isEmpty) {
      throw Exception(l10nWithoutContext.coreFlutterNoFilesDownloaded);
    }

    // Encode to ZIP
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception(l10nWithoutContext.coreFlutterZipFailed);
    }

    // Generate safe filename
    final safeName = _sanitizeFileName(songName);
    final fileName = '${safeName}_files.zip';

    // Use platform-specific implementation
    await platform.saveZipFile(Uint8List.fromList(zipData), fileName);
  }

  /// [name], or "name (2).ext", "name (3).ext" … when [used] has it; the
  /// returned name is added to [used].
  @visibleForTesting
  static String uniqueArchiveName(String name, Set<String> used) {
    var result = name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var n = 2; used.contains(result.toLowerCase()); n++) {
      result = '$base ($n)$ext';
    }
    used.add(result.toLowerCase());
    return result;
  }

  /// Sanitize filename for safe file system usage
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}

/// Provider for ZipService
final zipServiceProvider = Provider<ZipService>((ref) {
  return ZipService();
});
