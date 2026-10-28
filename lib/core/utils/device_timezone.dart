/// IANA timezone of the device (Ionic register.page:
/// `Intl.DateTimeFormat().resolvedOptions().timeZone`).
///
/// On the web the browser's zone is read via JS interop. Native platforms
/// cannot read the IANA name without a plugin, so they return null and the
/// caller falls back to its default.
library;

export 'device_timezone_stub.dart'
    if (dart.library.js_interop) 'device_timezone_web.dart';
