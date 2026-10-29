import 'dart:async';
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/branding_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
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

/// Delayed fake of the `attendance` row: every write waits for [release]
/// while [hold] is set and applies the update like the database would.
class _FakeDb {
  _FakeDb(this.row);

  PlanAttendance row;
  final calls = <Map<String, dynamic>>[];
  final _gates = <Completer<bool>>[];
  bool hold = false;
  bool failNext = false;

  int get waiting => _gates.length;

  /// Lets the oldest waiting write finish ([fail]: with an error).
  void release({bool fail = false}) => _gates.removeAt(0).complete(fail);

  Future<PlanAttendance> update(int id, Map<String, dynamic> update) async {
    calls.add(update);
    var fail = false;
    if (hold) {
      final gate = Completer<bool>();
      _gates.add(gate);
      fail = await gate.future;
    } else if (failNext) {
      failNext = false;
      fail = true;
    }
    if (fail) throw Exception('network down');
    row = PlanAttendance.fromJson({...row.toJson(), ...update});
    return row;
  }
}

/// SOL_FIX24: invalid edits block leaving the plan (no silent loss), and
/// multi-step plan operations block the editor while they write and reload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  PlanAttendance attendance({bool withPlan = true, List<Plan>? extra}) => PlanAttendance(
        id: 7,
        tenantId: 1,
        date: DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
        plan: withPlan
            ? const Plan(
                time: '18:00',
                end: '2026-01-01T18:30',
                title: 'Probe',
                fields: [PlanField(id: 'a', name: 'Einspielen', time: '30')],
              )
            : null,
        extraPlans: extra,
      );

  const secondPlan = Plan(
    id: 'p2',
    time: '20:00',
    title: 'Zweiter',
    fields: [PlanField(id: 'b', name: 'Stück B', time: '5')],
  );

  late _MockPlanRepository repo;
  late _FakeDb db;
  late ProviderContainer container;
  var popped = false;

  Future<void> openPage(WidgetTester tester, PlanAttendance att) async {
    db = _FakeDb(att);
    popped = false;
    repo = _MockPlanRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer(
      (inv) => db.update(inv.positionalArguments[0] as int, inv.positionalArguments[1] as Map<String, dynamic>),
    );
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = createTestContainer(
      tenant: TestFactories.createTenant(id: 1),
      overrides: [
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
    await container.read(orgPlansProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => PlanningPage(attendanceId: att.id)))
                  .then((_) => popped = true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder titleField(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

  Future<void> setTitle(WidgetTester tester, String from, String to) async {
    await tester.enterText(titleField(from), to);
    await tester.pump();
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
  }

  /// Lets the error toast run out so no timer is left at the end.
  Future<void> dismissToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> planOf(Map<String, dynamic> update) => update['plan'] as Map<String, dynamic>;

  Finder minutesField() =>
      find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);

  /// Dialog button (Material dialogs show their labels upper case).
  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is Text && (w.data == label || w.data == label.toUpperCase()));

  Finder busyOverlay() => find.byKey(const ValueKey('planning-busy'));

  const fillRequired = 'Bitte fülle alle erforderlichen Felder aus.';

  group('item 1: invalid edits block switch and close', () {
    testWidgets('cleared minutes keep the page open with the Ionic toast; fixed minutes are saved',
        (tester) async {
      await openPage(tester, attendance());
      await tester.enterText(minutesField(), '');
      await tester.pumpAndSettle();
      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(find.text(fillRequired), findsOneWidget);
      expect(popped, isFalse);
      expect(db.calls, isEmpty, reason: 'an invalid plan is never stored (Ionic validate)');
      await dismissToasts(tester);

      await tester.enterText(minutesField(), '15');
      await tester.pump();
      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(db.calls, hasLength(1));
      expect(((planOf(db.calls.single)['fields'] as List).single as Map)['time'], '15');
    });

    testWidgets('cleared minutes keep the open plan on a plan switch', (tester) async {
      await openPage(tester, attendance(extra: const [secondPlan]));
      await tester.enterText(minutesField(), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan 2'));
      await tester.pumpAndSettle();
      expect(find.text(fillRequired), findsOneWidget);
      expect(titleField('Probe'), findsOneWidget);
      expect(titleField('Zweiter'), findsNothing);
      expect(db.calls, isEmpty);
      await dismissToasts(tester);
    });
  });

  group('item 2: multi-step plan operations block the page', () {
    Future<void> tryToEdit(WidgetTester tester, String title) async {
      await tester.tap(titleField(title), warnIfMissed: false);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isFalse, reason: 'no field can be focused while busy');
      await tester.tap(minutesField().first, warnIfMissed: false);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isFalse);
      await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
      await tester.pump();
      await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
      await tester.pump();
      expect(popped, isFalse, reason: 'no close while busy');
    }

    testWidgets('add plan (copy): blocked while writing, then the new plan is open', (tester) async {
      await openPage(tester, attendance());
      db.hold = true;
      await tester.tap(find.byTooltip('Feld hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiteren Ablaufplan anlegen'));
      await tester.pumpAndSettle();
      await tester.tap(button('Kopie'));
      await tester.pump();
      await tester.pump();
      expect(db.waiting, 1);
      expect(busyOverlay(), findsOneWidget);
      await tryToEdit(tester, 'Probe');

      db.release();
      await tester.pumpAndSettle();
      expect(busyOverlay(), findsNothing);
      expect(find.text('Plan 2'), findsOneWidget);
      expect(db.calls, hasLength(1));
      expect(db.calls.single['extra_plans'] as List, hasLength(1));

      // The copy is open: an edit after the write lands in the new plan.
      db.hold = false;
      await setTitle(tester, 'Probe', 'Kopie neu');
      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(db.calls, hasLength(2));
      expect(planOf(db.calls.last)['title'], 'Probe');
      expect(((db.calls.last['extra_plans'] as List).single as Map)['title'], 'Kopie neu');
    });

    testWidgets('delete plan: blocked while writing, then the remaining plan is open', (tester) async {
      await openPage(tester, attendance(extra: const [secondPlan]));
      db.hold = true;
      await tester.tap(find.byTooltip('Plan-Optionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan löschen'));
      await tester.pumpAndSettle();
      await tester.tap(button('Löschen'));
      await tester.pump();
      await tester.pump();
      expect(db.waiting, 1);
      expect(busyOverlay(), findsOneWidget);
      await tryToEdit(tester, 'Probe');

      db.release();
      await tester.pumpAndSettle();
      expect(busyOverlay(), findsNothing);
      expect(titleField('Zweiter'), findsOneWidget);
      expect(db.calls, hasLength(1));

      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(db.calls, hasLength(1), reason: 'the loaded plan holds no pending change');
    });
  });

  group('source', () {
    test('every multi-plan write runs while the page is blocked', () {
      final src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
      // SOL_FIX29: the plan list operations write via `_writePlanOp`.
      final calls = RegExp(r'await _writePlanOp\(attId, ').allMatches(src).toList();
      expect(calls, hasLength(5), reason: 'add, rename, day, move, delete');
      for (final m in calls) {
        final before = src.substring(m.start - 200, m.start);
        expect(before, contains('_whileBusy('), reason: src.substring(m.start, m.start + 40));
      }
    });
  });
}
