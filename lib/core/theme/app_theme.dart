import 'package:flutter/cupertino.dart'
    show CupertinoFullscreenDialogTransition, CupertinoPageTransition;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/adaptive/adaptive_platform.dart' show IosGlass;
import '../../shared/widgets/adaptive/app_toolbar.dart'
    show IosCircleIcon, IonToolbarButtonMetrics, kIonTitleFontSize;
import 'app_colors.dart';

/// App theme configuration.
///
/// Mirrors the Ionic app's look (src/theme/variables.scss + global.scss with
/// @rdlabo/ionic-theme-ios27 on the iPhone): teal primary, grouped light-grey page
/// background with white inset lists, light toolbars with a hairline and
/// centered 17pt titles.
///
/// IOS_LOOK: on iOS (iPhone app and Flutter web in iOS Safari) the theme
/// follows Ionic's **iOS mode** as rendered on an iPhone: black toolbar icons
/// with a Liquid Glass back chevron, stadium buttons (17pt, disabled grey),
/// round checkboxes, white glass FAB with black icon, 17pt list rows,
/// frosted toasts and the exact iOS colours (dark: #222428 pages, black
/// rows). Elsewhere the Material look of Ionic md mode is kept.
class AppTheme {
  AppTheme._();

  /// IOS27_SWEEP: ion-button `--border-radius: 24px` (ionic-theme-ios27).
  static const double iosButtonRadius = 24;

  /// IOS27_SWEEP: ion-button host `min-height: 3.1em` with the ios27
  /// 1.05rem font (17.85pt) = 55.35pt.
  static const double iosButtonMinHeight = 3.1 * 17.85;

  /// IOS27_SWEEP: ion-fab-button 61 × 61 (60px + 0.5px rim on each side).
  static const double iosFabSize = 61;

  /// Light theme
  static ThemeData get light => forPlatform(Brightness.light, defaultTargetPlatform);

  /// Dark theme
  static ThemeData get dark => forPlatform(Brightness.dark, defaultTargetPlatform);

  /// Theme for [brightness] on [platform] (iOS → Ionic iOS mode).
  static ThemeData forPlatform(Brightness brightness, TargetPlatform platform) =>
      _build(brightness, ios: platform == TargetPlatform.iOS);

  static ThemeData _build(Brightness brightness, {required bool ios}) {
    final isDark = brightness == Brightness.dark;
    // IOS_THEME2: iOS dark = black page with #1c1c1d rows / cards (as on
    // the iPhone); md dark = Ionic md #121212 page, #1e1e1e items / cards.
    final background = ios
        ? (isDark ? AppColors.iosPageDark : AppColors.iosPageLight)
        : (isDark ? AppColors.mdPageDark : AppColors.backgroundLight);
    final surface = ios && isDark
        ? AppColors.iosItemDark
        : (isDark ? AppColors.mdItemDark : AppColors.surfaceLight);
    final cardColor = ios
        ? (isDark ? AppColors.iosItemDark : AppColors.surfaceLight)
        : (isDark ? AppColors.mdItemDark : AppColors.surfaceLight);
    // IOS_THEME2: Ionic md toolbar = page/background colour (white, dark
    // #1f1f1f) with the md header shadow instead of a grey bar + hairline.
    final bar = ios
        ? (isDark ? AppColors.iosToolbarDark : AppColors.iosToolbarLight)
        : (isDark ? AppColors.mdToolbarDark : Colors.white);
    final barBorder = ios
        ? (isDark
            ? AppColors.iosToolbarBorderDark
            : AppColors.iosToolbarBorderLight)
        : (isDark ? AppColors.mdBorderDark : AppColors.dividerLight);
    final textPrimary = ios && !isDark
        ? AppColors.iosTextLight
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    // IOS27_SWEEP: ionic-theme-ios27 `ion-list.ios { --ion-border-color:
    // step-100 }` – #e8e8e8, dark #1a1a1a item lines.
    final divider = ios
        ? (isDark ? AppColors.iosListLineDark : AppColors.iosListLineLight)
        : (isDark ? AppColors.dividerDark : AppColors.dividerLight);
    final inputFill =
        isDark ? AppColors.inputFillDark : AppColors.inputFillLight;
    final medium = isDark ? AppColors.mediumOnDark : AppColors.medium;
    // IOS27_SWEEP: Ionic 9 `ion-label p` (`--ion-color-step-400`).
    final labelP =
        isDark ? AppColors.iosLabelPDark : AppColors.iosLabelPLight;
    // Ionic global `ion-button[disabled] { opacity: .5 }` on primary buttons;
    // iOS 26 theme: neutral grey (#ccc) with a white label.
    final disabledPrimary = ios
        ? AppColors.iosDisabledButton
        : AppColors.primary.withValues(alpha: 0.5);
    // Toolbar / header button colour: iOS 26 theme renders clear toolbar
    // buttons in the text colour; IOS_THEME2: Ionic md toolbar buttons are
    // black / grey too (toolbar colour), not primary.
    final barIcon = ios
        ? textPrimary
        : (isDark ? Colors.white : const Color(0xFF424242));
    // IOS_THEME2: Ionic iOS has no ripple, no hover / focus highlight on
    // items (ios26: --background-hover/focused-opacity 0); a touch shows
    // the activated grey (`--background-activated` text colour at .12).
    final pressHighlight = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.12);

    final base =
        isDark
            ? const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              primaryContainer: AppColors.primaryDark,
              onPrimaryContainer: Colors.white,
              onSecondary: Colors.white,
              secondaryContainer: AppColors.secondaryDark,
              onSecondaryContainer: AppColors.secondaryLight,
              // IOS_THEME2: Ionic dark palette (attendix-dark-theme-body)
              secondary: AppColors.secondaryOnDark,
              tertiary: AppColors.tertiaryOnDark,
              onTertiary: Colors.white,
              error: AppColors.dangerOnDark,
              onError: Colors.white,
              outline: AppColors.mediumOnDark,
            )
            : const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFD9ECEE),
              onPrimaryContainer: AppColors.primaryDark,
              secondary: AppColors.secondary,
              onSecondary: Colors.white,
              secondaryContainer: AppColors.secondaryLight,
              onSecondaryContainer: AppColors.secondaryDark,
              tertiary: AppColors.tertiary,
              onTertiary: Colors.white,
              error: AppColors.danger,
              onError: Colors.white,
              outline: AppColors.medium,
            );

    final colorScheme = base.copyWith(
      surface: surface,
      onSurface: textPrimary,
      surfaceTint: Colors.transparent,
      outline: medium,
      // Neutral (untinted) containers like iOS grouped tables.
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer:
          isDark ? const Color(0xFF242426) : const Color(0xFFF7F7F9),
      surfaceContainerHigh:
          isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
      surfaceContainerHighest:
          isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE9E9EE),
      outlineVariant: divider,
    );

    final radius8 = BorderRadius.circular(8);
    final radius10 = BorderRadius.circular(10);
    // IOS27_SWEEP: ion-button (ionic-theme-ios27 `theme-button`):
    // `--border-radius: 24px`, 1.05rem (17.85pt) medium label, 12pt
    // padding, host `min-height: 3.1em` (55.35pt).
    final OutlinedBorder buttonShape = ios
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.iosButtonRadius))
        : RoundedRectangleBorder(borderRadius: radius10);
    final buttonPadding = ios
        ? const EdgeInsets.symmetric(horizontal: 12)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    final buttonText = ios
        ? const TextStyle(
            fontSize: IonToolbarButtonMetrics.textSize,
            fontWeight: FontWeight.w500)
        : null;
    final Size? buttonMinSize =
        ios ? const Size(64, AppTheme.iosButtonMinHeight) : null;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: divider,
      // IOS_THEME2: iOS list rows / buttons: no ripple and no lingering
      // hover / focus highlight after a tap (e.g. returning from a pushed
      // page); md keeps the Material ink.
      splashFactory: ios ? NoSplash.splashFactory : null,
      highlightColor: ios ? pressHighlight : null,
      hoverColor: ios ? Colors.transparent : null,
      focusColor: ios ? Colors.transparent : null,
      // IOS_THEME2: ion-toggle is primary (teal) on iOS too – the default
      // iOS switch adaptation would drop the theme and use system green.
      adaptations: const <Adaptation<Object>>[_IonToggleAdaptation()],
      // IOS_R6: Ionic iOS pushes pages with the iOS slide; every
      // MaterialPage / MaterialPageRoute uses it on iOS (incl. the iPhone
      // Safari PWA). Ionic disables the edge swipe-back
      // (`swipeBackEnabled: false` in app.module.ts, it caused a double back
      // with the browser's own swipe), so the slide comes without the
      // gesture. md keeps the Flutter defaults.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: IonIosPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // ion-header (iOS): light toolbar, hairline border, centered 17pt title.
      // IOS_SHELL: Ionic headers are `translucent` (iOS 26 theme:
      // `--background: transparent`), i.e. they show the page background
      // (white / black) instead of a grey bar – keep only the hairline.
      // IOS_THEME2: md (desktop / Android) = Ionic md toolbar: white
      // (dark #1f1f1f) with the md header shadow, left-aligned 20pt title.
      appBarTheme: AppBarTheme(
        elevation: ios ? 0 : 4,
        scrolledUnderElevation: ios ? 0 : 4,
        shadowColor: ios ? null : Colors.black.withValues(alpha: 0.5),
        centerTitle: ios,
        backgroundColor: ios ? Colors.transparent : bar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: barIcon),
        actionsIconTheme: IconThemeData(color: barIcon),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        shape: ios
            ? Border(bottom: BorderSide(color: barBorder, width: 0.5))
            : null,
        titleTextStyle: TextStyle(
          color: textPrimary,
          // IOS27_SWEEP: ion-title min(1.0625rem, 20.4px) = 18.06pt
          fontSize: ios ? kIonTitleFontSize : 20,
          fontWeight: ios ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      // ion-back-button: iOS 26 Liquid Glass circle with a black chevron
      // (Ionic pages use `text=""`); modal close: grey circle with ✕.
      actionIconTheme: ActionIconThemeData(
        // IOS_THEME2: md back button = arrow-back-sharp (←).
        backButtonIconBuilder: (context) => ios
            ? const IosCircleIcon(icon: Icons.arrow_back_ios_new, iconSize: 20)
            : const Icon(Icons.arrow_back),
        closeButtonIconBuilder: ios
            ? (context) => const IosCircleIcon(icon: Icons.close, filled: true)
            : null,
      ),
      // ion-list inset / ion-card: rounded sections without border.
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
        surfaceTintColor: Colors.transparent,
      ),
      // ion-item (iOS): 17pt label, 14pt grey paragraph.
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: medium,
        titleTextStyle:
            ios ? TextStyle(fontSize: 17, color: textPrimary) : null,
        // IOS27_SWEEP: ion-label p .875rem (14.875pt), step-400.
        subtitleTextStyle:
            ios ? TextStyle(fontSize: 0.875 * 17, color: labelP) : null,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 0.5, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius8,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: ios ? const TextStyle(color: Color(0xFF777777)) : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          // Ionic: a disabled ion-button keeps its colour at opacity 0.5.
          disabledBackgroundColor: disabledPrimary,
          disabledForegroundColor: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
          disabledBackgroundColor: disabledPrimary,
          disabledForegroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // IOS27_SWEEP: ion-button 1.05rem
          textStyle: ios
              ? const TextStyle(fontSize: IonToolbarButtonMetrics.textSize)
              : null,
        ),
      ),
      // ion-fab-button: md round primary; IOS27_SWEEP ionic-theme-ios27:
      // 61pt glass circle `rgba(glass, .72)` (dark `glass.dark-fill` .5)
      // with a black icon (28px), the 0.5pt `rgba(text, .22)` ring of
      // `glass.light-shadow` instead of a Material shadow.
      floatingActionButtonTheme: ios
          ? FloatingActionButtonThemeData(
              backgroundColor: IosGlass.background(
                  brightness, isDark ? 0.5 : 0.72),
              foregroundColor: textPrimary,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              shape: CircleBorder(
                side: BorderSide(
                  color: isDark
                      ? IosGlass.border(brightness)
                      : const Color(0x38000000),
                  width: 0.5,
                ),
              ),
              sizeConstraints: const BoxConstraints.tightFor(
                  width: AppTheme.iosFabSize, height: AppTheme.iosFabSize),
              iconSize: 28,
            )
          : const FloatingActionButtonThemeData(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: CircleBorder(),
            ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bar,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: medium,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // ion-tab-bar: no pill, selected icon + label in primary,
      // unselected in medium grey, small labels under the icons.
      // (iOS renders its own floating glass tab bar, see MainShell.)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 58,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: selected ? AppColors.primary : medium,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary : medium,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bar,
        indicatorColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: medium),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelTextStyle: TextStyle(fontSize: 12, color: medium),
      ),
      // ion-segment: primary text, light pill (iOS: see AppSegmentedButton).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : textPrimary,
          ),
        ),
      ),
      // IOS_THEME2: TabBars standing in for an md `ion-segment`: primary
      // label + 2pt underline, 60 % text colour otherwise, no divider.
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: textPrimary.withValues(alpha: 0.6),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.84),
        unselectedLabelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.84),
      ),
      // ion-toggle (iOS): primary track when on, white thumb; off track
      // rgba(text, .23) in the iOS 26 theme.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? null : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          if (ios) {
            // ionic-theme-ios26: rgba(text, .23)
            return (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.23);
          }
          return isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EA);
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      // ion-checkbox: iOS round (22pt), md square.
      checkboxTheme: CheckboxThemeData(
        shape: ios
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        // IOS27_SWEEP: core iOS checkbox border `rgba(text, .23)`,
        // 0.125rem on the 1.375rem box – the same proportion (1.6pt) on
        // Flutter's 18pt box.
        side: ios
            ? WidgetStateBorderSide.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const BorderSide(color: Colors.transparent)
                    : BorderSide(
                        color: textPrimary.withValues(alpha: 0.23),
                        width: 1.6,
                      ),
              )
            : null,
        fillColor: ios
            ? WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : Colors.transparent,
              )
            : null,
      ),
      radioTheme: ios
          ? const RadioThemeData(
              fillColor: WidgetStatePropertyAll(AppColors.primary),
            )
          : null,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      // IOS27_SWEEP: ion-chip (core iOS): `rgba(text, .12)` / `.87` text,
      // radius 16, 12 × 6 padding, 0.875rem (14.875pt).
      chipTheme: ios
          ? ChipThemeData(
              backgroundColor: textPrimary.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                  fontSize: 0.875 * 17,
                  color: textPrimary.withValues(alpha: 0.87)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              side: BorderSide.none,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : ChipThemeData(
              backgroundColor: inputFill,
              labelStyle: const TextStyle(fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
      // ion-toast (global.scss `--border-radius: 24px` over the ios27 28px;
      // IOS27_SWEEP: ios27 glass overlay rim `rgba(text, .18)`, core iOS
      // text `--ion-color-step-850` #262626 / dark #d9d9d9, .94rem
      // (15.98pt), `--start/--end: 16px`, max-width 560. The background
      // stays nearly opaque: a SnackBar cannot blur what is behind it (the
      // ios27 toast is .67 / dark .52 over a 20px blur).
      snackBarTheme: ios
          ? SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: isDark
                  ? const Color(0xF23E3E3E)
                  : Colors.white.withValues(alpha: 0.96),
              contentTextStyle: TextStyle(
                color: isDark
                    ? const Color(0xFFD9D9D9)
                    : const Color(0xFF262626),
                fontSize: 0.94 * 17,
                height: 1.33,
              ),
              actionTextColor: AppColors.primary,
              closeIconColor: textPrimary,
              elevation: 2,
              width: null,
              insetPadding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: IosGlass.overlayBorder(brightness),
                  width: 0.5,
                ),
              ),
            )
          : SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
      // ion-alert: rounded, untinted (iOS alerts: AppAlertDialog).
      dialogTheme: DialogThemeData(
        backgroundColor: ios && isDark ? AppColors.iosModalDark : cardColor,
        surfaceTintColor: Colors.transparent,
        // IOS27_SWEEP: ion-alert `.alert-wrapper` radius 36.
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ios ? 36 : 16)),
      ),
      // IOS_THEME2: ion-popover – iOS 26 radius 24, md radius 4; opens
      // below its trigger (no row under the pointer gets highlighted).
      popupMenuTheme: PopupMenuThemeData(
        color: ios && isDark ? AppColors.iosModalDark : cardColor,
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
        // IOS27_SWEEP: ios27 popover `::part(content)` radius 34; rows are
        // ion-items (1rem = 17pt).
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ios ? 34 : 4)),
        labelTextStyle: ios
            ? WidgetStatePropertyAll(
                TextStyle(fontSize: 17, color: textPrimary))
            : null,
      ),
      // ion-modal sheet (iOS 26 theme: --border-radius 30px on sheets;
      // PARITY_R3: Ionic md modal `--border-radius: 0` on phones – the
      // desktop size/radius comes from IonModalTheme).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ios && isDark ? AppColors.iosModalDark : cardColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        clipBehavior: ios ? Clip.antiAlias : null,
        dragHandleColor: ios
            ? (isDark ? const Color(0xFF404040) : const Color(0xFFC8C7CC))
            : null,
        // PARITY_R5: ionic-theme-ios27 handle 60 × 4 and sheet radius 32.
        dragHandleSize: ios ? const Size(60, 4) : null,
        shape: ios
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              )
            : const RoundedRectangleBorder(),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}

/// IOS_THEME2: Ionic `ion-toggle` keeps the app colours on iOS (primary
/// track, white handle). Flutter's default adaptation replaces the theme's
/// [SwitchThemeData] with an empty one on iOS/macOS, which renders
/// `Switch.adaptive` / `SwitchListTile.adaptive` in system green.
class _IonToggleAdaptation extends Adaptation<SwitchThemeData> {
  const _IonToggleAdaptation();

  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) =>
      defaultValue;
}

/// IOS_R6: the iOS page slide (and the bottom-up slide for full-screen
/// dialogs) without the edge swipe-back gesture, like Ionic with
/// `swipeBackEnabled: false`.
class IonIosPageTransitionsBuilder extends PageTransitionsBuilder {
  const IonIosPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.fullscreenDialog) {
      return CupertinoFullscreenDialogTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: false,
        child: child,
      );
    }
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}
