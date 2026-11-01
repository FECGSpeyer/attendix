import 'package:flutter/foundation.dart';

/// PWA_UPDATE: whether a new version is announced with a toast / banner /
/// login button.
///
/// The web app does not: a new version loads in the background and takes
/// over at the next start (service worker, web/index.html), so nobody is
/// interrupted while using the app; "Update installieren" in the settings
/// stays for those who want it now. The native apps still announce a store
/// update, which they cannot install themselves.
bool showUpdateHint(bool updateAvailable, {bool isWeb = kIsWeb}) =>
    updateAvailable && !isWeb;
