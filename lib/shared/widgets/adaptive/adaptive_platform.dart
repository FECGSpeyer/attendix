import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// IOS_LOOK: true when the app should render like Ionic in iOS mode
/// (`mode="ios"`): on iPhone/iPad – the native app and Flutter web in iOS
/// Safari both report [TargetPlatform.iOS]. Everywhere else the app keeps the
/// Material look (Ionic md mode).
bool useIosLook(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Colours of the Liquid Glass surfaces of the Ionic iOS 26 theme
/// (@rdlabo/ionic-theme-ios26: `--ios26-glass-*`).
class IosGlass {
  IosGlass._();

  /// `--ios26-glass-background-rgb`: white (light) / rgb(62,62,62) (dark).
  static Color background(Brightness b, [double opacity = 0.72]) =>
      (b == Brightness.dark ? const Color(0xFF3E3E3E) : Colors.white)
          .withValues(alpha: opacity);

  /// 0.5px rim of glass surfaces (`--ios26-glass-border-color-rgb`).
  static Color border(Brightness b) => b == Brightness.dark
      ? const Color(0xFF444444)
      : Colors.white.withValues(alpha: 0.9);

  /// Outer glow (`0 0 10px rgba(220,220,220,.82)`; none in dark mode).
  static List<BoxShadow> shadow(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(color: Color(0xD1DCDCDC), blurRadius: 10),
          BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 6)),
        ];

  /// Overlay buttons inside alerts / action sheets:
  /// `rgba(var(--ion-text-color-rgb), .065)`.
  static Color overlayButton(Brightness b) =>
      (b == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.065);

  /// Selected tab / segment pill (`--ios26-button-color-selected-rgb`, .095).
  static Color selectedPill(Brightness b) =>
      (b == Brightness.dark ? Colors.white : const Color(0xFF101010))
          .withValues(alpha: 0.095);
}

/// A rounded Liquid Glass surface (blurred translucent background, thin rim,
/// soft glow) as used by the Ionic iOS 26 theme for tab bars, segments,
/// toolbar button groups, alerts and action sheets.
class IosGlassSurface extends StatelessWidget {
  const IosGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
    this.opacity = 0.72,
    this.blur = 12,
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double opacity;
  final double blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: IosGlass.shadow(b),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: IosGlass.background(b, opacity),
              borderRadius: borderRadius,
              border: Border.all(color: IosGlass.border(b), width: 0.5),
            ),
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
        ),
      ),
    );
  }
}
