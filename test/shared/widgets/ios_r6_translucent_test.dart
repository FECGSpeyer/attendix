import 'dart:io';

import 'package:attendix/core/services/native/native_platform.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// IOS_R6: shared Ionic iOS `ion-header translucent` toolbar, content inset
/// under it, platform refresher and iOS swipe-back transitions.
void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  Widget page({
    required bool condensed,
    ThemeData? theme,
    ValueNotifier<bool>? listenable,
  }) =>
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            extendBodyBehindAppBar: isIosLook(context),
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

  // A zero-height first list child is dropped by the sliver list.
  double insetHeight(WidgetTester tester) {
    final finder = find.byType(IonContentTopInset);
    return finder.evaluate().isEmpty ? 0 : tester.getSize(finder).height;
  }

  group('IonTranslucentAppBar', () {
    testWidgets('iOS condensed: blur over transparent bar, content under it',
        (tester) async {
      await tester.pumpWidget(page(condensed: true));
      expect(find.byType(BackdropFilter), findsOneWidget);
      final material = tester.widget<Material>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first);
      expect(material.color, Colors.transparent);
      // body extends behind the bar: inset = status bar + toolbar
      final barHeight = tester.getSize(find.byType(AppBar)).height;
      expect(insetHeight(tester), barHeight);
      final refresher = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator));
      expect(refresher.edgeOffset, barHeight);
    }, variant: ios);

    testWidgets('iOS large title visible: no blur, no hairline',
        (tester) async {
      await tester.pumpWidget(page(condensed: false));
      expect(find.byType(BackdropFilter), findsNothing);
      final material = tester.widget<Material>(find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first);
      expect(material.shape, const Border());
    }, variant: ios);

    testWidgets('iOS dark: tint is the dark page colour at 20 %',
        (tester) async {
      final dark = AppTheme.dark;
      await tester.pumpWidget(page(condensed: true, theme: dark));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(DecoratedBox)));
      final color = (box.decoration as BoxDecoration).color!;
      expect(color.a, closeTo(IonTranslucentBarBackground.tintOpacity, 0.01));
      expect(color.withValues(alpha: 1), dark.scaffoldBackgroundColor);
    }, variant: ios);

    testWidgets('condensedListenable toggles the blur', (tester) async {
      final condensed = ValueNotifier(false);
      addTearDown(condensed.dispose);
      await tester
          .pumpWidget(page(condensed: false, listenable: condensed));
      expect(find.byType(BackdropFilter), findsNothing);
      condensed.value = true;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);
    }, variant: ios);

    testWidgets('md: plain AppBar, no blur, no inset, default refresher',
        (tester) async {
      await tester.pumpWidget(page(condensed: true));
      expect(find.byType(IonTranslucentBarBackground), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(insetHeight(tester), 0);
      final refresher = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator));
      expect(refresher.edgeOffset, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('iOS swipe-back', () {
    test('theme pins the iOS slide (no swipe) on iOS, Zoom on Android', () {
      final iosTheme =
          AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS);
      final mdTheme =
          AppTheme.forPlatform(Brightness.light, TargetPlatform.android);
      expect(iosTheme.pageTransitionsTheme.builders[TargetPlatform.iOS],
          isA<IonIosPageTransitionsBuilder>());
      expect(mdTheme.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<ZoomPageTransitionsBuilder>());
    });

    // Ionic: `swipeBackEnabled: false` (app.module.ts) – kept on the web.
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

    // SWIPE_BACK: the installed iOS app swipes back from the left edge.
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

  // Cheap regression guard: every page Ionic renders with
  // `ion-header translucent` + `ion-content fullscreen` uses the shared bar.
  test('translucent Ionic pages use IonTranslucentAppBar + fullscreen body',
      () {
    const pages = [
      'lib/features/songs/presentation/pages/songs_list_page.dart',
      'lib/features/songs/presentation/pages/song_detail_page.dart',
      'lib/features/parents/presentation/pages/parents_portal_page.dart',
      'lib/features/settings/presentation/pages/settings_page.dart',
      'lib/features/settings/presentation/pages/general_settings_page.dart',
      'lib/features/settings/presentation/pages/extra_fields_page.dart',
      'lib/features/settings/presentation/pages/role_permissions_page.dart',
      'lib/features/settings/presentation/pages/attendance_types_page.dart',
      'lib/features/settings/presentation/pages/attendance_type_edit_page.dart',
      'lib/features/settings/presentation/pages/handover_page.dart',
      'lib/features/settings/presentation/pages/handover_detail_page.dart',
      'lib/features/organisation/presentation/pages/org_settings_page.dart',
      'lib/features/organisation/presentation/pages/org_plans_page.dart',
      'lib/features/organisation/presentation/pages/org_plan_public_page.dart',
      'lib/features/organisation/presentation/pages/org_person_fields_page.dart',
      'lib/features/organisation/presentation/pages/org_planning_templates_page.dart',
      'lib/features/notifications/presentation/pages/notifications_page.dart',
      'lib/features/dashboard/presentation/pages/administration_page.dart',
      'lib/features/dashboard/presentation/pages/home_dashboard_page.dart',
      'lib/features/dashboard/presentation/pages/dashboard_settings_page.dart',
      'lib/features/help/presentation/pages/help_page.dart',
      'lib/features/help/presentation/pages/help_article_page.dart',
      'lib/features/help/presentation/pages/help_glossary_page.dart',
      'lib/features/legal/presentation/pages/terms_page.dart',
      'lib/features/registration/presentation/pages/tenant_registration_page.dart',
      // shifts + public planning share IonCondenseScaffold
      'lib/features/planning/presentation/widgets/ion_items.dart',
    ];
    for (final path in pages) {
      final src = File(path).readAsStringSync();
      expect(src, contains('IonTranslucentAppBar('), reason: path);
      expect(src, contains('extendBodyBehindAppBar:'), reason: path);
      expect(src, contains('IonContentTopInset()'), reason: path);
      expect(src, isNot(contains('condenseBarColor(')), reason: path);
    }
  });
}
