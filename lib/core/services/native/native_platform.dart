import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

const _platformInfoChannel = MethodChannel('de.attendix/platform_info');
bool? _iosAppOnMac;

/// Ionic 4.17.20 `Utils.isIosAppOnMac`: the iPhone/iPad app installed on an
/// Apple silicon Mac reports itself as iOS, but the native file preview
/// shows nothing there. Asks iOS (`ProcessInfo.isiOSAppOnMac`, channel
/// `de.attendix/platform_info` in ios/Runner/AppDelegate.swift); false on
/// every other platform and when the channel is missing. Cached.
Future<bool> isIosAppOnMac() async {
  final override = debugIsIosAppOnMacOverride;
  if (override != null) return override;
  if (!isNativeIos) return false;
  final cached = _iosAppOnMac;
  if (cached != null) return cached;
  try {
    return _iosAppOnMac =
        await _platformInfoChannel.invokeMethod<bool>('isiOSAppOnMac') ?? false;
  } catch (_) {
    return _iosAppOnMac = false;
  }
}

/// Test hook: forces [isIosAppOnMac] (null = detect).
@visibleForTesting
bool? debugIsIosAppOnMacOverride;
