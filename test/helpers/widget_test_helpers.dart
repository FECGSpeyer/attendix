import 'package:attendix/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to pump a widget with common test infrastructure
///
/// Wraps the widget in:
/// - MaterialApp with app theme
/// - ProviderScope with optional overrides
/// - Scaffold (optional)
///
/// Example:
/// ```dart
/// await tester.pumpApp(
///   StatusBadge(status: AttendanceStatus.present),
/// );
/// ```
extension WidgetTesterExtension on WidgetTester {
  /// Pump a widget with MaterialApp and ProviderScope
  Future<void> pumpApp(
    Widget widget, {
    List<Override>? overrides,
    bool wrapInScaffold = false,
    ThemeMode themeMode = ThemeMode.light,
    NavigatorObserver? navigatorObserver,
  }) async {
    Widget child = widget;

    if (wrapInScaffold) {
      child = Scaffold(body: Center(child: widget));
    }

    await pumpWidget(
      ProviderScope(
        overrides: overrides ?? [],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: child,
          navigatorObservers:
              navigatorObserver != null ? [navigatorObserver] : [],
        ),
      ),
    );
  }

  /// Pump a widget and settle all animations
  Future<void> pumpAppAndSettle(
    Widget widget, {
    List<Override>? overrides,
    bool wrapInScaffold = false,
    ThemeMode themeMode = ThemeMode.light,
    Duration? duration,
  }) async {
    await pumpApp(
      widget,
      overrides: overrides,
      wrapInScaffold: wrapInScaffold,
      themeMode: themeMode,
    );
    await pumpAndSettle(duration ?? const Duration(seconds: 2));
  }

  /// Pump with router for testing navigation
  Future<void> pumpAppWithRouter(
    Widget widget, {
    List<Override>? overrides,
    String initialRoute = '/',
    Map<String, WidgetBuilder>? routes,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides ?? [],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          initialRoute: initialRoute,
          routes: routes ??
              {
                '/': (context) => widget,
              },
        ),
      ),
    );
  }
}

/// Helper to create a testable widget with common wrapper
Widget createTestableWidget(
  Widget widget, {
  List<Override>? overrides,
  bool wrapInScaffold = false,
  ThemeMode themeMode = ThemeMode.light,
}) {
  Widget child = widget;

  if (wrapInScaffold) {
    child = Scaffold(body: Center(child: widget));
  }

  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: child,
    ),
  );
}

/// Finder helpers for common widget patterns
extension FinderExtensions on CommonFinders {
  /// Find widget by semantic label
  Finder bySemanticsLabel(String label) {
    return find.bySemanticsLabel(label);
  }

  /// Find a widget by its tooltip
  Finder byTooltipText(String tooltip) {
    return find.byTooltip(tooltip);
  }

  /// Find a Text widget containing the substring
  Finder textContaining(String substring) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.contains(substring) ?? false),
    );
  }

  /// Find by test key string
  Finder byTestKey(String key) {
    return find.byKey(Key(key));
  }
}

/// Matcher helpers for widget testing
Matcher hasBackgroundColor(Color color) => _HasBackgroundColorMatcher(color);

class _HasBackgroundColorMatcher extends Matcher {
  final Color expectedColor;

  _HasBackgroundColorMatcher(this.expectedColor);

  @override
  Description describe(Description description) {
    return description.add('has background color $expectedColor');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is Container) {
      final decoration = item.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == expectedColor;
      }
    }
    return false;
  }

  @override
  Description describeMismatch(
    item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is Container) {
      final decoration = item.decoration;
      if (decoration is BoxDecoration) {
        return mismatchDescription
            .add('has background color ${decoration.color}');
      }
    }
    return mismatchDescription.add('is not a Container with BoxDecoration');
  }
}

/// Check if a widget has specific text style properties
Matcher hasTextStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
}) =>
    _HasTextStyleMatcher(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );

class _HasTextStyleMatcher extends Matcher {
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;

  _HasTextStyleMatcher({this.color, this.fontSize, this.fontWeight});

  @override
  Description describe(Description description) {
    final parts = <String>[];
    if (color != null) parts.add('color: $color');
    if (fontSize != null) parts.add('fontSize: $fontSize');
    if (fontWeight != null) parts.add('fontWeight: $fontWeight');
    return description.add('has text style with ${parts.join(', ')}');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is Text) {
      final style = item.style;
      if (style == null) return false;

      if (color != null && style.color != color) return false;
      if (fontSize != null && style.fontSize != fontSize) return false;
      if (fontWeight != null && style.fontWeight != fontWeight) return false;

      return true;
    }
    return false;
  }
}

/// Test helper for async provider states
Future<void> waitForProviderState<T>(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Helper to extract widget from finder
T? widgetOfType<T extends Widget>(Finder finder) {
  final element = finder.evaluate().firstOrNull;
  return element?.widget as T?;
}

/// Mock NavigatorObserver for testing navigation
class MockNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>?> pushedRoutes = [];
  final List<Route<dynamic>?> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }

  void reset() {
    pushedRoutes.clear();
    poppedRoutes.clear();
  }
}

/// Test group helper for widget tests
void widgetTestGroup(
  String description,
  void Function() body, {
  bool skip = false,
}) {
  group('Widget: $description', body, skip: skip);
}

/// Named test for widget behavior
void widgetTest(
  String description,
  Future<void> Function(WidgetTester) callback, {
  bool skip = false,
  Duration? timeout,
}) {
  testWidgets(
    description,
    callback,
    skip: skip,
    timeout: timeout == null ? null : Timeout(timeout),
  );
}
