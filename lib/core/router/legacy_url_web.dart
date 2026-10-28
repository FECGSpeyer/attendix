import 'package:web/web.dart' as web;

import 'legacy_routes.dart';

/// LINKS_STARTUP: the app uses the hash URL strategy, so path links
/// (`https://attendix.de/tabs/messages/5`, `/open-attendance?id=…`,
/// `/open-file?…`) are rewritten to `/#/tabs/messages/5` before the router
/// reads the initial location. Must run before `runApp`.
void promoteLegacyPathToHash() {
  try {
    final base = Uri.parse(web.document.baseURI).path;
    final target = legacyPathToHashUrl(
      Uri.parse(web.window.location.href),
      basePath: base.isEmpty ? '/' : base,
    );
    if (target != null) web.window.history.replaceState(null, '', target);
  } catch (_) {
    // Keep the URL as it is.
  }
}
