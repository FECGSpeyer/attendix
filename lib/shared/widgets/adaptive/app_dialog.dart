import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';

/// IOS_LOOK: [showDialog] with the Ionic overlay backdrop.
///
/// Same parameters and return value as [showDialog]. On iOS the backdrop
/// uses Ionic's iOS theme opacity (`--backdrop-opacity: .2`); the dialog
/// itself decides its look (use [AppAlertDialog] for alerts).
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
  final ios = useIosLook(context);
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? (ios ? const Color(0x33000000) : null),
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
  );
}

/// IOS_LOOK: drop-in replacement for [AlertDialog] that looks like
/// `ion-alert`.
///
/// - iOS: Ionic iOS 26 alert – frosted rounded card (≈275pt wide), bold
///   17pt title and grey message aligned left, any content (text fields,
///   lists …) below, and the actions as full-width grey pill buttons stacked
///   vertically in the given order (black semibold label, destructive ones
///   red). A single action stays one pill.
/// - elsewhere: a plain Material [AlertDialog] with exactly the given
///   parameters (Ionic md alert).
///
/// The actions keep their callbacks: a [TextButton] / [ElevatedButton] /
/// [FilledButton] / [OutlinedButton] is rendered as an iOS pill with the
/// same `onPressed` (null = disabled) and child. A button styled with the
/// error/danger colour becomes a destructive (red) action. Other widgets are
/// shown as they are.
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
    if (!useIosLook(context)) {
      return AlertDialog(
        icon: icon,
        title: title,
        content: content,
        actions: actions,
        contentPadding: contentPadding,
        titlePadding: titlePadding,
        actionsPadding: actionsPadding,
        actionsAlignment: actionsAlignment,
        insetPadding: insetPadding,
        scrollable: scrollable,
        backgroundColor: backgroundColor,
        shape: shape,
        titleTextStyle: titleTextStyle,
        contentTextStyle: contentTextStyle,
        semanticLabel: semanticLabel,
      );
    }
    return IosAlertCard(
      icon: icon,
      title: title,
      content: content,
      contentPadding: contentPadding,
      scrollable: scrollable,
      semanticLabel: semanticLabel,
      actions: [
        for (final a in actions ?? const <Widget>[])
          if (a is! Spacer) iosAlertActionFrom(context, a),
      ],
    );
  }
}

/// IOS_LOOK: [SimpleDialog] replacement – on iOS an [IosAlertCard] with the
/// options as list rows (ion-alert with radio/plain buttons), otherwise the
/// Material [SimpleDialog].
class AppSimpleDialog extends StatelessWidget {
  const AppSimpleDialog({super.key, this.title, this.children});

  final Widget? title;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return SimpleDialog(title: title, children: children);
    }
    return IosAlertCard(
      title: title,
      contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children ?? const [],
      ),
      actions: const [],
    );
  }
}

/// Converts a Material dialog action into an iOS alert pill button.
Widget iosAlertActionFrom(BuildContext context, Widget action) {
  if (action is ButtonStyleButton) {
    final style = action.style;
    const states = <WidgetState>{};
    final fg = style?.foregroundColor?.resolve(states);
    final bg = style?.backgroundColor?.resolve(states);
    final error = Theme.of(context).colorScheme.error;
    final destructive = _isDanger(fg, error) ||
        (action is! TextButton && _isDanger(bg, error));
    return IosAlertButton(
      onPressed: action.onPressed,
      destructive: destructive,
      child: action.child ?? const SizedBox.shrink(),
    );
  }
  return action;
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

/// Ionic iOS 26 `ion-alert` card. Used by [AppAlertDialog]; usable directly
/// for custom alerts.
class IosAlertCard extends StatelessWidget {
  const IosAlertCard({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.content,
    this.contentPadding,
    this.scrollable = false,
    this.semanticLabel,
    required this.actions,
  });

  final Widget? icon;
  final Widget? title;

  /// Plain message under the title (alternative to [content]).
  final String? message;
  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final bool scrollable;
  final String? semanticLabel;
  final List<Widget> actions;

  /// Ionic: `--min-width: 280px`, `--max-width: 322px`; on an iPhone 15 the
  /// alert renders ≈275pt wide.
  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final textColor = theme.colorScheme.onSurface;
    final messageColor =
        b == Brightness.dark ? const Color(0xFF999999) : const Color(0xFF666666);
    final mq = MediaQuery.of(context);
    final maxWidth = (mq.size.width - 32).clamp(200.0, width);

    final titleStyle = TextStyle(
      fontSize: 17,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: textColor,
    );
    final messageStyle =
        TextStyle(fontSize: 15, height: 1.25, color: messageColor);

    Widget? body = content ??
        (message != null && message!.isNotEmpty ? Text(message!) : null);
    if (body != null) {
      body = DefaultTextStyle.merge(style: messageStyle, child: body);
      body = Padding(
        padding:
            contentPadding ?? const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: body,
      );
      body = scrollable
          ? Flexible(child: SingleChildScrollView(child: body))
          : Flexible(child: body);
    }

    final children = <Widget>[
      if (icon != null)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: IconTheme.merge(
            data: IconThemeData(color: theme.colorScheme.primary, size: 28),
            child: icon!,
          ),
        ),
      if (title != null)
        Padding(
          padding: EdgeInsets.fromLTRB(22, icon != null ? 10 : 22, 22,
              body != null ? 8 : 18),
          child: DefaultTextStyle.merge(style: titleStyle, child: title!),
        )
      else
        const SizedBox(height: 18),
      if (body != null) body,
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                actions[i],
              ],
            ],
          ),
        ),
    ];

    return AnimatedPadding(
      padding: mq.viewInsets + const EdgeInsets.symmetric(vertical: 24),
      duration: const Duration(milliseconds: 100),
      curve: Curves.decelerate,
      child: MediaQuery.removeViewInsets(
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        context: context,
        child: Center(
          child: _PopIn(
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: semanticLabel,
              child: SizedBox(
                width: maxWidth,
                child: Material(
                  type: MaterialType.transparency,
                  child: IosGlassSurface(
                    borderRadius: const BorderRadius.all(Radius.circular(28)),
                    opacity: b == Brightness.dark ? 0.86 : 0.9,
                    blur: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
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

/// Grey full-width pill button of an iOS alert / action sheet.
class IosAlertButton extends StatelessWidget {
  const IosAlertButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.destructive = false,
    this.bold = true,
    this.minHeight = 48,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool destructive;
  final bool bold;
  final double minHeight;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final color =
        destructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(minHeight / 2);
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: IosGlass.overlayButton(b),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed == null
              ? null
              : () {
                  try {
                    HapticFeedback.selectionClick();
                  } catch (_) {}
                  onPressed!();
                },
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: color, size: 20),
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                    child: icon == null
                        ? child
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              icon!,
                              const SizedBox(width: 8),
                              Flexible(child: child),
                            ],
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

/// ion-alert iOS enter animation: scale 1.1 → 1 with fade.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
      builder: (context, t, child) => Transform.scale(
        scale: 1.1 - 0.1 * t,
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Convenience alerts (ion-alert with OK / confirm / prompt)
// ---------------------------------------------------------------------------

/// ion-alert with a message and one "OK" button.
Future<void> showAppAlert(
  BuildContext context, {
  required String title,
  String? message,
  String? okText,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(okText ?? ctx.l10n.commonOk),
        ),
      ],
    ),
  );
}

/// ion-alert with "Abbrechen" (role cancel) and a confirm button
/// (destructive = red). Returns true when confirmed.
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

/// ion-alert with one text input. Returns the entered text, or null when
/// cancelled.
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
