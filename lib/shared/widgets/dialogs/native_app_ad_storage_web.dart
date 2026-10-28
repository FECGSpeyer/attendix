import 'package:web/web.dart' as web;

/// LINKS_STARTUP: same raw localStorage key as Ionic
/// (`native_app_ad_shown`), so users who already saw the alert in the Ionic
/// app on attendix.de do not get it again.
const String _key = 'native_app_ad_shown';

bool nativeAppAdWasShown() {
  try {
    return web.window.localStorage.getItem(_key) != null;
  } catch (_) {
    return true; // Storage blocked: never nag.
  }
}

void markNativeAppAdShown() {
  try {
    web.window.localStorage.setItem(_key, 'true');
  } catch (_) {}
}

bool isIosUserAgent() {
  try {
    return RegExp('iPad|iPhone|iPod').hasMatch(web.window.navigator.userAgent);
  } catch (_) {
    return false;
  }
}
