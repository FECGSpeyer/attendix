import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/adaptive/app_toolbar.dart' show IosCircleIcon;
import 'app_colors.dart';

/// App theme configuration.
///
/// Mirrors the Ionic app's look (src/theme/variables.scss + global.scss with
/// @rdlabo/ionic-theme-ios26): teal primary, grouped light-grey page
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

  /// Light theme
  static ThemeData get light => forPlatform(Brightness.light, defaultTargetPlatform);

  /// Dark theme
  static ThemeData get dark => forPlatform(Brightness.dark, defaultTargetPlatform);

  /// Theme for [brightness] on [platform] (iOS → Ionic iOS mode).
  static ThemeData forPlatform(Brightness brightness, TargetPlatform platform) =>
      _build(brightness, ios: platform == TargetPlatform.iOS);

  static ThemeData _build(Brightness brightness, {required bool ios}) {
    final isDark = brightness == Brightness.dark;
    final background = ios
        ? (isDark ? AppColors.iosPageDark : AppColors.iosPageLight)
        : (isDark ? AppColors.backgroundDark : AppColors.backgroundLight);
    final surface = ios && isDark
        ? AppColors.iosItemDark
        : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final bar = ios
        ? (isDark ? AppColors.iosToolbarDark : AppColors.iosToolbarLight)
        : (isDark ? AppColors.barDark : AppColors.barLight);
    final barBorder = ios
        ? (isDark
            ? AppColors.iosToolbarBorderDark
            : AppColors.iosToolbarBorderLight)
        : (isDark ? AppColors.dividerDark : AppColors.dividerLight);
    final textPrimary = ios && !isDark
        ? AppColors.iosTextLight
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final divider = ios
        ? (isDark ? AppColors.iosItemBorderDark : AppColors.iosItemBorderLight)
        : (isDark ? AppColors.dividerDark : AppColors.dividerLight);
    final inputFill =
        isDark ? AppColors.inputFillDark : AppColors.inputFillLight;
    final medium = ios && isDark ? AppColors.iosMediumDark : AppColors.medium;
    final note = isDark ? AppColors.iosNoteDark : AppColors.iosNoteLight;
    // Ionic global `ion-button[disabled] { opacity: .5 }` on primary buttons;
    // iOS 26 theme: neutral grey (#ccc) with a white label.
    final disabledPrimary = ios
        ? AppColors.iosDisabledButton
        : AppColors.primary.withValues(alpha: 0.5);
    // Toolbar / header button colour: iOS 26 theme renders clear toolbar
    // buttons in the text colour, md keeps primary.
    final barIcon = ios ? textPrimary : AppColors.primary;

    final base =
        isDark
            ? const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              primaryContainer: AppColors.primaryDark,
              onPrimaryContainer: Colors.white,
              secondary: AppColors.secondary,
              onSecondary: Colors.white,
              secondaryContainer: AppColors.secondaryDark,
              onSecondaryContainer: AppColors.secondaryLight,
              tertiary: AppColors.tertiary,
              onTertiary: Colors.white,
              error: AppColors.danger,
              onError: Colors.white,
              outline: AppColors.medium,
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
    // ion-button (iOS 26 theme): stadium, 17pt label, ~46pt high.
    final OutlinedBorder buttonShape =
        ios ? const StadiumBorder() : RoundedRectangleBorder(borderRadius: radius10);
    final buttonPadding = ios
        ? const EdgeInsets.symmetric(horizontal: 22, vertical: 13)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    final buttonText = ios
        ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)
        : null;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: divider,
      // ion-header (iOS): light toolbar, hairline border, centered 17pt title.
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: bar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: barIcon),
        actionsIconTheme: IconThemeData(color: barIcon),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        shape: Border(bottom: BorderSide(color: barBorder, width: 0.5)),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      // ion-back-button: iOS 26 Liquid Glass circle with a black chevron
      // (Ionic pages use `text=""`); modal close: grey circle with ✕.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => ios
            ? const IosCircleIcon(icon: Icons.arrow_back_ios_new, iconSize: 20)
            : const Icon(Icons.arrow_back_ios_new, size: 20),
        closeButtonIconBuilder: ios
            ? (context) => const IosCircleIcon(icon: Icons.close, filled: true)
            : null,
      ),
      // ion-list inset / ion-card: rounded sections without border.
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: ios && isDark ? AppColors.iosItemDark : cardColor,
        surfaceTintColor: Colors.transparent,
      ),
      // ion-item (iOS): 17pt label, 14pt grey paragraph.
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: medium,
        titleTextStyle:
            ios ? TextStyle(fontSize: 17, color: textPrimary) : null,
        subtitleTextStyle: ios ? TextStyle(fontSize: 14, color: note) : null,
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
          shape: buttonShape,
          textStyle: buttonText,
          disabledBackgroundColor: disabledPrimary,
          disabledForegroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: ios ? const TextStyle(fontSize: 17) : null,
        ),
      ),
      // ion-fab-button: md round primary; iOS 26 theme: white glass circle
      // (61pt) with a black icon.
      floatingActionButtonTheme: ios
          ? FloatingActionButtonThemeData(
              backgroundColor: isDark
                  ? const Color(0xFF3E3E3E)
                  : Colors.white.withValues(alpha: 0.96),
              foregroundColor: textPrimary,
              elevation: 3,
              focusElevation: 3,
              hoverElevation: 4,
              highlightElevation: 2,
              shape: const CircleBorder(),
              sizeConstraints:
                  const BoxConstraints.tightFor(width: 60, height: 60),
              iconSize: 26,
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
            return (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.28 : 0.23);
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
        side: ios
            ? WidgetStateBorderSide.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const BorderSide(color: Colors.transparent)
                    : BorderSide(
                        color: isDark
                            ? const Color(0xFF4D4D4D)
                            : const Color(0xFFB3B3B3),
                        width: 1.5,
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
      chipTheme: ChipThemeData(
        backgroundColor: inputFill,
        labelStyle: const TextStyle(fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // ion-toast (iOS theme: --border-radius 24px; iOS 26: frosted glass
      // with dark text).
      snackBarTheme: ios
          ? SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: isDark
                  ? const Color(0xF23E3E3E)
                  : Colors.white.withValues(alpha: 0.96),
              contentTextStyle: TextStyle(color: textPrimary, fontSize: 15),
              actionTextColor: AppColors.primary,
              closeIconColor: textPrimary,
              elevation: 6,
              insetPadding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? const Color(0xFF444444) : Colors.white,
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ios ? 28 : 16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ios && isDark ? AppColors.iosModalDark : cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ios ? 20 : 12)),
      ),
      // ion-modal sheet (iOS 26 theme: --border-radius 30px on sheets).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ios && isDark ? AppColors.iosModalDark : cardColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        clipBehavior: ios ? Clip.antiAlias : null,
        dragHandleColor: ios
            ? (isDark ? const Color(0xFF404040) : const Color(0xFFC8C7CC))
            : null,
        dragHandleSize: ios ? const Size(36, 5) : null,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(ios ? 30 : 16)),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
