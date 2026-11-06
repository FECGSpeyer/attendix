import 'package:attendix/features/redesign/presentation/pages/rd_help_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter router(String initial) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/ich', builder: (_, __) => const Text('ich')),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const Text('settings'),
            routes: [
              GoRoute(
                path: 'help',
                builder: (context, __) => TextButton(
                  onPressed: () => rdHelpBack(context, '/ich'),
                  child: const Text('back'),
                ),
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
    expect(find.text('ich'), findsOneWidget);
    expect(r.routerDelegate.currentConfiguration.uri.path, '/ich');
  });
}
