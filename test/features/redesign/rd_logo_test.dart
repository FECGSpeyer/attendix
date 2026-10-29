import 'dart:io';

import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_appearance_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_logo.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/display/attendix_logo.dart';
import 'package:attendix/shared/widgets/display/attendix_logo_paths.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOGO: the Ionic app's logo as a vector, in the colours of each Farbwelt,
/// and the iOS home screen icon that follows the Farbwelt.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => RedesignRoutes.active = false);

  group('AttendixLogo', () {
    test('the traced outlines sit where the Ionic icon has them', () {
      final glyph = attendixLogoGlyphPath().getBounds();
      expect(glyph.left, closeTo(222, 3));
      expect(glyph.top, closeTo(99, 3));
      expect(glyph.right, closeTo(805, 3));
      expect(glyph.bottom, closeTo(903, 3));
      final check = attendixLogoCheckPath().getBounds();
      expect(glyph.contains(check.center), isTrue);
      expect(check.left, greaterThan(500));
      expect(check.top, greaterThan(580));
    });

    testWidgets('draws at the given size with a label', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: AttendixLogo(size: 64)),
      ));
      expect(tester.getSize(find.byType(AttendixLogo)), const Size(64, 64));
      expect(find.bySemanticsLabel('Attendix'), findsOneWidget);
    });
  });

  group('Farbwelten', () {
    test('Petrol is the original, every Farbwelt has its own tile', () {
      expect(rdLogoColors(RdFarbwelt.petrol), AttendixLogoColors.original);
      final tiles = {for (final w in RdFarbwelt.values) rdLogoColors(w).tile};
      expect(tiles, hasLength(RdFarbwelt.values.length));
      expect(rdLogoColors(RdFarbwelt.nachtblau).tile,
          rdPalette(RdFarbwelt.nachtblau, Brightness.light).primary);
      expect(rdLogoColors(RdFarbwelt.konzertsaal).tile,
          rdPalette(RdFarbwelt.konzertsaal, Brightness.light).primary);
    });

    test('glyph stands out from the tile (>= 4.5:1)', () {
      double lum(Color c) => c.computeLuminance();
      for (final w in RdFarbwelt.values) {
        final c = rdLogoColors(w);
        final a = lum(c.tile), b = lum(c.glyph);
        final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
        // The original teal tile keeps its look (about 2.9:1); the others
        // are at least 4.5:1.
        expect(ratio, greaterThan(w == RdFarbwelt.petrol ? 2.5 : 4.5), reason: w.name);
      }
    });
  });

  group('home screen icon', () {
    test('only in the new design, only when it follows the Farbwelt', () {
      const on = RedesignSettings(enabled: true, world: RdFarbwelt.konzertsaal);
      expect(on.appIconName, 'AppIconKonzertsaal');
      expect(on.copyWith(world: RdFarbwelt.petrol).appIconName, isNull);
      expect(on.copyWith(enabled: false).appIconName, isNull);
      expect(on.copyWith(appIcon: false).appIconName, isNull);
    });

    test('every alternate icon is in the asset catalog and the build setting', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      for (final w in RdFarbwelt.values) {
        final name = w.appIconName;
        if (name == null) continue;
        final dir = 'ios/Runner/Assets.xcassets/$name.appiconset';
        expect(File('$dir/Contents.json').existsSync(), isTrue, reason: name);
        expect(File('$dir/Icon-1024.png').existsSync(), isTrue, reason: name);
        expect(
          RegExp('ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "[^"]*\\b$name\\b').allMatches(pbx),
          hasLength(3),
          reason: '$name in Debug, Release and Profile',
        );
      }
      final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(swift, contains('"de.attendix/app_icon"'));
      expect(swift, contains('AppIconPlugin.register(with: registrar)'));
    });

    test('on iOS the icon is switched only when it changes', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <Object?>[];
      const channel = MethodChannel('de.attendix/app_icon');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'set');
        calls.add(call.arguments);
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(redesignSettingsProvider.notifier);

      await notifier.setWorld(RdFarbwelt.konzertsaal); // old design: default icon stays
      expect(calls, isEmpty);
      await notifier.setEnabled(true);
      expect(calls, ['AppIconKonzertsaal']);
      await notifier.setMode(RdBrightnessMode.dark);
      expect(calls, hasLength(1));
      await notifier.setWorld(RdFarbwelt.petrol);
      expect(calls.last, isNull);
      await notifier.setAppIcon(false);
      await notifier.setWorld(RdFarbwelt.klar);
      expect(calls, hasLength(2));
      await notifier.setAppIcon(true);
      expect(calls.last, 'AppIconKlar');
      await notifier.setEnabled(false);
      expect(calls, ['AppIconKonzertsaal', null, 'AppIconKlar', null]);

      expect((await loadInitialRedesignSettings()).appIcon, isTrue);
      await notifier.setAppIcon(false);
      expect((await loadInitialRedesignSettings()).appIcon, isFalse);
    });

    test('off iOS nothing is called', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(redesignSettingsProvider.notifier);
      // No mock handler: a call would throw MissingPluginException (caught,
      // but the notifier must not even try).
      await notifier.setEnabled(true);
      await notifier.setWorld(RdFarbwelt.nachtblau);
      expect(container.read(redesignSettingsProvider).appIconName, 'AppIconNachtblau');
    });
  });

  testWidgets('Darstellung: logo per Farbwelt and the app icon switch', (tester) async {
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget app(bool showAppIcon) => ProviderScope(
          overrides: [
            initialRedesignSettingsProvider.overrideWithValue(
              const RedesignSettings(enabled: true, world: RdFarbwelt.nachtblau),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: const Locale('de'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildRdTheme(ref.watch(redesignSettingsProvider).world, Brightness.light),
              home: RdAppearancePage(showAppIcon: showAppIcon),
            ),
          ),
        );

    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    final logos = tester.widgetList<RdLogo>(find.byType(RdLogo)).toList();
    expect(logos.map((l) => l.world), RdFarbwelt.values);
    expect(find.text('App-Symbol in Farbwelt'), findsNothing);

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('APP-SYMBOL'), findsOneWidget);
    expect(find.text('App-Symbol in Farbwelt'), findsOneWidget);
    final element = tester.element(find.text('App-Symbol in Farbwelt'));
    final container = ProviderScope.containerOf(element);
    expect(container.read(redesignSettingsProvider).appIcon, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(redesignSettingsProvider).appIcon, isFalse);
    // Off: the row shows the default (Petrol) icon.
    final rowLogo = tester.widgetList<RdLogo>(find.byType(RdLogo)).last;
    expect(rowLogo.world, RdFarbwelt.petrol);
  });
}
