import 'package:attendix/core/router/go_replace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
      if (widget.wait) await untilRouteShown(route);
      router.go('/heute');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Gruppen'));
}

Future<Object?> _leaveShellAndReturn(WidgetTester tester, {required bool wait}) async {
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
}
