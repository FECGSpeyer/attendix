import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/redesign/rd_palette.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import 'app_pickers.dart';
import 'ion_button_label.dart';

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

/// Text input used inside an [AppAlertDialog] / [AppAlertInputGroup].
class AppAlertInput extends StatelessWidget {
  const AppAlertInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.textarea = false,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.enabled,
    this.inputFormatters,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.betaDecoration,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final bool textarea;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool? enabled;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final InputDecoration? betaDecoration;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      enabled: enabled,
      inputFormatters: inputFormatters,
      focusNode: focusNode,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      decoration: betaDecoration ?? InputDecoration(hintText: placeholder),
    );
  }
}

/// Column of alert message and inputs/widgets for an [AppAlertDialog].
class AppAlertInputGroup extends StatelessWidget
    implements AppAlertGroupContent {
  const AppAlertInputGroup({
    super.key,
    this.message,
    required this.children,
    this.betaCrossAxisAlignment = CrossAxisAlignment.center,
    this.beta,
  });

  final Widget? message;
  final List<Widget> children;
  final CrossAxisAlignment betaCrossAxisAlignment;
  final Widget? beta;

  @override
  String? get alertMessageText => switch (message) {
        final Text t => t.data,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final beta = this.beta;
    if (beta != null) return beta;
    final message = this.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: betaCrossAxisAlignment,
      children: [if (message != null) message, ...children],
    );
  }
}

/// Dialog title wrapper (ignores legacy subHeader).
class AppAlertTitle extends StatelessWidget {
  const AppAlertTitle(this.title, {super.key, this.subHeader});

  final String title;
  final String? subHeader;

  @override
  Widget build(BuildContext context) => Text(title);
}

/// Vertical spacing helper inside an [AppAlertInputGroup].
class AppAlertBetaGap extends StatelessWidget {
  const AppAlertBetaGap(this.height, {super.key});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Alert dialog with a date picker input field.
Future<DateTime?> showAppDateAlert(
  BuildContext context, {
  required String title,
  String? message,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String confirmText,
}) {
  return showAppDialog<DateTime>(
    context: context,
    builder: (_) => _DateAlert(
      title: title,
      message: message,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      confirmText: confirmText,
    ),
  );
}

class _DateAlert extends StatefulWidget {
  const _DateAlert({
    required this.title,
    required this.message,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.confirmText,
  });

  final String title;
  final String? message;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String confirmText;

  @override
  State<_DateAlert> createState() => _DateAlertState();
}

class _DateAlertState extends State<_DateAlert> {
  late DateTime _value = widget.initialDate;
  final _text = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _text.text = MaterialLocalizations.of(context).formatCompactDate(_value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _value,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _value = picked;
      _text.text = MaterialLocalizations.of(context).formatCompactDate(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void cancel() => Navigator.of(context).pop();
    void confirm() => Navigator.of(context).pop(_value);
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
            controller: _text,
            readOnly: true,
            onTap: _pick,
            decoration: InputDecoration(
              suffixIcon: Icon(AppIcons.calendarTodayOutlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: cancel, child: Text(l10n.commonCancel)),
        TextButton(onPressed: confirm, child: Text(widget.confirmText)),
      ],
    );
  }
}

/// Result of [showAppRadioAlert].
class AppRadioAlertResult<T> {
  const AppRadioAlertResult(this.value);
  final T? value;
}

/// Radio alert dialog with options, cancel and confirm buttons.
Future<AppRadioAlertResult<T>?> showAppRadioAlert<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<(T value, String label)> options,
  T? initialValue,
  String? confirmText,
  String? cancelText,
  bool cancelDestructive = false,
  bool barrierDismissible = true,
}) {
  return showAppDialog<AppRadioAlertResult<T>>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _RadioAlert<T>(
      title: title,
      message: subtitle,
      options: options,
      initialValue: initialValue,
      confirmText: confirmText,
      cancelText: cancelText,
      cancelDestructive: cancelDestructive,
    ),
  );
}

class _RadioAlert<T> extends StatefulWidget {
  const _RadioAlert({
    required this.title,
    required this.message,
    required this.options,
    required this.initialValue,
    required this.confirmText,
    required this.cancelText,
    required this.cancelDestructive,
  });

  final String title;
  final String? message;
  final List<(T, String)> options;
  final T? initialValue;
  final String? confirmText;
  final String? cancelText;
  final bool cancelDestructive;

  @override
  State<_RadioAlert<T>> createState() => _RadioAlertState<T>();
}

class _RadioAlertState<T> extends State<_RadioAlert<T>> {
  late T? _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final cancelText = widget.cancelText ?? context.l10n.commonCancel;
    final confirmText = widget.confirmText ?? context.l10n.commonOk;
    void cancel() => Navigator.of(context).pop();
    void confirm() => Navigator.of(context).pop(AppRadioAlertResult<T>(_value));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    final rd = context.rd;
    final message = widget.message;
    return AppAlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(bottom: 14),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null && message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: Text(message),
                ),
              for (final (value, label) in widget.options)
                Semantics(
                  checked: value == _value,
                  inMutuallyExclusiveGroup: true,
                  child: InkWell(
                    onTap: () => setState(() => _value = value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: rd.line, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.3,
                                  fontWeight: value == _value
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: value == _value ? rd.primary : rd.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            value == _value
                                ? Icon(Icons.check, size: 22, color: rd.primary)
                                : const SizedBox(width: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: cancel,
          style: widget.cancelDestructive
              ? TextButton.styleFrom(foregroundColor: AppColors.danger)
              : null,
          child: Text(cancelText),
        ),
        TextButton(onPressed: confirm, child: Text(confirmText)),
      ],
    );
  }
}
