import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/utils/helper_member.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_new_person_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('"Neue Person" im Termin: Pflichtnamen, Register, legt an und schließt', (tester) async {
    final created = <Person>[];
    Person? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<Person>(
                      context: context,
                      isScrollControlled: true,
                      builder:
                          (_) => RdNewPersonSheet(
                            groups: const [Group(id: 1, name: 'Sopran'), Group(id: 2, name: 'Alt')],
                            initialGroup: 1,
                            create: (_, person) async {
                              created.add(person);
                              return person.copyWith(id: 99);
                            },
                          ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Without names nothing is created.
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib Vor- und Nachnamen ein.'), findsOneWidget);
    expect(created, isEmpty);

    await tester.enterText(find.byKey(const Key('rd-new-person-first')), 'Anna');
    await tester.enterText(find.byKey(const Key('rd-new-person-last')), 'Gast');
    await tester.tap(find.byKey(const Key('rd-new-person-group-2')));
    await tester.pump();
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(created.single.firstName, 'Anna');
    expect(created.single.lastName, 'Gast');
    expect(created.single.instrument, 2);
    expect(result?.id, 99);
    expect(find.byType(RdNewPersonSheet), findsNothing);
  });

  testWidgets('Aushilfe: "dabei bis" startet beim Termin-Tag und wird gespeichert', (tester) async {
    final created = <Person>[];
    final eventDay = DateTime.now().add(const Duration(days: 8));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: Scaffold(
          body: RdNewPersonSheet(
            groups: const [Group(id: 1, name: 'Sopran')],
            initialGroup: 1,
            eventDay: eventDay,
            create: (_, person) async {
              created.add(person);
              return person.copyWith(id: 5);
            },
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('rd-new-person-helper-until')), findsNothing);
    await tester.tap(find.byKey(const Key('rd-new-person-helper')));
    await tester.pump();
    expect(find.byKey(const Key('rd-new-person-helper-until')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('rd-new-person-first')), 'Ben');
    await tester.enterText(find.byKey(const Key('rd-new-person-last')), 'Aushilfe');
    await tester.tap(find.text('Anlegen'));
    await tester.pump();

    expect(helperUntil(created.single), helperDay(eventDay));
  });

  test('helperCoversDate: nur Termine bis zum letzten Tag', () {
    final fields = {helperUntilKey: '2026-12-20'};
    expect(helperCoversDate(fields, '2026-12-20T11:00:00.000Z'), isTrue);
    expect(helperCoversDate(fields, '2026-12-21T11:00:00.000Z'), isFalse);
    expect(helperCoversDate(null, '2030-01-01'), isTrue);
    expect(helperCoversDate({helperUntilKey: null}, '2030-01-01'), isTrue);
  });
}
