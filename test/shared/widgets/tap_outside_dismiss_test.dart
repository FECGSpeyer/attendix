import 'package:attendix/shared/widgets/layout/tap_outside_dismiss.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ionic web view: tapping outside a field closes the keyboard (number pads
/// have no return key); scrolling keeps it open.
void main() {
  Future<FocusNode> pump(WidgetTester tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => TapOutsideToDismissKeyboard(child: child!),
      home: Scaffold(
        body: ListView(children: [
          TextField(focusNode: node, keyboardType: TextInputType.number),
          const SizedBox(height: 2000),
        ]),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);
    return node;
  }

  testWidgets('tap outside unfocuses on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final node = await pump(tester);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(node.hasFocus, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('dragging outside keeps the focus', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final node = await pump(tester);
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -100));
    await tester.pump();
    expect(node.hasFocus, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
