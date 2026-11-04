import 'package:flutter/widgets.dart';

import 'toast_helper.dart';

/// Ionic `Utils.showToast(..., 'danger')` from services: error toasts that
/// do not depend on the calling page (e.g. "Fehler beim Laden der Kirchen"
/// wherever the list fails to load).
///
/// [contextResolver] is set once by the app (root navigator context of the
/// router); without it (tests, before the first frame) nothing is shown.
class GlobalToast {
  GlobalToast._();

  static BuildContext? Function()? contextResolver;

  static void error(String message) {
    final context = contextResolver?.call();
    if (context == null || !context.mounted) return;
    ToastHelper.showError(context, message);
  }
}
