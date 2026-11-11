// REDESIGN: the Beta Ablauf editor uses the classic editor's saving; the
// inline duration field (presets) and "Löschen" with "Rückgängig" store the
// plan like every other edit. Blocks: the "+ Punkt in „…“" row ends a block
// (dropped above it = inside, below = behind it) and adds several items.
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

  group('blocks', () {
    final withBlock = _att.copyWith(
      plan: const Plan(
        time: '16:00',
        end: '2026-01-01T17:00',
        title: 'Konzert',
        fields: [
          PlanField(id: 'a', name: 'Begrüßung', time: '5'),
          PlanField(id: 'g', name: 'Programm', time: '0', isGroup: true),
          PlanField(id: 'g1', name: 'Lied', time: '10', groupId: 'g'),
          PlanField(id: 'g2', name: 'Chor', time: '10', groupId: 'g'),
          PlanField(id: 'c', name: 'Schlusslied', time: '5'),
        ],
      ),
    );

    List<String> stored() => [
      for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List))
        '${(f as Map<String, dynamic>)['id']}${f['groupId'] == null ? '' : '>${f['groupId']}'}',
    ];

    /// Drags the row of field [index] by its grip so the card's top edge
    /// ends 2 px below [targetTop].
    Future<void> dragTo(WidgetTester tester, int index, double targetTop) async {
      final row = find.byKey(ValueKey('rd-plan-row-$index'));
      final grip = find.descendant(of: row, matching: find.byType(ReorderableDragStartListener));
      final from = tester.getCenter(grip);
      final grab = from.dy - tester.getTopLeft(row).dy;
      final gesture = await tester.startGesture(from);
      await tester.pump();
      final to = targetTop + 2 + grab;
      for (var i = 1; i <= 8; i++) {
        await gesture.moveTo(Offset(from.dx, from.dy + (to - from.dy) * i / 8));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }

    testWidgets('below the "+ Punkt in" row is behind the block, above it is inside', (tester) async {
      await pump(tester, attendance: withBlock);
      expect(find.text('Punkt in „Programm“'), findsOneWidget);
      // The last Unterpunkt dragged down past the block's end (its gap opens
      // below the "+ Punkt in" row): it leaves the block.
      await dragTo(tester, 3, tester.getTopLeft(find.byKey(const ValueKey('rd-plan-block-add-g'))).dy);
      expect(stored(), ['a', 'g', 'g1>g', 'g2', 'c']);
      // Schlusslied up to right above the end row: it joins the block.
      final end = tester.getTopLeft(find.byKey(const ValueKey('rd-plan-block-add-g'))).dy;
      await dragTo(tester, 4, end);
      expect(stored(), ['a', 'g', 'g1>g', 'c>g', 'g2']);
      await close(tester);
    });

    testWidgets('"+ Punkt in" adds several items to the end of the block', (tester) async {
      await pump(tester, attendance: withBlock);
      await tester.tap(find.byKey(const ValueKey('rd-plan-block-add-g')));
      await tester.pumpAndSettle();
      expect(find.text('In „Programm“'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('rd-plan-field-name')), 'Solo');
      await tester.tap(find.byKey(const Key('rd-plan-quick-add')));
      await tester.pumpAndSettle();
      // Enter adds too; the sheet stays open for the next one.
      await tester.enterText(find.byKey(const Key('rd-plan-field-name')), 'Duett');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rd-plan-quick-added-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('rd-plan-quick-done')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final ids = stored();
      expect(ids.length, 7);
      expect(ids.take(4), ['a', 'g', 'g1>g', 'g2>g']);
      expect(ids.last, 'c');
      final names = [
        for (final f in ((calls.last['plan'] as Map<String, dynamic>)['fields'] as List))
          (f as Map<String, dynamic>)['name'],
      ];
      expect(names.sublist(4, 6), ['Solo', 'Duett']);
      expect(ids[4].endsWith('>g') && ids[5].endsWith('>g'), isTrue);
      await close(tester);
    });

    testWidgets('"Block" in the item sheet moves the item into a block', (tester) async {
      await pump(tester, attendance: withBlock);
      await tester.tap(find.text('Begrüßung'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rd-plan-item-block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rd-plan-pick-block-g')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(stored(), ['g', 'g1>g', 'g2>g', 'a>g', 'c']);
      await close(tester);
    });
  });
}
