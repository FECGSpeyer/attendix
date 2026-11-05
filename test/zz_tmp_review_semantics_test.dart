import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/event_list/excuse_reason_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, RegistrationField field, dynamic existing) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (ctx) => TextButton(
        onPressed: () => showRegistrationFieldAlert(ctx, field: field, existing: existing),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('single select', (tester) async {
    final h = tester.ensureSemantics();
    await _open(tester, const RegistrationField(id: 'f', label: 'Essen', type: RegistrationFieldType.select, options: ['A', 'B']), 'A');
    // ignore: avoid_print
    print(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!.toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder));
    expect(find.bySemanticsLabel('A'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('B'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print(tester.getSemantics(find.bySemanticsLabel('B')));
    h.dispose();
  });
  testWidgets('multi select', (tester) async {
    final h = tester.ensureSemantics();
    await _open(tester, const RegistrationField(id: 'f', label: 'Essen', type: RegistrationFieldType.multiSelect, options: ['A', 'B']), ['B']);
    // ignore: avoid_print
    print(tester.getSemantics(find.bySemanticsLabel('A')));
    // ignore: avoid_print
    print(tester.getSemantics(find.bySemanticsLabel('B')));
    h.dispose();
  });
}
