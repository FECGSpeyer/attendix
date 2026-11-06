import 'pwa_platform.dart';
export 'pwa_platform.dart';

/// PWA detection service stub for non-web platforms
class PwaService {
  /// Check if app is running in standalone mode (installed as PWA)
  bool isPwaInstalled() => true; // Native apps are "installed"

  /// Check if running on mobile web (potential PWA install candidate)
  bool isMobileWeb() => false;

  /// Detect platform for showing appropriate install instructions
  PwaPlatform getPlatform() => PwaPlatform.unknown;

  /// Should show PWA install hint
  bool shouldShowInstallHint() => false;

  /// Whether the browser opens Android `intent://` links (Chromium on
  /// Android), falling back to their page when the app is missing.
  bool opensAndroidIntents() => false;
}
