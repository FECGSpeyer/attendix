import 'package:flutter/foundation.dart';

/// LINKS_STARTUP: outside the browser the ad is never shown.
bool nativeAppAdWasShown() => true;

void markNativeAppAdShown() {}

bool isIosUserAgent() => defaultTargetPlatform == TargetPlatform.iOS;
