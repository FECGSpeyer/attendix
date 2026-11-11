import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/models/song/song.dart';
import 'zip_service_stub.dart'
    if (dart.library.io) 'zip_service_io.dart'
    if (dart.library.js_interop) 'zip_service_web.dart' as platform;
import '../../l10n/l10n.dart';

/// Service for creating and sharing ZIP archives
class ZipService {
  /// Download all song files as a ZIP archive. [onProgress] is told how
  /// many of the files are loaded so far (for a "3 von 19" hint);
  /// [onPacked] runs right before the share sheet (or download) opens.
  Future<void> downloadSongFilesAsZip({
    required List<SongFile> files,
    required String songName,
    void Function(int done, int total)? onProgress,
    VoidCallback? onPacked,
  }) async {
    if (files.isEmpty) {
      throw Exception(l10nWithoutContext.coreFlutterNoFilesToDownload);
    }

    final withUrl = files.where((f) => f.url.isNotEmpty).toList();
    final bodies = await downloadAll(withUrl, onProgress: onProgress);

    // Add in the order of the list (equal names get " (2)" etc.). Stored
    // without compression: PDFs and MP3s hardly shrink, and deflating them
    // only blocks the UI.
    final archive = Archive();
    final used = <String>{};
    for (var i = 0; i < withUrl.length; i++) {
      final bytes = bodies[i];
      if (bytes == null) continue;
      archive.addFile(ArchiveFile.noCompress(uniqueArchiveName(withUrl[i].fileName, used), bytes.length, bytes));
    }

    if (archive.isEmpty) {
      throw Exception(l10nWithoutContext.coreFlutterNoFilesDownloaded);
    }

    // Encode to ZIP
    final zipData = ZipEncoder().encode(archive, level: DeflateLevel.none);

    // Generate safe filename
    final safeName = _sanitizeFileName(songName);
    final fileName = '${safeName}_files.zip';

    onPacked?.call();

    // Use platform-specific implementation
    await platform.saveZipFile(Uint8List.fromList(zipData), fileName, text: l10nWithoutContext.coreFlutterSongFiles);
  }

  /// Loads [files] a few at a time instead of one after another; a file
  /// that fails to load is null.
  @visibleForTesting
  static Future<List<Uint8List?>> downloadAll(
    List<SongFile> files, {
    void Function(int done, int total)? onProgress,
    Future<Uint8List?> Function(String url)? load,
    int parallel = 4,
  }) async {
    final get = load ?? _load;
    final result = List<Uint8List?>.filled(files.length, null);
    var next = 0;
    var done = 0;
    onProgress?.call(0, files.length);
    Future<void> worker() async {
      while (next < files.length) {
        final i = next++;
        try {
          result[i] = await get(files[i].url);
        } catch (e) {
          // Skip files that fail to download
          debugPrint('Failed to download ${files[i].fileName}: $e');
        }
        onProgress?.call(++done, files.length);
      }
    }

    await Future.wait([for (var w = 0; w < parallel && w < files.length; w++) worker()]);
    return result;
  }

  static Future<Uint8List?> _load(String url) async {
    final response = await http.get(Uri.parse(url));
    return response.statusCode == 200 ? response.bodyBytes : null;
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
