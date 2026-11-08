import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_form_widgets.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The top bar holds the only submit of a form page: on a small phone
  // with very large text it must stay whole and tappable.
  testWidgets('small phone with very large text: Anlegen and Fertig stay whole', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var submitted = 0;
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(children: [
          RdFormTopBar(
            title: 'Neuer Termin',
            cancel: 'Abbrechen',
            submit: 'Anlegen',
            saving: false,
            onCancel: () {},
            onSubmit: () => submitted++,
            submitKey: const Key('submit'),
          ),
          RdEditTopBar(title: 'Termin bearbeiten', onDone: () => done++, doneKey: const Key('done')),
        ]),
      ),
    ));

    // No overflow (the test would fail on one); both actions fit the screen.
    for (final key in const [Key('submit'), Key('done')]) {
      expect(tester.getRect(find.byKey(key)).right, lessThanOrEqualTo(320));
    }
    await tester.tap(find.text('Anlegen'));
    await tester.tap(find.text('Fertig'));
    expect((submitted, done), (1, 1));
  });
}
