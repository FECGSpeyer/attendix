import 'package:attendix/core/services/native/keyboard_focus_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('native Tab / Shift-Tab move the focus between fields',
      (tester) async {
    final email = FocusNode();
    final password = FocusNode();
    addTearDown(email.dispose);
    addTearDown(password.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          TextField(focusNode: email),
          TextField(focusNode: password),
        ]),
      ),
    ));
    email.requestFocus();
    await tester.pump();

    expect(await handleKeyboardFocusCall(const MethodCall('next')), isTrue);
    await tester.pump();
    expect(password.hasFocus, isTrue);

    expect(await handleKeyboardFocusCall(const MethodCall('previous')), isTrue);
    await tester.pump();
    expect(email.hasFocus, isTrue);

    expect(await handleKeyboardFocusCall(const MethodCall('other')), isFalse);
  });
}
