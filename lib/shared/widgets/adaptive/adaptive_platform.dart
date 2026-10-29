import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// IOS_LOOK: true when the app should render like Ionic in iOS mode
/// (`mode="ios"`): on iPhone/iPad – the native app and Flutter web in iOS
/// Safari both report [TargetPlatform.iOS]. Everywhere else the app keeps the
/// Material look (Ionic md mode).
bool useIosLook(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Colours of the Liquid Glass surfaces of the Ionic iOS theme the iPhone
/// renders: @rdlabo/ionic-theme-ios27 1.1.0 (`--ios26-glass-*` variables,
/// `utils/_glass.scss`, `utils/api.scss`).
class IosGlass {
  IosGlass._();

  /// `--ios26-glass-background-rgb`: white (light) / rgb(62,62,62) (dark).
  static Color background(Brightness b, [double opacity = 0.72]) =>
      (b == Brightness.dark ? const Color(0xFF3E3E3E) : Colors.white)
          .withValues(alpha: opacity);

  /// 0.5px rim of glass controls (`glass.light-rim`: `border: 0.5px solid
  /// rgb(--ios26-glass-border-color-rgb)` – white; dark #444).
  static Color border(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF444444) : Colors.white;

  /// IOS27_SWEEP: `glass.light-shadow` of glass controls (toolbar buttons,
  /// FAB, tab bar): a 0.5px ring in `rgba(text, .22)` and a
  /// `0 .5px 1px rgba(text, .08)` drop – painted outside the surface only
  /// (CSS box-shadows never show through a translucent element). Dark
  /// (`glass.dark-shadow` with `background-clip: border-area`): none.
  static List<BoxShadow> shadow(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(color: Color(0x38000000), spreadRadius: 0.5),
          BoxShadow(
              color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 0.5)),
        ];

  /// IOS27_SWEEP: `api.glass-overlay-variables` (alert, action sheet,
  /// popover, toast): `--background: rgba(glass, .67)`; the dark theme
  /// overrides alert / action sheet / toast with `rgba(glass, .52)`.
  static double overlayOpacity(Brightness b) =>
      b == Brightness.dark ? 0.52 : 0.67;

  /// `--border-color: rgba(text, .18)` (0.5px) of glass overlays.
  static Color overlayBorder(Brightness b) =>
      (b == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.18);

  /// `0 12px 32px color-mix(#000 15%)` of glass overlays ([opacity] .06
  /// for toasts).
  static List<BoxShadow> overlayShadow([double opacity = 0.15]) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  /// IOS27_SWEEP: buttons inside alerts / action sheets
  /// (`glass-background-overlay-button`: `--ion-background-color-step-200`
  /// → #cccccc in light mode, the app's dark `--ion-color-step-200`
  /// #333333).
  static Color overlayButton(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF333333) : const Color(0xFFCCCCCC);

  /// Pressed overlay button (`.ion-activated`: `rgba(text, .06)`).
  static Color overlayButtonActivated(Brightness b) =>
      (b == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.06);

  /// IOS27_SWEEP: pressed `ion-item` (`--background-activated` text colour
  /// at `--background-activated-opacity: .12`) – rows in popovers / selects.
  static Color itemActivated(Brightness b) =>
      (b == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: 0.12);

  /// IOS27_SWEEP: `--ios-theme-destructive-color` of overlay actions:
  /// #ea292d, dark #ff686b (independent of the app's danger colour).
  static Color destructive(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFFF686B) : const Color(0xFFEA292D);

  /// Selected tab pill: light `rgba(16,16,16,.095)`
  /// (`--ios27-button-color-selected-default-rgb`); dark
  /// `--ios27-tab-selected-background` = `rgba(0,0,0,.72)`.
  static Color selectedPill(Brightness b) => b == Brightness.dark
      ? Colors.black.withValues(alpha: 0.72)
      : const Color(0xFF101010).withValues(alpha: 0.095);
}

/// A rounded Liquid Glass surface (blurred translucent background, thin rim)
/// as used by ionic-theme-ios27 for tab bars, segments, toolbar button
/// groups and – with [overlay] – alerts, action sheets, popovers and toasts.
class IosGlassSurface extends StatelessWidget {
  const IosGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
    this.opacity,
    this.blur = 12,
    this.padding,
    this.overlay = false,
    this.shadowOpacity = 0.15,
    this.shadows,
    this.backdropBrightness = 1,
    this.color,
  });

  /// IOS27_SWEEP: an `ion-popover` surface (ionic-theme-ios27):
  /// `rgba(glass, .42)` (dark `.08`) over `blur(12px) brightness(1.35)`
  /// (dark `.9`), radius 34, 0.5pt `rgba(text, .18)` border and
  /// `0 4px 16px rgba(0,0,0,.12)`.
  factory IosGlassSurface.popover({
    Key? key,
    required Brightness brightness,
    required Widget child,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(34)),
    EdgeInsetsGeometry? padding,
  }) =>
      IosGlassSurface(
        key: key,
        borderRadius: borderRadius,
        overlay: true,
        opacity: brightness == Brightness.dark ? 0.08 : 0.42,
        blur: 12,
        backdropBrightness: brightness == Brightness.dark ? 0.9 : 1.35,
        shadows: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
        padding: padding,
        child: child,
      );

  final Widget child;
  final BorderRadius borderRadius;

  /// Background opacity; default .72 (controls) or
  /// [IosGlass.overlayOpacity] ([overlay]).
  final double? opacity;
  final double blur;
  final EdgeInsetsGeometry? padding;

  /// IOS27_SWEEP: `api.glass-overlay-surface` – `rgba(text, .18)` 0.5px
  /// border and the `0 12px 32px` overlay shadow instead of the white rim
  /// and the hairline ring of glass controls.
  final bool overlay;

  /// Opacity of the overlay shadow (toast .06).
  final double shadowOpacity;

  /// Replaces the default outer shadows.
  final List<BoxShadow>? shadows;

  /// CSS `backdrop-filter: brightness()` applied to the blurred backdrop.
  final double backdropBrightness;

  /// Replaces the glass background colour (then [opacity] is ignored).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = opacity ?? (overlay ? IosGlass.overlayOpacity(b) : 0.72);
    final shadows = this.shadows ??
        (overlay ? IosGlass.overlayShadow(shadowOpacity) : IosGlass.shadow(b));
    final blurFilter = ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    final k = backdropBrightness;
    final filter = k == 1
        ? blurFilter
        : ImageFilter.compose(
            outer: ColorFilter.matrix(<double>[
              k, 0, 0, 0, 0, //
              0, k, 0, 0, 0, //
              0, 0, k, 0, 0, //
              0, 0, 0, 1, 0, //
            ]),
            inner: blurFilter,
          );
    return CustomPaint(
      painter: shadows.isEmpty
          ? null
          : IosOuterShadowPainter(borderRadius: borderRadius, shadows: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: filter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color ?? IosGlass.background(b, bg),
              borderRadius: borderRadius,
              border: Border.all(
                color: overlay ? IosGlass.overlayBorder(b) : IosGlass.border(b),
                width: 0.5,
              ),
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

/// IOS27_SWEEP: paints [shadows] around a rounded rect but never under it,
/// like CSS `box-shadow` below a translucent glass surface.
class IosOuterShadowPainter extends CustomPainter {
  const IosOuterShadowPainter({
    required this.borderRadius,
    required this.shadows,
  });

  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(200))
      ..addRRect(rrect));
    for (final s in shadows) {
      canvas.drawRRect(
        rrect.shift(s.offset).inflate(s.spreadRadius),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(IosOuterShadowPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.shadows != shadows;
}
