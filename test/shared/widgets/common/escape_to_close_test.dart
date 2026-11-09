import 'package:attendix/shared/widgets/common/escape_to_close.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Escape closes the viewer route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const EscapeToClose(child: Text('Viewer')),
          )),
          child: const Text('Werk'),
        ),
      ),
    ));
    await tester.tap(find.text('Werk'));
    await tester.pumpAndSettle();
    expect(find.text('Viewer'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Viewer'), findsNothing);
    expect(find.text('Werk'), findsOneWidget);
  });
}
