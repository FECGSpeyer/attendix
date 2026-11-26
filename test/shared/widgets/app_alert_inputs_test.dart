import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared alert inputs: `AppAlertInput`, `AppAlertInputGroup`,
/// `AppAlertRadioGroup`, `AppAlertCheckboxGroup`, `showAppCheckboxAlert`.
void main() {
  Widget app(ThemeData theme, Widget home) => MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: home),
      );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('checkbox alert ($platform): toggles, veto and result', (tester) async {
      Set<int>? result;
      await tester.pumpWidget(app(
        AppTheme.forPlatform(Brightness.light, platform),
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showAppCheckboxAlert<int>(
              context,
              title: 'Verfügbare Status',
              options: const [
                AppAlertOption(1, 'Anwesend', enabled: false),
                AppAlertOption(2, 'Entschuldigt'),
                AppAlertOption(3, 'Verspätet'),
              ],
              initialValues: const [1, 2],
              confirmText: 'Übernehmen',
              // "At least two stay checked".
              canChange: (current, value, checked) => checked || current.length > 2,
            ),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AppAlertCheckboxGroup<int>), findsOneWidget);

      // Disabled row does not change, the veto keeps "Entschuldigt".
      await tester.tap(find.text('Anwesend'));
      await tester.tap(find.text('Entschuldigt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verspätet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(result, {1, 2, 3});
    });
  }

  testWidgets('AppAlertInput and AppAlertRadioGroup render with standard theme', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(
      buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      Column(
        children: [
          AppAlertInput(
            controller: controller,
            placeholder: 'Platzhalter',
            betaDecoration: const InputDecoration(labelText: 'Bezeichnung'),
          ),
          AppAlertRadioGroup<int>(
            options: const [AppAlertOption(1, 'Eins')],
            groupValue: 1,
            onChanged: (_) {},
            beta: const Text('beta content'),
          ),
          const AppAlertBetaGap(8),
        ],
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.labelText, 'Bezeichnung');
    expect(field.decoration?.hintText, isNull);
    expect(find.text('beta content'), findsOneWidget);
    expect(find.text('Eins'), findsNothing);
    expect(tester.getSize(find.byType(AppAlertBetaGap)).height, 8);
  });
}
