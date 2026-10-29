// SOL_FIX25 item 1: a shell tab switch (`context.go`) never drops pending
// edits of the Ablaufplan editor: MainShell awaits the page's leave guard,
// and a dispose without the close flow still writes the pending edits.
import 'dart:async';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/branding_providers.dart';
import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/optional_tabs_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/plan_repository.dart';
import 'package:attendix/features/planning/presentation/pages/planning_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:attendix/shared/widgets/layout/route_leave_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

/// Delayed fake of the `attendance` row (see SOL_FIX24 test).
class _FakeDb {
  _FakeDb(this.row);

  PlanAttendance row;
  final calls = <Map<String, dynamic>>[];
  final _gates = <Completer<bool>>[];
  bool hold = false;

  int get waiting => _gates.length;

  void release({bool fail = false}) => _gates.removeAt(0).complete(fail);

  Future<PlanAttendance> update(int id, Map<String, dynamic> update) async {
    calls.add(update);
    var fail = false;
    if (hold) {
      final gate = Completer<bool>();
      _gates.add(gate);
      fail = await gate.future;
    }
    if (fail) throw Exception('network down');
    row = PlanAttendance.fromJson({...row.toJson(), ...update});
    return row;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('RouteLeaveGuardRegistry', () {
    test('no guard: leave', () async {
      expect(await RouteLeaveGuardRegistry().canLeave(), isTrue);
    });

    test('a guard that says stay (or throws) keeps the page', () async {
      final r = RouteLeaveGuardRegistry();
      Future<bool> stay() async => false;
      r.add(stay);
      expect(await r.canLeave(), isFalse);
      r.remove(stay);
      r.add(() async => throw Exception('x'));
      expect(await r.canLeave(), isFalse);
    });

    test('a second check while one runs says stay (double tap)', () async {
      final r = RouteLeaveGuardRegistry();
      final gate = Completer<bool>();
      r.add(() => gate.future);
      final first = r.canLeave();
      expect(await r.canLeave(), isFalse);
      gate.complete(true);
      expect(await first, isTrue);
    });
  });

  PlanAttendance attendance() => PlanAttendance(
        id: 7,
        tenantId: 1,
        date: DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
        plan: const Plan(
          time: '18:00',
          end: '2026-01-01T18:30',
          title: 'Probe',
          fields: [PlanField(id: 'a', name: 'Einspielen', time: '30')],
        ),
      );

  late _FakeDb db;
  late ProviderContainer container;

  ProviderContainer makeContainer(PlanAttendance att) {
    db = _FakeDb(att);
    final repo = _MockPlanRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer(
      (inv) => db.update(inv.positionalArguments[0] as int, inv.positionalArguments[1] as Map<String, dynamic>),
    );
    final c = createTestContainer(
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
        // MainShell: no Supabase in tests.
        showDashboardTabProvider.overrideWithValue(false),
        showSongsTabProvider.overrideWithValue(false),
        showOrgPlansTabProvider.overrideWithValue(false),
        userTenantsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder titleField(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

  Finder minutesField() =>
      find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);

  Map<String, dynamic> planOf(Map<String, dynamic> update) => update['plan'] as Map<String, dynamic>;

  String minutesOf(Map<String, dynamic> update) =>
      ((planOf(update)['fields'] as List).single as Map<String, dynamic>)['time'] as String;

  const fillRequired = 'Bitte fülle alle erforderlichen Felder aus.';

  group('MainShell tab switch from /planning', () {
    late GoRouter router;

    Future<void> openInShell(WidgetTester tester) async {
      phone(tester);
      container = makeContainer(attendance());
      await container.read(orgPlansProvider.future);
      router = GoRouter(
        initialLocation: '/planning',
        routes: [
          ShellRoute(
            builder: (context, state, child) => MainShell(child: child),
            routes: [
              GoRoute(path: '/people', builder: (_, __) => const Placeholder(key: Key('people'))),
              GoRoute(path: '/attendance', builder: (_, __) => const Placeholder(key: Key('attendance'))),
              GoRoute(path: '/settings', builder: (_, __) => const Placeholder(key: Key('settings'))),
              GoRoute(path: '/planning', builder: (_, __) => const PlanningPage(attendanceId: 7)),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
      expect(titleField('Probe'), findsOneWidget);
    }

    Future<void> tapTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).last);
      await tester.pump();
    }

    testWidgets('waits for the running write and stores the pending edit before switching',
        (tester) async {
      await openInShell(tester);
      db.hold = true;
      await tester.enterText(minutesField(), '15');
      await tester.pump(const Duration(milliseconds: 450));
      expect(db.waiting, 1, reason: 'autosave of 15 is running');
      await tester.enterText(titleField('Probe'), 'Neu');
      await tester.pump();

      await tapTab(tester, 'Personen');
      await tester.pump();
      expect(find.byKey(const Key('people')), findsNothing, reason: 'switch waits for the write');
      expect(titleField('Neu'), findsOneWidget);

      db.release();
      await tester.pump();
      await tester.pump();
      expect(db.waiting, 1, reason: 'pending title is written before leaving');
      db.release();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('people')), findsOneWidget);
      expect(db.calls, hasLength(2));
      expect(planOf(db.calls.last)['title'], 'Neu');
      expect(minutesOf(db.calls.last), '15');
      expect(container.read(routeLeaveGuardRegistryProvider).hasGuards, isFalse,
          reason: 'guard removed on dispose');
    });

    testWidgets('an invalid plan with user edits keeps the page (Ionic validate toast)', (tester) async {
      await openInShell(tester);
      await tester.enterText(minutesField(), '');
      await tester.pumpAndSettle();
      await tapTab(tester, 'Personen');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people')), findsNothing);
      expect(find.text(fillRequired), findsOneWidget);
      expect(db.calls, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(minutesField(), '20');
      await tester.pump();
      await tapTab(tester, 'Personen');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people')), findsOneWidget);
      expect(db.calls, hasLength(1));
      expect(minutesOf(db.calls.single), '20');
    });

    testWidgets('a failed write keeps the page and the edit', (tester) async {
      await openInShell(tester);
      db.hold = true;
      await tester.enterText(titleField('Probe'), 'Neu');
      await tester.pump();
      await tapTab(tester, 'Personen');
      await tester.pump();
      db.release(fail: true);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('people')), findsNothing);
      expect(titleField('Neu'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      db.hold = false;
      await tapTab(tester, 'Personen');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('people')), findsOneWidget);
      expect(planOf(db.calls.last)['title'], 'Neu');
    });

    testWidgets('a direct route change (deep link / browser back) still writes the pending edit',
        (tester) async {
      await openInShell(tester);
      db.hold = true;
      await tester.enterText(minutesField(), '15');
      await tester.pump(const Duration(milliseconds: 450));
      expect(db.waiting, 1);
      await tester.enterText(titleField('Probe'), 'Neu');
      await tester.pump();

      // Bypasses MainShell: the page is disposed with a pending edit.
      router.go('/attendance');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attendance')), findsOneWidget);
      expect(db.calls, hasLength(1), reason: 'the dispose write waits for the running one');

      db.release();
      await tester.pump();
      await tester.pump();
      expect(db.calls, hasLength(2));
      db.release();
      await tester.pump();
      expect(planOf(db.calls.last)['title'], 'Neu');
      expect(minutesOf(db.calls.last), '15');
      expect(planOf(db.row.toJson())['title'], 'Neu');
    });
  });

  testWidgets('dispose without pending edits writes nothing', (tester) async {
    phone(tester);
    container = makeContainer(attendance());
    await container.read(orgPlansProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PlanningPage(attendanceId: 7),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(db.calls, isEmpty);
  });
}
