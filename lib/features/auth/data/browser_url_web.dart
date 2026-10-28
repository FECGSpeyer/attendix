import 'package:web/web.dart' as web;

/// AUTH: removes auth tokens (token_hash, code, …) from the browser URL so a
/// reload does not try to consume the one-time link again (Ionic
/// `window.history.replaceState({}, '', '/login')`).
void clearAuthParamsFromBrowserUrl() {
  try {
    final path = web.window.location.pathname;
    web.window.history.replaceState(null, '', path);
  } catch (_) {
    // Ignore – purely cosmetic.
  }
}
