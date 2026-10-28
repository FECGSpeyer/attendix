// SOL_FIX8: readers of read-only shared plan links (no realtime channel)
// get the plan re-fetched every 15 s; paused in background, stopped on
// dispose.
import 'dart:io';

import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/public_plan_repository.dart';
import 'package:attendix/features/planning/presentation/pages/shared_plan_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo extends PublicPlanRepository {
  _FakeRepo(super.ref);

  SharedPlan? shared;
  PlanAttendance? att;
  int sharedCalls = 0;
  int attCalls = 0;

  @override
  Future<SharedPlan?> getSharedPlan(String key) async {
    sharedCalls++;
    return shared;
  }

  @override
  Future<PlanAttendance?> getSharedAttendancePlan(int id, String key) async {
    attCalls++;
    return att;
  }
}

void main() {
  late _FakeRepo repo;

  Future<void> pumpPage(WidgetTester tester, SharedPlanPage page) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        publicPlanRepositoryProvider.overrideWith((ref) => repo = _FakeRepo(ref)..shared = _shared..att = _att),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  setUp(() {
    _shared = const SharedPlan(
      id: 'k1',
      editKey: '',
      planTitle: 'Plan A',
      time: '18:00',
      fields: [PlanField(id: 'a', name: 'Einsingen', time: '10')],
    );
    _att = const PlanAttendance(
      id: 5,
      date: '2026-11-01',
      plan: Plan(time: '18:00', fields: [PlanField(id: 'a', name: 'Einsingen', time: '10')]),
    );
  });

  testWidgets('ad-hoc read link re-fetches every 15 s and shows updates', (tester) async {
    await pumpPage(tester, const SharedPlanPage(shareKey: 'k1'));
    expect(repo.sharedCalls, 1);
    expect(find.text('Einsingen'), findsOneWidget);

    repo.shared = repo.shared!.copyWith(
      planTitle: 'Plan B',
      fields: const [PlanField(id: 'b', name: 'Probe', time: '20')],
    );
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(repo.sharedCalls, 2);
    expect(find.text('Probe'), findsOneWidget);
    expect(find.text('Plan B'), findsWidgets);
    expect(find.text('Einsingen'), findsNothing);

    await disposePage(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(repo.sharedCalls, 2, reason: 'timer cancelled on dispose');
  });

  testWidgets('Termin read link re-fetches plan; paused in background', (tester) async {
    await pumpPage(tester, const SharedPlanPage(attendanceId: 5, shareKey: 's1'));
    expect(repo.attCalls, 1);

    repo.att = repo.att!.copyWith(
      plan: const Plan(time: '18:00', fields: [PlanField(id: 'b', name: 'Probe', time: '20')]),
    );
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(repo.attCalls, 2);
    expect(find.text('Probe'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 45));
    expect(repo.attCalls, 2, reason: 'no polling while hidden');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repo.attCalls, 3, reason: 'refresh right after coming back');
    await tester.pump(const Duration(seconds: 15));
    expect(repo.attCalls, 4);

    await disposePage(tester);
  });

  testWidgets('a revoked link shows "not found" and stops polling', (tester) async {
    await pumpPage(tester, const SharedPlanPage(shareKey: 'k1'));
    repo.shared = null;
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.text(lookupAppLocalizations(const Locale('de')).plansNotFound), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(repo.sharedCalls, 2);
    await disposePage(tester);
  });

  test('polling only for read links, realtime only for verified edit links', () {
    final src = File('lib/features/planning/presentation/pages/shared_plan_page.dart')
        .readAsStringSync();
    expect(src, contains('Duration(seconds: 15)'));
    expect(src, contains('if (!_notFound && !_editMode)'));
    expect(src, contains('_refreshTimer?.cancel()'));
    final dispose = src.substring(src.indexOf('void dispose()'));
    expect(dispose.substring(0, 300), contains('_stopRefresh()'));
    expect(dispose.substring(0, 300), contains('_lifecycle?.dispose()'));
  });
}

SharedPlan? _shared;
PlanAttendance? _att;
