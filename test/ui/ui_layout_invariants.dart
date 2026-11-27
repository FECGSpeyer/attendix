import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/account_switch_providers.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/appearance_providers.dart';
import 'package:attendix/core/services/account_switch/saved_account.dart';
import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:attendix/core/theme/app_palette.dart';
import 'package:attendix/core/theme/design_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/debug/debug_role_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/support/golden_backend.dart';
import '../golden/support/golden_world.dart';

/// Viewport, platform, brightness, and text-scale preset for UI invariant tests.
@immutable
class UiViewportProfile {
  const UiViewportProfile({
    required this.name,
    required this.size,
    required this.platform,
    this.brightness = Brightness.light,
    this.textScale = 1.0,
    this.padding = EdgeInsets.zero,
  });

  final String name;
  final Size size;
  final TargetPlatform platform;
  final Brightness brightness;
  final double textScale;
  final EdgeInsets padding;

  static const narrowPhone = UiViewportProfile(
    name: 'narrowPhone (320x640, 1.0x)',
    size: Size(320, 640),
    platform: TargetPlatform.iOS,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 20),
  );

  static const narrowPhoneLargeText = UiViewportProfile(
    name: 'narrowPhoneLargeText (320x640, 1.6x)',
    size: Size(320, 640),
    platform: TargetPlatform.iOS,
    textScale: 1.6,
    padding: EdgeInsets.only(top: 20),
  );

  static const iphone = UiViewportProfile(
    name: 'iphone (390x844, 1.0x)',
    size: Size(390, 844),
    platform: TargetPlatform.iOS,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 59, bottom: 34),
  );

  static const iphoneDark = UiViewportProfile(
    name: 'iphoneDark (390x844, dark, 1.0x)',
    size: Size(390, 844),
    platform: TargetPlatform.iOS,
    brightness: Brightness.dark,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 59, bottom: 34),
  );

  static const desktop = UiViewportProfile(
    name: 'desktop (1280x800, macOS, 1.0x)',
    size: Size(1280, 800),
    platform: TargetPlatform.macOS,
    textScale: 1.0,
    padding: EdgeInsets.zero,
  );
}

/// Runs [body] while capturing all [FlutterError] reports (such as
/// `RenderFlex overflowed`, layout assertions, or widget build errors).
///
/// Always restores the previous [FlutterError.onError] in `finally` and fails
/// immediately if any error was reported.
Future<void> runCapturingFlutterErrors(Future<void> Function() body) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previousOnError;
  }
  if (errors.isNotEmpty) {
    final details = errors.map((e) => e.exceptionAsString()).join('\n---\n');
    fail('Captured ${errors.length} FlutterError(s):\n$details');
  }
}

/// Verifies every finder in [finders] resolves to a widget with a non-zero
/// [Size] and that no two bounding rectangles overlap.
void expectNoOverlaps(WidgetTester tester, List<Finder> finders) {
  final rects = <Rect>[];
  for (final finder in finders) {
    expect(finder, findsOneWidget, reason: 'Expected $finder to resolve to one widget');
    final rect = tester.getRect(finder);
    expect(rect.width, greaterThan(0), reason: 'Expected non-zero width for $finder');
    expect(rect.height, greaterThan(0), reason: 'Expected non-zero height for $finder');
    rects.add(rect);
  }
  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      expect(
        rects[i].overlaps(rects[j]),
        isFalse,
        reason: 'Widgets ${finders[i]} (${rects[i]}) and ${finders[j]} (${rects[j]}) overlap',
      );
    }
  }
}

/// Asserts that [finder] lies horizontally within `[0, viewport.width]` (with
/// a 0.5 px subpixel tolerance).
void expectHorizontallyWithinViewport(
  WidgetTester tester,
  Finder finder,
  Size viewport,
) {
  expect(finder, findsOneWidget, reason: 'Expected $finder to resolve to one widget');
  final rect = tester.getRect(finder);
  expect(
    rect.left,
    greaterThanOrEqualTo(-0.5),
    reason: '$finder extends past left viewport edge: $rect',
  );
  expect(
    rect.right,
    lessThanOrEqualTo(viewport.width + 0.5),
    reason: '$finder extends past right viewport edge (${viewport.width}): $rect',
  );
}

/// Bounded pump loop for pages with continuous animations or polling spinners.
Future<void> settleUi(WidgetTester tester, {int steps = 15}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps [child] inside a full `ProviderScope` + `MaterialApp.router` matching
/// [profile], German l10n, Redesign theme tokens, and [goldenBackend].
Future<void> pumpUiApp(
  WidgetTester tester,
  Widget child, {
  required UiViewportProfile profile,
  List<Override> overrides = const [],
  Map<String, List<Map<String, dynamic>>> tables = const {},
  Widget Function(Widget)? shell,
  String path = '/',
  RdFarbwelt world = RdFarbwelt.petrol,
}) async {
  SharedPreferences.setMockInitialValues({});
  if (!dotenv.isInitialized) {
    dotenv.testLoad(
      fileInput: 'SUPABASE_URL=http://localhost:54321\nSUPABASE_ANON_KEY=test-anon-key\n',
    );
  }
  await initializeDateFormatting('de_DE');
  await initializeDateFormatting('de');

  tester.view.physicalSize = profile.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  if (profile.brightness != Brightness.light) {
    tester.platformDispatcher.platformBrightnessTestValue = profile.brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  DebugRoleFab.hidden = true;
  addTearDown(() => DebugRoleFab.hidden = false);

  final routes = <RouteBase>[
    GoRoute(path: path, builder: (_, __) => child),
    GoRoute(
      path: '/:rest(.*)',
      builder: (_, state) => Scaffold(body: Text('route:${state.uri}')),
    ),
  ];
  final router = GoRouter(
    initialLocation: path,
    routes: [
      if (shell == null)
        ...routes
      else
        ShellRoute(builder: (_, __, shellChild) => shell(shellChild), routes: routes),
    ],
  );
  addTearDown(router.dispose);

  final backend = (await tester.runAsync(() => goldenBackend(tables: tables)))!;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(backend),
        isInTeamsProvider.overrideWithValue(false),
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        initialRedesignSettingsProvider.overrideWithValue(
          RedesignSettings(
            world: world,
            mode: profile.brightness == Brightness.dark ? RdBrightnessMode.dark : RdBrightnessMode.light,
          ),
        ),
        savedAccountsProvider.overrideWith((ref) => Stream.value(const <SavedAccount>[])),
        ...worldOverrides(),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final activeWorld = ref.watch(redesignSettingsProvider).world;
          final theme = buildRdTheme(activeWorld, profile.brightness).copyWith(platform: profile.platform);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('de'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            routerConfig: router,
            builder: (context, appChild) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  padding: profile.padding,
                  viewPadding: profile.padding,
                  textScaler: TextScaler.linear(profile.textScale),
                ),
                child: TooltipVisibility(visible: false, child: appChild!),
              );
            },
          );
        },
      ),
    ),
  );
  await settleUi(tester);
}
