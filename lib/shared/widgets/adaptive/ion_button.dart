import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
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
/// The look comes from the app theme (iOS look: ionic-theme-ios27 pill
/// button, md look: Ionic md button, uppercase label; Beta design: its own
/// themed buttons), this widget only maps the Ionic attributes:
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
    final ios = useIosLook(context);
    final solid = fill == IonButtonFill.solid;
    final fg = solid ? (foregroundColor ?? (color == null ? null : Colors.white)) : color;

    // Only what differs from the themed default is set, so an [IonButton]
    // without attributes is exactly the themed button.
    final style = ButtonStyle(
      backgroundColor: solid && color != null
          ? WidgetStateProperty.resolveWith(
              // Ionic: a disabled button keeps its colour at opacity .5.
              (states) => states.contains(WidgetState.disabled)
                  ? color!.withValues(alpha: 0.5)
                  : color,
            )
          : null,
      foregroundColor: fg == null ? null : WidgetStatePropertyAll(fg),
      iconColor: fg == null ? null : WidgetStatePropertyAll(fg),
      side: fill == IonButtonFill.outline && color != null
          ? WidgetStatePropertyAll(BorderSide(color: color!, width: ios ? 1 : 2))
          : null,
      shape: round
          ? const WidgetStatePropertyAll(StadiumBorder())
          : small && ios
              ? WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                )
              : null,
      padding: round
          ? const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 26))
          : small
              ? WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: ios ? 12.4 : 11.7, vertical: 4),
                )
              : null,
      minimumSize: small
          ? WidgetStatePropertyAll(Size(0, ios ? 29 : 27.3))
          : null,
      textStyle: small
          ? WidgetStatePropertyAll(
              ios
                  ? const TextStyle(fontSize: 13.8125, fontWeight: FontWeight.w500)
                  : const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.78,
                    ),
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
