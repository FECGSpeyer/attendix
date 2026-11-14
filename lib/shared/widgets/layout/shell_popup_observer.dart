import 'package:flutter/widgets.dart';

/// F-RAHMEN-08 / F-EINST-10 / F-EINST-11 / ROLLEN-A-23: counts the popup
/// routes (sheets, dialogs, popovers) open on the shell navigator.
///
/// The classic iOS shell draws its floating tab bar above the shell
/// navigator, so a sheet opened on that navigator lay UNDER the bar, which
/// stayed bright and tappable. Ionic overlays always cover the tab bar; the
/// shell hides the bar while [popupOpen] is true.
class ShellPopupObserver extends NavigatorObserver {
  /// One observer per router (a NavigatorObserver may only watch one
  /// navigator); the newest one is the one the shell listens to.
  ShellPopupObserver() {
    current = this;
  }

  /// The observer of the newest app router's tab shell navigator.
  static ShellPopupObserver? current;

  /// Whether at least one popup route is open on the observed navigator.
  final ValueNotifier<bool> popupOpen = ValueNotifier(false);

  final Set<Route<dynamic>> _popups = {};

  void _add(Route<dynamic>? route) {
    if (route is PopupRoute) _popups.add(route);
    _sync();
  }

  void _remove(Route<dynamic>? route) {
    if (route != null) _popups.remove(route);
    _sync();
  }

  void _sync() {
    final open = _popups.isNotEmpty;
    if (popupOpen.value == open) return;
    // Navigator callbacks can arrive during a build; notify afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) => popupOpen.value = _popups.isNotEmpty);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _popups.remove(oldRoute);
    _add(newRoute);
  }
}
