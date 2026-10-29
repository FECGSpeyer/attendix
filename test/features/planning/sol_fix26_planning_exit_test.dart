// SOL_FIX26 items 1 + 3: every exit of the Ablaufplan editor refreshes the
// caches after a successful (auto)save, and a write queued on a direct leave
// that fails keeps the edit as a local draft that is restored on reopening.
import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/features/planning/data/planning_write_sync.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

class _MockPlanRepository extends Mock implements PlanRepository {}

/// Delayed fake of the `attendance` row (see SOL_FIX25 test).
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

  late _FakeDb db;
  late ProviderContainer container;
  late GoRouter router;
  var attendanceLoads = 0;
  var orgPlanLoads = 0;

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

  ProviderContainer makeContainer(PlanAttendance att) {
    db = _FakeDb(att);
    attendanceLoads = 0;
    orgPlanLoads = 0;
    final repo = _MockPlanRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer(
      (inv) => db.update(inv.positionalArguments[0] as int, inv.positionalArguments[1] as Map<String, dynamic>),
    );
    final c = createTestContainer(
      tenant: TestFactories.createTenant(id: 1),
      overrides: [
        planRepositoryWithTenantProvider.overrideWithValue(repo),
        // The stored row as of the (re)load.
        planAttendancesProvider.overrideWith((ref) async {
          attendanceLoads++;
          return [db.row];
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
        showDashboardTabProvider.overrideWithValue(false),
        showSongsTabProvider.overrideWithValue(false),
        showOrgPlansTabProvider.overrideWithValue(false),
        userTenantsProvider.overrideWith((ref) async => const []),
        currentAuthUserIdProvider.overrideWith((ref) => 'u1'), // SOL_FIX27
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Finder titleField(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

  Finder minutesField() =>
      find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);

  Map<String, dynamic> planOf(Map<String, dynamic> update) => update['plan'] as Map<String, dynamic>;

  Future<void> openInShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  Future<List<String>> draftKeys() async =>
      (await SharedPreferences.getInstance()).getKeys().where((k) => k.startsWith('planning_draft_')).toList();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlanningWriteSync.reset();
  });

  testWidgets('item 1: a direct route change after a finished autosave refreshes the caches', (tester) async {
    await openInShell(tester);
    expect(attendanceLoads, 1);
    expect(orgPlanLoads, 1);

    await tester.enterText(minutesField(), '15');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(db.calls, hasLength(1), reason: 'autosave finished, nothing pending');

    // Deep link / browser back: bypasses the shell guard, page is disposed.
    router.go('/attendance');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance')), findsOneWidget);
    expect(db.calls, hasLength(1), reason: 'no pending edit, no further write');

    await container.read(orgPlansProvider.future);
    expect(orgPlanLoads, 2, reason: 'org plans invalidated');

    router.go('/planning');
    await tester.pumpAndSettle();
    expect(attendanceLoads, 2, reason: 'Termine reloaded');
    expect(tester.widget<TextField>(minutesField()).controller!.text, '15', reason: 'no stale plan');
  });

  testWidgets('item 1: no write, no invalidation', (tester) async {
    await openInShell(tester);
    router.go('/attendance');
    await tester.pumpAndSettle();
    router.go('/planning');
    await tester.pumpAndSettle();
    expect(attendanceLoads, 1);
  });

  testWidgets('item 3: a failed write on direct leave keeps a draft that is restored and saved',
      (tester) async {
    await openInShell(tester);
    db.hold = true;
    await tester.enterText(titleField('Probe'), 'Neu');
    await tester.pump();

    router.go('/attendance');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance')), findsOneWidget);
    expect(db.waiting, 1, reason: 'a write is running');
    expect(await draftKeys(), ['planning_draft_u1_1_7_i0'], reason: 'draft kept before the write');

    // Every queued write fails (the title's focus-loss autosave, if it
    // started, and the write queued by dispose).
    while (db.waiting > 0) {
      db.release(fail: true);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ablaufplan konnte nicht gespeichert werden – Entwurf lokal gesichert'), findsOneWidget);
    expect(await draftKeys(), hasLength(1), reason: 'draft stays after the failure');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Reopen: the draft differs from the stored plan → restored as dirty.
    db.hold = false;
    router.go('/planning');
    await tester.pumpAndSettle();
    expect(titleField('Neu'), findsOneWidget);
    expect(find.text('Nicht gespeicherte Änderungen wiederhergestellt'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(planOf(db.calls.last)['title'], 'Neu', reason: 'autosaved');
    expect(planOf(db.row.toJson())['title'], 'Neu');
    expect(await draftKeys(), isEmpty, reason: 'removed once stored');
    await tester.pump(const Duration(seconds: 5));
    // Leaving again refreshes the caches (written page).
    router.go('/attendance');
    await tester.pumpAndSettle();
    expect(attendanceLoads, 1);
    router.go('/planning');
    await tester.pumpAndSettle();
    expect(attendanceLoads, 2);
    expect(titleField('Neu'), findsOneWidget);
  });

  testWidgets('item 3: a successful write on direct leave removes the draft', (tester) async {
    await openInShell(tester);
    await tester.enterText(titleField('Probe'), 'Neu');
    await tester.pump();
    router.go('/attendance');
    await tester.pumpAndSettle();
    expect(planOf(db.calls.single)['title'], 'Neu');
    expect(await draftKeys(), isEmpty);

    router.go('/planning');
    await tester.pumpAndSettle();
    expect(titleField('Neu'), findsOneWidget, reason: 'caches refreshed after the dispose write');
    expect(find.text('Nicht gespeicherte Änderungen wiederhergestellt'), findsNothing);
  });

  testWidgets('item 3: a draft equal to the stored plan is dropped silently', (tester) async {
    SharedPreferences.setMockInitialValues({
      'planning_draft_u1_1_7_i0':
          '{"time":"18:00","title":"Probe","fields":[{"id":"a","name":"Einspielen","time":"30"}]}',
    });
    await openInShell(tester);
    await tester.pumpAndSettle();
    expect(find.text('Nicht gespeicherte Änderungen wiederhergestellt'), findsNothing);
    expect(await draftKeys(), isEmpty);
    expect(db.calls, isEmpty);
  });

  testWidgets('item 3: drafts are tenant-scoped', (tester) async {
    SharedPreferences.setMockInitialValues({
      'planning_draft_u1_2_7_i0': '{"time":"18:00","title":"Fremd","fields":[]}',
    });
    await openInShell(tester);
    await tester.pumpAndSettle();
    expect(titleField('Probe'), findsOneWidget);
    expect(db.calls, isEmpty);
  });
}
