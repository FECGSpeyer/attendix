import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// REDESIGN: the home screen icon in the colours of the Farbwelt.
///
/// Only the iOS app can switch its icon (alternate icons in
/// ios/Runner/Assets.xcassets, AppIconPlugin in ios/Runner/AppDelegate.swift,
/// MethodChannel `de.attendix/app_icon`). iOS shows a short notice after
/// every change, so the icon is only set when it differs.
class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('de.attendix/app_icon');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Sets the alternate icon [name]; null: the default icon.
  static Future<bool> setIcon(String? name) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('set', name) ?? false;
    } catch (e) {
      debugPrint('AppIconService.setIcon($name) failed: $e');
      return false;
    }
  }
}
