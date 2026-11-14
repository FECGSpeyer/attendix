import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ROLLEN-A-35: TabBarFab of a covered page does not break hit tests after an address change', (tester) async {
    var taps = 0;
    final router = GoRouter(initialLocation: '/signout', routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          body: Stack(children: [
            Positioned.fill(child: IosTabBarScope(bottom: 20, right: 16, child: child)),
          ]),
        ),
        routes: [
          GoRoute(
            path: '/signout',
            pageBuilder: (c, s) => NoTransitionPage(key: s.pageKey, child: const Scaffold(body: Text('signout'))),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (c, s) => NoTransitionPage(
              key: s.pageKey,
              child: Scaffold(
                body: const Text('settings'),
                floatingActionButton: TabBarFab(child: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.apps))),
              ),
            ),
            routes: [
              GoRoute(
                path: 'notifications',
                builder: (c, s) => Scaffold(
                  appBar: AppBar(title: const Text('notif')),
                  body: Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('tap me'))),
                ),
              ),
            ],
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS, web: true),
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    router.go('/settings/notifications');
    await tester.pumpAndSettle();
    await tester.tap(find.text('tap me'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(taps, 1);
  });
}
