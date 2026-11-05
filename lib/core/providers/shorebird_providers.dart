import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../services/native/shorebird_patch_service.dart';

/// SHOREBIRD: installed code push patch number (null without patch, on the
/// web and in non-Shorebird builds). Read once; a newly downloaded patch only
/// becomes active on the next app start.
final shorebirdPatchProvider = FutureProvider<int?>((ref) {
  return readShorebirdPatchNumber();
});

/// App version as shown in the settings ("Was ist neu"):
/// `5.0.0`, or `5.0.0 (Patch 2)` while a Shorebird patch is running.
final appVersionLabelProvider = Provider<String>((ref) {
  final patch = ref.watch(shorebirdPatchProvider).valueOrNull;
  return appVersionLabel(patch);
});

/// [AppConstants.appVersion] with ` (Patch N)` appended when [patch] is set.
String appVersionLabel(int? patch) => patch == null
    ? AppConstants.appVersion
    : '${AppConstants.appVersion} (Patch $patch)';
