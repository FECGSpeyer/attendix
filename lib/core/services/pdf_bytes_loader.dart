
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Loads a PDF for the in-app viewers.
///
/// iOS/Android: through the file cache, so a PDF opened once (sheet music,
/// Ablaufplan) also opens later without network, e.g. in a rehearsal room
/// without reception. Copies expire after 30 days without use.
/// Web: plain download (the browser cache applies).
class PdfBytesLoader {
  PdfBytesLoader._();

  /// File cache only in the native app (not on the web, not in tests,
  /// where path_provider has no platform implementation).
  static bool get _useFileCache => !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

  static final CacheManager _cache = CacheManager(
    Config(
      'attendix_pdf_v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );

  static Future<Uint8List> load(String url) async {
    if (_useFileCache) {
      final file = await _cache.getSingleFile(url);
      return file.readAsBytes();
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Removes all offline copies (sign-out).
  static Future<void> clear() async {
    if (!_useFileCache) return;
    try {
      await _cache.emptyCache();
    } catch (_) {
      // Best effort: the cache directory may already be gone.
    }
  }
}
