import 'package:web/web.dart' as web;

import 'auth_redirect_path.dart';

/// AUTH: removes auth tokens (token_hash, code, …) from the browser URL so a
/// reload does not try to consume the one-time link again (Ionic
/// `window.history.replaceState({}, '', '/login')`).
void clearAuthParamsFromBrowserUrl() {
  try {
    web.window.history
        .replaceState(null, '', appBasePath(web.window.location.pathname));
  } catch (_) {
    // Ignore – purely cosmetic.
  }
}
