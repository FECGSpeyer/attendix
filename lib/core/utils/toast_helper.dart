import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'demo_guard.dart';

/// QUE-26: a button of a toast (Ionic `toastController.create({ buttons:
/// [{ text, handler }] })`), e.g. "Rückgängig". Tapping it closes the toast
/// and calls [onPressed].
class ToastAction {
  const ToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// QUE-26: the raw Material [SnackBar] a call site showed before it moved to
/// the Ionic toast of [ToastHelper]. The Beta design keeps exactly that
/// SnackBar (`beta:` of the `ToastHelper.show…` methods); the classic design
/// never shows it.
class LegacySnackBar {
  const LegacySnackBar({
    this.color,
    this.floating = false,
    this.duration,
    this.icon,
  });

  /// `SnackBar(content: Text(message))`.
  static const plain = LegacySnackBar();
  static const success = LegacySnackBar(color: AppColors.success);
  static const danger = LegacySnackBar(color: AppColors.danger);
  static const warning = LegacySnackBar(color: AppColors.warning);

  final Color? color;

  /// `behavior: SnackBarBehavior.floating`.
  final bool floating;
  final Duration? duration;

  /// White icon in front of the (then white) message.
  final IconData? icon;

  SnackBar build(String message) => SnackBar(
        content: icon == null
            ? Text(message)
            : Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        backgroundColor: color,
        behavior: floating ? SnackBarBehavior.floating : null,
        duration: duration ?? const Duration(milliseconds: 4000),
      );
}

/// Helper class for showing toast messages.
///
/// Ionic `Utils.showToast(message, color = 'success', duration = 3000)`:
/// `toastController.create({ message, color, position: 'top', duration })`
/// – a toast at the top in the Ionic colour, without an icon, gone after
/// 3 s. Every toast of the classic design goes through here (QUE-26); the
/// [BuildContext] may also be one above the navigator (root messenger), the
/// toast then uses the root navigator's overlay.
class ToastHelper {
  /// Shows a success toast (Ionic `color: 'success'`, the default).
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    ToastAction? action,
    LegacySnackBar? beta,
  }) {
    if (_betaSnackBar(context, message, beta)) return;
    // DEMO_GUARD: the operation was blocked (notifiers may swallow the
    // DemoModeException); don't claim success right after the demo toast.
    if (DemoGuard.recentlyShown) return;
    _showToast(
      context,
      message,
      backgroundColor: Colors.green,
      icon: AppIcons.checkCircle,
      duration: duration,
      action: action,
    );
  }

  /// Shows an error toast (Ionic `color: 'danger'`).
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    ToastAction? action,
    LegacySnackBar? beta,
  }) {
    if (_betaSnackBar(context, message, beta)) return;
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
      icon: AppIcons.error,
      duration: duration,
      action: action,
    );
  }

  /// Shows an info toast without a colour (Ionic default toast surface).
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    ToastAction? action,
    LegacySnackBar? beta,
  }) {
    if (_betaSnackBar(context, message, beta)) return;
    _showToast(
      context,
      message,
      icon: AppIcons.info,
      duration: duration,
      action: action,
    );
  }

  /// Shows a warning toast (Ionic `color: 'warning'`).
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
    ToastAction? action,
    LegacySnackBar? beta,
  }) {
    if (_betaSnackBar(context, message, beta)) return;
    _showToast(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: AppIcons.warning,
      duration: duration,
      action: action,
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
            Icon(AppIcons.systemUpdate, color: Colors.white),
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

  /// QUE-26: in the Beta design a call site that showed a raw SnackBar
  /// before keeps it ([legacy]); true when it was shown.
  static bool _betaSnackBar(
      BuildContext context, String message, LegacySnackBar? legacy) {
    if (legacy == null) return false;
    final messenger = context is StatefulElement &&
            context.state is ScaffoldMessengerState
        ? context.state as ScaffoldMessengerState
        : ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return false;
    messenger.showSnackBar(legacy.build(message));
    return true;
  }

  static void _showToast(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration? duration,
    ToastAction? action,
  }) {
    // MD_SWEEP: md (desktop / Android) shows the Ionic md toast.
    // x-7da97d6aac: the iOS look uses the root overlay too (Ionic ion-toast
    // sits above every modal); a SnackBar of the page Scaffold was hidden
    // behind any open bottom sheet.
    final above = Overlay.maybeOf(context, rootOverlay: true);
    // QUE-26: a context above the navigator (root messenger, the router's
    // navigator itself) has no overlay above it – take the navigator's.
    final overlay = above ?? _overlayBelow(context);
    if (overlay != null) {
      // The theme sits below the root messenger: read it at the overlay.
      final themed = above != null ? context : overlay.context;
      showToastOverlay(
        overlay,
        message,
        color: _ionColorFor(backgroundColor),
        ios: Theme.of(themed).platform == TargetPlatform.iOS,
        duration: duration ?? const Duration(milliseconds: 3000),
        action: action,
      );
      return;
    }
    // No navigator at all (bare widget tests): the Material fallback.
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
        duration: duration ?? const Duration(seconds: 4),
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

/// QUE-26: the overlay of the first navigator at or below [context] (the
/// root navigator when [context] is the root messenger or the router's
/// navigator); null when there is none or the tree cannot be visited now.
OverlayState? _overlayBelow(BuildContext context) {
  if (!context.mounted) return null;
  OverlayState? found;
  bool take(Element e) {
    if (e is StatefulElement && e.state is NavigatorState) {
      found = (e.state as NavigatorState).overlay;
      return true;
    }
    return false;
  }

  void visit(Element e) {
    if (found != null || take(e)) return;
    e.visitChildElements(visit);
  }

  try {
    if (context is Element && take(context)) return found;
    context.visitChildElements(visit);
  } catch (_) {
    // Called while building: the caller falls back.
    return null;
  }
  return found;
}

OverlayEntry? _mdToastEntry;

/// MD_SWEEP: Ionic md `ion-toast` as Utils.showToast creates it
/// (`position: 'top'`, `duration: 3000`, a colour, no buttons): a card 8px
/// below the top (+ safe area), centred, at most 700px wide with 8px side
/// Shows a toast banner in the root overlay above modals and sheets. A new
/// toast replaces the previous one.
void showToastOverlay(
  OverlayState overlay,
  String message, {
  Color? color,
  Duration duration = const Duration(milliseconds: 3000),
  bool ios = false,
  ToastAction? action,
}) {
  final previous = _mdToastEntry;
  if (previous != null && previous.mounted) {
    try {
      previous.remove();
    } catch (_) {}
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => AppToast(
      message: message,
      color: color,
      duration: duration,
      ios: ios,
      action: action,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_mdToastEntry, entry)) _mdToastEntry = null;
      },
    ),
  );
  _mdToastEntry = entry;
  overlay.insert(entry);
}

/// Toast overlay card shown by [showToastOverlay].
class AppToast extends StatefulWidget {
  const AppToast({
    super.key,
    required this.message,
    this.color,
    this.duration = const Duration(milliseconds: 3000),
    this.ios = false,
    this.action,
    this.onDismissed,
  });

  final String message;
  final Color? color;
  final Duration duration;

  /// Uses iOS native toast geometry (10px inset, 14px radius, no elevation).
  final bool ios;

  final ToastAction? action;
  final VoidCallback? onDismissed;

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast>
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With assistive technology (VoiceOver/TalkBack) the toast stays longer,
    // like a SnackBar, so the announcement can be heard and re-read.
    _timer ??= Timer(
      MediaQuery.maybeAccessibleNavigationOf(context) ?? false
          ? widget.duration * 4
          : widget.duration,
      _dismiss,
    );
  }

  bool _actionDone = false;

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
    final ios = widget.ios;
    final background = base ??
        (ios
            ? (dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2))
            : (dark ? const Color(0xFFD0D0D0) : const Color(0xFF333333)));
    final textColor = base != null
        ? (base == AppColors.warning || base == AppColors.warningOnDark
            ? Colors.black
            : Colors.white)
        : (ios
            ? (dark ? const Color(0xFFDBDBDB) : const Color(0xFF262626))
            : (dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2)));
    final inset = ios ? 10.0 : 8.0;
    final top = MediaQuery.paddingOf(context).top + (ios ? 10.0 : 8.0);
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final message = Text(
      widget.message,
      style: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: textColor,
      ),
    );
    const messagePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final action = widget.action;
    final Widget content = action == null
        ? Padding(padding: messagePadding, child: message)
        : Row(
            children: [
              Expanded(child: Padding(padding: messagePadding, child: message)),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ToastButton(
                  label: action.label,
                  ios: ios,
                  color: base != null ? textColor : AppColors.primary,
                  onPressed: () {
                    if (_actionDone) return;
                    _actionDone = true;
                    _dismiss();
                    action.onPressed();
                  },
                ),
              ),
            ],
          );
    return Positioned(
      top: top,
      left: inset,
      right: inset,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, -0.5), end: Offset.zero)
                      .animate(curved),
                  child: Material(
                    color: background,
                    elevation: ios ? 0 : 6,
                    shadowColor: Colors.black,
                    borderRadius: BorderRadius.circular(ios ? 14 : 4),
                    child: content,
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

/// `.toast-button`: md uppercase 14px / 500 with .84px letter spacing in
/// 10 × 15 padding; iOS 17px / 500, at least 44px high.
class _ToastButton extends StatelessWidget {
  const _ToastButton({
    required this.label,
    required this.ios,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool ios;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: Size(0, ios ? 44 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // based on the theme style: keeps the app's font family
        textStyle: (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
            .copyWith(
          fontSize: ios ? 17 : 14,
          fontWeight: FontWeight.w500,
          letterSpacing: ios ? 0 : 0.84,
        ),
      ),
      child: Text(
          ios ? label : label.toUpperCase().replaceAll('ß', 'SS')),
    );
  }
}
