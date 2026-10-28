import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'demo_guard.dart';

/// Helper class for showing toast messages (SnackBars)
///
/// Based on Ionic Utils.ts showToast method
class ToastHelper {
  /// Shows a success toast with green background
  static void showSuccess(BuildContext context, String message) {
    // DEMO_GUARD: the operation was blocked (notifiers may swallow the
    // DemoModeException); don't claim success right after the demo toast.
    if (DemoGuard.recentlyShown) return;
    _showToast(
      context,
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  /// Shows an error toast with red background
  static void showError(BuildContext context, String message) {
    // DEMO_GUARD: a blocked demo mutation already showed Ionic's warning
    // toast; don't stack the generic error toast of the same operation.
    if (DemoGuard.recentlyShown) return;
    if (message.contains(kDemoRestrictedMessage)) {
      showDemoRestricted(context);
      return;
    }
    _showToast(
      context,
      message,
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  }

  /// Shows an info toast with default background
  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: Icons.info,
    );
  }

  /// Shows a warning toast with orange background
  static void showWarning(BuildContext context, String message) {
    _showToast(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning,
    );
  }

  /// DEMO_GUARD: Ionic `Utils.showToast(translate('people.demoUnavailable'),
  /// 'warning')`.
  static void showDemoRestricted(BuildContext context) {
    showWarning(context, kDemoRestrictedMessage);
  }

  /// Shows a persistent update available snackbar (does not auto-dismiss)
  static void showUpdateAvailable(
    BuildContext context, {
    required VoidCallback onUpdate,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.coreFlutterNewVersionAvailable,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 365), // Persistent - won't auto-dismiss
        action: SnackBarAction(
          label: context.l10n.coreFlutterUpdate,
          textColor: Colors.white,
          onPressed: onUpdate,
        ),
      ),
    );
  }

  static void _showToast(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: SnackBarAction(
          label: context.l10n.commonOk,
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
