import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMenuItems skips disabled caption items without a value', () {
    final options = AppSelectOption.fromMenuItems<String>(const [
      DropdownMenuItem<String>(enabled: false, child: Text('Standard-Felder')),
      DropdownMenuItem<String>(value: 'firstName', child: Text('Vorname')),
      DropdownMenuItem<String>(value: 'lastName', child: Text('Nachname')),
    ]);
    expect(options.map((o) => o.value), ['firstName', 'lastName']);
  });

  test('fromMenuItems keeps a null option of a nullable select', () {
    final options = AppSelectOption.fromMenuItems<String?>(const [
      DropdownMenuItem<String?>(value: null, child: Text('Keine')),
      DropdownMenuItem<String?>(value: 'a', child: Text('A')),
    ]);
    expect(options.map((o) => o.value), [null, 'a']);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('select with a caption item: hint shown, opens, picks ($platform)',
        (tester) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.forPlatform(Brightness.light, platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: AppDropdownFormField<String>(
            // ignore: deprecated_member_use
            value: null,
            hint: const Text('hint'),
            items: const [
              DropdownMenuItem<String>(enabled: false, child: Text('Header')),
              DropdownMenuItem(value: 'a', child: Text('A')),
            ],
            onChanged: (v) => picked = v,
          ),
        ),
      ));
      expect(find.text('hint'), findsOneWidget);
      expect(find.text('Header'), findsNothing);
      await tester.tap(find.text('hint'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      if (picked == null && find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      expect(picked, 'a');
    });
  }
}
