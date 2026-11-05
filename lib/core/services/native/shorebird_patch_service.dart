import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'native_platform.dart';

/// SHOREBIRD: number of the Shorebird code push patch the app is running.
///
/// The store apps (iOS/Android) are built with `shorebird release`; Dart-only
/// changes then ship as patches (see docs/release/shorebird.md). Downloading
/// is done by the Shorebird engine itself (`auto_update: true` in
/// shorebird.yaml): in the background on app start, active from the next
/// start. This service only reads the current patch number, e.g. for the
/// version label and Sentry.
///
/// Returns null on the web, on desktop, in builds made with `flutter build`
/// / `flutter run` (no Shorebird engine), when no patch is installed and on
/// any error. Never throws.
Future<int?> readShorebirdPatchNumber() async {
  if (kIsWeb || !isNativeApp) return null;
  try {
    final updater = ShorebirdUpdater();
    if (!updater.isAvailable) return null;
    final patch = await updater.readCurrentPatch();
    return patch?.number;
  } catch (e) {
    if (kDebugMode) debugPrint('[Shorebird] reading patch failed: $e');
    return null;
  }
}

DateTime? _lastResumeCheck;
bool _resumeCheckRunning = false;

/// SHOREBIRD: when the app returns from the background, look for a new patch
/// and download it silently (at most every 30 minutes). Like `auto_update` on
/// a cold start, the patch only becomes active on the next app start: no
/// dialog, no restart, nothing visible. Without this, a patch needs two cold
/// starts (download, then activate); with it, usually one.
///
/// No-op on the web, on desktop and in builds without the Shorebird engine.
/// Never throws.
Future<void> checkShorebirdPatchOnResume({DateTime? now}) async {
  if (kIsWeb || !isNativeApp || _resumeCheckRunning) return;
  final time = now ?? DateTime.now();
  final last = _lastResumeCheck;
  if (last != null && time.difference(last) < const Duration(minutes: 30)) {
    return;
  }
  _lastResumeCheck = time;
  _resumeCheckRunning = true;
  try {
    final updater = ShorebirdUpdater();
    if (!updater.isAvailable) return;
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.outdated) await updater.update();
  } catch (e) {
    if (kDebugMode) debugPrint('[Shorebird] resume check failed: $e');
  } finally {
    _resumeCheckRunning = false;
  }
}
