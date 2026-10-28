import 'package:in_app_update/in_app_update.dart';

/// NATIVE_MISC: Google Play In-App Updates – is a newer version published?
Future<bool> playUpdateAvailable() async {
  final info = await InAppUpdate.checkForUpdate();
  return info.updateAvailability == UpdateAvailability.updateAvailable &&
      info.immediateUpdateAllowed;
}

/// NATIVE_MISC: runs the Play immediate update flow; false when it could not
/// be started or the user cancelled it.
Future<bool> performPlayUpdate() async {
  try {
    final result = await InAppUpdate.performImmediateUpdate();
    return result == AppUpdateResult.success;
  } catch (_) {
    return false;
  }
}
