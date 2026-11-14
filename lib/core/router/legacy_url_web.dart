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
  }
}
