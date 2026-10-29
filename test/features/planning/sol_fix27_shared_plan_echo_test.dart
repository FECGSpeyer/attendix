// SOL_FIX27 item 3: an own write suppresses at most one matching realtime
// echo, and only shortly after it completed. A foreign change back to an
// earlier own state (after the own echoes arrived) is applied, not dropped
// as a stale own echo.
import 'dart:convert';
import 'dart:io';

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

Map<String, dynamic> _json(Object? v) => jsonDecode(jsonEncode(v)) as Map<String, dynamic>;

/// Stores every write and keeps the stored rows, so the test can replay
/// realtime rows (own echoes and foreign changes) as the database sends them.
class _FakeRepo extends PublicPlanRepository {
  _FakeRepo(super.ref, {this.att, this.shared});

  PlanAttendance? att;
  SharedPlan? shared;
  final storedRows = <Map<String, dynamic>>[];
  final calls = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic> row)? onUpdate;

  @override
  Future<PlanAttendance?> getSharedAttendancePlan(int id, String key) async => att;

  @override
  Future<bool> verifySharedAttendanceEditKey(int id, String key, String editKey) async => true;

  @override
  RealtimeChannel watchSharedAttendancePlan(int id, void Function(Map<String, dynamic> row) onUpdate) {
    this.onUpdate = onUpdate;
    return _MockChannel();
  }

  @override
  Future<SharedPlan?> getSharedPlan(String key) async => shared;

  @override
  Future<bool> verifySharedPlanEditKey(String key, String editKey) async => true;

  @override
  RealtimeChannel watchSharedPlan(String key, void Function(Map<String, dynamic> row) onUpdate) {
    this.onUpdate = onUpdate;
    return _MockChannel();
  }

  @override
  Future<void> unwatch(RealtimeChannel channel) async {}

  @override
  Future<void> updateSharedAttendancePlan(
      int id, String key, String editKey, Map<String, dynamic> planColumns) async {
    calls.add(planColumns);
    att = PlanAttendance.fromJson(_json({...att!.toJson(), ...planColumns}));
    storedRows.add(_json(att!.toJson()));
  }

  @override
  Future<void> updateSharedPlan(String key, String editKey,
      {required List<PlanField> fields, String? title, String? time, String? endTime}) async {
    final data = PublicPlanRepository.sharedPlanUpdateData(fields: fields, title: title, time: time, endTime: endTime);
    calls.add(data);
    shared = SharedPlan.fromJson(_json({...shared!.toJson(), ...data}));
    storedRows.add(_json(shared!.toJson()));
  }
}

void main() {
  late _FakeRepo repo;

  Future<void> pumpPage(WidgetTester tester, _FakeRepo Function(Ref ref) create, SharedPlanPage page) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [publicPlanRepositoryProvider.overrideWith((ref) => repo = create(ref))],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder minutesFields() =>
      find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.number);

  String minutesOnScreen(WidgetTester tester) => tester.widget<TextField>(minutesFields().first).controller!.text;

  /// Own edits 30 → 40 → 50, both echoes arrive, then another editor sets
  /// the full state back to 40 (the stored row of own write 1): it is
  /// applied, and a follow-up save builds on it.
  Future<void> foreignRevertAfterEchoes(
      WidgetTester tester, String Function(Map<String, dynamic>) storedMinutes) async {
    await tester.enterText(minutesFields().first, '40');
    await tester.pumpAndSettle();
    await tester.enterText(minutesFields().first, '50');
    await tester.pumpAndSettle();
    expect(repo.storedRows, hasLength(2));
    final state40 = repo.storedRows[0];
    final state50 = repo.storedRows[1];

    repo.onUpdate!(state40); // echo of own write 1: stale, ignored
    await tester.pumpAndSettle();
    expect(minutesOnScreen(tester), '50');
    repo.onUpdate!(state50); // echo of own write 2
    await tester.pumpAndSettle();
    expect(minutesOnScreen(tester), '50');

    // The minutes input only takes over outside values without focus.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));

    repo.onUpdate!(_json(state40)); // another editor: full state back to 40
    await tester.pumpAndSettle();
    expect(minutesOnScreen(tester), '40', reason: 'a foreign revert is applied');

    await tester.enterText(minutesFields().last, '9');
    await tester.pumpAndSettle();
    expect(storedMinutes(repo.calls.last), '40', reason: 'the follow-up save keeps the foreign change');
  }

  testWidgets('Termin plan: a foreign revert to an earlier own state is applied', (tester) async {
    await pumpPage(
      tester,
      (ref) => _FakeRepo(ref,
          att: const PlanAttendance(
            id: 5,
            date: '2030-01-01',
            plan: Plan(time: '18:00', title: 'Probe', fields: [
              PlanField(id: 'a', name: 'Einspielen', time: '30'),
              PlanField(id: 'b', name: 'Stück B', time: '5'),
            ]),
          )),
      const SharedPlanPage(attendanceId: 5, shareKey: 's1', editKey: 'e1'),
    );
    await foreignRevertAfterEchoes(
      tester,
      (c) => (((_json(c)['plan'] as Map)['fields'] as List).first as Map)['time'] as String,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ad-hoc plan: a foreign revert to an earlier own state is applied', (tester) async {
    await pumpPage(
      tester,
      (ref) => _FakeRepo(ref,
          shared: const SharedPlan(
            id: 'k1',
            editKey: 'e1',
            planTitle: 'Ablauf',
            date: '2030-01-01',
            time: '2030-01-01T18:00',
            fields: [
              PlanField(id: 'a', name: 'Einspielen', time: '30'),
              PlanField(id: 'b', name: 'Stück B', time: '5'),
            ],
          )),
      const SharedPlanPage(shareKey: 'k1', editKey: 'e1'),
    );
    await foreignRevertAfterEchoes(tester, (c) => ((_json(c)['fields'] as List).first as Map)['time'] as String);
    await tester.pumpWidget(const SizedBox());
  });

  group('OwnWriteLog', () {
    Map<String, dynamic> t(String time) => {
          'plan': {'time': time},
        };

    test('each own write suppresses at most one echo', () {
      final log = OwnWriteLog();
      log.complete(log.record(t('40')));
      log.complete(log.record(t('50')));
      expect(log.classify(t('40')), EchoKind.olderOwn);
      expect(log.classify(t('50')), EchoKind.latestOwn);
      expect(log.classify(t('40')), EchoKind.foreign, reason: 'write 1 was consumed by its echo');
      expect(log.classify(t('50')), EchoKind.foreign, reason: 'write 2 was consumed by its echo');
    });

    test('the echo of a newer write drops every older write', () {
      final log = OwnWriteLog();
      log.complete(log.record(t('40')));
      log.complete(log.record(t('50')));
      // Echo of write 1 was lost; write 2's echo arrives.
      expect(log.classify(t('50')), EchoKind.latestOwn);
      expect(log.classify(t('40')), EchoKind.foreign);
    });

    test('only within the window after the write completed', () {
      var now = DateTime(2026, 1, 1, 12);
      final log = OwnWriteLog(clock: () => now);
      log.record(t('40'));
      now = now.add(const Duration(minutes: 5));
      expect(log.classify(t('40')), EchoKind.latestOwn, reason: 'a running write never expires');

      log.complete(log.record(t('50')));
      now = now.add(const Duration(seconds: 14));
      log.complete(log.record(t('60')));
      now = now.add(const Duration(seconds: 2));
      // Write 50 completed 16 s ago: expired (and with it every older write).
      expect(log.classify(t('50')), EchoKind.foreign);
      expect(log.classify(t('60')), EchoKind.latestOwn);
    });

    test('a newer write that expired drops the older ones too', () {
      var now = DateTime(2026, 1, 1, 12);
      final log = OwnWriteLog(clock: () => now);
      log.complete(log.record(t('40')));
      log.complete(log.record(t('50')));
      now = now.add(const Duration(seconds: 16));
      expect(log.classify(t('40')), EchoKind.foreign);
      expect(log.classify(t('50')), EchoKind.foreign);
    });

    test('a failed write suppresses nothing; the page starts each window after the write', () {
      final log = OwnWriteLog();
      final id = log.record(t('1'));
      log.forget(id);
      expect(log.classify(t('1')), EchoKind.foreign);
      final src = File('lib/features/planning/presentation/pages/shared_plan_page.dart').readAsStringSync();
      expect(RegExp(r'_ownWrites\.complete\(writeId\)').allMatches(src), hasLength(2));
    });
  });
}
