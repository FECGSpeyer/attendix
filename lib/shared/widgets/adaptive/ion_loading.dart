import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import 'adaptive_platform.dart';
import 'app_dialog.dart' show showAppDialog;
import 'app_spinner.dart';

/// Handle of an open [showIonLoading] overlay.
class IonLoadingController {
  IonLoadingController._(this._navigator, this._message);

  final NavigatorState _navigator;
  final ValueNotifier<String?> _message;
  Route<void>? _route;
  bool _dismissed = false;

  /// Ionic `loading.message = …` (e.g. the upload progress per file).
  set message(String? value) => _message.value = value;

  /// Ionic `loading.dismiss()`; safe to call more than once.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    final route = _route;
    if (route == null || !route.isActive) return;
    // On top: the normal (animated) pop; under another route: remove it.
    route.isCurrent ? _navigator.pop() : _navigator.removeRoute(route);
  }
}

/// Ionic `ion-loading` (`LoadingController.create({ message })`): a
/// blocking box over a dimmed backdrop with the spinner and the optional
/// [message] next to it.
///
/// * iOS: radius 8, padding 24 / 34, `step-100` box (#f9f9f9, dark
///   #1a1a1a), bold 14pt message, backdrop .3.
/// * md: radius 2, padding 24, `step-50` box (#f2f2f2, dark #1e1e1e) with
///   the md shadow, 14px message, backdrop .32.
///
/// The Beta design gets its old plain spinner without box.
///
/// ```dart
/// final loading = showIonLoading(context, message: l10n.filesSendingTelegram);
/// try { await work(); } finally { loading.dismiss(); }
/// ```
IonLoadingController showIonLoading(BuildContext context, {String? message}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final notifier = ValueNotifier<String?>(message);
  final controller = IonLoadingController._(navigator, notifier);
  final beta = context.rdSkin != null;
  final ios = useIosLook(context);
  showAppDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: beta ? null : Colors.black.withValues(alpha: ios ? 0.3 : 0.32),
    builder: (ctx) {
      if (controller._route == null) {
        final route = controller._route = ModalRoute.of(ctx);
        // Dismissed before the route was built: close it right away.
        if (controller._dismissed && route != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (route.isActive) navigator.removeRoute(route);
          });
        }
      }
      return PopScope(
        canPop: false,
        child: beta
            ? const Center(child: AppSpinner())
            : ValueListenableBuilder<String?>(
                valueListenable: notifier,
                builder: (_, text, __) => IonLoadingBox(message: text),
              ),
      );
    },
  ).whenComplete(notifier.dispose);
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

/// The box of an `ion-loading` (see [showIonLoading]).
class IonLoadingBox extends StatelessWidget {
  const IonLoadingBox({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = ios
        ? (dark ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9))
        : (dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2));
    final text = message;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ios ? 270 : 280),
        child: Material(
          color: background,
          elevation: ios ? 0 : 24,
          borderRadius: BorderRadius.circular(ios ? 8 : 2),
          child: Padding(
            padding: ios
                ? const EdgeInsets.symmetric(horizontal: 34, vertical: 24)
                : const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 28, height: 28, child: AppSpinner()),
                if (text != null && text.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: ios ? FontWeight.w600 : FontWeight.w400,
                        color: dark ? const Color(0xFFD9D9D9) : const Color(0xFF262626),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
