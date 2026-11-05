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

  // Issue #318: Person / Termin pages in the card close themselves with
  // Navigator.of(context) (X via maybePop, _closePage / _leavePage /
  // _openLocation via pop). The card sits on the root navigator, so that is
  // the card's route even when opened from a nested (shell) navigator.
  group('page inside the card (opened from a nested navigator)', () {
    Future<void> openNested(WidgetTester tester,
        {bool canPop = true, VoidCallback? onBlockedPop}) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Übersicht')),
              body: Center(
                child: TextButton(
                  onPressed: () => showIosCardModal<void>(
                    context,
                    builder: (_) => PopScope(
                      canPop: canPop,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) onBlockedPop?.call();
                      },
                      child: Builder(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Person'),
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ],
                          ),
                          body: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('archivieren'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Person'), findsOneWidget);
    }

    testWidgets('X (maybePop) closes the card', (tester) async {
      await openNested(tester);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Person'), findsNothing);
      expect(find.text('Übersicht'), findsOneWidget);
    });

    testWidgets('Navigator.of(context).pop() closes only the card',
        (tester) async {
      await openNested(tester);
      await tester.tap(find.text('archivieren'));
      await tester.pumpAndSettle();
      expect(find.text('Person'), findsNothing);
      expect(find.text('Übersicht'), findsOneWidget);
    });

    testWidgets('swipe down respects PopScope (unsaved changes)',
        (tester) async {
      var blocked = 0;
      await openNested(tester, canPop: false, onBlockedPop: () => blocked++);
      await tester.fling(find.text('Person'), const Offset(0, 400), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Person'), findsOneWidget);
      expect(blocked, 1);
      // Card snapped back to its resting place.
      final card = find.ancestor(
        of: find.text('Person'),
        matching: find.byType(ClipRRect),
      );
      expect(tester.getTopLeft(card.last).dy, 40);
    });
  });
}
