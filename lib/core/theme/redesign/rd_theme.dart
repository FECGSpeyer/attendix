import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'rd_palette.dart';

/// REDESIGN: tokens of the active Farbwelt, attached to the theme.
///
/// New pages read their colours, radii and title styles from here
/// (`context.rd`), so all five Farbwelten work without per-page code.
@immutable
class RdTokens extends ThemeExtension<RdTokens> {
  const RdTokens({required this.world, required this.palette});

  final RdFarbwelt world;
  final RdPalette palette;

  @override
  RdTokens copyWith({RdFarbwelt? world, RdPalette? palette}) =>
      RdTokens(world: world ?? this.world, palette: palette ?? this.palette);

  @override
  RdTokens lerp(covariant ThemeExtension<RdTokens>? other, double t) =>
      t < 0.5 || other is! RdTokens ? this : other;
}

extension RdContext on BuildContext {
  /// Palette of the new design. Outside the Beta theme (tests, old shell)
  /// it falls back to Petrol in the current brightness.
  RdPalette get rd {
    final theme = Theme.of(this);
    return theme.extension<RdTokens>()?.palette ??
        rdPalette(RdFarbwelt.petrol, theme.brightness);
  }
}

/// Font family of serif titles (Konzertsaal). Georgia ships with iOS,
/// macOS and Windows; Android falls back to its serif font.
const rdSerifFamily = 'Georgia';
const rdSerifFallback = ['Times New Roman', 'Noto Serif', 'serif'];

/// The six text levels of the new design. Sizes are logical pixels and grow
/// with the system text size (MediaQuery.textScaler).
class RdType {
  RdType._();

  static TextStyle _head(RdPalette p, double size, {double spacing = -0.4}) =>
      TextStyle(
        fontSize: size,
        fontWeight: p.headWeight,
        letterSpacing: spacing,
        color: p.text,
        height: 1.15,
        fontFamily: p.serifHeadings ? rdSerifFamily : null,
        fontFamilyFallback: p.serifHeadings ? rdSerifFallback : null,
      );

  /// "Heute", "Ich" (34).
  static TextStyle largeTitle(RdPalette p) => _head(p, 34, spacing: -0.5);

  /// Sub page title ("Darstellung", 30).
  static TextStyle title(RdPalette p) => _head(p, 30);

  /// Card title ("Gesamtprobe", 20).
  static TextStyle cardTitle(RdPalette p) => _head(p, 20, spacing: -0.2);

  /// Section heading ("Diese Woche", 17).
  static TextStyle section(RdPalette p) => _head(p, 17, spacing: 0);

  /// Body text (15).
  static TextStyle body(RdPalette p) =>
      TextStyle(fontSize: 15, color: p.text, height: 1.3);

  /// Meta line (14 / 13).
  static TextStyle meta(RdPalette p, {double size = 14}) =>
      TextStyle(fontSize: size, color: p.text2, height: 1.3);

  /// Uppercase eyebrow / group label (12).
  static TextStyle eyebrow(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      );
}

/// Theme of the new design for [world] in [brightness].
///
/// Built on the existing app theme, so pages that are not redesigned yet
/// keep their component styles and only take over the Farbwelt colours.
ThemeData buildRdTheme(RdFarbwelt world, Brightness brightness) {
  final p = rdPalette(world, brightness);
  final base = AppTheme.forPlatform(p.brightness, AppTheme.lookPlatform);
  final scheme = base.colorScheme.copyWith(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.soft,
    onPrimaryContainer: p.softText,
    secondary: p.primary,
    onSecondary: p.onPrimary,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.text2,
    outlineVariant: p.line,
    surfaceContainerHighest: p.track,
    error: p.absent,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [
      ...base.extensions.values.where((e) => e is! RdTokens),
      RdTokens(world: world, palette: p),
    ],
  );
}
