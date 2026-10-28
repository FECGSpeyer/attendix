import 'dart:io';

import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/tenant/tenant_switcher_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

/// IOS_SHELL: iOS tab shell (Ionic iOS 26 theme): FAB in the tab bar row,
/// full tab labels, grouped header buttons, tenant popover.
void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('IosTabBar: long labels are scaled down, not truncated',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: IosTabBar(
          selectedIndex: 0,
          onSelected: (_) {},
          items: const [
            IosTabBarItem(icon: Icons.person_outline, label: 'Meine Termine'),
            IosTabBarItem(icon: Icons.calendar_today, label: 'Übersicht'),
            IosTabBarItem(icon: Icons.check_box_outlined, label: 'Termine'),
            IosTabBarItem(icon: Icons.more_horiz, label: 'Mehr'),
          ],
        ),
      ),
    ));
    final paragraph =
        tester.renderObject<RenderParagraph>(find.text('Meine Termine'));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(find.ancestor(
            of: find.text('Meine Termine'), matching: find.byType(FittedBox)),
        findsOneWidget);
    expect(IosTabBar.barHeight, 60);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  Widget shell({required VoidCallback onFab}) => MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: IosTabBarScope(
              bottom: 10,
              right: 16,
              child: Scaffold(
                body: const SizedBox.expand(),
                floatingActionButton: TabBarFab(
                  child: FloatingActionButton(
                    onPressed: onFab,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('TabBarFab: iOS → in the tab bar row, centred with the bar',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    await tester.pumpWidget(shell(onFab: () => taps++));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(FloatingActionButton));
    // bar: bottom 10, 60 high → centre 40 above the screen bottom
    expect(852 - rect.center.dy, closeTo(10 + IosTabBar.barHeight / 2, 0.5));
    expect(393 - rect.right, closeTo(16, 0.5));
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('TabBarFab: hidden while another route covers the page',
      (tester) async {
    await tester.pumpWidget(shell(onFab: () {}));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail'))));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    nav.pop();
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('TabBarFab: Material keeps the Scaffold position',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(shell(onFab: () {}));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(FloatingActionButton));
    // endFloat: 16pt margin above the Scaffold bottom
    expect(852 - rect.bottom, closeTo(16, 0.5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('ToolbarButtonGroup: iOS glass capsule around the buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(actions: [
          ToolbarButtonGroup(children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline)),
            IconButton(
                onPressed: () {}, icon: const Icon(Icons.notifications_none)),
          ]),
        ]),
      ),
    ));
    expect(find.byType(IosGlassSurface), findsOneWidget);
    expect(tester.getSize(find.byType(IosGlassSurface)).height, 44);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('AppTheme iOS: transparent header with hairline, Material unchanged',
      () {
    final ios = AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS);
    final md = AppTheme.forPlatform(Brightness.light, TargetPlatform.android);
    expect(ios.appBarTheme.backgroundColor, Colors.transparent);
    expect(ios.appBarTheme.shape, isA<Border>());
    expect(md.appBarTheme.backgroundColor, isNot(Colors.transparent));
  });

  testWidgets('TenantSwitcherTitle iOS: tap opens the popover with "Aktuell"',
      (tester) async {
    final chor = TestFactories.createTenant(id: 1, longName: 'Chor');
    final orchester = TestFactories.createTenant(id: 2, longName: 'Orchester');
    final container = createTestContainer(
      tenant: chor,
      overrides: [
        userTenantsProvider.overrideWith((ref) async => [chor, orchester]),
      ],
    );
    addTearDown(container.dispose);
    final picked = <int?>[];
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            title: TenantSwitcherTitle(onSelected: (t) => picked.add(t.id)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);

    await tester.tap(find.text('Chor'));
    await tester.pumpAndSettle();
    expect(find.text('Orchester'), findsOneWidget);
    expect(find.text('Aktuell'), findsOneWidget);
    // directly below the capsule
    expect(tester.getTopLeft(find.text('Orchester')).dy,
        greaterThan(tester.getBottomLeft(find.byType(IosGlassSurface).first).dy));

    await tester.tap(find.text('Orchester'));
    await tester.pumpAndSettle();
    expect(picked, [2]);
    expect(find.text('Orchester'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('Source checks', () {
    test('tab page FABs use TabBarFab, header buttons are grouped', () {
      for (final f in [
        'lib/features/attendance/presentation/pages/attendance_list_page.dart',
        'lib/features/people/presentation/pages/people_list_page.dart',
        'lib/features/settings/presentation/pages/settings_page.dart',
        'lib/features/songs/presentation/pages/songs_list_page.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('TabBarFab('), reason: f);
        expect(src, contains('ToolbarButtonGroup('), reason: f);
      }
      expect(
          File('lib/features/self_service/presentation/pages/signout_page.dart')
              .readAsStringSync(),
          allOf(contains('ToolbarButtonGroup('),
              contains('TenantSwitcherTitle(onSelected: _switchTenant)')));
    });

    test('auto navigation never uses ref after an async gap', () {
      for (final f in [
        'lib/features/auth/presentation/pages/login_page.dart',
        'lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('ProviderScope.containerOf(context, listen: false)'),
            reason: f);
        expect(src, contains('await container.read(currentTenantUserProvider.future)'),
            reason: f);
        expect(src, isNot(contains('await ref.read(currentTenantUserProvider.future)')),
            reason: f);
      }
    });

    test('tooltips are hidden on iOS', () {
      expect(File('lib/main.dart').readAsStringSync(),
          contains('TooltipVisibility('));
    });
  });
}
