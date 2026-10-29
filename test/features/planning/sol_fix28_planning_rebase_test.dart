// SOL_FIX28 items 1 + 2: every write of the Ablaufplan editor builds on the
// newest stored row of the Termin (it replaces only the plan it edited), and
// "Entwurf lokal gesichert" is only shown for a confirmed local draft.
import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
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
import 'package:attendix/core/services/planning_draft_store.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/plan_repository.dart';
import 'package:attendix/features/planning/data/planning_write_sync.dart';
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

class _MockPrefs extends Mock implements SharedPreferences {}

/// Delayed fake of the `attendance` row (see SOL_FIX26 test).
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

/// Signed-in account of the test (null = signed out).
final _userProvider = StateProvider<String?>((ref) => 'u1');

const _keptToast = 'Ablaufplan konnte nicht gespeichert werden – Entwurf lokal gesichert';
const _lostToast = 'Ablaufplan konnte nicht gespeichert werden – Änderungen gehen verloren';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDb db;
  late ProviderContainer container;
  late GoRouter router;

  PlanAttendance attendance({bool twoPlans = false}) => PlanAttendance(
        id: 7,
        tenantId: 1,
        date: DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
        plan: Plan(
          id: twoPlans ? 'p1' : null,
          time: '18:00',
          end: '2026-01-01T18:30',
          title: twoPlans ? 'Eins' : 'Probe',
          fields: const [PlanField(id: 'a', name: 'Einspielen', time: '30')],
        ),
        extraPlans: twoPlans
            ? const [
                Plan(
                  id: 'p2',
                  time: '20:00',
                  end: '2026-01-01T20:30',
                  title: 'Zwei',
                  fields: [PlanField(id: 'b', name: 'Konzert', time: '30')],
                ),
              ]
            : null,
      );

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
        planAttendancesProvider.overrideWith((ref) async => [db.row]),
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
        showDashboardTabProvider.overrideWithValue(false),
        showSongsTabProvider.overrideWithValue(false),
        showOrgPlansTabProvider.overrideWithValue(false),
        userTenantsProvider.overrideWith((ref) async => const []),
        currentAuthUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Finder titleField(String text) =>
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  Future<void> openInShell(WidgetTester tester, {bool twoPlans = false}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = makeContainer(attendance(twoPlans: twoPlans));
    router = GoRouter(
      initialLocation: '/planning',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/attendance', builder: (_, __) => const Placeholder(key: Key('attendance'))),
            GoRoute(path: '/planning', builder: (_, __) => const PlanningPage(attendanceId: 7)),
            GoRoute(
                path: '/planning2', builder: (_, __) => const PlanningPage(attendanceId: 7, initialPlanIndex: 1)),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(tester);
    expect(titleField(twoPlans ? 'Eins' : 'Probe'), findsOneWidget);
  }

  Future<List<String>> draftKeys() async =>
      (await SharedPreferences.getInstance()).getKeys().where((k) => k.startsWith('planning_draft_')).toList();

  /// Releases every held write (in arrival order) until none is left.
  Future<void> releaseAll(WidgetTester tester, {bool fail = false}) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      await tester.pump();
      if (db.waiting == 0) continue;
      db.release(fail: fail);
    }
    await tester.pump();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlanningWriteSync.reset();
  });

  tearDown(() => PlanningDraftStore.preferences = SharedPreferences.getInstance);

  /// Title of plan 1 (`plan`) and plan 2 (`extra_plans[0]`) of the stored row.
  List<String?> storedTitles() {
    final json = db.row.toJson();
    final extra = json['extra_plans'] as List?;
    return [
      (json['plan'] as Map?)?['title'] as String?,
      extra == null || extra.isEmpty ? null : (extra.first as Map)['title'] as String?,
    ];
  }

  /// Preferences whose `setString` returns false ([throws]: throws).
  SharedPreferences failingPrefs({required bool throws}) {
    final prefs = _MockPrefs();
    when(() => prefs.getString(any())).thenReturn(null);
    when(() => prefs.getKeys()).thenReturn(<String>{});
    when(() => prefs.remove(any())).thenAnswer((_) async => true);
    if (throws) {
      when(() => prefs.setString(any(), any())).thenThrow(Exception('quota exceeded'));
    } else {
      when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
    }
    return prefs;
  }

  /// Edits the title, leaves the editor directly and lets every held write
  /// (autosave and the write queued by dispose) fail.
  Future<void> failedLeave(WidgetTester tester) async {
    await openInShell(tester);
    db.hold = true;
    await tester.enterText(titleField('Probe'), 'Neu');
    await tester.pump();
    router.go('/attendance');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance')), findsOneWidget);
    while (db.waiting > 0) {
      db.release(fail: true);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('item 1: writes build on the newest stored row', () {
    testWidgets('two open editors on two plans: the stored row keeps both changes', (tester) async {
      tester.view.physicalSize = const Size(390, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container = makeContainer(attendance(twoPlans: true));
      Widget pane(Key key, int plan) =>
          SizedBox(key: key, height: 1400, child: PlanningPage(attendanceId: 7, initialPlanIndex: plan));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Column(children: [pane(const Key('A'), 0), pane(const Key('B'), 1)]),
        ),
      ));
      await tester.pumpAndSettle();
      Finder inPane(String pane, Finder f) => find.descendant(of: find.byKey(Key(pane)), matching: f);
      expect(inPane('A', titleField('Eins')), findsOneWidget);
      expect(inPane('B', titleField('Zwei')), findsOneWidget);

      // A stores plan 1.
      await tester.enterText(inPane('A', titleField('Eins')), 'Von A');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(storedTitles(), ['Von A', 'Zwei']);

      // B (its copy still holds plan 1 = "Eins") stores plan 2.
      await tester.enterText(inPane('B', titleField('Zwei')), 'Von B');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(storedTitles(), ['Von A', 'Von B'], reason: 'B replaces only plan 2');
      expect(db.calls.last.keys, containsAll(['plan', 'extra_plans']), reason: 'same payload shape as before');

      // And the other way round: A builds on B's commit.
      await tester.enterText(inPane('A', titleField('Von A')), 'Wieder A');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(storedTitles(), ['Wieder A', 'Von B']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('left editor stores plan 1 while the reopened editor edits plan 2', (tester) async {
      await openInShell(tester, twoPlans: true);
      db.hold = true;
      // Editor A edits plan 1 and is left directly (its write is held).
      await tester.enterText(titleField('Eins'), 'Von A');
      await tester.pump();
      router.go('/attendance');
      await tester.pumpAndSettle();
      // Editor B opens plan 2 from the copy loaded before A's write.
      router.go('/planning2');
      await tester.pumpAndSettle();
      expect(titleField('Zwei'), findsOneWidget);
      await tester.enterText(titleField('Zwei'), 'Von B');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));

      await releaseAll(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(storedTitles(), ['Von A', 'Von B'], reason: 'B does not reset the plan 1 stored by A');
      expect(await draftKeys(), isEmpty);
      router.go('/attendance');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    });

    test('latestSince: the newest commit only when it is newer than the known one', () {
      final key = PlanningWriteSync.keyFor(1, 7);
      final a = PlanningWriteSync.newInstance();
      final first = attendance();
      final second = attendance(twoPlans: true);
      expect(PlanningWriteSync.latestSince(key, 0), isNull);
      final s1 = PlanningWriteSync.commit(key, a, first);
      expect(PlanningWriteSync.latestSince(key, 0), same(first));
      expect(PlanningWriteSync.latestSince(key, s1), isNull);
      PlanningWriteSync.commit(key, a, second);
      expect(PlanningWriteSync.latestSince(key, s1), same(second));
      expect(PlanningWriteSync.latestSince(PlanningWriteSync.keyFor(2, 7), 0), isNull);
    });
  });

  group('item 2: the draft toast only for a confirmed draft', () {
    for (final throws in [false, true]) {
      testWidgets('setString ${throws ? 'throws' : 'returns false'} + failed write: loss warning',
          (tester) async {
        PlanningDraftStore.preferences = () async => failingPrefs(throws: throws);
        await failedLeave(tester);
        expect(find.text(_lostToast), findsOneWidget);
        expect(find.text(_keptToast), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('confirmed draft + failed write: "Entwurf lokal gesichert"', (tester) async {
      await failedLeave(tester);
      expect(find.text(_keptToast), findsOneWidget);
      expect(find.text(_lostToast), findsNothing);
      expect(await draftKeys(), ['planning_draft_u1_1_7_i0']);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    test('write returns a revision only for a confirmed write', () async {
      const key = 'planning_draft_u1_1_7_i0';
      PlanningDraftStore.preferences = () async => failingPrefs(throws: false);
      expect(await PlanningDraftStore.write(key, {'title': 'A'}, allowed: () => true), isNull);
      PlanningDraftStore.preferences = () async => failingPrefs(throws: true);
      expect(await PlanningDraftStore.write(key, {'title': 'A'}, allowed: () => true), isNull);
      PlanningDraftStore.preferences = SharedPreferences.getInstance;
      expect(await PlanningDraftStore.write(key, {'title': 'A'}, allowed: () => true), isNotNull);
      expect((await PlanningDraftStore.read(key))?.data['title'], 'A');
    });
  });
}
