// SOL_FIX25 item 2: the public edit link serialises its writes, builds each
// payload from the current full state when the write starts and blocks plan
// switches until the open plan's edits are stored.
import 'dart:async';

import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/public_plan_repository.dart';
import 'package:attendix/features/planning/presentation/pages/shared_plan_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockChannel extends Mock implements RealtimeChannel {}

/// Delayed fake: every write waits for [release] while [hold] is set.
class _FakeRepo extends PublicPlanRepository {
  _FakeRepo(super.ref, this.att);

  PlanAttendance att;
  final calls = <Map<String, dynamic>>[];
  final _gates = <Completer<bool>>[];
  bool hold = false;
  int running = 0;
  int maxRunning = 0;

  int get waiting => _gates.length;

  void release({bool fail = false}) => _gates.removeAt(0).complete(fail);

  @override
  Future<PlanAttendance?> getSharedAttendancePlan(int id, String key) async => att;

  @override
  Future<bool> verifySharedAttendanceEditKey(int id, String key, String editKey) async => true;

  @override
  RealtimeChannel watchSharedAttendancePlan(int id, void Function(Map<String, dynamic> row) onUpdate) =>
      _MockChannel();

  @override
  Future<void> unwatch(RealtimeChannel channel) async {}

  @override
  Future<void> updateSharedAttendancePlan(
      int id, String key, String editKey, Map<String, dynamic> planColumns) async {
    calls.add(planColumns);
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      var fail = false;
      if (hold) {
        final gate = Completer<bool>();
        _gates.add(gate);
        fail = await gate.future;
      }
      if (fail) throw Exception('network down');
      att = PlanAttendance.fromJson({...att.toJson(), ...planColumns});
    } finally {
      running--;
    }
  }
}

void main() {
  late _FakeRepo repo;

  const plan1 = Plan(
    id: 'p1',
    time: '18:00',
    title: 'Erster',
    fields: [PlanField(id: 'a', name: 'Einspielen', time: '30')],
  );
  const plan2 = Plan(
    id: 'p2',
    time: '20:00',
    title: 'Zweiter',
    fields: [PlanField(id: 'b', name: 'Stück B', time: '5')],
  );

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        publicPlanRepositoryProvider.overrideWith((ref) => repo = _FakeRepo(
              ref,
              const PlanAttendance(id: 5, date: '2030-01-01', plan: plan1, extraPlans: [plan2]),
            )),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SharedPlanPage(attendanceId: 5, shareKey: 's1', editKey: 'e1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder minutesField() =>
      find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);

  Map<String, dynamic> fieldOf(Map<String, dynamic> plan) =>
      (plan['fields'] as List).single as Map<String, dynamic>;

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('plan switch waits for the running write; next write keeps plan 1', (tester) async {
    await pumpPage(tester);
    expect(find.text('Einspielen'), findsOneWidget);

    repo.hold = true;
    await tester.enterText(minutesField(), '45');
    await tester.pump();
    expect(repo.waiting, 1);

    // Switch requested while plan 1's write is still running: blocked.
    await tester.tap(find.text('Plan 2'));
    await tester.pump();
    expect(find.text('Einspielen'), findsOneWidget);
    expect(find.text('Stück B'), findsNothing);

    repo.release();
    await tester.pumpAndSettle();
    expect(find.text('Stück B'), findsOneWidget, reason: 'switched once plan 1 was stored');
    expect(find.text('Einspielen'), findsNothing);

    await tester.enterText(minutesField(), '7');
    await tester.pump();
    repo.release();
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(2));
    final second = repo.calls.last;
    expect(fieldOf(second['plan'] as Map<String, dynamic>)['time'], '45',
        reason: "plan 1's new state is never overwritten by its old state");
    expect(fieldOf((second['extra_plans'] as List).single as Map<String, dynamic>)['time'], '7');
    expect(repo.maxRunning, 1, reason: 'writes never overlap');
    await disposePage(tester);
  });

  testWidgets('edits during a running write are written afterwards from the newest state',
      (tester) async {
    await pumpPage(tester);
    repo.hold = true;
    await tester.enterText(minutesField(), '40');
    await tester.pump();
    await tester.enterText(minutesField(), '41');
    await tester.pump();
    await tester.enterText(minutesField(), '42');
    await tester.pump();
    expect(repo.waiting, 1, reason: 'the second write waits for the first');

    repo.release();
    await tester.pump();
    await tester.pump();
    expect(repo.waiting, 1, reason: 'queued edits collapse into one write');
    repo.release();
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(2));
    expect(fieldOf(repo.calls.last['plan'] as Map<String, dynamic>)['time'], '42');
    expect(repo.maxRunning, 1);
    await disposePage(tester);
  });

  testWidgets('a failed write keeps plan 1 open; the next switch retries', (tester) async {
    await pumpPage(tester);
    repo.hold = true;
    await tester.enterText(minutesField(), '45');
    await tester.pump();
    await tester.tap(find.text('Plan 2'));
    await tester.pump();

    repo.release(fail: true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Einspielen'), findsOneWidget, reason: 'failed write: no switch');
    expect(find.text('Stück B'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    repo.hold = false;
    await tester.tap(find.text('Plan 2'));
    await tester.pumpAndSettle();
    expect(find.text('Stück B'), findsOneWidget);
    expect(repo.calls, hasLength(2));
    expect(fieldOf(repo.calls.last['plan'] as Map<String, dynamic>)['time'], '45');
    expect(fieldOf(repo.att.plan!.toJson())['time'], '45');
    await disposePage(tester);
  });
}
