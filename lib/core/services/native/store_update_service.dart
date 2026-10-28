import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import 'native_platform.dart';
import 'store_update_stub.dart'
    if (dart.library.io) 'store_update_io.dart' as impl;

/// NATIVE_MISC: closest Flutter equivalent of Ionic's OTA live update
/// (@capawesome/capacitor-live-update, `LiveUpdateService`).
///
/// Ionic downloads a signed web bundle from Supabase Storage and swaps it in
/// ("Update installieren" on login + settings). A Flutter app ships compiled
/// Dart in the native binary, so a new version can only come from the store.
/// On every cold start the native app therefore asks the store whether a
/// newer version exists and – like Ionic's `updateAvailable` signal – exposes
/// an "Update installieren" action:
/// * iOS: public iTunes lookup API → opens the App Store page.
/// * Android: Google Play In-App Updates API (immediate update), falling back
///   to the Play Store page.
/// Web keeps the service-worker update flow (`app_update_service_web.dart`).
class StoreUpdateService {
  StoreUpdateService({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Bundle id / applicationId of the Flutter app.
  static const bundleId = 'de.attendix.attendix';

  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=$bundleId';

  /// Returns the action that installs the update, or null when the app is
  /// up to date (or the store could not be asked). Never throws.
  Future<Future<void> Function()?> check() async {
    if (!isNativeApp) return null;
    try {
      if (isNativeIos) return await _checkIos();
      if (isNativeAndroid) return await _checkAndroid();
    } catch (e) {
      if (kDebugMode) debugPrint('[StoreUpdate] check failed: $e');
    }
    return null;
  }

  Future<Future<void> Function()?> _checkIos() async {
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'bundleId': bundleId,
      // cache-buster like Ionic's manifest fetch
      't': '${DateTime.now().millisecondsSinceEpoch}',
    });
    final client = _client ?? http.Client();
    try {
      final res = await client.get(uri);
      if (res.statusCode != 200) return null;
      final store = parseItunesLookup(res.body);
      if (store == null) return null;
      if (compareVersions(store.version, AppConstants.appVersion) <= 0) return null;
      return () => _openStore(store.url);
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<Future<void> Function()?> _checkAndroid() async {
    if (!await impl.playUpdateAvailable()) return null;
    return () async {
      if (await impl.performPlayUpdate()) return;
      await _openStore(playStoreUrl);
    };
  }

  static Future<void> _openStore(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('[StoreUpdate] open store failed: $e');
    }
  }

  /// Parses an iTunes lookup response into store version and App Store URL.
  static ({String version, String url})? parseItunesLookup(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map || json['resultCount'] == 0) return null;
      final results = json['results'];
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final version = first['version'];
      final url = first['trackViewUrl'];
      if (version is! String || url is! String || version.isEmpty) return null;
      return (version: version, url: url);
    } catch (_) {
      return null;
    }
  }

  /// Numeric "x.y.z" compare (Ionic `LiveUpdateService.compareVersions`).
  /// Returns -1 if `a < b`, 0 if equal, 1 if `a > b`.
  static int compareVersions(String a, String b) {
    List<int> parse(String v) =>
        v.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final av = parse(a);
    final bv = parse(b);
    final len = av.length > bv.length ? av.length : bv.length;
    for (var i = 0; i < len; i++) {
      final x = i < av.length ? av[i] : 0;
      final y = i < bv.length ? bv[i] : 0;
      if (x > y) return 1;
      if (x < y) return -1;
    }
    return 0;
  }
}
