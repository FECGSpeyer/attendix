import 'package:web/web.dart' as web;

import 'auth_redirect_path.dart';

/// AUTH: removes auth tokens (token_hash, code, …) from the browser URL so a
/// reload does not try to consume the one-time link again (Ionic
/// `window.history.replaceState({}, '', '/login')`).
void clearAuthParamsFromBrowserUrl() {
  try {
    // REVIEW_FIX2: keep the `#/route` (hash URL strategy), drop only the
    // auth params, so go_router's location and the browser URL stay in sync.
    web.window.history.replaceState(
      null,
      '',
      appBasePath(web.window.location.pathname) +
          cleanedAuthHash(web.window.location.hash),
    );
  } catch (_) {
    // Ignore – purely cosmetic.
  }
}
