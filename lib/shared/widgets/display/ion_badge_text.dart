import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// PARITY_R8: font family of the bundled Roboto Bold subset
/// (`assets/fonts/IonBadge-Bold.ttf`, see pubspec.yaml).
const String kIonBadgeFontFamily = 'IonBadge';

/// PARITY_R8: whether badge labels use [kIonBadgeFontFamily]. Only on the
/// web: CanvasKit ships Roboto Regular alone and fakes bold, which renders
/// `ion-badge` labels at ≈500 instead of Ionic's `font-weight: bold` (700).
/// Native iOS / Android have real bold system fonts. Overridable in tests.
@visibleForTesting
bool? debugIonBadgeUseWebFont;

bool get _useBadgeFont => debugIonBadgeUseWebFont ?? kIsWeb;

/// PARITY_R8: label style of an Ionic `ion-badge` (badge.ios.css /
/// badge.md.css: `font-weight: bold`, `line-height: 1`; 13px unless the
/// caller passes another size). Every badge label should go through this,
/// so the rendered weight is a real 700 on all platforms.
TextStyle ionBadgeTextStyle({
  Color? color,
  double fontSize = 13,
  double? height = 1,
  FontWeight fontWeight = FontWeight.w700,
}) =>
    ionBadgeFont(TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    ));

/// PARITY_R8: [style] with the real-bold badge font on the web (keeps the
/// system font family as fallback for glyphs the subset lacks, e.g. ✓).
TextStyle ionBadgeFont(TextStyle style) {
  if (!_useBadgeFont) return style;
  final weight = style.fontWeight ?? FontWeight.w400;
  if (weight.value < FontWeight.w600.value) return style;
  return style.copyWith(
    fontFamily: kIonBadgeFontFamily,
    fontFamilyFallback: [
      if (style.fontFamily != null) style.fontFamily!,
      ...?style.fontFamilyFallback,
    ],
  );
}
