import 'package:flutter/material.dart';

import 'ion_button_label.dart';

/// Ionic `fill` of an `ion-button`.
enum IonButtonFill {
  /// `fill="solid"` (the default of a button in content).
  solid,

  /// `fill="outline"`.
  outline,

  /// `fill="clear"`.
  clear,
}

/// Ionic `<ion-button>` in page content – ONE widget for the button that
/// used to be written as `ElevatedButton`, `FilledButton`, `OutlinedButton`
/// or `TextButton` with hand-set styles.
///
/// The look comes from the app theme; this widget maps button variants:
///
/// - [fill]: solid (default) / outline / clear,
/// - [color]: Ionic `color="…"` (null = primary) with [foregroundColor] as
///   its contrast colour (null = white on solid buttons),
/// - [small]: `size="small"` (2.1em high, .8125rem label, .9em padding,
///   iOS radius 6),
/// - [round]: `shape="round"` (pill, 26px padding),
/// - [expand]: `expand="block"` (full width),
/// - [icon]: `ion-icon slot="start"`.
///
/// ```dart
/// IonButton(label: context.l10n.messagesRetry, onPressed: retry)
/// IonButton(label: 'Löschen', color: AppColors.danger, expand: true, onPressed: …)
/// IonButton(label: 'Datum', fill: IonButtonFill.outline, small: true, onPressed: …)
/// ```
class IonButton extends StatelessWidget {
  const IonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fill = IonButtonFill.solid,
    this.color,
    this.foregroundColor,
    this.small = false,
    this.round = false,
    this.expand = false,
  });

  /// The label as written; md shows it uppercased ([IonButtonLabel]).
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IonButtonFill fill;
  final Color? color;
  final Color? foregroundColor;
  final bool small;
  final bool round;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final solid = fill == IonButtonFill.solid;
    final fg = solid ? (foregroundColor ?? (color == null ? null : Colors.white)) : color;
    final theme = Theme.of(context);
    final themedText = switch (fill) {
          IonButtonFill.solid => theme.filledButtonTheme.style,
          IonButtonFill.outline => theme.outlinedButtonTheme.style,
          IonButtonFill.clear => theme.textButtonTheme.style,
        }
            ?.textStyle
            ?.resolve(const <WidgetState>{}) ??
        theme.textTheme.labelLarge ??
        const TextStyle();

    final style = ButtonStyle(
      backgroundColor: solid && color != null
          ? WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? color!.withValues(alpha: 0.5)
                  : color,
            )
          : null,
      foregroundColor: fg == null ? null : WidgetStatePropertyAll(fg),
      iconColor: fg == null ? null : WidgetStatePropertyAll(fg),
      side: fill == IonButtonFill.outline && color != null
          ? WidgetStatePropertyAll(BorderSide(color: color!, width: 1.5))
          : null,
      shape: round ? const WidgetStatePropertyAll(StadiumBorder()) : null,
      padding: round
          ? const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 26))
          : small
              ? const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                )
              : null,
      minimumSize: small ? const WidgetStatePropertyAll(Size(0, 29)) : null,
      textStyle: small
          ? WidgetStatePropertyAll(
              themedText.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500),
            )
          : null,
      tapTargetSize: small ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: small ? VisualDensity.standard : null,
    );

    final text = IonButtonLabel(label);
    final leading = icon == null ? null : Icon(icon, size: small ? 16 : null);
    final Widget button;
    switch (fill) {
      case IonButtonFill.solid:
        button = leading == null
            ? FilledButton(onPressed: onPressed, style: style, child: text)
            : FilledButton.icon(onPressed: onPressed, style: style, icon: leading, label: text);
      case IonButtonFill.outline:
        button = leading == null
            ? OutlinedButton(onPressed: onPressed, style: style, child: text)
            : OutlinedButton.icon(onPressed: onPressed, style: style, icon: leading, label: text);
      case IonButtonFill.clear:
        button = leading == null
            ? TextButton(onPressed: onPressed, style: style, child: text)
            : TextButton.icon(onPressed: onPressed, style: style, icon: leading, label: text);
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
