import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../shared/widgets/adaptive/adaptive_platform.dart' show useIosLook;
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
  ///
  /// REVIEW_FIX2: called from the root widget, whose context sits above
  /// MaterialApp (no ScaffoldMessenger / localizations there), so it takes
  /// the root messenger and uses the context-free l10n.
  static void showUpdateAvailable(
    ScaffoldMessengerState? messenger, {
    required VoidCallback onUpdate,
  }) {
    if (messenger == null) return;
    final l10n = l10nWithoutContext;
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.coreFlutterNewVersionAvailable,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 365), // Persistent - won't auto-dismiss
        action: SnackBarAction(
          label: l10n.coreFlutterUpdate,
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
    // MD_SWEEP: md (desktop / Android) shows the Ionic md toast.
    if (!useIosLook(context)) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay != null) {
        showIonMdToast(overlay, message, color: _ionColorFor(backgroundColor));
        return;
      }
    }
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


/// MD_SWEEP: the Ionic colour of a [ToastHelper] toast (Utils.showToast
/// passes `success` / `danger` / `warning`; info has no colour).
Color? _ionColorFor(Color? background) {
  if (background == Colors.green) return AppColors.success;
  if (background == Colors.red) return AppColors.danger;
  if (background == Colors.orange) return AppColors.warning;
  return null;
}

OverlayEntry? _mdToastEntry;

/// MD_SWEEP: Ionic md `ion-toast` as Utils.showToast creates it
/// (`position: 'top'`, `duration: 3000`, a colour, no buttons): a card 8px
/// below the top (+ safe area), centred, at most 700px wide with 8px side
/// margins, radius 4, the md elevation-6 shadow, 14px / 20px text with
/// 16 × 14 padding. With [color] it is filled with that Ionic colour (dark
/// mode palette in dark mode) and its contrast text; without, the md
/// default #333 (dark #d0d0d0) with step-50 text. A new toast replaces the
/// previous one.
void showIonMdToast(
  OverlayState overlay,
  String message, {
  Color? color,
  Duration duration = const Duration(milliseconds: 3000),
}) {
  final previous = _mdToastEntry;
  if (previous != null && previous.mounted) {
    try {
      previous.remove();
    } catch (_) {}
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => IonMdToast(
      message: message,
      color: color,
      duration: duration,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_mdToastEntry, entry)) _mdToastEntry = null;
      },
    ),
  );
  _mdToastEntry = entry;
  overlay.insert(entry);
}

/// MD_SWEEP: the md toast card of [showIonMdToast].
class IonMdToast extends StatefulWidget {
  const IonMdToast({
    super.key,
    required this.message,
    this.color,
    this.duration = const Duration(milliseconds: 3000),
    this.onDismissed,
  });

  final String message;
  final Color? color;
  final Duration duration;
  final VoidCallback? onDismissed;

  @override
  State<IonMdToast> createState() => _IonMdToastState();
}

class _IonMdToastState extends State<IonMdToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final dark = b == Brightness.dark;
    final base = widget.color == null
        ? null
        : AppColors.forBrightness(widget.color!, b);
    final background = base ??
        (dark ? const Color(0xFFD0D0D0) : const Color(0xFF333333));
    final textColor = base != null
        ? (base == AppColors.warning || base == AppColors.warningOnDark
            ? Colors.black
            : Colors.white)
        : (dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2));
    final top = MediaQuery.paddingOf(context).top + 8;
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return Positioned(
      top: top,
      left: 8,
      right: 8,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, -0.5), end: Offset.zero)
                    .animate(curved),
                child: Material(
                  color: background,
                  elevation: 6,
                  shadowColor: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
