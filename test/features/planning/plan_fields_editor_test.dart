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
}
