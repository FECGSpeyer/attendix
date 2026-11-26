import 'package:flutter/material.dart';

import 'app_dialog.dart' show showAppDialog;
import 'app_spinner.dart';

/// Handle of an open [showIonLoading] overlay.
class IonLoadingController {
  IonLoadingController._(this._navigator);

  final NavigatorState _navigator;
  Route<void>? _route;
  bool _dismissed = false;

  set message(String? value) {}

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    final route = _route;
    if (route == null || !route.isActive) return;
    route.isCurrent ? _navigator.pop() : _navigator.removeRoute(route);
  }
}

/// Blocking spinner overlay.
IonLoadingController showIonLoading(BuildContext context, {String? message}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final controller = IonLoadingController._(navigator);
  showAppDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) {
      if (controller._route == null) {
        final route = controller._route = ModalRoute.of(ctx);
        if (controller._dismissed && route != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (route.isActive) navigator.removeRoute(route);
          });
        }
      }
      return const PopScope(
        canPop: false,
        child: Center(child: AppSpinner()),
      );
    },
  );
  return controller;
}

/// Runs [work] under [showIonLoading] and closes it afterwards.
Future<T> withIonLoading<T>(
  BuildContext context,
  Future<T> Function() work, {
  String? message,
}) async {
  final loading = showIonLoading(context, message: message);
  try {
    return await work();
  } finally {
    loading.dismiss();
  }
}
