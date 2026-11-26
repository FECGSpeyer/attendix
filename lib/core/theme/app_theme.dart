import 'package:flutter/cupertino.dart'
    show
        CupertinoFullscreenDialogTransition,
        CupertinoPageTransitionsBuilder,
        CupertinoPageTransition,
        CupertinoRouteTransitionMixin;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/native/native_platform.dart' show isNativeIos;
import 'app_colors.dart';
import 'browser_navigation_transition_gate.dart';

/// Base Material 3 theme configuration shared by [buildRdTheme] across all
/// Farbwelten and platforms.
class AppTheme {
  AppTheme._();

  /// Optional platform look override (used by tests and web query previews).
  static TargetPlatform? webLookOverride;

  /// Active platform used when building the base theme.
  static TargetPlatform get lookPlatform => webLookOverride ?? defaultTargetPlatform;

  /// Light base theme.
  static ThemeData get light => forPlatform(Brightness.light, lookPlatform);

  /// Dark base theme.
  static ThemeData get dark => forPlatform(Brightness.dark, lookPlatform);

  /// Bundled Roboto font family used on the web so CanvasKit renders real
  /// weights (400/500/600/700 + italic).
  static const String webFontFamily = 'Roboto';

  /// Base theme for [brightness] on [platform]. [web] defaults to [kIsWeb].
  static ThemeData forPlatform(
    Brightness brightness,
    TargetPlatform platform, {
    bool web = kIsWeb,
  }) =>
      _build(brightness, ios: platform == TargetPlatform.iOS, web: web)
          .copyWith(platform: platform);

  static ThemeData _build(
    Brightness brightness, {
    required bool ios,
    required bool web,
  }) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.lightOnDark : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.iosTextLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final medium = isDark ? AppColors.mediumOnDark : AppColors.medium;

    final base = isDark
        ? const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            primaryContainer: AppColors.primaryDark,
            onPrimaryContainer: Colors.white,
            secondary: AppColors.secondaryOnDark,
            onSecondary: Colors.white,
            secondaryContainer: AppColors.secondaryDark,
            onSecondaryContainer: AppColors.secondaryLight,
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
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: isDark ? const Color(0xFF242426) : const Color(0xFFF7F7F9),
      surfaceContainerHigh: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
      surfaceContainerHighest: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE9E9EE),
      outlineVariant: divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: web ? webFontFamily : null,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: divider,
      hoverColor: ios ? Colors.transparent : null,
      focusColor: ios ? Colors.transparent : null,
      // Keep the theme's SwitchThemeData on iOS/macOS instead of system green.
      adaptations: const <Adaptation<Object>>[_IonToggleAdaptation()],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: IonIosPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: textPrimary.withValues(alpha: 0.6),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.84,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.84,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: ios
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.25)),
        side: ios
            ? WidgetStateBorderSide.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const BorderSide(color: Colors.transparent)
                    : BorderSide(
                        color: textPrimary.withValues(alpha: 0.23),
                        width: 1.6,
                      ),
              )
            : WidgetStateBorderSide.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const BorderSide(color: AppColors.primary, width: 2)
                    : BorderSide(
                        color: textPrimary.withValues(alpha: 0.6),
                        width: 2,
                      ),
              ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
      ),
      chipTheme: const ChipThemeData(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        insetPadding: EdgeInsets.fromLTRB(16, 5, 16, 10),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        dragHandleSize: ios ? const Size(60, 4) : null,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}

/// Keeps the theme's [SwitchThemeData] on iOS/macOS instead of Flutter's
/// default adaptation that replaces it with system green.
class _IonToggleAdaptation extends Adaptation<SwitchThemeData> {
  const _IonToggleAdaptation();

  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) =>
      defaultValue;
}

/// iOS page slide (and bottom-up slide for full-screen dialogs).
///
/// Native iOS keeps the left-edge swipe-back gesture; web skips the duplicate
/// slide when Safari already animated the browser history gesture.
class IonIosPageTransitionsBuilder extends PageTransitionsBuilder {
  const IonIosPageTransitionsBuilder({this.swipeBack, this.skipCheck});

  /// Defaults to [isNativeIos]; tests set it explicitly.
  final bool? swipeBack;

  /// Whether the browser just animated a history step itself.
  final bool Function()? skipCheck;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (swipeBack ?? isNativeIos) {
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
          route, context, animation, secondaryAnimation, child);
    }
    return BrowserNavigationTransitionGate(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      skipCheck: skipCheck,
      builder: (animation, secondaryAnimation) {
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
      },
    );
  }
}

/// Android / web zoom page transition that skips duplicate animation when the
/// browser already animated a history gesture.
class AppZoomPageTransitionsBuilder extends ZoomPageTransitionsBuilder {
  const AppZoomPageTransitionsBuilder({this.skipCheck});

  /// Defaults to the browser check; tests set it explicitly.
  final bool Function()? skipCheck;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!kIsWeb && skipCheck == null) {
      return super.buildTransitions(
          route, context, animation, secondaryAnimation, child);
    }
    return BrowserNavigationTransitionGate(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      skipCheck: skipCheck,
      builder: (animation, secondaryAnimation) => super.buildTransitions(
          route, context, animation, secondaryAnimation, child),
    );
  }
}
