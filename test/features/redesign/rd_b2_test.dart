// B2 (#414): Verlauf, Abwesenheit für andere, Nicht verfügbar and Gemeinde
// wählen in the Beta design. The old views keep their logic.
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/church/church.dart';
import 'package:attendix/data/models/duty/person_unavailability.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/people/presentation/widgets/church_picker_sheet.dart';
import 'package:attendix/features/people/presentation/widgets/person_detail/person_detail.dart'
    show filterHistoryBySeason, historyWithoutEntry;
import 'package:attendix/features/redesign/presentation/pages/rd_unavailability_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_absence_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  group('Verlauf helpers', () {
    final history = <Map<String, dynamic>>[
      {'date': '2026-10-01', 'type': 4, 'text': 'X'},
      {'date': '2026-07-01', 'type': 4, 'text': 'A'},
      {'date': null, 'type': 1, 'text': ''},
    ];

    test('season filter keeps entries from the season start and undated ones', () {
      final season = DateTime(2026, 9, 1);
      expect(filterHistoryBySeason(history, season, showAll: false).length, 2);
      expect(filterHistoryBySeason(history, season, showAll: true).length, 3);
      expect(filterHistoryBySeason(history, null, showAll: false).length, 3);
    });

    test('historyWithoutEntry removes exactly the matching change', () {
      const a = PlayerHistoryEntry(date: '2026-10-01T10:00:00Z', type: 1, text: 'Urlaub');
      const b = PlayerHistoryEntry(date: '2026-10-01T10:00:00Z', type: 1, text: 'Krank');
      final left = historyWithoutEntry([a, b], {'date': '2026-10-01T10:00:00Z', 'type': 1, 'text': 'Urlaub'});
      expect(left, [b.toJson()]);
    });
  });

  test('Abwesenheit für andere: Termin title like "Kommende Termine"', () {
    expect(
      rdAbsenceTermTitle({
        'typeInfo': 'Generalprobe',
        'attType': {'name': 'Probe'},
      }),
      'Generalprobe',
    );
    expect(
      rdAbsenceTermTitle({
        'typeInfo': null,
        'attType': {'name': 'Probe'},
      }),
      'Probe',
    );
  });

  testWidgets('Gemeinde wählen: Beta sheet with search, "Nicht gelistet" and a check mark', (tester) async {
    String? result = 'unset';
    const churches = [Church(id: 'a', name: 'FECG Speyer'), Church(id: 'b', name: 'Gemeinde Lahr')];
    await tester.pumpWidget(
      _app(
        [redesignEnabledProvider.overrideWithValue(true)],
        Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () async =>
                        result = await showChurchPickerSheet(
                          context,
                          title: 'Gemeinde',
                          churches: churches,
                          selectedId: 'a',
                        ),
                child: const Text('open'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(RdChurchPicker), findsOneWidget);
    expect(find.text('Nicht gelistet'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'lahr');
    await tester.pump();
    expect(find.text('FECG Speyer'), findsNothing);
    await tester.tap(find.text('Gemeinde Lahr'));
    await tester.pumpAndSettle();
    expect(result, 'b');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicht gelistet'));
    await tester.pumpAndSettle();
    expect(result, '');
  });

  testWidgets('Nicht verfügbar: one section per rule, chips, Regel hinzufügen', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app([
        currentTenantIdProvider.overrideWithValue(42),
        attendanceTypesProvider.overrideWith(
          (ref) async => [TestFactories.createAttendanceType(id: 't1', name: 'Gottesdienst')],
        ),
        unavailabilityByPersonProvider(1).overrideWith(
          (ref) async => const [
            PersonUnavailability(id: 'r1', tenantId: 42, personId: 1, weekdays: [3], reason: 'Kinderstunde'),
          ],
        ),
      ], const RdUnavailabilityPage(personId: 1, personName: 'Lea Jäger', forOther: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nicht verfügbar'), findsOneWidget);
    expect(find.textContaining('Lea Jäger wird an diesen Tagen'), findsOneWidget);
    expect(find.text('REGEL 1'), findsOneWidget);
    expect(find.text('Kinderstunde'), findsOneWidget);
    expect(find.text('Unbefristet'), findsOneWidget);
    expect(find.text('Gottesdienst'), findsOneWidget);
    expect(find.text('Regel löschen'), findsOneWidget);

    await tester.tap(find.text('Regel hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('REGEL 2'), findsOneWidget);
    expect(find.text('Regel löschen'), findsNWidgets(2));
  });
}
