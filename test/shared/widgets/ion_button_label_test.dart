// MD_BUTTONS: Ionic md `ion-button` labels are `text-transform: uppercase`
// (@ionic/core button.md.css); Ionic iOS keeps them as written.

import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _md() =>
    AppTheme.forPlatform(Brightness.light, TargetPlatform.android, web: false);

ThemeData _ios() =>
    AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS, web: false)
        .copyWith(platform: TargetPlatform.iOS);

Widget _app(ThemeData theme, Widget child) =>
    MaterialApp(theme: theme, home: Scaffold(body: Center(child: child)));

void main() {
  group('IonButtonLabel', () {
    testWidgets('md: label is uppercase, ß becomes SS like CSS',
        (tester) async {
      await tester.pumpWidget(_app(
        _md(),
        Column(children: [
          FilledButton(
              onPressed: () {}, child: const IonButtonLabel('Speichern')),
          TextButton(onPressed: () {}, child: const IonButtonLabel('Straße')),
        ]),
      ));
      expect(find.text('SPEICHERN'), findsOneWidget);
      expect(find.text('STRASSE'), findsOneWidget);
      expect(find.text('Speichern'), findsNothing);
    });

    testWidgets('iOS: label keeps its case', (tester) async {
      await tester.pumpWidget(_app(
        _ios(),
        FilledButton(
            onPressed: () {}, child: const IonButtonLabel('Speichern')),
      ));
      expect(find.text('Speichern'), findsOneWidget);
      expect(find.text('SPEICHERN'), findsNothing);
    });

    testWidgets('passes style, maxLines and overflow to the Text',
        (tester) async {
      await tester.pumpWidget(_app(
        _md(),
        const IonButtonLabel('Weiter',
            style: TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
      ));
      final text = tester.widget<Text>(find.text('WEITER'));
      expect(text.style?.fontSize, 13);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.textAlign, TextAlign.center);
    });

    test('ionUppercase: CSS-like, ß → SS on the VM too', () {
      expect(ionUppercase('Schließen'), 'SCHLIESSEN');
      expect(ionUppercase('Änderungen übernehmen'), 'ÄNDERUNGEN ÜBERNEHMEN');
    });

    testWidgets('ionButtonText follows the platform', (tester) async {
      late String md, ios;
      await tester.pumpWidget(_app(_md(), Builder(builder: (c) {
        md = ionButtonText(c, 'Abbrechen');
        return const SizedBox();
      })));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(_ios(), Builder(builder: (c) {
        ios = ionButtonText(c, 'Abbrechen');
        return const SizedBox();
      })));
      expect(md, 'ABBRECHEN');
      expect(ios, 'Abbrechen');
    });
  });

  group('alert actions with an IonButtonLabel', () {
    testWidgets('md alert button: plain uppercase Text, right aligned',
        (tester) async {
      late Widget converted;
      await tester.pumpWidget(_app(_md(), Builder(builder: (c) {
        converted = mdAlertActionFrom(
            c, TextButton(onPressed: () {}, child: const IonButtonLabel('Ok')));
        return converted;
      })));
      final child = (converted as TextButton).child;
      expect(child, isA<Text>());
      expect((child! as Text).data, 'OK');
      expect((child as Text).textAlign, TextAlign.end);
    });

    testWidgets('iOS alert pill: plain Text as written (measurable)',
        (tester) async {
      late Widget converted;
      await tester.pumpWidget(_app(_ios(), Builder(builder: (c) {
        converted = iosAlertActionFrom(c,
            TextButton(onPressed: () {}, child: const IonButtonLabel('Löschen')));
        return converted;
      })));
      final pill = converted as IosAlertButton;
      expect(pill.child, isA<Text>());
      expect((pill.child as Text).data, 'Löschen');
      expect(pill.labelWidth(TextScaler.noScaling, TextDirection.ltr),
          isNotNull);
    });
  });
}
