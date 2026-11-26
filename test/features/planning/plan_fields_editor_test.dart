import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/utils/plan_utils.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/features/planning/presentation/widgets/plan_fields_editor.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan fields editor: duration editing in the row sheet, reorder handles,
/// "Themen aufnehmen" on the agenda marker, and Beamer rows.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  Future<List<PlanField>? Function()> pump(
    WidgetTester tester,
    List<PlanField> fields, {
    VoidCallback? onAddTopics,
    BeamerFile? Function(PlanField)? fileOf,
  }) async {
    List<PlanField>? emitted;
    await tester.pumpWidget(wrap(
      PlanFieldsEditor(
        fields: fields,
        startTime: '18:00',
        onChanged: (f) => emitted = f,
        onAddTopics: onAddTopics,
        beamerFileOf: fileOf,
      ),
    ));
    return () => emitted;
  }

  testWidgets('plain fields edit minutes via row sheet and emit changes', (tester) async {
    final emitted = await pump(tester, const [PlanField(id: 'a', name: 'Einsingen', time: '10')]);

    await tester.tap(find.text('Einsingen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rd-plan-field-minutes')), '25');
    await tester.tap(find.byKey(const Key('rd-sheet-close')));
    await tester.pumpAndSettle();
    expect(emitted()?.single.time, '25');
  });

  testWidgets('note fields have no minutes input', (tester) async {
    await pump(tester, const [PlanField(id: 'noteFld1', name: 'Bitte pünktlich', time: '0')]);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Bitte pünktlich'), findsOneWidget);
  });

  testWidgets('rows have drag handles for reordering', (tester) async {
    await pump(tester, const [
      PlanField(id: 'a', name: 'A', time: '10'),
      PlanField(id: 'b', name: 'B', time: '5'),
    ]);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
  });

  testWidgets('agenda marker offers "Themen aufnehmen" when allowed', (tester) async {
    var tapped = false;
    await pump(
      tester,
      const [PlanField(id: PlanUtils.agendaPlaceholderId, name: 'Tagesordnung', time: '0')],
      onAddTopics: () => tapped = true,
    );
    await tester.tap(find.text('Themen aufnehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Themen aufnehmen').last);
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  group('Beamer rows', () {
    testWidgets('no status line when the Beamer feature is off', (tester) async {
      await pump(tester, const [PlanField(id: 'a', name: 'Gemeindelied', time: '5')]);
      expect(find.text('Beamer-Datei fehlt'), findsNothing);
    });

    testWidgets('status line shows "Beamer-Datei fehlt" only when missing', (tester) async {
      await pump(
        tester,
        const [
          PlanField(id: 'a', name: 'Gemeindelied', time: '5'),
          PlanField(id: '7', name: 'Werk', time: '5', songId: 7),
          PlanField(id: 'c', name: 'Predigt', time: '30'),
        ],
        fileOf: (f) => f.songId == 7 ? const BeamerFile(name: 'werk.sng', path: 'p') : null,
      );
      expect(find.text('Beamer-Datei fehlt'), findsOneWidget);
    });

    testWidgets('edit sheet switches "Beamer-Datei nötig" off by hand', (tester) async {
      final emitted = await pump(
        tester,
        const [PlanField(id: 'a', name: 'Gemeindelied', time: '5')],
        fileOf: (_) => null,
      );
      await tester.tap(find.text('Gemeindelied'));
      await tester.pumpAndSettle();
      expect(find.text('Beamer-Datei nötig'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('rd-plan-field-beamer')));
      await tester.tap(find.byKey(const Key('rd-plan-field-beamer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rd-sheet-close')));
      await tester.pumpAndSettle();
      expect(emitted()?.single.needsBeamer, isFalse);
    });

    testWidgets('edit sheet has no Beamer section when the feature is off', (tester) async {
      await pump(tester, const [PlanField(id: 'a', name: 'Gemeindelied', time: '5', needsBeamer: true)]);
      await tester.tap(find.text('Gemeindelied'));
      await tester.pumpAndSettle();
      expect(find.text('Beamer-Datei nötig'), findsNothing);
    });
  });
}
