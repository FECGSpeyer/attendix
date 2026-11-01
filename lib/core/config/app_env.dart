import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only env file bundled into the app (client keys, see pubspec assets).
const appEnvFileName = '.env.app';

/// PWA_OFFLINE: web copy of [appEnvFileName] for an offline start.
@visibleForTesting
const appEnvCacheKey = 'app_env_cache_v1';

/// Keys without which the app cannot start (SupabaseConfig.initialize).
@visibleForTesting
const appEnvRequiredKeys = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];

/// Whether [text] holds a non-empty value for every [appEnvRequiredKeys].
@visibleForTesting
bool isUsableAppEnv(String? text) {
  if (text == null || text.trim().isEmpty) return false;
  final values = const Parser().parse(text.split('\n'));
  return appEnvRequiredKeys.every((k) => (values[k] ?? '').trim().isNotEmpty);
}

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

  // SOL (#270): only a complete file replaces the stored copy – a broken
  // deploy (empty anon key) must not destroy the working offline config.
  final usable = isUsableAppEnv(text);
  if (usable) {
    dotenv.testLoad(fileInput: text!);
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

  if (isWeb) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(appEnvCacheKey);
      if (isUsableAppEnv(cached)) {
        dotenv.testLoad(fileInput: cached!);
        return;
      }
    } catch (_) {}
  }
  // Nothing usable: load what there is, SupabaseConfig reports the gap.
  if (text != null && text.trim().isNotEmpty) dotenv.testLoad(fileInput: text);
}
