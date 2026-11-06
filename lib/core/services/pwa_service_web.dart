import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'pwa_platform.dart';
export 'pwa_platform.dart';

/// PWA detection service for web platform
class PwaService {
  /// Check if app is running in standalone mode (installed as PWA)
  bool isPwaInstalled() {
    if (!kIsWeb) return true; // Native apps are "installed"

    try {
      // Check display-mode: standalone
      if (web.window
          .matchMedia('(display-mode: standalone)')
          .matches) {
        return true;
      }

      // Check navigator.standalone (iOS Safari)
      final standalone = _getNavigatorStandalone();
      if (standalone == true) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if running on mobile web (potential PWA install candidate)
  bool isMobileWeb() {
    if (!kIsWeb) return false;

    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      return userAgent.contains('iphone') ||
          userAgent.contains('ipad') ||
          userAgent.contains('android');
    } catch (_) {
      return false;
    }
  }

  /// Whether the browser opens Android `intent://` links (Chromium on
  /// Android, not in an in-app WebView), falling back to their page when
  /// the app is missing.
  bool opensAndroidIntents() {
    if (!kIsWeb) return false;
    try {
      final ua = web.window.navigator.userAgent.toLowerCase();
      return ua.contains('android') && ua.contains('chrome/') && !ua.contains('; wv)') && !ua.contains('firefox');
    } catch (_) {
      return false;
    }
  }

  /// Detect platform for showing appropriate install instructions
  PwaPlatform getPlatform() {
    if (!kIsWeb) return PwaPlatform.unknown;

    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
        return PwaPlatform.ios;
      }
      if (userAgent.contains('android')) {
        return PwaPlatform.android;
      }
      return PwaPlatform.desktop;
    } catch (_) {
      return PwaPlatform.unknown;
    }
  }

  /// Should show PWA install hint
  bool shouldShowInstallHint() {
    return kIsWeb && isMobileWeb() && !isPwaInstalled();
  }
}

/// JS interop to check navigator.standalone (iOS Safari)
@JS('window.navigator.standalone')
external bool? get _jsNavigatorStandalone;

bool? _getNavigatorStandalone() {
  try {
    return _jsNavigatorStandalone;
  } catch (_) {
    return null;
  }
}
