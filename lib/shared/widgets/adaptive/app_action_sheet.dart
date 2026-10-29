import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import '../layout/ionic_md.dart' show IonMd; // MD_SWEEP
import 'app_dialog.dart' show IosAlertButton, iosAlertMessageColor;

/// One button of [showAppActionSheet] (Ionic `ActionSheetButton`).
class AppActionSheetAction<T> {
  const AppActionSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.destructive = false,
    this.color,
    this.enabled = true,
    this.subtitle,
  });

  final String label;

  /// Returned by [showAppActionSheet] when this button is tapped.
  final T value;

  /// `ActionSheetButton.icon` (Ionic shows icons only in md mode unless set;
  /// we show them on both platforms like the Flutter pages did before).
  final IconData? icon;

  /// `role: 'destructive'` → red label.
  final bool destructive;

  /// Optional text/icon colour (e.g. a status colour). Ignored for
  /// destructive actions.
  final Color? color;

  final bool enabled;

  /// Optional second line (Material only).
  final String? subtitle;
}

/// IOS_LOOK: `ion-action-sheet`.
///
/// - iOS (IOS27_SWEEP, ionic-theme-ios27): a floating glass card (12pt
///   from the screen edges, radius 36, 16pt padding) with the start-aligned
///   17pt semibold title in the text colour (sub-title 16pt grey), grey
///   48pt pill buttons (17pt medium, destructive = #ea292d) 8pt apart and
///   the semibold "Abbrechen" button 8pt below them.
/// - elsewhere: a Material bottom sheet like the Ionic md action sheet
///   (title, icon + label rows, cancel row last).
///
/// Returns the `value` of the tapped action, or null when cancelled or
/// dismissed. Set [cancelLabel] to override "Abbrechen", [showCancel] false to
/// hide it (Ionic sheets without a cancel button), [cancelDestructive] for
/// Ionic's `{ text: 'Abbrechen', role: 'destructive' }` (red, last button of
/// the main group instead of a separate cancel button).
Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppActionSheetAction<T>> actions,
  String? cancelLabel,
  bool showCancel = true,
  bool cancelDestructive = false,
  bool useRootNavigator = true,
}) {
  if (useIosLook(context)) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: const Color(0x33000000),
      showDragHandle: false,
      builder: (ctx) => _IosActionSheet<T>(
        title: title,
        message: message,
        actions: actions,
        cancelLabel: showCancel ? (cancelLabel ?? ctx.l10n.commonCancel) : null,
        cancelDestructive: cancelDestructive,
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(),
    // PARITY_R3: Ionic md action sheet `--max-width: 500px`, centred.
    constraints: const BoxConstraints(maxWidth: 500),
    builder: (ctx) => _MaterialActionSheet<T>(
      title: title,
      message: message,
      actions: actions,
      cancelLabel: showCancel ? (cancelLabel ?? ctx.l10n.commonCancel) : null,
      cancelDestructive: cancelDestructive,
    ),
  );
}

class _IosActionSheet<T> extends StatelessWidget {
  const _IosActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
    this.cancelDestructive = false,
  });

  final String? title;
  final String? message;
  final List<AppActionSheetAction<T>> actions;
  final String? cancelLabel;
  final bool cancelDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    // --ios26-floating-safe-area-bottom: max(10px, safe-area-bottom - 12px)
    final bottom = (mq.padding.bottom - 12).clamp(10.0, double.infinity);
    final grey = iosAlertMessageColor(theme.brightness);

    Widget button(AppActionSheetAction<T> a) => IosAlertButton(
          minHeight: 48,
          bold: false,
          destructive: a.destructive,
          icon: a.icon == null ? null : Icon(a.icon),
          onPressed:
              a.enabled ? () => Navigator.of(context).pop(a.value) : null,
          child: a.color != null && !a.destructive
              ? Text(a.label, style: TextStyle(color: a.color))
              : Text(a.label),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, mq.padding.top + 12, 12, bottom),
      child: Material(
        type: MaterialType.transparency,
        child: IosGlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(36)),
          overlay: true,
          blur: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || message != null)
                Padding(
                  // ios27 `.action-sheet-title { padding: 6px 14px 20px }`
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.21,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      if (message != null)
                        Padding(
                          padding: EdgeInsets.only(top: title != null ? 8 : 0),
                          child: Text(
                            message!,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                                fontSize: 0.94 * 17, height: 1.19, color: grey),
                          ),
                        ),
                    ],
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        button(actions[i]),
                      ],
                      if (cancelLabel != null && cancelDestructive) ...[
                        const SizedBox(height: 8),
                        IosAlertButton(
                          minHeight: 48,
                          bold: false,
                          destructive: true,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(cancelLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (cancelLabel != null && !cancelDestructive) ...[
                // ios27 `.action-sheet-cancel { margin-top: 8px }` below the
                // group's last button.
                const SizedBox(height: 8),
                IosAlertButton(
                  minHeight: 48,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(cancelLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialActionSheet<T> extends StatelessWidget {
  const _MaterialActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
    this.cancelDestructive = false,
  });

  final String? title;
  final String? message;
  final List<AppActionSheetAction<T>> actions;
  final String? cancelLabel;
  final bool cancelDestructive;

  @override
  Widget build(BuildContext context) {
    // MD_SWEEP: Ionic md `ion-action-sheet` – `--background:
    // var(--ion-background-color)` (#fff, dark #121212); title 16px in
    // rgba(text, .54) (padding 20 16 17, min-height 60), sub-title 14px
    // 16px below; 52px buttons (padding 12 16) with 16px step-850 labels
    // and 24px rgba(text, .54) icons 32px before the label. md has no
    // destructive colour (`role: 'destructive'` only styles iOS) and no
    // extra padding above / below the button groups.
    final b = Theme.of(context).brightness;
    final grey = IonMd.text(b).withValues(alpha: 0.54);
    final buttonColor = IonMd.step850(b);

    Widget button({
      required String label,
      IconData? icon,
      Color? color,
      String? subtitle,
      bool enabled = true,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Opacity(
              opacity: enabled ? 1 : 0.38,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 24, color: color ?? grey),
                    const SizedBox(width: IonMd.startIconGap),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 16, color: color ?? buttonColor)),
                        if (subtitle != null)
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: IonMd.pFontSize,
                                  color: IonMd.labelP(b))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: IonMd.background(b),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || message != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(title!,
                              style: TextStyle(fontSize: 16, color: grey)),
                        if (message != null)
                          Padding(
                            padding:
                                EdgeInsets.only(top: title != null ? 16 : 0),
                            child: Text(message!,
                                style: TextStyle(fontSize: 14, color: grey)),
                          ),
                      ],
                    ),
                  ),
                ),
              for (final a in actions)
                button(
                  label: a.label,
                  icon: a.icon,
                  color: a.destructive ? null : a.color,
                  subtitle: a.subtitle,
                  enabled: a.enabled,
                  onTap: () => Navigator.of(context).pop(a.value),
                ),
              if (cancelLabel != null)
                button(
                  label: cancelLabel!,
                  onTap: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
