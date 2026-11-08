// REDESIGN: the Beta Ablauf editor uses the classic editor's saving; the
// inline duration field (presets) and "Löschen" with "Rückgängig" store the
// plan like every other edit.
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/branding_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/plan_repository.dart';
import 'package:attendix/features/planning/presentation/pages/planning_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  final _att = PlanAttendance(
    id: 7,
    tenantId: 1,
    date: DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
    plan: const Plan(
      time: '16:00',
      end: '2026-01-01T17:00',
      title: 'Konzert',
      fields: [
        PlanField(id: 'a', name: 'Begrüßung', time: '5'),
        PlanField(id: 'b', name: 'Predigt', time: '20'),
        PlanField(id: 'c', name: 'Schlusslied', time: '5'),
      ],
    ),
  );

  late List<Map<String, dynamic>> calls;

  Future<void> pump(WidgetTester tester, {PlanAttendance? attendance}) async {
    final att = attendance ?? _att;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    calls = [];
    var row = att;
    final repo = _MockPlanRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer((inv) async {
      final update = inv.positionalArguments[1] as Map<String, dynamic>;
      calls.add(update);
      row = PlanAttendance.fromJson({...row.toJson(), ...update});
      return row;
    });
    final container = createTestContainer(
      tenant: TestFactories.createTenant(id: 1),
      overrides: [
        redesignEnabledProvider.overrideWithValue(true),
        planRepositoryWithTenantProvider.overrideWithValue(repo),
        planAttendancesProvider.overrideWith((ref) async => [att]),
        orgPlansProvider.overrideWith((ref) async => const []),
        planAttendanceTypesProvider.overrideWith((ref) async => const []),
        planBlockTemplatesProvider.overrideWith((ref) async => const []),
        planSongsProvider.overrideWith((ref) async => const []),
        currentSongsProvider.overrideWith((ref) async => const []),
        groupsProvider.overrideWith((ref) async => const []),
        groupCategoriesProvider.overrideWith((ref) async => const []),
        protocolTypesProvider.overrideWith((ref) async => const []),
        currentOrganisationProvider.overrideWith((ref) async => null),
        hasBrandingProvider.overrideWithValue(false),
        effectiveRoleProvider.overrideWithValue(Role.admin),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlanningPage(attendanceId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The editor refreshes the caches after its last write on dispose.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<String> storedMinutes() => [
    for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List))
      (f as Map<String, dynamic>)['time'] as String,
  ];

  testWidgets('a preset changes the duration and the times below', (tester) async {
    await pump(tester);
    expect(find.text('Ablauf'), findsOneWidget);
    expect(find.text('16:25'), findsOneWidget); // Schlusslied
    await tester.tap(find.byKey(const ValueKey('rd-plan-dur-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rd-plan-preset-40')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(storedMinutes(), ['5', '40', '5']);
    expect(find.text('16:45'), findsOneWidget);
    expect(find.text('Gespeichert'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Löschen stores the plan; Rückgängig brings the item back', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Predigt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-plan-item-delete')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(storedMinutes(), ['5', '5']);
    expect(find.text('Predigt'), findsNothing);
    await tester.tap(find.text('Rückgängig'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(storedMinutes(), ['5', '20', '5']);
    expect(find.text('Predigt'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a dragged block takes its Unterpunkte along as one card', (tester) async {
    final withBlock = _att.copyWith(
      plan: const Plan(
        time: '16:00',
        end: '2026-01-01T17:00',
        title: 'Konzert',
        fields: [
          PlanField(id: 'a', name: 'Begrüßung', time: '5'),
          PlanField(id: 'g', name: 'Programm', time: '0', isGroup: true),
          PlanField(id: 'g1', name: 'Lied', time: '10', groupId: 'g'),
          PlanField(id: 'c', name: 'Schlusslied', time: '5'),
        ],
      ),
    );
    await pump(tester, attendance: withBlock);
    final grip = find.byType(ReorderableDragStartListener).at(1); // Programm
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pumpAndSettle();
    // The Unterpunkt folded into the head while it moves.
    expect(find.text('Lied'), findsNothing);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final stored = [
      for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List))
        (f as Map<String, dynamic>)['id'] as String,
    ];
    expect(stored, ['a', 'c', 'g', 'g1']);
    expect(find.text('Lied'), findsOneWidget);
    await close(tester);
  });
}
