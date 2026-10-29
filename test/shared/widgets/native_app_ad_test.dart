import 'package:attendix/shared/widgets/dialogs/native_app_ad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store follows the user agent like Ionic', () {
    final ios = NativeAppAdStore.forUserAgent(isIos: true);
    expect(ios.name, 'App Store');
    expect(ios.url, contains('apps.apple.com'));
    final other = NativeAppAdStore.forUserAgent(isIos: false);
    expect(other.name, 'Play Store');
    expect(other.url, contains('play.google.com'));
  });

  testWidgets('dialog shows the Ionic texts and closes with "Später"',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showNativeAppAdDialog(
            context,
            NativeAppAdStore.forUserAgent(isIos: false),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Attendix als App verfügbar!'), findsOneWidget);
    expect(find.textContaining('Jetzt im Play Store herunterladen!'),
        findsOneWidget);
    // PARITY_R3: Ionic md alert buttons are UPPERCASE
    expect(find.text('ZUM PLAY STORE'), findsOneWidget);

    await tester.tap(find.text('SPÄTER'));
    await tester.pumpAndSettle();
    expect(find.text('Attendix als App verfügbar!'), findsNothing);
  });
}
