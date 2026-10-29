import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/app_update_service.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// IOS_SHELL2: pages scroll under the floating iOS tab bar (inset handed
/// over as MediaQuery padding), sheets above the bar, update toast above the
/// bar, Ionic md tab bar clustered on wide screens.
class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Tenant? build() => null;

  @override
  Future<void> setTenant(Tenant? tenant) async {}

  @override
  Future<void> loadFromPrefs() async {}
}

double? _pagePadding;
Size? _pageSize;

GoRouter _router() => GoRouter(
      initialLocation: '/people',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            for (final path in ['/people', '/attendance', '/settings'])
              GoRoute(
                path: path,
                builder: (context, state) => Scaffold(
                  backgroundColor:
                      path == '/attendance' ? Colors.white : null,
                  body: LayoutBuilder(builder: (context, constraints) {
                    _pagePadding = MediaQuery.paddingOf(context).bottom;
                    _pageSize = constraints.biggest;
                    return Center(
                      child: Builder(
                        builder: (context) => TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            useRootNavigator: true,
                            builder: (_) => const SizedBox(
                                height: 200, child: Text('Sheet content')),
                          ),
                          child: Text('open $path'),
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ],
    );

Widget _app({bool updateAvailable = false}) => ProviderScope(
      overrides: [
        effectiveRoleProvider.overrideWithValue(Role.admin),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        appUpdateAvailableProvider.overrideWith((ref) => updateAvailable),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: _router()),
    );

void main() {
  // No SharedPreferences mock on purpose: CurrentTenantNotifier's restore
  // then never reaches Supabase (as in main_shell_test).

  void phone(WidgetTester tester, {double bottomSafeArea = 34}) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomSafeArea, top: 47);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomSafeArea, top: 47);
    addTearDown(tester.view.reset);
  }

  testWidgets('iOS: page fills the screen, bar inset as MediaQuery padding',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Content runs under the floating bar …
    expect(_pageSize!.height, 852);
    // … and gets Ionic's `60px + max(10px, safe-area-bottom - 12px)`.
    expect(_pagePadding, IosTabBar.contentPadding + 22);
    expect(find.byType(IosTabBarFade), findsOneWidget);
    expect(find.byType(IosTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: the fade takes the background of the page on top',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    Color? fade() =>
        tester.widget<IosTabBarFade>(find.byType(IosTabBarFade)).color;
    expect(fade(), AppTheme.light.scaffoldBackgroundColor);
    await tester.tap(find.text('Termine'));
    await tester.pumpAndSettle();
    expect(fade(), Colors.white);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: sheets open above the tab bar (root navigator)',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open /people'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsOneWidget);
    // Not inside the shell (whose tab bar is painted over its pages).
    expect(
        find.ancestor(
            of: find.text('Sheet content'),
            matching: find.byType(IosTabBarScope)),
        findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: update toast above the bar enlarges the inset',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_app(updateAvailable: true));
    await tester.pumpAndSettle();
    expect(find.text('Neue Version verfügbar'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final toast = tester.getRect(find.text('Neue Version verfügbar'));
    final bar = tester.getRect(find.byType(IosTabBar));
    expect(toast.bottom, lessThan(852 - 22 - IosTabBar.barHeight));
    expect(bar.bottom, 852);
    expect(_pagePadding, IosTabBar.contentPadding + 22 + 50 + 8);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Neue Version verfügbar'), findsNothing);
    expect(_pagePadding, IosTabBar.contentPadding + 22);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('scrollEndPadding: FAB room only outside the iOS tab shell',
      (tester) async {
    phone(tester);
    double? inShell;
    double? outside;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Column(children: [
        Builder(builder: (context) {
          outside = scrollEndPadding(context, base: 16, fabRoom: 80);
          return const SizedBox();
        }),
        IosTabBarScope(
          bottom: 22,
          right: 16,
          child: Builder(builder: (context) {
            inShell = scrollEndPadding(context, base: 16, fabRoom: 80);
            return const SizedBox();
          }),
        ),
      ]),
    ));
    expect(outside, 16 + 80 + 34);
    expect(inShell, 16 + 34);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Material: md tab bar clusters 168px tabs, no tooltips',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(NavigationBar));
    final tabs =
        tester.widgetList(find.byType(NavigationDestination)).length;
    expect(bar.width, 168.0 * tabs);
    expect(bar.center.dx, 720);
    for (final d in tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))) {
      expect(d.tooltip, '');
    }
    expect(find.byType(IosTabBar), findsNothing);
  });

  group('source', () {
    test('every showModalBottomSheet uses the root navigator', () {
      final offenders = <String>[];
      final call = RegExp(r'showModalBottomSheet\s*(<[^(]*>)?\s*\(');
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        for (final m in call.allMatches(src)) {
          var i = m.end, depth = 1;
          while (depth > 0 && i < src.length) {
            final c = src[i];
            if (c == '(') depth++;
            if (c == ')') depth--;
            i++;
          }
          if (!src.substring(m.end, i).contains('useRootNavigator')) {
            offenders.add(
                '${f.path}:${'\n'.allMatches(src.substring(0, m.start)).length + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('pushed routes update the browser URL', () {
      expect(File('lib/main.dart').readAsStringSync(),
          contains('GoRouter.optionURLReflectsImperativeAPIs = true'));
    });
  });
}
