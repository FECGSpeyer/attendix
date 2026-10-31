import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/statistics_providers.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/statistics/presentation/widgets/field_stats_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ionic 4.17.17 stats "🧩 Zusatzfelder" section.
void main() {
  Widget app(List<ExtraField> fields, List<Person> persons) => ProviderScope(
        overrides: [
          personListExtraFieldsProvider.overrideWithValue(fields),
          fieldStatsPersonsProvider.overrideWith((ref) async => persons),
          groupsProvider.overrideWith((ref) async => const [
                Group(id: 1, name: 'Sopran'),
                Group(id: 2, name: 'Alt'),
              ]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FieldStatsSection(header: Text('🧩 Zusatzfelder')),
            ),
          ),
        ),
      );

  testWidgets('hidden without select / yes-no / church fields',
      (tester) async {
    await tester.pumpWidget(app(
      const [ExtraField(id: 't', name: 'Notiz', type: 'text')],
      const [],
    ));
    await tester.pumpAndSettle();
    expect(find.text('🧩 Zusatzfelder'), findsNothing);
  });

  testWidgets('shows the distribution and the per-group bars',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(
      const [
        ExtraField(
            id: 'shirt',
            name: 'T-Shirt',
            type: 'select',
            options: ['S', 'M']),
      ],
      const [
        Person(firstName: 'A', lastName: 'A', instrument: 1,
            additionalFields: {'shirt': 'S'}),
        Person(firstName: 'B', lastName: 'B', instrument: 2,
            additionalFields: {'shirt': 'M'}),
        Person(firstName: 'C', lastName: 'C', instrument: 2,
            additionalFields: {}),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('🧩 Zusatzfelder'), findsOneWidget);
    expect(find.text('Gesamt'), findsOneWidget);
    // S: 1 (33 %), M: 1 + default S → S 2 (67 %), M 1 (33 %)
    expect(find.text('67%'), findsWidgets);
    expect(find.text('Sopran (1)'), findsOneWidget);
    expect(find.text('Alt (2)'), findsOneWidget);
  });
}
