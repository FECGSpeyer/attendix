import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Beta radio alert: the checked option is announced, confirm returns it', (tester) async {
    final semantics = tester.ensureSemantics();
    AppRadioAlertResult<bool>? result;
    await tester.pumpWidget(MaterialApp(
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showAppRadioAlert<bool>(
            context,
            title: 'Sammlung löschen',
            subtitle: 'Was soll mit den Werken passieren?',
            options: const [(false, 'Ins Repertoire'), (true, 'Samt Noten löschen')],
            initialValue: false,
            confirmText: 'Löschen',
          ),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    Matcher checked(bool on) => isSemantics(isChecked: on, isInMutuallyExclusiveGroup: true);
    expect(tester.getSemantics(find.text('Ins Repertoire')), checked(true));
    await tester.tap(find.text('Samt Noten löschen'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('Samt Noten löschen')), checked(true));
    expect(tester.getSemantics(find.text('Ins Repertoire')), checked(false));

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(result?.value, isTrue);
    semantics.dispose();
  });
}
