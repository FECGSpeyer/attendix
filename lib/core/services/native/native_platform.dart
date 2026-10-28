import 'package:flutter/foundation.dart';

import 'native_platform_stub.dart'
    if (dart.library.io) 'native_platform_io.dart' as impl;

/// NATIVE_MISC: true when running inside the installed iOS/Android app
/// (Ionic `Capacitor.isNativePlatform()`), false on web/PWA, desktop and in
/// unit tests.
///
/// Uses the real host OS (dart:io `Platform`), not [defaultTargetPlatform],
/// so tests – which default to TargetPlatform.android – stay on the web/desktop
/// code paths unless they set [debugIsNativeAppOverride].
bool get isNativeApp {
  if (kIsWeb) return false;
  return debugIsNativeAppOverride ?? impl.hostIsNativeMobile;
}

/// True inside the installed iOS app (Ionic `Capacitor.getPlatform() === 'ios'`).
bool get isNativeIos =>
    isNativeApp && defaultTargetPlatform == TargetPlatform.iOS;

/// True inside the installed Android app.
bool get isNativeAndroid =>
    isNativeApp && defaultTargetPlatform == TargetPlatform.android;

/// Test hook: forces [isNativeApp] (null = detect).
@visibleForTesting
bool? debugIsNativeAppOverride;
