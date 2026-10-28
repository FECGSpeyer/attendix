// IOS_R4: Ionic iOS card modal (presentingElement) – page behind scaled on
// a black body, card 10pt below max(30, safe area), strip tap closes.
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Mehr')),
          body: Center(
            child: TextButton(
              onPressed: () => showIosCardModal<void>(
                context,
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Werkhistorie')),
                  body: const Text('Inhalt'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  test('presenting top follows Ionic max(30px, safe-area-top)', () {
    expect(iosCardModalPresentingTop(0), 30);
    expect(iosCardModalPresentingTop(59), 59);
  });

  testWidgets('card sits 40pt from the top over the black body',
      (tester) async {
    await open(tester);
    expect(find.text('Werkhistorie'), findsOneWidget);
    final card = find.ancestor(
      of: find.text('Werkhistorie'),
      matching: find.byType(ClipRRect),
    );
    expect(tester.getTopLeft(card.last).dy, 40);
    // Card toolbar: 64pt (ionic-theme `.modal-card` header).
    final bar = tester.getSize(find.ancestor(
        of: find.text('Werkhistorie'), matching: find.byType(AppBar)));
    expect(bar.height, kIosCardModalToolbarHeight);
    // Black body behind the presenting page.
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((b) => b.color == Colors.black),
      isTrue,
    );
  });

  testWidgets('tap on the strip above the card closes it', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.text('Werkhistorie'), findsNothing);
    expect(find.text('Mehr'), findsOneWidget);
  });

  testWidgets('swipe down closes the card', (tester) async {
    await open(tester);
    await tester.fling(find.text('Werkhistorie'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Werkhistorie'), findsNothing);
  });
}
