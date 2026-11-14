import 'package:attendix/shared/widgets/layout/scroll_away_dismiss.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<FocusNode> pumpList(WidgetTester tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ScrollAwayDismissesKeyboard(
        child: Scaffold(
          body: ListView(children: [
            TextField(focusNode: node),
            for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('Zeile $i')),
          ]),
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);
    return node;
  }

  testWidgets('field scrolled out of the list loses focus (iOS)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final node = await pumpList(tester);
    await tester.drag(find.text('Zeile 5'), const Offset(0, -10));
    await tester.pump();
    expect(node.hasFocus, isTrue, reason: 'still visible, keyboard stays');
    await tester.drag(find.text('Zeile 5'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
