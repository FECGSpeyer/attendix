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
      // PARITY_R3: Ionic md `ion-alert` – 4px radius, 20/500 title,
      // grey 16px message, flat UPPERCASE primary text buttons aligned
      // right; 3+ buttons stacked (`alert-button-group-vertical`).
      final theme = Theme.of(context);
      final mdActions = [
        for (final a in actions ?? const <Widget>[])
          if (a is! Spacer) mdAlertActionFrom(context, a),
      ];
      return AlertDialog(
        icon: icon,
        title: title,
        content: content,
        actions: mdActions.isEmpty
            ? null
            : [MdAlertButtonGroup(children: mdActions)],
        contentPadding: contentPadding ??
            EdgeInsets.fromLTRB(24, title == null ? 20 : 0, 24, 20),
        titlePadding: titlePadding ??
            EdgeInsets.fromLTRB(24, 20, 24, content == null ? 20 : 15),
        actionsPadding: actionsPadding ?? const EdgeInsets.all(8),
        actionsAlignment: actionsAlignment,
        insetPadding: insetPadding ??
            const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        scrollable: scrollable,
        backgroundColor: backgroundColor,
        shape: shape ??
            const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4))),
        titleTextStyle: titleTextStyle ??
            TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
        contentTextStyle: contentTextStyle ??
            TextStyle(
              fontSize: 16,
              height: 1.4,
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF8C8C8C)
                  : const Color(0xFF737373),
            ),
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
      bold: false,
      child: action.child ?? const SizedBox.shrink(),
    );
  }
  return action;
}

/// PARITY_R3: converts a Material dialog action into an Ionic md alert
/// button: a flat primary text button with an UPPERCASE label (Ionic md
/// `.alert-button`: 14px, weight 500, `text-transform: uppercase`, padding
/// 10px, 2px radius). Filled/elevated buttons become text buttons too –
/// Ionic md alerts only have flat buttons.
Widget mdAlertActionFrom(BuildContext context, Widget action) {
  if (action is! ButtonStyleButton) return action;
  final primary = Theme.of(context).colorScheme.primary;
  Widget child = action.child ?? const SizedBox.shrink();
  if (child is Text && child.data != null) {
    child = Text(
      child.data!.toUpperCase(),
      key: child.key,
      style: child.style,
      textAlign: TextAlign.end,
      maxLines: child.maxLines,
      overflow: child.overflow,
    );
  }
  return TextButton(
    onPressed: action.onPressed,
    onLongPress: action.onLongPress,
    focusNode: action.focusNode,
    autofocus: action.autofocus,
    style: TextButton.styleFrom(
      foregroundColor: primary,
      disabledForegroundColor: primary.withValues(alpha: 0.38),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.all(10),
      minimumSize: const Size(48, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerRight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2))),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    child: child,
  );
}

/// PARITY_R3: Ionic md `.alert-button-group`: one or two buttons sit in a
/// right-aligned row (8px apart, wrapping upwards when they do not fit –
/// `flex-wrap: wrap-reverse`), three or more are stacked full width with
/// right-aligned labels (`.alert-button-group-vertical`).
class MdAlertButtonGroup extends StatelessWidget {
  const MdAlertButtonGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.length > 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children)
            Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 8,
        overflowAlignment: OverflowBarAlignment.end,
        overflowDirection: VerticalDirection.up,
        children: children,
      ),
    );
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
            contentPadding ?? const EdgeInsets.fromLTRB(30, 0, 30, 21),
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
          padding: EdgeInsets.fromLTRB(30, icon != null ? 10 : 22, 30,
              body != null ? 7 : 19),
          child: DefaultTextStyle.merge(style: titleStyle, child: title!),
        )
      else
        const SizedBox(height: 18),
      if (body != null) body,
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _IosAlertButtonGroup(actions: actions),
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
                    borderRadius: const BorderRadius.all(Radius.circular(34)),
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

/// PARITY_R3: iOS `.alert-button-group` – exactly two buttons sit side by
/// side (each `min-width: calc(50% - 4px)`, 8px gap) as long as both labels
/// fit into half the width (`flex-wrap: wrap` otherwise puts them on two
/// lines); one or three and more buttons are stacked
/// (`.alert-button-group-vertical`).
class _IosAlertButtonGroup extends StatelessWidget {
  const _IosAlertButtonGroup({required this.actions});

  final List<Widget> actions;

  Widget _stacked() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            actions[i],
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (actions.length != 2 || actions.any((a) => a is! IosAlertButton)) {
      return _stacked();
    }
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final half = (constraints.maxWidth - 8) / 2;
      final fits = actions.every((a) {
        final w = (a as IosAlertButton).labelWidth(scaler, direction);
        return w == null || w <= half;
      });
      if (!fits) return _stacked();
      return Row(
        children: [
          Expanded(child: actions[0]),
          const SizedBox(width: 8),
          Expanded(child: actions[1]),
        ],
      );
    });
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

  /// Ionic iOS 26 `.alert-button { padding: 12px }`.
  static const double _hPadding = 12;

  TextStyle _labelStyle(Color? color) => TextStyle(
        fontSize: 17,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: color,
      );

  /// Natural width of the button (label + padding) when its child is a
  /// plain [Text]; null when it cannot be measured (e.g. a spinner).
  double? labelWidth(TextScaler scaler, TextDirection direction) {
    final c = child;
    if (c is! Text || c.data == null) return null;
    final painter = TextPainter(
      text: TextSpan(text: c.data, style: _labelStyle(null).merge(c.style)),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = painter.width + 2 * _hPadding + (icon == null ? 0 : 28);
    painter.dispose();
    return w;
  }

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
              padding: const EdgeInsets.symmetric(
                  horizontal: _hPadding, vertical: 8),
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(color: color, size: 20),
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: _labelStyle(color),
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
