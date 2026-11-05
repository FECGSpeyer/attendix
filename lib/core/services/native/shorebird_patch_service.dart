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
