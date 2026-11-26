// Renders a page the way main.dart shows it and compares it with its golden
// image. See test/golden/README.md.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/account_switch_providers.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/services/account_switch/saved_account.dart';
import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/debug/debug_role_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_backend.dart';

/// Visual theme configuration for golden snapshots.
enum GoldenLook {
  /// Standard app design.
  beta('beta');

  const GoldenLook(this.prefix);

  /// First part of the image name: `beta_heute.png`.
  final String prefix;
}

const goldenPhone = Size(390, 844);

/// Pumps [page] as the route [path] of an app that looks like the real one.
///
/// Providers come from [overrides]; whatever else the page reads from the
/// database gets the rows in [tables] (empty when not given).
/// [shell] wraps the page in the tab frame (`RdShell`, `MainShell`); the tab
/// that belongs to [path] is the selected one. [pixelRatio] 2 gives images a
/// person can read; pages with a photo use 1 to keep the file small.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget page, {
  required GoldenLook look,
  List<Override> overrides = const [],
  Map<String, List<Map<String, dynamic>>> tables = const {},
  String path = '/',
  Widget Function(Widget child)? shell,
  Size size = goldenPhone,
  double pixelRatio = 2,
  Brightness brightness = Brightness.light,
  TextScaler? textScaler,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  if (brightness != Brightness.light) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  // A phone has no keyboard focus: no focus rings.
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  DebugRoleFab.hidden = true;
  addTearDown(() => DebugRoleFab.hidden = false);

  const platform = TargetPlatform.iOS;
  final routes = [
    GoRoute(path: path, builder: (_, __) => page),
    // Links of the page lead nowhere.
    GoRoute(path: '/:rest(.*)', builder: (_, state) => Scaffold(body: Text(state.uri.toString()))),
  ];
  final router = GoRouter(
    initialLocation: path,
    routes: [
      if (shell == null) ...routes else ShellRoute(builder: (_, __, child) => shell(child), routes: routes),
    ],
  );
  addTearDown(router.dispose);

  final backend = (await tester.runAsync(() => goldenBackend(tables: tables)))!;

  await tester.pumpWidget(
    ProviderScope(
      observers: [_FailureLog()],
      overrides: [
        supabaseClientProvider.overrideWithValue(backend),
        isInTeamsProvider.overrideWithValue(false),
        // Online; the plugin behind it does not exist in a test.
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings()),
        // No further accounts on this device (the store needs the app config).
        savedAccountsProvider.overrideWith((ref) => Stream.value(const <SavedAccount>[])),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final theme = buildRdTheme(ref.watch(redesignSettingsProvider).world, brightness)
              .copyWith(platform: platform);
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
            builder: (context, child) {
              Widget result = TooltipVisibility(visible: false, child: child!);
              if (textScaler != null) {
                result = MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: result,
                );
              }
              return result;
            },
          );
        },
      ),
    ),
  );
  await settle(tester);
}

/// Bounded pumps: spinners and pulse animations never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Compares the screen with `goldens/<look>_<name>.png`.
///
/// [replace] swaps texts that change from day to day (the app reads the
/// clock directly) for fixed ones: `{today's date: 'Donnerstag, 1. Januar'}`.
Future<void> expectGolden(
  WidgetTester tester,
  GoldenLook look,
  String name, {
  Map<String, String> replace = const {},
}) async {
  await _loadImages(tester);
  _useRealFont(tester, replace);
  // Tests draw shadows as black frames unless told otherwise.
  debugDisableShadows = false;
  try {
    for (final object in tester.allRenderObjects) {
      object.markNeedsPaint();
    }
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${look.prefix}_$name.png'),
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// Asset images decode asynchronously; a test has to wait for them itself.
Future<void> _loadImages(WidgetTester tester) async {
  final elements = find.byType(Image).evaluate().toList();
  if (elements.isEmpty) return;
  await tester.runAsync(() async {
    for (final element in elements) {
      await precacheImage((element.widget as Image).image, element, onError: (_, __) {});
    }
  });
  await settle(tester);
}

/// Text without a font family uses the system font on a device, but the
/// block font in a test. Give those texts the app font, so the image shows
/// what a person would see. Also applies [replace].
void _useRealFont(WidgetTester tester, Map<String, String> replace) {
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final text = paragraph.text;
    if (text is! TextSpan) continue;
    final style = text.style ?? const TextStyle();
    // The check mark of the status badges comes from the system font on a
    // device; the app's own fonts do not have it.
    if (text.text == '✓') {
      paragraph.text = TextSpan(
        text: String.fromCharCode(Icons.check.codePoint),
        style: style.copyWith(fontFamily: Icons.check.fontFamily, fontWeight: FontWeight.w400),
      );
      continue;
    }
    final swapped = replace[text.text];
    if (swapped == null && style.fontFamily != null) continue;
    paragraph.text = TextSpan(
      text: swapped ?? text.text,
      children: text.children,
      style: style.fontFamily != null ? style : style.copyWith(fontFamily: 'Roboto'),
      recognizer: text.recognizer,
      semanticsLabel: text.semanticsLabel,
      locale: text.locale,
      spellOut: text.spellOut,
    );
  }
}

/// Prints every provider that fails, with the place it is defined at, so a
/// new page shows what its test still has to provide.
final class _FailureLog extends ProviderObserver {
  void _log(ProviderBase<Object?> provider, Object error, StackTrace? stack) {
    final frame = '$stack'.split('\n').firstWhere(
          (line) => line.contains('package:attendix/') && !line.contains('base_repository'),
          orElse: () => '',
        );
    debugPrint('golden: ${provider.name ?? provider.runtimeType} failed: ${'$error'.split('\n').first} ${frame.trim()}');
  }

  @override
  void providerDidFail(ProviderBase<Object?> provider, Object error, StackTrace stackTrace, ProviderContainer container) =>
      _log(provider, error, stackTrace);

  @override
  void didUpdateProvider(ProviderBase<Object?> provider, Object? previousValue, Object? newValue, ProviderContainer container) {
    if (newValue is AsyncError) _log(provider, newValue.error, newValue.stackTrace);
  }

  @override
  void didAddProvider(ProviderBase<Object?> provider, Object? value, ProviderContainer container) {
    if (value is AsyncError) _log(provider, value.error, value.stackTrace);
  }
}
