import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'native_file_stub.dart'
    if (dart.library.io) 'native_file_io.dart' as impl;
import '../web_window.dart' as web_window;
import 'native_platform.dart';

/// NATIVE_MISC: platform-aware file opening / saving / printing.
///
/// Mirrors Ionic `Utils.openFileNative`, `Utils.downloadFileNative` and
/// `PrintService.printBlob`:
/// * Native app (iOS/Android): files are written to the cache dir and opened
///   in the system viewer (Ionic @capacitor/filesystem + @capacitor/file-viewer;
///   here `open_filex`). Printing uses the system print dialog
///   (Ionic @capgo/capacitor-printer; here `printing`) and falls back to the
///   viewer when that fails.
/// * Web/PWA and desktop: unchanged – URLs open in a new tab/external app,
///   bytes go through `Printing.sharePdf` (browser download / share sheet).
class NativeFileService {
  NativeFileService._();

  /// Test seams (production: real implementations).
  @visibleForTesting
  static Future<bool> Function(String url, String fileName) downloadAndOpen =
      impl.downloadAndOpen;
  @visibleForTesting
  static Future<bool> Function(Uint8List bytes, String fileName) writeAndOpen =
      impl.writeAndOpen;
  @visibleForTesting
  static Future<bool> Function(Uri uri) launchExternal = _launchExternal;
  @visibleForTesting
  static Future<bool> Function(Uint8List bytes, String fileName) shareBytes =
      (bytes, fileName) => Printing.sharePdf(bytes: bytes, filename: fileName);
  @visibleForTesting
  static Future<bool> Function(Uint8List bytes, String name) layoutPdf =
      (bytes, name) => Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

  @visibleForTesting
  static bool Function() isStandaloneWeb = web_window.isStandaloneWebApp;
  @visibleForTesting
  static Future<Uint8List> Function(String url) fetchBytes = _fetchBytes;
  @visibleForTesting
  static bool Function(Uint8List bytes, String fileName) browserDownload =
      web_window.downloadBytesInBrowser;

  /// Restores the production implementations (tests).
  @visibleForTesting
  static void debugReset() {
    downloadAndOpen = impl.downloadAndOpen;
    writeAndOpen = impl.writeAndOpen;
    launchExternal = _launchExternal;
    shareBytes = (bytes, fileName) => Printing.sharePdf(bytes: bytes, filename: fileName);
    layoutPdf = (bytes, name) => Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
    isStandaloneWeb = web_window.isStandaloneWebApp;
    fetchBytes = _fetchBytes;
    browserDownload = web_window.downloadBytesInBrowser;
  }

  static Future<Uint8List> _fetchBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Ionic 4.17.19: the web app runs installed (Safari "Zum Dock
  /// hinzufügen" …), where new windows are blocked entirely, so files have
  /// to be shown inside the app.
  static bool get isInstalledWebApp => isStandaloneWeb();

  /// Ionic 4.17.19 in-app file viewer "Datei herunterladen": loads [url]
  /// and hands it to the browser as a download. Returns false on failure.
  static Future<bool> downloadInBrowser(String url, String fileName) async {
    try {
      final bytes = await fetchBytes(url);
      return browserDownload(
          bytes, fileName.trim().isEmpty ? fileNameFromUrl(url) : fileName);
    } catch (e) {
      if (kDebugMode) debugPrint('[NativeFileService] download failed: $e');
      return false;
    }
  }

  /// Opens [uri] in the browser / external app. Web: Ionic 4.17.18
  /// `Utils.openInNewTab` – installed web apps ignore `window.open`, so a
  /// real link is clicked there.
  static Future<bool> _launchExternal(Uri uri) async {
    if (kIsWeb && (uri.isScheme('http') || uri.isScheme('https'))) {
      return web_window.openInNewTab(uri.toString());
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens [uri] externally (song links, Ionic `openLink`).
  static Future<bool> openExternal(Uri uri) async {
    try {
      return await launchExternal(uri);
    } catch (_) {
      return false;
    }
  }

  /// Ionic `Utils.openFileNative(url, fileName)`: native → download to the
  /// cache dir and open the system viewer; web → open the URL externally.
  /// Returns false when nothing could open the file.
  ///
  /// Ionic 4.17.20: the iOS app on an Apple silicon Mac opens http(s) files
  /// in the browser, the native file preview shows nothing there.
  static Future<bool> openUrl(String url, {String? fileName}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || url.isEmpty) return false;
    final viaBrowser =
        (uri.isScheme('http') || uri.isScheme('https')) && await isIosAppOnMac();
    if (isNativeApp && !viaBrowser) {
      try {
        final name = (fileName == null || fileName.trim().isEmpty)
            ? fileNameFromUrl(url)
            : fileName;
        if (await downloadAndOpen(url, name)) return true;
      } catch (e) {
        if (kDebugMode) debugPrint('[NativeFileService] open failed: $e');
      }
    }
    try {
      return await launchExternal(uri);
    } catch (_) {
      return false;
    }
  }

  /// Ionic `Utils.downloadFileNative(blob, fileName)`: native → write to the
  /// cache dir and open the system viewer (share sheet as fallback); web →
  /// browser download / share sheet as before.
  static Future<void> saveBytes(Uint8List bytes, String fileName) async {
    if (isNativeApp) {
      try {
        if (await writeAndOpen(bytes, fileName)) return;
      } catch (e) {
        if (kDebugMode) debugPrint('[NativeFileService] save failed: $e');
      }
    }
    await shareBytes(bytes, fileName);
  }

  /// Ionic `PrintService.printBlob`: system print dialog; on native a failing
  /// print falls back to the file viewer (Ionic: "Native print failed,
  /// opening viewer instead").
  static Future<bool> printPdf(Uint8List bytes, String name) async {
    try {
      return await layoutPdf(bytes, name);
    } catch (e) {
      if (!isNativeApp) rethrow;
      if (kDebugMode) debugPrint('[NativeFileService] print failed: $e');
      final fileName = name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf';
      await saveBytes(bytes, fileName);
      return false;
    }
  }

  /// Last path segment of [url] without query (Ionic fallback
  /// `document_<ts>.pdf` when nothing usable is left).
  static String fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segment = (uri != null && uri.pathSegments.isNotEmpty)
        ? Uri.decodeComponent(uri.pathSegments.last)
        : '';
    if (segment.trim().isEmpty) {
      return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    return segment;
  }

  /// File name for the cache dir (Ionic `PrintService.toCacheFileName`):
  /// keeps the extension, strips accents/umlauts and everything that is not
  /// `[A-Za-z0-9-]`, so no path separators or odd characters reach the
  /// native viewer.
  static String cacheFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final hasExt = dot > 0 && dot < fileName.length - 1;
    final ext = hasExt
        ? fileName.substring(dot + 1).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
        : '';
    var base = hasExt ? fileName.substring(0, dot) : fileName;
    const map = {
      'ä': 'a', 'ö': 'o', 'ü': 'u', 'Ä': 'A', 'Ö': 'O', 'Ü': 'U', 'ß': 'ss',
      'à': 'a', 'á': 'a', 'â': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ò': 'o', 'ó': 'o', 'ô': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ç': 'c', 'ñ': 'n',
    };
    map.forEach((k, v) => base = base.replaceAll(k, v));
    base = base
        .replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'datei';
    return ext.isEmpty ? base : '$base.$ext';
  }
}
