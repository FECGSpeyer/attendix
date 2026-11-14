import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'legacy_routes.dart';

/// LINKS_STARTUP: the app uses the hash URL strategy, so path links
/// (`https://attendix.de/tabs/messages/5`, `/open-attendance?id=…`,
/// `/open-file?…`) are rewritten to `/#/tabs/messages/5` before the router
/// reads the initial location. Must run before `runApp`.
void promoteLegacyPathToHash() {
  try {
    final base = Uri.parse(web.document.baseURI).path;
    final current = Uri.parse(web.window.location.href);
    // OEFF-41: a fragment that is no route (Supabase `#error=…` /
    // `#access_token=…`) would leave go_router without a start location.
    final cleaned =
        nonRouteFragmentUrl(current, basePath: base.isEmpty ? '/' : base);
    if (cleaned != null) {
      startupLinkUri = current;
      web.window.history.replaceState(null, '', cleaned);
      return;
    }
    final target = legacyPathToHashUrl(
      current,
      basePath: base.isEmpty ? '/' : base,
    );
    if (target != null) web.window.history.replaceState(null, '', target);
  } catch (_) {
    // Keep the URL as it is.
  } finally {
    _cleanNonRouteHashWhileRunning();
  }
}

/// NACHTEST-A-91: the cleanup above only runs before `runApp`. A fragment
/// that is no route typed into the running app (`#foo=bar`) reached the
/// router as a relative location (RangeError, address stays). Registered
/// before the engine's own `popstate` listener (created with the router), so
/// the engine then reads the cleaned `#/login` – the same start a fresh load
/// with that fragment gets (signed in, `/login` leads to the start page).
void _cleanNonRouteHashWhileRunning() {
  web.window.addEventListener(
    'popstate',
    ((web.Event _) {
      try {
        final current = Uri.parse(web.window.location.href);
        if (current.fragment.isEmpty || current.fragment.startsWith('/')) return;
        final base = Uri.parse(web.document.baseURI).path;
        final cleaned =
            nonRouteFragmentUrl(current, basePath: base.isEmpty ? '/' : base);
        if (cleaned == null) return;
        web.window.history.replaceState(
            null, '', cleaned.contains('#') ? cleaned : '$cleaned#/login');
      } catch (_) {
        // Keep the URL as it is.
      }
    }).toJS,
  );
}
