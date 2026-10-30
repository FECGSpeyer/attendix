import 'package:flutter/foundation.dart' show kIsWeb;
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

extension RdSkinContext on BuildContext {
  /// Palette of the new design while the Beta theme is active, else null.
  ///
  /// The old (Ionic) building blocks draw themselves in the new design when
  /// this is set ("Beta-Skin"), so every old page, sheet and dialog that is
  /// reachable from the Beta looks like the new design. Without the Beta
  /// they keep the Ionic look.
  RdPalette? get rdSkin => Theme.of(this).extension<RdTokens>()?.palette;
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
  final font = kIsWeb ? AppTheme.webFontFamily : null;
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.buttonRadius));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: p.offBorder),
  );
  WidgetStateProperty<Color?> selectedOr(Color on, Color? off) =>
      WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? on : off);
  // Beta-Skin: component themes of the new design for the old pages. Pages
  // built from the Rd* widgets set their own styles and are not affected.
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.surface,
    dividerColor: p.line,
    splashFactory: InkRipple.splashFactory,
    highlightColor: p.text.withValues(alpha: 0.04),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: false,
      shape: const Border(),
      iconTheme: IconThemeData(color: p.link),
      actionsIconTheme: IconThemeData(color: p.link, size: 24),
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Icon(Icons.chevron_left, size: 30, color: p.link),
      closeButtonIconBuilder: (context) => Icon(Icons.close, color: p.link),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.cardRadius)),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      minTileHeight: 52,
      iconColor: p.text2,
      textColor: p.text,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w500, color: p.text),
      subtitleTextStyle: TextStyle(fontFamily: font, fontSize: 13, height: 1.3, color: p.text2),
      leadingAndTrailingTextStyle: TextStyle(fontFamily: font, fontSize: 15, color: p.text2),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: p.surface,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.primary, width: 2)),
      errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.absent)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.absent, width: 2)),
      labelStyle: TextStyle(color: p.text2),
      floatingLabelStyle: TextStyle(color: p.primary),
      hintStyle: TextStyle(color: p.text2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        disabledBackgroundColor: p.track,
        disabledForegroundColor: p.text2,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        disabledBackgroundColor: p.track,
        disabledForegroundColor: p.text2,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.offBorder, width: 1.5),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.link,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.link)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 4,
      iconSize: 26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: selectedOr(p.surface, p.track),
        foregroundColor: selectedOr(p.text, p.text2),
        side: WidgetStatePropertyAll(BorderSide(color: p.track)),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: p.primary,
      unselectedLabelColor: p.text2,
      indicatorColor: p.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? Colors.white.withValues(alpha: 0.7) : Colors.white,
      ),
      // Locked switches look locked: the track fades out.
      trackColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected) ? p.primary : p.track;
        return s.contains(WidgetState.disabled) ? on.withValues(alpha: 0.4) : on;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: base.checkboxTheme.copyWith(
      fillColor: selectedOr(p.primary, Colors.transparent),
      checkColor: WidgetStatePropertyAll(p.onPrimary),
    ),
    radioTheme: RadioThemeData(fillColor: selectedOr(p.primary, p.text2)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.track),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.surface,
      selectedColor: p.soft,
      labelStyle: TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w500, color: p.text),
      side: BorderSide(color: p.offBorder),
      shape: const StadiumBorder(),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: p.toastBg,
      contentTextStyle: TextStyle(fontFamily: font, fontSize: 15, color: p.toastText),
      actionTextColor: p.toastAction,
      closeIconColor: p.toastText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700, color: p.text),
      contentTextStyle: TextStyle(fontFamily: font, fontSize: 15, height: 1.35, color: p.text2),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: font, fontSize: 16, color: p.text)),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: p.bg,
      modalBackgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: p.offBorder,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    datePickerTheme: base.datePickerTheme.copyWith(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: p.primary,
      headerForegroundColor: p.onPrimary,
      todayBorder: BorderSide(color: p.primary),
    ),
    timePickerTheme: base.timePickerTheme.copyWith(
      backgroundColor: p.surface,
      dialHandColor: p.primary,
    ),
    extensions: [
      ...base.extensions.values.where((e) => e is! RdTokens),
      RdTokens(world: world, palette: p),
    ],
  );
}
