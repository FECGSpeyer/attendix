import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/adaptive/app_pickers.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// F-EINST-27: the save button of the Terminart page (TabBarFab) must be
/// back whenever the page is the current route again.
class _TypePage extends StatefulWidget {
  const _TypePage();

  @override
  State<_TypePage> createState() => _TypePageState();
}

class _TypePageState extends State<_TypePage> {
  String _start = '19:00';

  Future<void> _pickStart({bool rootNavigator = true}) async {
    final t = await showAppTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
      minuteInterval: 5,
      useRootNavigator: rootNavigator,
    );
    // Like the page: setState right after the picker closed.
    if (mounted) setState(() => _start = t == null ? '$_start ' : '${t.hour}:${t.minute}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Text(_start),
        TextButton(onPressed: _pickStart, child: const Text('Beginn')),
        TextButton(onPressed: () => _pickStart(rootNavigator: false), child: const Text('Beginn shell')),
      ]),
      floatingActionButton: TabBarFab(
        child: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.save_outlined)),
      ),
    );
  }
}

void main() {
  late ValueNotifier<bool> withScope;
  late ValueNotifier<TargetPlatform> platform;

  Future<void> pumpShell(WidgetTester tester) async {
    withScope = ValueNotifier(true);
    platform = ValueNotifier(TargetPlatform.iOS);
    final router = GoRouter(initialLocation: '/type', routes: [
      ShellRoute(
        // Like MainShell: the iOS shell provides the scope, the side panel
        // shell (tablet / desktop width) does not; the shell navigator
        // (GlobalKey) and with it the page state survive the switch.
        builder: (context, state, child) => Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: withScope,
            builder: (context, scoped, _) => scoped
                ? Stack(children: [
                    Positioned.fill(child: IosTabBarScope(bottom: 20, right: 16, child: child)),
                  ])
                : Row(children: [const SizedBox(width: 72), Expanded(child: child)]),
          ),
        ),
        routes: [
          GoRoute(
            path: '/type',
            pageBuilder: (c, s) => NoTransitionPage(key: s.pageKey, child: const _TypePage()),
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(ValueListenableBuilder<TargetPlatform>(
      valueListenable: platform,
      builder: (context, p, _) => MaterialApp.router(
        theme: AppTheme.forPlatform(Brightness.light, p, web: true),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> closePicker(WidgetTester tester) async {
    // Tap outside the card: the iOS time popover closes.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  }

  final fab = find.byIcon(Icons.save_outlined);

  testWidgets('F-EINST-27: save button is back after the Beginn time popover (root navigator)', (tester) async {
    await pumpShell(tester);
    expect(fab, findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Beginn'));
      await tester.pumpAndSettle();
      await closePicker(tester);
      expect(fab, findsOneWidget);
    }
    await tester.tap(find.text('Beginn shell'));
    await tester.pumpAndSettle();
    expect(fab, findsNothing, reason: 'covered by a popup of the shell navigator');
    await closePicker(tester);
    expect(fab, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F-EINST-27: save button is back after the tab shell was left and entered again on the same page', (tester) async {
    await pumpShell(tester);
    expect(fab, findsOneWidget);
    // Window wider than a phone (side panel shell) and back.
    withScope.value = false;
    await tester.pumpAndSettle();
    withScope.value = true;
    await tester.pumpAndSettle();
    expect(fab, findsOneWidget);
    await tester.tap(find.text('Beginn'));
    await tester.pumpAndSettle();
    await closePicker(tester);
    expect(fab, findsOneWidget);
    // md look and back to the iOS look.
    platform.value = TargetPlatform.android;
    await tester.pumpAndSettle();
    platform.value = TargetPlatform.iOS;
    await tester.pumpAndSettle();
    expect(fab, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
