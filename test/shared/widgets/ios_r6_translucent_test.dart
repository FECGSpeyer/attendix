import 'dart:io';

import 'package:attendix/core/services/native/native_platform.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared translucent iOS toolbar, content inset, adaptive refresher and
/// iOS swipe-back page transitions.
void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  Widget page({
    required bool condensed,
    ThemeData? theme,
    ValueNotifier<bool>? listenable,
  }) =>
      MaterialApp(
        theme: theme ?? buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            extendBodyBehindAppBar:
                Theme.of(context).platform == TargetPlatform.iOS,
            appBar: IonTranslucentAppBar(
              condensed: condensed,
              condensedListenable: listenable,
              child: AppBar(title: const Text('Werke')),
            ),
            body: IonRefresher(
              onRefresh: () async {},
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  IonContentTopInset(),
                  SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );

  double insetHeight(WidgetTester tester) {
    final finder = find.byType(IonContentTopInset);
    return finder.evaluate().isEmpty ? 0 : tester.getSize(finder).height;
  }

  final tint = find.descendant(
    of: find.byType(IonTranslucentAppBar),
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border != null,
    ),
  );

  group('IonTranslucentAppBar', () {
    testWidgets('iOS condensed: solid tint over transparent bar, content under it',
        (tester) async {
      await tester.pumpWidget(page(condensed: true));
      expect(tint, findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      final material = tester.widget<Material>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first);
      expect(material.color, Colors.transparent);
      final barHeight = tester.getSize(find.byType(AppBar)).height;
      expect(insetHeight(tester), barHeight);
      final refresher = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator));
      expect(refresher.edgeOffset, barHeight);
    }, variant: ios);

    testWidgets('iOS large title visible: no blur, no hairline',
        (tester) async {
      await tester.pumpWidget(page(condensed: false));
      expect(tint, findsNothing);
      final material = tester.widget<Material>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first);
      expect(material.shape, const Border());
    }, variant: ios);

    testWidgets('iOS dark: condensed bar uses the dark Farbwelt page colour',
        (tester) async {
      final dark = buildRdTheme(RdFarbwelt.petrol, Brightness.dark);
      await tester.pumpWidget(page(condensed: true, theme: dark));
      final box = tester.widget<DecoratedBox>(tint);
      final expected = rdPalette(RdFarbwelt.petrol, Brightness.dark)
          .bg
          .withValues(alpha: 0.96);
      expect((box.decoration as BoxDecoration).color, expected);
    }, variant: ios);

    testWidgets('condensedListenable toggles the tint', (tester) async {
      final condensed = ValueNotifier(false);
      addTearDown(condensed.dispose);
      await tester
          .pumpWidget(page(condensed: false, listenable: condensed));
      expect(tint, findsNothing);
      condensed.value = true;
      await tester.pump();
      expect(tint, findsOneWidget);
    }, variant: ios);

    testWidgets('Android: plain AppBar, no blur, no inset, default refresher',
        (tester) async {
      await tester.pumpWidget(page(condensed: true));
      expect(tint, findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(insetHeight(tester), 0);
      final refresher = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator));
      expect(refresher.edgeOffset, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('iOS swipe-back', () {
    test('theme pins the iOS slide on iOS, Zoom on Android', () {
      final iosTheme =
          AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS);
      final mdTheme =
          AppTheme.forPlatform(Brightness.light, TargetPlatform.android);
      expect(iosTheme.pageTransitionsTheme.builders[TargetPlatform.iOS],
          isA<IonIosPageTransitionsBuilder>());
      expect(mdTheme.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<ZoomPageTransitionsBuilder>());
    });

    testWidgets('web: edge swipe does not pop a pushed page', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.light,
        home: const Scaffold(body: Text('Liste')),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Detail')))));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(5, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
    }, variant: ios);

    Future<void> pushAndSwipe(WidgetTester tester, {bool canPop = true}) async {
      final navKey = GlobalKey<NavigatorState>();
      final base = AppTheme.light;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        theme: base.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.iOS: IonIosPageTransitionsBuilder(swipeBack: true),
          }),
        ),
        home: const Scaffold(body: Text('Liste')),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => PopScope(
                canPop: canPop,
                child: const Scaffold(body: Center(child: Text('Detail'))),
              )));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(5, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('native iOS: edge swipe pops a pushed page', (tester) async {
      await pushAndSwipe(tester);
      expect(find.text('Detail'), findsNothing);
      expect(find.text('Liste'), findsOneWidget);
    }, variant: ios);

    testWidgets('native iOS: no swipe while PopScope blocks (unsaved changes)',
        (tester) async {
      await pushAndSwipe(tester, canPop: false);
      expect(find.text('Detail'), findsOneWidget);
    }, variant: ios);

    testWidgets('native iOS: swipe-back defaults to on in the installed app',
        (tester) async {
      debugIsNativeAppOverride = true;
      addTearDown(() => debugIsNativeAppOverride = null);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS),
        home: const Scaffold(body: Text('Liste')),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('Detail')))));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(5, 300));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
    }, variant: ios);
  });

  test('translucent pages use IonTranslucentAppBar + fullscreen body', () {
    const pages = [
      'lib/features/organisation/presentation/pages/org_plan_public_page.dart',
      'lib/features/legal/presentation/pages/terms_page.dart',
      'lib/features/planning/presentation/widgets/ion_items.dart',
    ];
    for (final path in pages) {
      final src = File(path).readAsStringSync();
      expect(src, contains('IonTranslucentAppBar('), reason: path);
      expect(src, contains('extendBodyBehindAppBar:'), reason: path);
      expect(src, contains('IonContentTopInset()'), reason: path);
    }
  });
}
