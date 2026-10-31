import 'package:attendix/core/utils/plan_utils.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/features/planning/presentation/widgets/plan_fields_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX parity with the Ionic plan editor: inline minutes input per row,
/// swipe options (Einrücken + delete), "Themen aufnehmen" on the agenda marker.
void main() {
  Future<List<PlanField>?> pump(
    WidgetTester tester,
    List<PlanField> fields, {
    VoidCallback? onAddTopics,
  }) async {
    List<PlanField>? emitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlanFieldsEditor(
            fields: fields,
            startTime: '18:00',
            onChanged: (f) => emitted = f,
            onAddTopics: onAddTopics,
          ),
        ),
      ),
    ));
    return emitted;
  }

  testWidgets('plain fields have an inline minutes input that emits changes', (tester) async {
    List<PlanField>? emitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlanFieldsEditor(
            fields: const [PlanField(id: 'a', name: 'Einsingen', time: '10')],
            startTime: '18:00',
            onChanged: (f) => emitted = f,
          ),
        ),
      ),
    ));

    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '25');
    expect(emitted?.single.time, '25');
  });

  testWidgets('note fields have no minutes input', (tester) async {
    await pump(tester, const [PlanField(id: 'noteFld1', name: 'Bitte pünktlich', time: '0')]);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Bitte pünktlich'), findsOneWidget);
  });

  testWidgets('rows are slidable (Ionic ion-item-sliding)', (tester) async {
    await pump(tester, const [
      PlanField(id: 'a', name: 'A', time: '10'),
      PlanField(id: 'b', name: 'B', time: '5'),
    ]);
    expect(find.byType(Slidable), findsNWidgets(2));
  });

  testWidgets('agenda marker offers "Themen aufnehmen" when allowed', (tester) async {
    var tapped = false;
    await pump(
      tester,
      const [PlanField(id: PlanUtils.agendaPlaceholderId, name: 'Tagesordnung', time: '0')],
      onAddTopics: () => tapped = true,
    );
    await tester.tap(find.text('Themen aufnehmen'));
    expect(tapped, isTrue);
  });

  group('Beamer rows (Ionic 4.17.10/4.17.11)', () {
    Future<List<PlanField>? Function()> pumpBeamer(
      WidgetTester tester,
      List<PlanField> fields, {
      BeamerFile? Function(PlanField)? fileOf,
    }) async {
      List<PlanField>? emitted;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanFieldsEditor(
              fields: fields,
              startTime: '18:00',
              onChanged: (f) => emitted = f,
              beamerFileOf: fileOf,
            ),
          ),
        ),
      ));
      return () => emitted;
    }

    testWidgets('no status line when the Beamer feature is off', (tester) async {
      await pumpBeamer(tester, const [PlanField(id: 'a', name: 'Gemeindelied', time: '5')]);
      expect(find.text('Beamer-Datei fehlt'), findsNothing);
    });

    testWidgets('status line shows the file or "Beamer-Datei fehlt"', (tester) async {
      await pumpBeamer(
        tester,
        const [
          PlanField(id: 'a', name: 'Gemeindelied', time: '5'),
          PlanField(id: '7', name: 'Werk', time: '5', songId: 7),
          PlanField(id: 'c', name: 'Predigt', time: '30'),
        ],
        fileOf: (f) => f.songId == 7 ? const BeamerFile(name: 'werk.sng', path: 'p') : null,
      );
      expect(find.text('Beamer-Datei fehlt'), findsOneWidget);
      expect(find.text('werk.sng'), findsOneWidget);
      expect(find.byKey(const ValueKey('beamer-status-c')), findsNothing);
    });

    testWidgets('edit dialog switches "Beamer-Datei nötig" off by hand', (tester) async {
      final emitted = await pumpBeamer(
        tester,
        const [PlanField(id: 'a', name: 'Gemeindelied', time: '5')],
        fileOf: (_) => null,
      );
      await tester.tap(find.text('Gemeindelied'));
      await tester.pumpAndSettle();
      expect(find.text('Beamer-Datei nötig'), findsOneWidget);
      expect(find.text('Automatisch an: Titel enthält „Lied“'), findsOneWidget);
      expect(find.text('Noch keine Datei verknüpft'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan-field-beamer-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Datei verknüpft'), findsNothing);

      await tester.tap(find.text('UPDATEN'));
      await tester.pumpAndSettle();
      expect(emitted()?.single.needsBeamer, isFalse);
    });

    testWidgets('edit dialog has no Beamer section when the feature is off', (tester) async {
      await pumpBeamer(tester, const [PlanField(id: 'a', name: 'Gemeindelied', time: '5', needsBeamer: true)]);
      await tester.tap(find.text('Gemeindelied'));
      await tester.pumpAndSettle();
      expect(find.text('Beamer-Datei nötig'), findsNothing);
    });
  });
}
