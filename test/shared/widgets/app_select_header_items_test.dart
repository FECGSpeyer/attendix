import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMenuItems skips disabled caption items without a value', () {
    // Bulk edit "Feld auswählen": section captions are disabled items with a
    // null value in a `String` select; they used to throw on the cast.
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
      // No value: the placeholder, not the caption item.
      expect(find.text('hint'), findsOneWidget);
      expect(find.text('Header'), findsNothing);
      await tester.tap(find.text('hint'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      // The Ionic alert interface commits on OK.
      if (picked == null && find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      expect(picked, 'a');
    });
  }

  testWidgets('dragging a sheet shut far past its height keeps the page below',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('home')),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showIonSheet<void>(
            context,
            breakpoints: const [0, 0.5],
            initialBreakpoint: 0.5,
            builder: (_, c) => IonSheetScaffold(
              title: 'Personen',
              body: ListView(controller: c, children: const [Text('x')]),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(tester.getCenter(find.text('Personen')));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Personen'), findsNothing); // sheet closed
    expect(find.text('open'), findsOneWidget); // its page is still there
  });
}
