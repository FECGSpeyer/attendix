import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only env file bundled into the app (client keys, see pubspec assets).
const appEnvFileName = '.env.app';

/// PWA_OFFLINE: web copy of [appEnvFileName] for an offline start.
@visibleForTesting
const appEnvCacheKey = 'app_env_cache_v1';

/// Loads [appEnvFileName] into [dotenv].
///
/// PWA_OFFLINE: Flutter's service worker leaves dotfiles out of its cache
/// list, so `assets/.env.app` is never cached and an installed PWA hung on
/// the splash screen offline (the Ionic PWA starts offline up to the login).
/// On web the file text is therefore also kept in local storage and used
/// when the asset cannot be fetched. The file only holds public client
/// values that are served with every page load anyway.
Future<void> loadAppEnv({AssetBundle? bundle, bool? web}) async {
  final isWeb = web ?? kIsWeb;
  String? text;
  try {
    text = await (bundle ?? rootBundle)
        .loadString(appEnvFileName, cache: false);
  } catch (e) {
    if (kDebugMode) debugPrint('Warning: Could not load $appEnvFileName: $e');
  }

  if (text != null && text.trim().isNotEmpty) {
    dotenv.testLoad(fileInput: text);
    if (isWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(appEnvCacheKey) != text) {
          await prefs.setString(appEnvCacheKey, text);
        }
      } catch (_) {
        // Storage unavailable (private mode): no offline start, app works.
      }
    }
    return;
  }

  if (!isWeb) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(appEnvCacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      dotenv.testLoad(fileInput: cached);
    }
  } catch (_) {}
}
