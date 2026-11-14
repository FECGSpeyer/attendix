import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../data/auth_flow_service.dart';

bool _alertOpen = false;

/// Ionic app.component `presentPasswordRecoveryAlert()` after a recovery
/// link or a `PASSWORD_RECOVERY` event: navigate to /login (the login flow
/// then opens the start page) and show the alert "Neues Passwort" on top.
///
/// Like Ionic only one alert at a time. The alert is shown on the root
/// navigator; when the login flow replaces the page below it while it is
/// open (e.g. the instance is opened), it is shown again on the new page.
Future<void> presentPasswordRecoveryAlert(AuthFlowService authFlow, GoRouter router) async {
  if (_alertOpen) return;
  _alertOpen = true;
  try {
    router.go('/login');
    // Ionic: closes on "Abbrechen", a tap outside or after the update.
    var closedByUser = false;
    // While the password update runs, "Abbrechen", a tap outside and back
    // are ignored.
    var busy = false;
    BuildContext? shownDialog;

    // Pops only the alert itself: once it is no longer the current route
    // (already popped, or replaced by a page change) a pop would close the
    // page below.
    void popShownDialog() {
      final dialogContext = shownDialog;
      if (dialogContext == null || !dialogContext.mounted) return;
      if (ModalRoute.of(dialogContext)?.isCurrent == true) {
        Navigator.of(dialogContext).pop();
      }
    }

    void close() {
      if (busy) return;
      closedByUser = true;
      popShownDialog();
    }

    // Reported even when the alert that sent the request was replaced in the
    // meantime, so it is not shown again after the update.
    void succeeded(String message) {
      busy = false;
      closedByUser = true;
      final dialogContext = shownDialog;
      if (dialogContext != null && dialogContext.mounted) {
        ToastHelper.showSuccess(dialogContext, message);
      }
      popShownDialog();
    }

    for (var attempt = 0; attempt < 5 && !closedByUser; attempt++) {
      await SchedulerBinding.instance.endOfFrame;
      if (closedByUser) break;
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.mounted) continue;
      // Closing by the user (buttons, tap outside, back) is tracked
      // explicitly: a route removed by a page change looks like a pop too.
      await showAppDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          shownDialog = dialogContext;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) close();
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: close),
                ),
                PasswordRecoveryDialog(
                  authFlow: authFlow,
                  onClose: close,
                  onSuccess: succeeded,
                  onBusyChanged: (value) => busy = value,
                ),
              ],
            ),
          );
        },
      );
    }
  } finally {
    _alertOpen = false;
  }
}

/// The alert: header "Neues Passwort", one password input (placeholder
/// "Min. 6 Zeichen eingeben..."), buttons Abbrechen / Passwort ändern. It
/// stays open on a too short password or a failed update so the user can
/// retry without losing the recovery session.
class PasswordRecoveryDialog extends StatefulWidget {
  const PasswordRecoveryDialog({
    super.key,
    required this.authFlow,
    required this.onClose,
    required this.onSuccess,
    required this.onBusyChanged,
  });

  final AuthFlowService authFlow;

  /// Closes the alert ("Abbrechen"; ignored while the update runs).
  final VoidCallback onClose;

  /// Successful update with its toast message; called even when this alert
  /// is no longer mounted. Shows the toast and closes the alert.
  final ValueChanged<String> onSuccess;

  /// The update request starts (true) or finishes (false).
  final ValueChanged<bool> onBusyChanged;

  @override
  State<PasswordRecoveryDialog> createState() => _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<PasswordRecoveryDialog> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    if (!_busy) widget.onClose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final password = _controller.text;
    if (password.length < 6) {
      ToastHelper.showError(context, context.l10n.appPasswordMin);
      return;
    }
    final onSuccess = widget.onSuccess;
    final onBusyChanged = widget.onBusyChanged;
    _busy = true;
    onBusyChanged(true);
    final (ok, message) = await widget.authFlow.updatePassword(password);
    _busy = false;
    onBusyChanged(false);
    if (ok) {
      onSuccess(message);
    } else if (mounted) {
      ToastHelper.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (useIosLook(context)) {
      return IosAlertCard(
        title: Text(l10n.appNewPassword),
        // ios27 `.alert-message:empty { padding: 0 0 12px }` above the inputs
        // (Beta keeps its spacing).
        contentPadding: EdgeInsets.fromLTRB(16, context.rdSkin == null ? 12 : 0, 16, 21),
        content: IosAlertInput(
          controller: _controller,
          placeholder: l10n.appMinSixPlaceholder,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => _confirm(),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: IosAlertButton(
                  bold: false,
                  onPressed: _cancel,
                  child: _OneLine(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: IosAlertButton(
                  bold: false,
                  onPressed: _confirm,
                  child: _OneLine(l10n.appChangePassword),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // md alert: the shared underlined alert input (like "Passwort
    // zurücksetzen"); Beta keeps its field.
    final theme = Theme.of(context);
    final line = UnderlineInputBorder(borderSide: BorderSide(color: theme.dividerColor));
    return AppAlertDialog(
      title: Text(l10n.appNewPassword),
      content: AppAlertInput(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        onSubmitted: (_) => _confirm(),
        placeholder: l10n.appMinSixPlaceholder,
        betaDecoration: InputDecoration(
          hintText: l10n.appMinSixPlaceholder,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: line,
          enabledBorder: line,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(l10n.commonCancel.toUpperCase())),
        TextButton(onPressed: _confirm, child: Text(l10n.appChangePassword.toUpperCase())),
      ],
    );
  }
}

/// Button label on one line (the iOS alert card is narrower than Ionic's).
class _OneLine extends StatelessWidget {
  const _OneLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
}
