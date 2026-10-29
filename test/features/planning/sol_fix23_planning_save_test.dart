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

/// SOL_FIX23: serialised writes of the Ablaufplan editor, no lost changes
/// on failed writes, and cache invalidation after every successful write.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  const errorToast = 'Fehler beim updaten der Anwesenheit';

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
  late int attendanceLoads;
  late int orgPlanLoads;
  late ProviderContainer container;
  bool? popResult;
  var popped = false;

  Future<void> openPage(WidgetTester tester, PlanAttendance att) async {
    db = _FakeDb(att);
    attendanceLoads = 0;
    orgPlanLoads = 0;
    popResult = null;
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
        planAttendancesProvider.overrideWith((ref) async {
          attendanceLoads++;
          return [att];
        }),
        orgPlansProvider.overrideWith((ref) async {
          orgPlanLoads++;
          return const [];
        }),
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
                  .then((v) {
                popped = true;
                popResult = v;
              }),
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

  group('item 1: writes are serialised', () {
    testWidgets('close waits for the running write and stores edits made meanwhile', (tester) async {
      await openPage(tester, attendance());
      db.hold = true;
      await setTitle(tester, 'Probe', 'A');
      await tapClose(tester);
      expect(db.calls, hasLength(1));
      expect(db.waiting, 1);

      // Edit while the write runs: dirty / baseline must not be reset yet.
      await setTitle(tester, 'A', 'B');
      db.release();
      await tester.pump();
      await tester.pump();
      expect(popped, isFalse, reason: 'close waits for the second write');
      expect(db.calls, hasLength(2));

      db.release();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(planOf(db.calls[0])['title'], 'A');
      expect(planOf(db.calls[1])['title'], 'B');
      expect(db.row.plan?.title, 'B');
    });

    testWidgets('plan switch waits for the running write; extra_plans come from the persisted row',
        (tester) async {
      await openPage(tester, attendance(extra: const [secondPlan]));
      db.hold = true;
      await setTitle(tester, 'Probe', 'Erster');
      await tester.tap(find.text('Plan 2'));
      await tester.pump();
      expect(db.calls, hasLength(1));
      // Still the first plan while its write runs.
      expect(titleField('Erster'), findsOneWidget);
      expect(titleField('Zweiter'), findsNothing);

      db.release();
      await tester.pumpAndSettle();
      expect(titleField('Zweiter'), findsOneWidget);
      expect(planOf(db.calls[0])['title'], 'Erster');
      expect(((db.calls[0]['extra_plans'] as List).single as Map)['title'], 'Zweiter');

      await setTitle(tester, 'Zweiter', 'Zweiter neu');
      await tapClose(tester);
      db.release();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(db.calls, hasLength(2));
      // First plan from the stored row (with its new title), second edited.
      expect(planOf(db.calls[1])['title'], 'Erster');
      expect(((db.calls[1]['extra_plans'] as List).single as Map)['title'], 'Zweiter neu');
    });
  });

  group('item 2: failed writes block switch and close', () {
    testWidgets('close stays open with the Ionic toast and the edit; retry closes', (tester) async {
      await openPage(tester, attendance());
      db.failNext = true;
      await setTitle(tester, 'Probe', 'X');
      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(find.text(errorToast), findsOneWidget);
      expect(popped, isFalse);
      expect(titleField('X'), findsOneWidget);
      await dismissToasts(tester);

      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(db.calls, hasLength(2));
      expect(planOf(db.calls.last)['title'], 'X');
    });

    testWidgets('plan switch stays on the plan when its write fails', (tester) async {
      await openPage(tester, attendance(extra: const [secondPlan]));
      db.failNext = true;
      await setTitle(tester, 'Probe', 'Erster');
      await tester.tap(find.text('Plan 2'));
      await tester.pumpAndSettle();
      expect(find.text(errorToast), findsOneWidget);
      expect(titleField('Erster'), findsOneWidget);
      expect(titleField('Zweiter'), findsNothing);
      await dismissToasts(tester);

      await tester.tap(find.text('Plan 2'));
      await tester.pumpAndSettle();
      expect(titleField('Zweiter'), findsOneWidget);
      expect(db.calls, hasLength(2));
      expect(planOf(db.calls.last)['title'], 'Erster');
    });
  });

  group('item 3: successful writes count as changes', () {
    testWidgets('auto-created default plan invalidates the plan caches on close', (tester) async {
      await openPage(tester, attendance(withPlan: false));
      expect(attendanceLoads, 1);
      expect(orgPlanLoads, 1);
      await tapClose(tester);
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(popResult, isTrue);
      expect(db.calls, hasLength(1));
      expect(db.calls.single.containsKey('plan'), isTrue);
      await container.read(planAttendancesProvider.future);
      await container.read(orgPlansProvider.future);
      expect(attendanceLoads, 2);
      expect(orgPlanLoads, 2);
    });
  });

  group('source', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
    });

    test('dirty and title baseline are reset only after a successful write', () {
      final body = RegExp(r'Future<bool> _writeOpenPlan\(\) async \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      final write = body.indexOf('updateAttendancePlanFields');
      expect(body.indexOf('_dirty = false'), greaterThan(write));
      expect(body.indexOf('_savedTitle = title'), greaterThan(write));
      expect(body, contains('if (editGen == _editGen) _dirty = false;'));
      expect(body.indexOf('_hasChanges = true'), greaterThan(write));
    });

    test('all attendance writes of the editor go through the chain', () {
      // SOL_FIX25: + the write of pending edits queued by dispose().
      expect(RegExp(r'updateAttendancePlanFields\(').allMatches(src), hasLength(4));
      expect(RegExp(r'_serialised\(').allMatches(src), hasLength(4));
    });
  });
}
