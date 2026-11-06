import 'package:attendix/core/router/go_replace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final shownResults = <bool>[];

/// Stand-in for the group selection: leaves the tab shell and goes back
/// into it right away (auto-navigation after an account switch).
class _Selection extends StatefulWidget {
  const _Selection({required this.wait});
  final bool wait;
  @override
  State<_Selection> createState() => _SelectionState();
}

class _SelectionState extends State<_Selection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = ModalRoute.of(context);
      final router = GoRouter.of(context);
      // Same checks as the group selection: shown and still on top.
      if (widget.wait && (!await untilRouteShown(route) || route?.isCurrent != true)) {
        shownResults.add(false);
        return;
      }
      shownResults.add(true);
      router.go('/heute');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Gruppen'));
}

Future<Object?> _leaveShellAndReturn(WidgetTester tester, {required bool wait, bool leaveAgain = false}) async {
  shownResults.clear();
  final router = GoRouter(
    initialLocation: '/ich',
    routes: [
      GoRoute(path: '/tenants', builder: (_, __) => _Selection(wait: wait)),
      ShellRoute(
        builder: (_, __, child) => Scaffold(body: Row(children: [const Text('Tabs'), Expanded(child: child)])),
        routes: [
          GoRoute(path: '/heute', builder: (_, __) => const Text('Heute')),
          GoRoute(path: '/ich', builder: (_, __) => const Text('Ich')),
        ],
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  router.go('/tenants');
  if (leaveAgain) {
    // Back to the shell while the selection still slides in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    router.go('/ich');
  }
  await tester.pumpAndSettle();
  return tester.takeException();
}

void main() {
  testWidgets('going back into the shell before the push ends clashes (the bug)', (tester) async {
    expect(await _leaveShellAndReturn(tester, wait: false), isNotNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('waiting for the push re-enters the shell cleanly', (tester) async {
    expect(await _leaveShellAndReturn(tester, wait: true), isNull);
    expect(find.text('Heute'), findsOneWidget);
    expect(find.text('Tabs'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('leaving the page while it slides in cancels the jump back', (tester) async {
    await _leaveShellAndReturn(tester, wait: true, leaveAgain: true);
    expect(shownResults, [false]);
    expect(find.text('Ich'), findsOneWidget);
    expect(find.text('Heute'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
