
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads a PDF for the in-app viewers.
///
/// iOS/Android: through the file cache, so a PDF opened once (sheet music,
/// Ablaufplan) also opens later without network, e.g. in a rehearsal room
/// without reception. Copies expire after 30 days without use. Copies are
/// kept per account and dropped on sign-out; a download still running at
/// sign-out is not kept.
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

  /// Raised by [clear]; a download started before it is not kept.
  static int _epoch = 0;

  static String? _accountId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> load(String url) async {
    final account = _accountId();
    if (_useFileCache && account != null) {
      final key = '$account|$url';
      final epoch = _epoch;
      try {
        final file = await _cache.getSingleFile(url, key: key);
        final bytes = await file.readAsBytes();
        if (epoch != _epoch) await _remove(key);
        return bytes;
      } catch (_) {
        if (epoch != _epoch) rethrow;
        // Offline after the copy's HTTP max-age: getSingleFile tries to
        // download again and fails, so fall back to the stale copy.
        final cached = await _cache.getFileFromCache(key);
        if (cached != null) return cached.file.readAsBytes();
        rethrow;
      }
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  static Future<void> _remove(String key) async {
    try {
      await _cache.removeFile(key);
    } catch (_) {
      // Best effort.
    }
  }

  /// Removes all offline copies (sign-out).
  static Future<void> clear() async {
    _epoch++;
    if (!_useFileCache) return;
    try {
      await _cache.emptyCache();
    } catch (_) {
      // Best effort: the cache directory may already be gone.
    }
  }
}
