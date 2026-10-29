// SOL_FIX30 (Sol review round 30):
// 1. A plan without id (Ionic's main plan) is matched by position only when
//    the newest row has the same plan count and the plan there is identical
//    to the editor's version; otherwise it is a conflict (no write, draft,
//    toast).
// 2. "Themen aufnehmen" writes inside the write queue on the newest stored
//    row and registers the full stored row.
// 3. Switching plans resolves the chosen plan by identity after the save.
// 4. A write of a disposed editor skipped because a later editor stored the
//    Termin is reported (conflict / loss toast).
import 'dart:io';

import 'package:attendix/core/services/planning_draft_store.dart';
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
          (ref) async => db.rows.values.toList()..sort((a, b) => b.date.compareTo(a.date)),
        ),
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

  Widget app({Widget? home, GoRouter? router}) {
    const locale = Locale('de');
    final delegates = AppLocalizations.localizationsDelegates;
    final supported = AppLocalizations.supportedLocales;
    return UncontrolledProviderScope(
      container: container,
      child:
          router != null
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
    PlanningWriteSync.commit(
      PlanningWriteSync.keyFor(1, stored.id!),
      instance ?? PlanningWriteSync.newInstance(),
      stored,
    );
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

  group('item 1: a plan without id is matched by position only when unchanged', () {
    testWidgets('main plan deleted by another editor: the plan that moved up is not overwritten', (tester) async {
      await openEditor(tester, const [_m0, _p2]);
      expect(titleField('Haupt'), findsOneWidget);
      // Editor B deletes the main plan (no id): plan 2 moves up to position 0.
      otherEditorStores(row(7, [_p2.copyWith(title: 'Von B')]));

      await setTitle(tester, 'Haupt', 'Von A');

      expect(db.calls, isEmpty, reason: 'position 0 is another plan now');
      expect(storedTitles(), ['Von B']);
      expect((await draft('planning_draft_u1_1_7_i0'))?['title'], 'Von A');
      expect(find.text(_changedDraftToast), findsOneWidget);
      await finish(tester);
    });

    testWidgets('main plan changed by another editor: conflict, no overwrite', (tester) async {
      await openEditor(tester, const [_m0, _p2]);
      otherEditorStores(row(7, [_m0.copyWith(title: 'Von B'), _p2]));

      await setTitle(tester, 'Haupt', 'Von A');

      expect(db.calls, isEmpty);
      expect(storedTitles(), ['Von B', 'Zwei']);
      expect((await draft('planning_draft_u1_1_7_i0'))?['title'], 'Von A');
      expect(find.text(_changedDraftToast), findsOneWidget);
      await finish(tester);
    });

    testWidgets('same plan count and unchanged main plan: written on top of the newest row', (tester) async {
      await openEditor(tester, const [_m0, _p2]);
      otherEditorStores(row(7, [_m0, _p2.copyWith(title: 'Von B')]));

      await setTitle(tester, 'Haupt', 'Von A');

      expect(db.calls, hasLength(1));
      expect(storedTitles(), ['Von A', 'Von B']);
      await finish(tester);
    });
  });

  group('item 3: switching plans resolves the target after the save', () {
    testWidgets('a plan deleted before the target: the target is opened at its new position', (tester) async {
      await openEditor(tester, const [_p0, _p1, _p2]);
      await tester.enterText(titleField('Null'), 'Von A');
      await tester.pump();
      // B deletes plan 2 while A has a pending edit.
      otherEditorStores(row(7, [_p0, _p2]));

      await tester.tap(find.text('Plan 3'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(storedTitles(), ['Von A', 'Zwei']);
      expect(titleField('Zwei'), findsOneWidget, reason: 'the chosen plan is opened');
      await finish(tester);
    });

    testWidgets('the target plan was deleted: toast, the open plan stays', (tester) async {
      await openEditor(tester, const [_p0, _p1, _p2]);
      await tester.enterText(titleField('Null'), 'Von A');
      await tester.pump();
      otherEditorStores(row(7, [_p0, _p1]));

      await tester.tap(find.text('Plan 3'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(storedTitles(), ['Von A', 'Eins']);
      expect(find.text(_deletedToast), findsOneWidget);
      expect(titleField('Von A'), findsOneWidget, reason: 'the open plan stays');
      await finish(tester);
    });
  });

  group('item 4: a skipped write of a disposed editor is reported', () {
    Future<void> disposeAfterNewerEditor(WidgetTester tester) async {
      await openEditor(tester, const [_p1, _p2]);
      // An editor created later stores another version of plan 1.
      otherEditorStores(row(7, [_p1.copyWith(title: 'Von B'), _p2]));
      await tester.enterText(titleField('Eins'), 'Von A');
      await tester.pump();
      // The page goes away without the leave flow (e.g. deep link).
      await tester.pumpWidget(app(home: const SizedBox()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('confirmed draft: conflict toast, draft kept', (tester) async {
      await disposeAfterNewerEditor(tester);

      expect(db.calls, isEmpty);
      expect(storedTitles(), ['Von B', 'Zwei']);
      expect((await draft('planning_draft_u1_1_7_p1'))?['title'], 'Von A');
      expect(find.text(_changedDraftToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('draft write failed: loss toast', (tester) async {
      PlanningDraftStore.preferences = () async => _failingPrefs();
      addTearDown(() => PlanningDraftStore.preferences = SharedPreferences.getInstance);
      await disposeAfterNewerEditor(tester);

      expect(db.calls, isEmpty);
      expect(find.text(_changedLostToast), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('item 2: "Themen aufnehmen" writes in the queue on the newest stored row', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
    });

    test('the picker gets the queued write; no copy from before the save is registered', () {
      final open = RegExp(r'Future<void> _openAgendaPicker\(\) async \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      expect(open, contains('save: (selections, removeIds) => _saveTopics('));
      expect(open, isNot(contains('_markWritten')));
      expect(open, isNot(contains('att.copyWith(plan:')));
      final save = RegExp(r'Future<Map<String, dynamic>> _saveTopics\([\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      expect(save, contains('_serialised(attId, () async {'));
      final read = save.indexOf('getPlanAttendanceById(attId)');
      final write = save.indexOf("updateAttendancePlanFields(attId, {'plan': plan})");
      expect(read, greaterThan(0));
      expect(write, greaterThan(read));
      expect(save.indexOf('_markWritten(attId, saved)'), greaterThan(write));
    });
  });
}

class _MockPrefs extends Mock implements SharedPreferences {}

SharedPreferences _failingPrefs() {
  final prefs = _MockPrefs();
  when(() => prefs.getString(any())).thenReturn(null);
  when(() => prefs.getKeys()).thenReturn(<String>{});
  when(() => prefs.remove(any())).thenAnswer((_) async => true);
  when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
  return prefs;
}

/// Main plan as Ionic stores it: without id.
const _m0 = Plan(
  time: '17:00',
  end: '2026-01-01T17:30',
  title: 'Haupt',
  fields: [PlanField(id: 'm', name: 'Stimmen', time: '30')],
);
const _p0 = Plan(
  id: 'p0',
  time: '16:00',
  end: '2026-01-01T16:30',
  title: 'Null',
  fields: [PlanField(id: 'z', name: 'Aufbau', time: '30')],
);

const _changedDraftToast = 'Plan wurde inzwischen geändert – Änderungen als Entwurf gesichert';
const _changedLostToast = 'Plan wurde inzwischen geändert – Änderungen gehen verloren';

List<Plan> _plans(PlanAttendance att) => att.plan == null ? const [] : [att.plan!, ...?att.extraPlans];
