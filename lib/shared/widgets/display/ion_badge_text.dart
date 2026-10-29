import 'package:flutter/widgets.dart';

/// PARITY_R8: label style of an Ionic `ion-badge` (badge.ios.css /
/// badge.md.css: `font-weight: bold`, `line-height: 1`; 13px unless the
/// caller passes another size). Every badge label should go through this.
///
/// WEB_FONTS: the real 700 on the web comes from the app-wide bundled
/// Roboto (AppTheme.webFontFamily), which replaced the badge-only
/// `IonBadge` font; native platforms use their system fonts.
TextStyle ionBadgeTextStyle({
  Color? color,
  double fontSize = 13,
  double? height = 1,
  FontWeight fontWeight = FontWeight.w700,
}) =>
    TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
