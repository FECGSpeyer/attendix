import 'dart:io';

import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/features/planning/presentation/widgets/plan_fields_editor.dart';
import 'package:attendix/features/planning/presentation/widgets/plan_view_list.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WAVE 5 i18n lane "planning": lib/features/planning + lib/features/organisation.
void main() {
  group('no hard-coded German UI literals', () {
    final files = [
      ...Directory('lib/features/planning').listSync(recursive: true),
      ...Directory('lib/features/organisation').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));

    // Ionic keeps the public planning templates and branding names German
    // (public-planning-templates.ts), so they stay data in Flutter too.
    const allowed = ['public_planning_page.dart'];

    for (final file in files) {
      if (allowed.any(file.path.endsWith)) continue;
      test(file.path, () {
        final umlautLiteral = RegExp(r"'[^'\n]*[äöüÄÖÜß][^'\n]*'");
        final offending = file
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .where(umlautLiteral.hasMatch)
            .toList();
        expect(offending, isEmpty);
      });
    }
  });

  test('Flutter-only planning keys exist in German and English', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(de.planningFlutterPdfA4, 'PDF (A4)');
    expect(de.planningFlutterSaveFailedWith('x'), 'Fehler beim Speichern: x');
    expect(de.plansFlutterFieldsCount(3), '3 Felder');
    expect(de.orgFlutterFieldCount(1), '1 Feld');
    expect(en.planningFlutterNoEvents, 'No events available');
    expect(en.plansFlutterHideTab, 'Hide tab');
  });

  Widget app(Widget child, Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  const plan = Plan(
    time: '18:00',
    end: '',
    fields: [PlanField(id: 'a', name: 'Einsingen', time: '10')],
  );

  testWidgets('PlanViewList keeps the German wording', (tester) async {
    await tester.pumpWidget(app(const PlanViewList(plan: plan, date: null), const Locale('de')));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('18:00 Uhr'), findsOneWidget);
    expect(find.text('Ende'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
  });

  testWidgets('PlanViewList follows the English locale', (tester) async {
    await tester.pumpWidget(app(const PlanViewList(plan: plan, date: null), const Locale('en')));
    expect(find.text('End'), findsOneWidget);
    expect(find.textContaining('Uhr'), findsNothing);
  });

  testWidgets('PlanFieldsEditor empty text is translated', (tester) async {
    await tester.pumpWidget(app(
      PlanFieldsEditor(fields: const [], startTime: '18:00', onChanged: (_) {}),
      const Locale('de'),
    ));
    expect(find.text('Keine Programmpunkte'), findsOneWidget);
  });
}
