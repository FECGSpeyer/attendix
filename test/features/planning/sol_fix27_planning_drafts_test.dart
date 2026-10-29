// SOL_FIX27 items 1 + 2: Ablaufplan editor drafts belong to the signed-in
// account (key with user id, removed on sign-out), and writes of every
// editor instance of a Termin run on one process-wide chain, so an editor
// that was left can never overwrite what a later editor stored.
import 'dart:async';
import 'dart:io';

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

const _restoredToast = 'Nicht gespeicherte Änderungen wiederhergestellt';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDb db;
  late ProviderContainer container;
  late GoRouter router;

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

  Finder minutesField() =>
      find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);

  Map<String, dynamic> planOf(Map<String, dynamic> update) => update['plan'] as Map<String, dynamic>;

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

  Future<void> openInShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = makeContainer(attendance());
    router = GoRouter(
      initialLocation: '/planning',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/attendance', builder: (_, __) => const Placeholder(key: Key('attendance'))),
            GoRoute(path: '/planning', builder: (_, __) => const PlanningPage(attendanceId: 7)),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(tester);
    expect(titleField('Probe'), findsOneWidget);
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

  group('item 1: drafts belong to the signed-in account', () {
    /// u1 edits the title, leaves directly and the queued write fails: the
    /// edit stays as u1's draft.
    Future<void> failedLeaveAsU1(WidgetTester tester) async {
      await openInShell(tester);
      db.hold = true;
      await tester.enterText(titleField('Probe'), 'Von u1');
      await tester.pump();
      router.go('/attendance');
      await tester.pumpAndSettle();
      await releaseAll(tester, fail: true);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      db.hold = false;
    }

    testWidgets('the draft key carries the auth user id', (tester) async {
      await failedLeaveAsU1(tester);
      expect(await draftKeys(), ['planning_draft_u1_1_7_i0']);
    });

    testWidgets('another account in the same tenant neither restores nor saves the draft', (tester) async {
      await failedLeaveAsU1(tester);
      final callsBefore = db.calls.length;

      container.read(_userProvider.notifier).state = 'u2';
      router.go('/planning');
      await tester.pumpAndSettle();
      expect(titleField('Probe'), findsOneWidget, reason: 'stored plan, not u1\'s draft');
      expect(find.text(_restoredToast), findsNothing);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(db.calls, hasLength(callsBefore), reason: 'u1\'s edit is never written as u2');
      expect(planOf(db.row.toJson())['title'], 'Probe');

      // Back as u1 (no sign-out in between): u1 gets the own draft back.
      container.read(_userProvider.notifier).state = 'u1';
      router.go('/attendance');
      await tester.pumpAndSettle();
      router.go('/planning');
      await tester.pumpAndSettle();
      expect(titleField('Von u1'), findsOneWidget);
      router.go('/attendance');
      await tester.pumpAndSettle();
      await releaseAll(tester);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('without a signed-in user no draft is written or restored', (tester) async {
      SharedPreferences.setMockInitialValues({
        'planning_draft__1_7_i0': '{"time":"18:00","title":"Fremd","fields":[]}',
      });
      await openInShell(tester);
      container.read(_userProvider.notifier).state = null;
      await tester.pump();
      db.hold = true;
      await tester.enterText(titleField('Probe'), 'Neu');
      await tester.pump();
      router.go('/attendance');
      await tester.pumpAndSettle();
      await releaseAll(tester, fail: true);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(await draftKeys(), ['planning_draft__1_7_i0'], reason: 'no new draft');
      expect(PlanningDraftStore.keyFor(userId: null, tenantId: 1, attId: 7, planKey: 'i0'), isNull);
      expect(PlanningDraftStore.keyFor(userId: '', tenantId: 1, attId: 7, planKey: 'i0'), isNull);
    });

    test('sign-out / account switch removes every planning draft', () async {
      SharedPreferences.setMockInitialValues({
        'planning_draft_u1_1_7_i0': '{}',
        'planning_draft_u2_3_9_p1': '{}',
        'planning_draft_1_7_i0': '{}', // older format
        'offline_writes_v1': '[]',
        'locale': 'de',
      });
      await clearPlanningDrafts();
      expect((await SharedPreferences.getInstance()).getKeys(), {'offline_writes_v1', 'locale'});

      final main = File('lib/main.dart').readAsStringSync();
      final listener = main.substring(main.indexOf('ref.listen(currentUserProvider'));
      final clearBlock = listener.substring(0, listener.indexOf('onUserChanged'));
      expect(clearBlock, contains('shouldClearOfflineReadCaches('));
      expect(clearBlock, contains('unawaited(clearPlanningDrafts());'));
    });
  });

  group('item 2: one write chain for every editor instance', () {
    testWidgets('leaving during a running autosave and reopening: the new editor is written last',
        (tester) async {
      await openInShell(tester);
      db.hold = true;
      // Editor A: autosave runs (held).
      await tester.enterText(minutesField(), '15');
      await tester.pump(const Duration(milliseconds: 450));
      expect(db.waiting, 1);
      // Leave (A queues its dispose snapshot) and reopen at once (B).
      router.go('/attendance');
      await tester.pumpAndSettle();
      router.go('/planning');
      await tester.pumpAndSettle();
      // B edits the title; its autosave must wait for A's writes.
      await tester.enterText(titleField('Probe'), 'Von B');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));
      expect(db.calls, hasLength(1), reason: 'B waits behind A\'s running write');

      await releaseAll(tester);
      // SOL_FIX30: B's copy of the main plan (no id) is older than A's
      // stored write, so the position no longer proves the plan's identity:
      // B's write is a conflict. Nothing of B is written over A's write; B's
      // edit is kept as a confirmed local draft and B is told.
      expect(find.text('Plan wurde inzwischen geändert – Änderungen als Entwurf gesichert'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(db.calls.where((c) => planOf(c)['title'] == 'Von B'), isEmpty);
      expect(planOf(db.row.toJson())['title'], 'Probe');
      expect(((planOf(db.row.toJson())['fields'] as List).first as Map)['time'], '15');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('planning_draft_u1_1_7_i0'), contains('Von B'));
      router.go('/attendance');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a disposed editor never overwrites what a later editor stored', (tester) async {
      tester.view.physicalSize = const Size(390, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container = makeContainer(attendance());
      final showA = ValueNotifier(true);
      Widget pane(Key key) => SizedBox(key: key, height: 1400, child: const PlanningPage(attendanceId: 7));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: showA,
            builder: (_, a, __) => Column(children: [
              if (a) pane(const Key('A')),
              pane(const Key('B')),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      Finder inPane(String pane, Finder f) => find.descendant(of: find.byKey(Key(pane)), matching: f);
      // A (opened first) holds an unsaved edit (its autosave failed).
      db.hold = true;
      await tester.enterText(inPane('A', minutesField()), '15');
      await tester.pump(const Duration(milliseconds: 450));
      expect(db.waiting, 1);
      db.release(fail: true);
      await tester.pump();
      await tester.pump();
      db.hold = false;
      // B (opened later) edits and stores.
      await tester.enterText(inPane('B', titleField('Probe')), 'Von B');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(db.calls.map((c) => planOf(c)['title']), contains('Von B'));
      final callsAfterB = db.calls.length;

      // A goes away with its pending (older) snapshot.
      showA.value = false;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(db.calls, hasLength(callsAfterB), reason: 'A\'s snapshot is not written over B');
      expect(planOf(db.row.toJson())['title'], 'Von B');
      // A's edit differs from what B stored: kept as A's draft.
      expect(await draftKeys(), ['planning_draft_u1_1_7_i0']);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      showA.dispose();
    });

    test('an older writer removes a draft only while it holds its revision', () async {
      const key = 'planning_draft_u1_1_7_i0';
      final older = await PlanningDraftStore.write(key, {'title': 'A'}, allowed: () => true);
      final newer = await PlanningDraftStore.write(key, {'title': 'B'}, allowed: () => true);
      expect(newer, greaterThan(older!));
      await PlanningDraftStore.removeIfRevision(key, older);
      expect((await PlanningDraftStore.read(key))?.data['title'], 'B', reason: 'newer draft stays');
      await PlanningDraftStore.removeIfRevision(key, newer);
      expect(await PlanningDraftStore.read(key), isNull);
      expect(await PlanningDraftStore.write(key, {'x': 1}, allowed: () => false), isNull);
      expect(await PlanningDraftStore.read(key), isNull);
    });

    test('newerCommit: only commits of later editors after the base count', () {
      final key = PlanningWriteSync.keyFor(1, 7);
      final a = PlanningWriteSync.newInstance();
      final b = PlanningWriteSync.newInstance();
      final row = attendance();
      expect(PlanningWriteSync.newerCommit(key, a, 0), isNull);
      final s1 = PlanningWriteSync.commit(key, a, row);
      expect(PlanningWriteSync.newerCommit(key, b, 0), isNull, reason: 'A is older than B');
      final s2 = PlanningWriteSync.commit(key, b, row);
      expect(PlanningWriteSync.newerCommit(key, a, s1), same(row));
      expect(PlanningWriteSync.newerCommit(key, a, s2), isNull, reason: 'A knows B\'s commit');
      expect(PlanningWriteSync.newerCommit(PlanningWriteSync.keyFor(2, 7), a, 0), isNull);
    });

    test('every editor write goes through the shared chain; drafts only by revision', () {
      final src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
      expect(src, isNot(contains('Future<void> _writeChain')));
      expect(src, contains('PlanningWriteSync.run(PlanningWriteSync.keyFor(_tenantId, attId), task)'));
      expect(src, isNot(contains('prefs.remove(')));
      expect(RegExp(r'PlanningDraftStore\.removeIfRevision\(').allMatches(src).length, greaterThanOrEqualTo(4));
    });
  });
}
