import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('IonAccordionTile: Ionic header, content only while open ($platform)',
        (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: IonAccordionTile(
            title: const Text('Themen'),
            onExpansionChanged: changes.add,
            children: const [Text('Inhalt')],
          ),
        ),
      ));
      final ios = platform == TargetPlatform.iOS;
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Inhalt'), findsNothing);
      // ion-item height: 52 (iOS theme) / 48 (md).
      expect(tester.getSize(find.byType(IonAccordionTile)).height, ios ? 52 : 48);
      expect(tester.widget<IonChevronDownIcon>(find.byType(IonChevronDownIcon)).size, ios ? 20 : 24);

      await tester.tap(find.text('Themen'));
      // Ionic: 300 ms – still moving after 200 ms, done after 300 ms.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Inhalt'), findsOneWidget);
      // The label keeps the item text colour when open (no primary tint).
      final style = DefaultTextStyle.of(tester.element(find.text('Themen'))).style;
      expect(style.color, AppTheme.light.colorScheme.onSurface);

      await tester.tap(find.text('Themen'));
      await tester.pumpAndSettle();
      expect(find.text('Inhalt'), findsNothing);
      expect(changes, [true, false]);
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('IonRadioItem: checkmark on iOS, Material radio on md ($platform)',
        (tester) async {
      int? picked;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(children: [
            IonRadioItem<int>(value: 1, groupValue: 1, labelEnd: true, title: const Text('A'), onChanged: (_) {}),
            IonRadioItem<int>(value: 2, groupValue: 1, title: const Text('B'), onChanged: (v) => picked = v),
          ]),
        ),
      ));
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(Radio<int>), findsNothing);
        // Only the selected row shows the checkmark; labelEnd puts it first.
        expect(find.byIcon(AppIcons.check), findsOneWidget);
        expect(tester.getCenter(find.byIcon(AppIcons.check)).dx,
            lessThan(tester.getCenter(find.text('A')).dx));
      } else {
        expect(find.byType(Radio<int>), findsNWidgets(2));
        // Default placement: label first, control at the end.
        expect(tester.getCenter(find.byType(Radio<int>).last).dx,
            greaterThan(tester.getCenter(find.text('B')).dx));
      }
      await tester.tap(find.text('B'));
      expect(picked, 2);
    }, variant: TargetPlatformVariant.only(platform));
  }
}
