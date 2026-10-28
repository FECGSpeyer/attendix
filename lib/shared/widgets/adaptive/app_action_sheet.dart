import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'app_dialog.dart' show IosAlertButton;

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
/// - iOS: the Ionic iOS 26 action sheet – a floating frosted card with the
///   (centred, grey) title/sub-title, grey pill buttons (destructive = red)
///   and the "Abbrechen" button separated below them.
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
    final grey = theme.brightness == Brightness.dark
        ? const Color(0xFF999999)
        : const Color(0xFF666666);

    Widget button(AppActionSheetAction<T> a) => IosAlertButton(
          minHeight: 52,
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
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          opacity: theme.brightness == Brightness.dark ? 0.86 : 0.9,
          blur: 20,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Column(
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: grey,
                          ),
                        ),
                      if (message != null)
                        Padding(
                          padding: EdgeInsets.only(top: title != null ? 6 : 0),
                          child: Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: grey),
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
                          minHeight: 52,
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
                const SizedBox(height: 12),
                IosAlertButton(
                  minHeight: 52,
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
    final theme = Theme.of(context);
    final grey = theme.colorScheme.onSurface.withValues(alpha: 0.54);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(title!,
                          style: TextStyle(fontSize: 16, color: grey)),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(message!,
                            style: TextStyle(fontSize: 14, color: grey)),
                      ),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
            for (final a in actions)
              ListTile(
                enabled: a.enabled,
                leading: a.icon == null
                    ? null
                    : Icon(a.icon,
                        color: a.destructive
                            ? theme.colorScheme.error
                            : a.color),
                title: Text(
                  a.label,
                  style: a.destructive
                      ? TextStyle(color: theme.colorScheme.error)
                      : (a.color != null ? TextStyle(color: a.color) : null),
                ),
                subtitle: a.subtitle == null ? null : Text(a.subtitle!),
                onTap: () => Navigator.of(context).pop(a.value),
              ),
            if (cancelLabel != null)
              ListTile(
                title: Text(
                  cancelLabel!,
                  style: cancelDestructive
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
