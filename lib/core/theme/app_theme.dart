import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// App theme configuration.
///
/// Mirrors the Ionic app's look (src/theme/variables.scss + global.scss with
/// the iOS theme): teal primary, grouped light-grey page background with
/// white inset cards, light toolbars with a hairline, centered 17pt titles,
/// primary-colored header buttons and an iOS-style back chevron, and a tab
/// bar without a selection pill (selected icon + label in primary).
class AppTheme {
  AppTheme._();

  /// Light theme
  static ThemeData get light => _build(Brightness.light);

  /// Dark theme
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final bar = isDark ? AppColors.barDark : AppColors.barLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final inputFill =
        isDark ? AppColors.inputFillDark : AppColors.inputFillLight;
    // Ionic global `ion-button[disabled] { opacity: .5 }` on primary buttons.
    final disabledPrimary = AppColors.primary.withValues(alpha: 0.5);

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

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      // ion-header (iOS): light toolbar, hairline border, centered 17pt title,
      // header buttons and back chevron in primary.
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: bar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actionsIconTheme: const IconThemeData(color: AppColors.primary),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        shape: Border(bottom: BorderSide(color: divider, width: 0.5)),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder:
            (context) => const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
      // ion-list inset / ion-card: white rounded sections without border.
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.medium,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius10),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          // Ionic: a disabled ion-button keeps its colour at opacity 0.5.
          disabledBackgroundColor: disabledPrimary,
          disabledForegroundColor: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius10),
          disabledBackgroundColor: disabledPrimary,
          disabledForegroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius10),
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      // ion-fab-button: round, primary.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bar,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.medium,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      // ion-tab-bar (iOS): no pill, selected icon + label in primary,
      // unselected in medium grey, small labels under the icons.
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
            color: selected ? AppColors.primary : AppColors.medium,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.medium,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bar,
        indicatorColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: const IconThemeData(color: AppColors.medium),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.medium,
        ),
      ),
      // ion-segment: primary text, light pill.
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
      // ion-toggle (iOS): primary track when on, white thumb.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? null : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : (isDark ? const Color(0xFF39393D) : const Color(0xFFE9E9EA));
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
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
      // ion-toast (iOS theme: --border-radius 24px)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      // ion-alert (iOS): rounded, untinted.
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
