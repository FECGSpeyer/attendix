import 'package:attendix/features/redesign/presentation/pages/rd_help_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // Same shape as the app: everything inside a ShellRoute.
  GoRouter router(String initial) => GoRouter(
        initialLocation: initial,
        routes: [
          ShellRoute(
            builder: (_, __, child) => Material(child: child),
            routes: [
              GoRoute(path: '/ich', builder: (_, __) => const Text('ich')),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const Text('settings'),
                routes: [
                  GoRoute(
                    path: 'help',
                    builder: (context, __) => Column(
                      children: [
                        const TextField(key: Key('search')),
                        TextButton(
                          onPressed: () => rdHelpBack(context, '/ich'),
                          child: const Text('back'),
                        ),
                      ],
                    ),
                    routes: [
                      GoRoute(
                        path: 'article',
                        builder: (context, __) => TextButton(
                          onPressed: () => rdHelpBack(context, '/settings/help'),
                          child: const Text('article back'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  testWidgets('direct call of /settings/help goes back to /ich', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router('/settings/help')));
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(find.text('ich'), findsOneWidget);
    expect(find.text('settings'), findsNothing);
  });

  testWidgets('pushed help pops to the page below', (tester) async {
    final r = router('/ich');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    r.push('/settings/help');
    await tester.pumpAndSettle();
    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();
    expect(r.routerDelegate.currentConfiguration.uri.path, '/ich');
  });

  testWidgets('back from a pushed article keeps the help search', (tester) async {
    final r = router('/ich');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    r.push('/settings/help');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search')), 'probe');
    r.push('/settings/help/article');
    await tester.pumpAndSettle();
    await tester.tap(find.text('article back'));
    await tester.pumpAndSettle();
    expect(find.text('probe'), findsOneWidget);
  });
}
