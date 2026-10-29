// SOL_FIX29: several Ablaufplan editors of one app instance share
// `PlanningWriteSync`.
// 1. A plan deleted by another editor is never restored by a write of its
//    old copy: no write, the edit is kept as a draft, toast.
// 2. Plan list operations (rename / day / move / delete / add) are applied
//    to the newest stored row inside the queued write, not to a copy taken
//    before their dialog.
// 3. Loading a Termin adopts the newest stored row together with its
//    sequence number (never marks a stale copy as current).
import 'dart:convert';

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

/// Fake `attendance` table: rows by id.
class _FakeDb {
  final rows = <int, PlanAttendance>{};
  final calls = <(int, Map<String, dynamic>)>[];

  Future<PlanAttendance> update(int id, Map<String, dynamic> update) async {
    calls.add((id, update));
    final row = PlanAttendance.fromJson({...rows[id]!.toJson(), ...update});
    rows[id] = row;
    return row;
  }
}

const _p1 = Plan(
  id: 'p1',
  time: '18:00',
  end: '2026-01-01T18:30',
  title: 'Eins',
  fields: [PlanField(id: 'a', name: 'Einspielen', time: '30')],
);
const _p2 = Plan(
  id: 'p2',
  time: '20:00',
  end: '2026-01-01T20:30',
  title: 'Zwei',
  fields: [PlanField(id: 'b', name: 'Konzert', time: '30')],
);

const _deletedDraftToast = 'Plan wurde inzwischen gelöscht – Änderungen als Entwurf gesichert';
const _deletedToast = 'Plan wurde inzwischen gelöscht';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDb db;
  late ProviderContainer container;

  String dateIn(int days) => DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);

  PlanAttendance row(int id, List<Plan> plans, {int days = 2}) => PlanAttendance(
        id: id,
        tenantId: 1,
        date: dateIn(days),
        plan: plans.isEmpty ? null : plans.first,
        extraPlans: plans.length > 1 ? plans.sublist(1) : null,
      );

  ProviderContainer makeContainer(List<PlanAttendance> rows) {
    db = _FakeDb();
    for (final r in rows) {
      db.rows[r.id!] = r;
    }
    final repo = _MockPlanRepository();
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer(
      (inv) => db.update(inv.positionalArguments[0] as int, inv.positionalArguments[1] as Map<String, dynamic>),
    );
    final c = createTestContainer(
      tenant: TestFactories.createTenant(id: 1),
      overrides: [
        planRepositoryWithTenantProvider.overrideWithValue(repo),
        planAttendancesProvider.overrideWith(
            (ref) async => db.rows.values.toList()..sort((a, b) => b.date.compareTo(a.date))),
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
        currentAuthUserIdProvider.overrideWith((ref) => 'u1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Finder titleField(String text) => find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

  Finder button(String label) =>
      find.byWidgetPredicate((w) => w is Text && (w.data == label || w.data == label.toUpperCase()));

  Widget app({Widget? home, GoRouter? router}) {
    const locale = Locale('de');
    final delegates = AppLocalizations.localizationsDelegates;
    final supported = AppLocalizations.supportedLocales;
    return UncontrolledProviderScope(
      container: container,
      child: router != null
          ? MaterialApp.router(
              theme: AppTheme.light,
              locale: locale,
              localizationsDelegates: delegates,
              supportedLocales: supported,
              routerConfig: router,
            )
          : MaterialApp(
              theme: AppTheme.light,
              locale: locale,
              localizationsDelegates: delegates,
              supportedLocales: supported,
              home: home,
            ),
    );
  }

  /// Opens the editor of Termin 7 (plans [plans]) directly.
  Future<void> openEditor(WidgetTester tester, List<Plan> plans, {List<PlanAttendance> others = const []}) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = makeContainer([row(7, plans), ...others]);
    await tester.pumpWidget(app(home: const PlanningPage(attendanceId: 7)));
    await tester.pumpAndSettle();
  }

  /// Another editor instance of the same app stored [stored] for Termin 7.
  void otherEditorStores(PlanAttendance stored, {int? instance}) {
    db.rows[stored.id!] = stored;
    PlanningWriteSync.commit(PlanningWriteSync.keyFor(1, stored.id!), instance ?? PlanningWriteSync.newInstance(), stored);
  }

  /// Titles of the stored plans of Termin [id], in order.
  List<String?> storedTitles([int id = 7]) => [for (final p in _plans(db.rows[id]!)) p.title];

  Future<Map<String, dynamic>?> draft(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> setTitle(WidgetTester tester, String from, String to) async {
    await tester.enterText(titleField(from), to);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  Future<void> openPlanOption(WidgetTester tester, String option) async {
    await tester.tap(find.byTooltip('Plan-Optionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlanningWriteSync.reset();
  });

  group('item 1: a plan deleted meanwhile is never restored', () {
    testWidgets('open editor: no write, edit kept as draft, toast, newest row shown', (tester) async {
      await openEditor(tester, const [_p1, _p2]);
      expect(titleField('Eins'), findsOneWidget);
      // Editor B deletes plan 1 and edits plan 2.
      otherEditorStores(row(7, [_p2.copyWith(title: 'Von B')]));

      await setTitle(tester, 'Eins', 'Von A');

      expect(db.calls, isEmpty, reason: 'the old row would restore plan 1 and reset plan 2');
      expect(storedTitles(), ['Von B']);
      expect((await draft('planning_draft_u1_1_7_p1'))?['title'], 'Von A');
      expect(find.text(_deletedDraftToast), findsOneWidget);
      expect(titleField('Von B'), findsOneWidget, reason: 'the editor shows the newest stored row');

      // A later edit builds on the newest row.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await setTitle(tester, 'Von B', 'Wieder A');
      expect(db.calls, hasLength(1));
      expect(storedTitles(), ['Wieder A']);
      await finish(tester);
    });

    testWidgets('write queued on leaving: no write, draft kept, toast', (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Editor B was opened before A (A's queued write is not skipped by the
      // "later editor wins" rule).
      final b = PlanningWriteSync.newInstance();
      container = makeContainer([row(7, const [_p1, _p2])]);
      final router = GoRouter(
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
      await tester.pumpWidget(app(router: router));
      await tester.pumpAndSettle();
      expect(titleField('Eins'), findsOneWidget);
      otherEditorStores(row(7, [_p2.copyWith(title: 'Von B')]), instance: b);

      await tester.enterText(titleField('Eins'), 'Von A');
      await tester.pump();
      router.go('/attendance');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attendance')), findsOneWidget);

      expect(db.calls, isEmpty);
      expect(storedTitles(), ['Von B']);
      expect((await draft('planning_draft_u1_1_7_p1'))?['title'], 'Von A');
      expect(find.text(_deletedDraftToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('item 2: plan operations run on the newest stored row', () {
    testWidgets('rename: a plan stored while the dialog was open is kept', (tester) async {
      await openEditor(tester, const [_p1, _p2]);
      await openPlanOption(tester, 'Umbenennen');
      // B stores plan 2 while A's rename dialog is open.
      otherEditorStores(row(7, [_p1, _p2.copyWith(title: 'Von B')]));
      await tester.enterText(find.byType(TextField).last, 'Neu');
      await tester.tap(button('Speichern'));
      await tester.pumpAndSettle();

      expect(db.calls, hasLength(1));
      expect(storedTitles(), ['Eins', 'Von B'], reason: "B's plan 2 is not reset");
      expect(_plans(db.rows[7]!).first.label, 'Neu');
      await finish(tester);
    });

    testWidgets('delete: a plan stored while the dialog was open is kept', (tester) async {
      await openEditor(tester, const [_p1, _p2]);
      await openPlanOption(tester, 'Plan löschen');
      otherEditorStores(row(7, [_p1, _p2.copyWith(title: 'Von B')]));
      await tester.tap(button('Löschen'));
      await tester.pumpAndSettle();

      expect(storedTitles(), ['Von B']);
      expect(titleField('Von B'), findsOneWidget, reason: 'the remaining (newest) plan is open');
      await finish(tester);
    });

    testWidgets('rename of a plan deleted while the dialog was open: no write, toast', (tester) async {
      await openEditor(tester, const [_p1, _p2]);
      await openPlanOption(tester, 'Umbenennen');
      otherEditorStores(row(7, [_p2.copyWith(title: 'Von B')]));
      await tester.enterText(find.byType(TextField).last, 'Neu');
      await tester.tap(button('Speichern'));
      await tester.pumpAndSettle();

      expect(db.calls, isEmpty);
      expect(storedTitles(), ['Von B']);
      expect(find.text(_deletedToast), findsOneWidget);
      expect(titleField('Von B'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('add: appended to the newest stored row', (tester) async {
      await openEditor(tester, const [_p1, _p2]);
      await tester.tap(find.byTooltip('Feld hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiteren Ablaufplan anlegen'));
      await tester.pumpAndSettle();
      otherEditorStores(row(7, [_p1, _p2.copyWith(title: 'Von B')]));
      await tester.tap(button('Leer'));
      await tester.pumpAndSettle();

      expect(db.calls, hasLength(1));
      expect(storedTitles(), ['Eins', 'Von B', null]);
      await finish(tester);
    });
  });

  group('item 3: loading a Termin adopts the newest stored row', () {
    testWidgets('switching back to a Termin stored by another editor meanwhile', (tester) async {
      // Termin 8 (later) is "Nächste" of Termin 7.
      const p8 = Plan(id: 'q', time: '10:00', title: 'Acht', fields: [PlanField(id: 'c', name: 'X', time: '10')]);
      await openEditor(tester, const [_p1, _p2], others: [row(8, const [p8], days: 5)]);
      expect(titleField('Eins'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.arrow_forward));
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(titleField('Acht'), findsOneWidget);

      // B stores plan 2 of Termin 7 while A shows Termin 8.
      otherEditorStores(row(7, [_p1, _p2.copyWith(title: 'Von B')]));

      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(titleField('Eins'), findsOneWidget);

      // A edits plan 1: built on B's row, plan 2 stays.
      await setTitle(tester, 'Eins', 'Von A');
      expect(db.calls.map((c) => c.$1), [7]);
      expect(storedTitles(), ['Von A', 'Von B']);
      await finish(tester);
    });

    test('refreshedSeq: commits after the last cache refresh are not in cached rows', () {
      final key = PlanningWriteSync.keyFor(1, 7);
      final a = PlanningWriteSync.newInstance();
      expect(PlanningWriteSync.refreshedSeq(key), 0);
      PlanningWriteSync.commit(key, a, row(7, const [_p1]));
      expect(PlanningWriteSync.refreshedSeq(key), 0);
      PlanningWriteSync.markCachesRefreshed();
      expect(PlanningWriteSync.refreshedSeq(key), 1);
      PlanningWriteSync.commit(key, a, row(7, const [_p2]));
      expect(PlanningWriteSync.refreshedSeq(key), 1);
      expect(PlanningWriteSync.latestSince(key, PlanningWriteSync.refreshedSeq(key)), isNotNull);
      PlanningWriteSync.reset();
      expect(PlanningWriteSync.refreshedSeq(key), 0);
    });
  });
}

List<Plan> _plans(PlanAttendance att) => att.plan == null ? const [] : [att.plan!, ...?att.extraPlans];
