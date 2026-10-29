// SOL_FIX31 (Sol review round 31):
// 1. A flag write ("Plan mit Mitgliedern teilen") checks the identity of the
//    open plan in the stored row before adopting it (conflict: draft, toast,
//    the editor shows the newest row).
// 2. The topic picker never restores a deleted / changed main plan.
// 3. Conflict drafts (and drafts whose base changed) are never restored or
//    autosaved on their own; the user decides.
import 'dart:io';

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

const _p2 = Plan(
  id: 'p2',
  time: '20:00',
  end: '2026-01-01T20:30',
  title: 'Zwei',
  fields: [PlanField(id: 'b', name: 'Konzert', time: '30')],
);

const _changedToast = 'Plan wurde inzwischen geändert';
const _conflictDraftMessage = 'Ein älterer Entwurf wurde wegen eines Konflikts nicht übernommen.';

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

  group('item 1: a flag write checks the plan identity before adopting the row', () {
    testWidgets('main plan deleted by B, then "teilen" toggled: editor reloads, no overwrite', (tester) async {
      await openEditor(tester, const [_m0, _p2]);
      expect(titleField('Haupt'), findsOneWidget);
      // Editor B deletes the main plan (no id): plan 2 moves up to position 0.
      otherEditorStores(row(7, [_p2.copyWith(title: 'Von B')]));

      await tester.tap(find.text('Plan mit Mitgliedern teilen'));
      await tester.pumpAndSettle();

      expect(find.text(_changedToast), findsOneWidget);
      expect(titleField('Haupt'), findsNothing, reason: 'the old main plan is not kept');
      expect(titleField('Von B'), findsOneWidget, reason: 'the editor shows the newest row');

      await setTitle(tester, 'Von B', 'Von A');
      expect(storedTitles(), ['Von A'], reason: 'the edit applies to the plan that is shown');
      await finish(tester);
    });

    testWidgets('pending edit at the conflict is kept as a confirmed conflict draft', (tester) async {
      await openEditor(tester, const [_m0, _p2]);
      otherEditorStores(row(7, [_p2.copyWith(title: 'Von B')]));
      await tester.enterText(titleField('Haupt'), 'Von A');
      await tester.pump();

      // The flag write runs in the queue right after the autosave (which hits
      // the conflict itself) or before it; in any case nothing overwrites B.
      await tester.tap(find.text('Plan mit Mitgliedern teilen'));
      await tester.pumpAndSettle();

      expect(storedTitles(), ['Von B']);
      final d = await draft('planning_draft_u1_1_7_i0');
      expect(d?['title'], 'Von A');
      expect(d?['conflict'], isTrue);
      await finish(tester);
    });
  });

  group('item 3: conflict drafts are never restored or autosaved on their own', () {
    Map<String, Object> stored(Map<String, dynamic> d) => {
      'planning_draft_u1_1_7_i0': jsonEncode({...d, 'rev': 1}),
    };

    Map<String, dynamic> draftOf(String title, {bool conflict = false, String? base}) => {
      'time': '17:00',
      'title': title,
      'fields': [const PlanField(id: 'm', name: 'Stimmen', time: '30').toJson()],
      if (conflict) 'conflict': true,
      if (base != null) 'base': base,
    };

    testWidgets('conflict draft: dialog, nothing loaded or written', (tester) async {
      SharedPreferences.setMockInitialValues(stored(draftOf('Von A', conflict: true)));
      await openEditor(tester, [_m0.copyWith(title: 'Von B')]);

      expect(find.text(_conflictDraftMessage), findsOneWidget);
      expect(titleField('Von B'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(db.calls, isEmpty, reason: 'no autosave of the conflict draft');
      await finish(tester);
    });

    testWidgets('normal draft whose base is no longer the stored plan counts as a conflict', (tester) async {
      final oldBase = jsonEncode(_m0.toJson());
      SharedPreferences.setMockInitialValues(stored(draftOf('Von A', base: oldBase)));
      await openEditor(tester, [_m0.copyWith(title: 'Von B')]);

      expect(find.text(_conflictDraftMessage), findsOneWidget);
      expect(titleField('Von B'), findsOneWidget);
      await tester.tap(find.textContaining(RegExp('verwerfen', caseSensitive: false)));
      await tester.pumpAndSettle();
      expect(await draft('planning_draft_u1_1_7_i0'), isNull);
      expect(db.calls, isEmpty);
      await finish(tester);
    });

    testWidgets('"Entwurf übernehmen" loads it as a pending change (then autosaved)', (tester) async {
      SharedPreferences.setMockInitialValues(stored(draftOf('Von A', conflict: true)));
      await openEditor(tester, [_m0.copyWith(title: 'Von B')]);

      await tester.tap(find.textContaining(RegExp('entwurf übernehmen', caseSensitive: false)));
      await tester.pumpAndSettle();
      expect(titleField('Von A'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(storedTitles(), ['Von A']);
      await finish(tester);
    });

    testWidgets('normal draft on an unchanged base is restored as before', (tester) async {
      SharedPreferences.setMockInitialValues(stored(draftOf('Von A', base: jsonEncode(_m0.toJson()))));
      await openEditor(tester, const [_m0]);

      expect(find.text(_conflictDraftMessage), findsNothing);
      expect(titleField('Von A'), findsOneWidget);
      await finish(tester);
    });
  });

  group('item 2: the topic picker never restores a deleted main plan', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
    });

    test('a gone / changed main plan is a conflict; no copyWith(plan: null)', () {
      final open = RegExp(r'Future<void> _openAgendaPicker\(\) async \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      expect(open, contains('final mainRef = _refOf(_att, 0);'));
      expect(open, contains('_saveTopics(attId, pickerAtt, type, selections, removeIds, mainRef)'));
      final save = RegExp(r'Future<Map<String, dynamic>> _saveTopics\([\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      final check = save.indexOf('_indexOfRef(base, mainRef) != 0');
      final write = save.indexOf("updateAttendancePlanFields(attId, {'plan': plan})");
      expect(check, greaterThan(0));
      expect(write, greaterThan(check));
      expect(save.substring(check, write), contains('throw '));
      expect(save, isNot(contains('copyWith(\n          plan: mainPlan == null ? null')));
      expect(save, isNot(contains('plan: mainPlan == null ? null')));
    });
  });
}

/// Main plan as Ionic stores it: without id.
const _m0 = Plan(
  time: '17:00',
  end: '2026-01-01T17:30',
  title: 'Haupt',
  fields: [PlanField(id: 'm', name: 'Stimmen', time: '30')],
);

List<Plan> _plans(PlanAttendance att) => att.plan == null ? const [] : [att.plan!, ...?att.extraPlans];
