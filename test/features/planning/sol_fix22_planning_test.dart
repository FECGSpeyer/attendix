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
import 'package:attendix/core/utils/plan_utils.dart';
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

/// SOL_FIX22: the Ablaufplan editor only writes real pending changes, clears
/// itself after the last plan is deleted (Ionic `loadPlan(att, undefined)`),
/// and rejects negative `?plan=` indices.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('PlanUtils.validPlanIndex (?plan=)', () {
    test('accepts 0..count-1 only, everything else is null', () {
      expect(PlanUtils.validPlanIndex(0, 2), 0);
      expect(PlanUtils.validPlanIndex(1, 2), 1);
      expect(PlanUtils.validPlanIndex(-1, 2), isNull);
      expect(PlanUtils.validPlanIndex(2, 2), isNull);
      expect(PlanUtils.validPlanIndex(0, 0), isNull);
      expect(PlanUtils.validPlanIndex(null, 2), isNull);
    });

    test('router resets negative plan values to null', () {
      final src = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(src, contains("rawPlan != null && rawPlan >= 0 ? rawPlan : null"));
    });

    test('editor falls back to the first plan via validPlanIndex', () {
      final src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
      expect(src, contains('PlanUtils.validPlanIndex(planIndex, plans.length) ?? 0'));
      expect(src, isNot(contains('planIndex < plans.length ? planIndex : 0')));
    });
  });

  group('editor state after delete (source)', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
    });

    test('_save only writes pending changes', () {
      // SOL_FIX23: the write itself runs in `_writeOpenPlan` (serialised).
      final save = RegExp(r'Future<bool> _writeOpenPlan\(int attId\) async \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      expect(save, contains('if (!mounted || !_hasPendingChanges) return true;'));
      expect(save.indexOf('_hasPendingChanges'), lessThan(save.indexOf('updateAttendancePlanFields')));
    });

    test('deleting the last plan clears the editor', () {
      expect(src, contains('_clearEditor(_att ?? current);'));
      final clear = RegExp(r'void _clearEditor\(PlanAttendance att\) \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
      expect(clear, contains('_dirty = false;'));
      expect(clear, contains('_fields = [];'));
      expect(clear, contains('_titleController.text = _defaultTitle(att);'));
      expect(clear, contains('_saveTimer?.cancel();'));
    });
  });

  group('PlanningPage dirty flag (widget)', () {
    late _MockPlanRepository repo;
    final calls = <Map<String, dynamic>>[];

    PlanAttendance attendance({List<Plan>? extra}) => PlanAttendance(
          id: 7,
          tenantId: 1,
          date: DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
          plan: const Plan(
            time: '18:00',
            end: '2026-01-01T18:30',
            title: 'Probe',
            fields: [PlanField(id: 'a', name: 'Einspielen', time: '30')],
          ),
          extraPlans: extra,
        );

    setUp(() {
      calls.clear();
      repo = _MockPlanRepository();
      when(() => repo.hasTenantId).thenReturn(true);
      when(() => repo.updateAttendancePlanFields(any(), any())).thenAnswer((inv) async {
        calls.add(inv.positionalArguments[1] as Map<String, dynamic>);
        return attendance();
      });
    });

    Future<void> pump(WidgetTester tester, PlanAttendance att, Widget home) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = createTestContainer(
        tenant: TestFactories.createTenant(id: 1),
        overrides: [
          planRepositoryWithTenantProvider.overrideWithValue(repo),
          planAttendancesProvider.overrideWith((ref) async => [att]),
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
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> openPage(WidgetTester tester, PlanAttendance att) async {
      await pump(
        tester,
        att,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlanningPage(attendanceId: att.id)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }

    Finder titleField() =>
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Probe');

    testWidgets('opening and closing a stored plan writes nothing', (tester) async {
      await openPage(tester, attendance());
      expect(titleField(), findsOneWidget);
      await close(tester);
      expect(find.text('open'), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('a real title change is saved on close', (tester) async {
      await openPage(tester, attendance());
      await tester.enterText(titleField(), 'Generalprobe');
      await tester.pump();
      await close(tester);
      expect(calls, hasLength(1));
      final plan = calls.single['plan'] as Map<String, dynamic>;
      expect(plan['title'], 'Generalprobe');
      expect((plan['fields'] as List), hasLength(1));
    });

    testWidgets('?plan=-1 opens the first plan', (tester) async {
      final att = attendance(extra: const [
        Plan(id: 'p2', time: '20:00', title: 'Zweiter', fields: [PlanField(id: 'b', name: 'B', time: '5')]),
      ]);
      await pump(tester, att, PlanningPage(attendanceId: att.id, initialPlanIndex: -1));
      expect(tester.takeException(), isNull);
      expect(titleField(), findsOneWidget);
      expect(find.text('Einspielen'), findsOneWidget);
    });
  });
}
