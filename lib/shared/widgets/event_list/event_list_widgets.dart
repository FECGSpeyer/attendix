import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/native/native_file_service.dart';
import '../../../core/utils/event_list_utils.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart';

/// Opens Google Maps (or Apple Maps on iOS after a choice) for a place.
Future<void> openEventNavigation(BuildContext context, String place) async {
  Future<void> open(Uri uri) async {
    try {
      if (kIsWeb) {
        await NativeFileService.openExternal(uri);
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('openEventNavigation failed: $e');
    }
  }

  // Also true for iOS browsers (PWA).
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;
  if (!isIos) {
    await open(EventListUtils.navigationUrl(place));
    return;
  }
  final apple = await showAppActionSheet<bool>(
    context,
    actions: [
      AppActionSheetAction(value: true, label: context.l10n.commonAppleMaps),
      const AppActionSheetAction(value: false, label: 'Google Maps'),
    ],
  );
  if (apple == null) return;
  await open(EventListUtils.navigationUrl(place, apple: apple));
}

/// Opens an attachment URL in the browser.
Future<void> openEventAttachment(String url) async {
  try {
    await NativeFileService.openLinkInApp(Uri.parse(url));
  } catch (e) {
    if (kDebugMode) debugPrint('openEventAttachment failed: $e');
  }
}
