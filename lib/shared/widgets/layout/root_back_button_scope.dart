import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/native/native_platform.dart';

/// NATIVE_MISC: Android hardware back button at the root tabs.
///
/// Ionic (@capacitor/app + ion-router-outlet): back pops the page stack and,
/// once nothing is left to pop, exits the app (`App.exitApp()`). go_router
/// already pops the nested tab navigator first, so this scope is only asked
/// when a root tab is showing – then it closes the app via
/// [SystemNavigator.pop], even if older routes (e.g. login) are still below
/// the shell in the root navigator.
///
/// Web/PWA and iOS: inactive (browser back / swipe gestures unchanged).
class RootBackButtonScope extends StatelessWidget {
  const RootBackButtonScope({
    super.key,
    required this.child,
    this.enabled,
    this.onExit,
  });

  final Widget child;

  /// Defaults to [isNativeAndroid]; tests set it explicitly.
  final bool? enabled;

  /// Defaults to [SystemNavigator.pop] (Ionic `App.exitApp()`).
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final active = enabled ?? isNativeAndroid;
    if (!active) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (onExit != null) {
          onExit!();
          return;
        }
        try {
          SystemNavigator.pop();
        } catch (_) {
          // Platform without a system navigator.
        }
      },
      child: child,
    );
  }
}
