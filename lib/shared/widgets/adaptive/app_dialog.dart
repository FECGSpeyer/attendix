import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/design_theme.dart';
import '../../../l10n/l10n.dart';
import 'app_pickers.dart';
import 'ion_button_label.dart';

part 'app_alert_helpers.dart';

/// Shows an app dialog with the standard overlay backdrop.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
}) {
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? const Color(0x52000000),
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
  );
}

/// Redesign alert dialog: rounded surface card, bold title, muted message, and
/// 48pt filled/outlined action buttons (3+ actions stacked).
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.titlePadding,
    this.actionsPadding,
    this.actionsAlignment,
    this.insetPadding,
    this.scrollable = false,
    this.backgroundColor,
    this.shape,
    this.titleTextStyle,
    this.contentTextStyle,
    this.semanticLabel,
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment? actionsAlignment;
  final EdgeInsets? insetPadding;
  final bool scrollable;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final TextStyle? titleTextStyle;
  final TextStyle? contentTextStyle;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final list = [
      for (final a in actions ?? const <Widget>[])
        if (a is! Spacer) a,
    ];
    final buttons = [
      for (var i = 0; i < list.length; i++)
        rdAlertActionFrom(context, rd, list[i], filled: i == list.length - 1),
    ];
    return AlertDialog(
      icon: icon,
      title: title,
      content: content,
      actions: buttons.isEmpty
          ? null
          : [
              if (buttons.length > 2)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      buttons[i],
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: buttons[i]),
                    ],
                  ],
                ),
            ],
      contentPadding:
          contentPadding ?? EdgeInsets.fromLTRB(22, title == null ? 22 : 0, 22, 18),
      titlePadding:
          titlePadding ?? EdgeInsets.fromLTRB(22, 22, 22, content == null ? 18 : 10),
      actionsPadding: actionsPadding ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
      insetPadding:
          insetPadding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      scrollable: scrollable,
      backgroundColor: backgroundColor ?? rd.surface,
      shape:
          shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: titleTextStyle ??
          TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: rd.text),
      contentTextStyle: contentTextStyle ??
          TextStyle(fontSize: 15, height: 1.35, color: rd.text2),
      semanticLabel: semanticLabel,
    );
  }
}

/// Marker interface implemented by alert option/input groups.
abstract interface class AppAlertGroupContent {
  String? get alertMessageText;
}

/// Converts a Material dialog action into a styled dialog button
/// ([filled]: primary, else outlined; destructive actions are red).
Widget rdAlertActionFrom(
  BuildContext context,
  RdPalette rd,
  Widget action, {
  required bool filled,
}) {
  if (action is! ButtonStyleButton) {
    return action;
  }
  const states = <WidgetState>{};
  final fg = action.style?.foregroundColor?.resolve(states);
  final bg = action.style?.backgroundColor?.resolve(states);
  final error = Theme.of(context).colorScheme.error;
  final onPressed = action.onPressed;
  final destructive =
      _isDanger(fg, error) || (action is! TextButton && _isDanger(bg, error));
  final autofocus = action.autofocus;
  final raw = action.child;
  final child = switch (raw) {
    final IonButtonLabel l => l.toText(context),
    final c => c ?? const SizedBox.shrink(),
  };
  final shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(rd.buttonRadius));
  const text = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  if (filled) {
    return FilledButton(
      onPressed: onPressed,
      autofocus: autofocus,
      style: FilledButton.styleFrom(
        backgroundColor: destructive ? rd.absent : rd.primary,
        foregroundColor: destructive ? rd.onStatus : rd.onPrimary,
        disabledBackgroundColor: rd.track,
        disabledForegroundColor: rd.text2,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: shape,
        textStyle: text,
      ),
      child: child,
    );
  }
  return OutlinedButton(
    onPressed: onPressed,
    autofocus: autofocus,
    style: OutlinedButton.styleFrom(
      foregroundColor: destructive ? rd.absent : rd.text,
      backgroundColor: rd.surface,
      side: BorderSide(color: destructive ? rd.absent : rd.offBorder, width: 1.5),
      minimumSize: const Size(64, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: shape,
      textStyle: text,
    ),
    child: child,
  );
}

/// Drop-in wrapper for [SimpleDialog].
class AppSimpleDialog extends StatelessWidget {
  const AppSimpleDialog({super.key, this.title, this.children});

  final Widget? title;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(title: title, children: children);
  }
}

bool _isDanger(Color? c, Color error) {
  if (c == null || c.a < 0.5) return false;
  if (c.toARGB32() == error.toARGB32() ||
      c.toARGB32() == AppColors.danger.toARGB32()) {
    return true;
  }
  final hsv = HSVColor.fromColor(c);
  return (hsv.hue < 15 || hsv.hue > 345) &&
      hsv.saturation > 0.35 &&
      hsv.value > 0.4;
}

/// Confirm dialog with cancel and confirm actions (destructive = red).
/// Returns true when confirmed.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmText,
  String? cancelText,
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelText ?? ctx.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          child: Text(confirmText ?? ctx.l10n.commonConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Prompt dialog with a single text input.
Future<String?> showAppPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? initialValue,
  String? hint,
  String? confirmText,
  String? cancelText,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(
      title: title,
      message: message,
      initialValue: initialValue,
      hint: hint,
      confirmText: confirmText ?? ctx.l10n.commonOk,
      cancelText: cancelText ?? ctx.l10n.commonCancel,
      keyboardType: keyboardType,
      maxLines: maxLines,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.message,
    required this.initialValue,
    required this.hint,
    required this.confirmText,
    required this.cancelText,
    required this.keyboardType,
    required this.maxLines,
  });

  final String title;
  final String? message;
  final String? initialValue;
  final String? hint;
  final String confirmText;
  final String cancelText;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(hintText: widget.hint),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
