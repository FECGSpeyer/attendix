import 'package:attendix/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SWIPE_BACK_WEB: after Safari's own swipe back the pop must not slide the
/// old page out a second time; other pops keep the iOS slide.
void main() {
  Future<NavigatorState> pumpPushed(
    WidgetTester tester,
    bool Function() skip,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.iOS: IonIosPageTransitionsBuilder(
                swipeBack: false,
                skipCheck: skip,
              ),
            },
          ),
        ),
        home: const Scaffold(body: Text('Einstellungen')),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Allgemein')),
      ),
    );
    await tester.pumpAndSettle();
    return navKey.currentState!;
  }

  testWidgets('pop right after a browser swipe shows the page below at once', (
    tester,
  ) async {
    var skip = false;
    final nav = await pumpPushed(tester, () => skip);
    skip = true;
    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.text('Allgemein')).dx,
      greaterThanOrEqualTo(width),
    );
    expect(tester.getTopLeft(find.text('Einstellungen')).dx, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('a normal pop still slides', (tester) async {
    final nav = await pumpPushed(tester, () => false);
    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final x = tester.getTopLeft(find.text('Allgemein')).dx;
    expect(x, greaterThan(0));
    expect(x, lessThan(width));
    await tester.pumpAndSettle();
  });
}
