// SOL_FIX26 item 2: delayed realtime echoes of older own writes never reset
// the public edit link's editor, also after every write finished.
import 'dart:convert';

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

/// Fake that stores every write and keeps the stored rows, so the test can
/// replay their realtime echoes later (as the database would send them).
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
    // Postgres orders jsonb keys differently: the echo must still match.
    final row = _json(shared!.toJson());
    row['fields'] = [
      for (final f in row['fields'] as List)
        Map<String, dynamic>.fromEntries((f as Map<String, dynamic>).entries.toList().reversed),
    ];
    storedRows.add(row);
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
  Finder minutesField() => minutesFields().first;

  String minutesOnScreen(WidgetTester tester) => tester.widget<TextField>(minutesField()).controller!.text;

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  /// Two completed writes (30 → 40 → 50), then both echoes in order: the
  /// editor stays at write 2 throughout and a follow-up save keeps it.
  Future<void> twoWritesThenEchoes(WidgetTester tester, String Function(Map<String, dynamic>) storedMinutes) async {
    await tester.enterText(minutesField(), '40');
    await tester.pumpAndSettle();
    await tester.enterText(minutesField(), '50');
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(2));
    expect(repo.storedRows, hasLength(2));

    repo.onUpdate!(repo.storedRows[0]);
    await tester.pumpAndSettle();
    expect(minutesOnScreen(tester), '50', reason: 'echo of write 1 is stale');

    repo.onUpdate!(repo.storedRows[1]);
    await tester.pumpAndSettle();
    expect(minutesOnScreen(tester), '50');

    // A follow-up edit persists on top of write 2.
    await tester.enterText(minutesFields().last, '9');
    await tester.pumpAndSettle();
    expect(repo.calls, hasLength(3));
    expect(storedMinutes(repo.calls.last), '50');
  }

  testWidgets('Termin plan: echoes of two finished writes keep write 2', (tester) async {
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
    expect(minutesOnScreen(tester), '30');
    await twoWritesThenEchoes(
      tester,
      (c) => (((_json(c)['plan'] as Map)['fields'] as List).first as Map)['time'] as String,
    );
    await disposePage(tester);
  });

  testWidgets('ad-hoc plan: echoes of two finished writes keep write 2', (tester) async {
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
    expect(minutesOnScreen(tester), '30');
    await twoWritesThenEchoes(tester, (c) => ((_json(c)['fields'] as List).first as Map)['time'] as String);
    await disposePage(tester);
  });

  test('a foreign change is applied, an older own write is not', () {
    final log = OwnWriteLog(capacity: 3);
    log.record({'plan': {'time': '18:00', 'title': null}});
    log.record({'plan': {'time': '19:00'}});
    expect(log.classify({'plan': {'time': '20:00'}}), EchoKind.foreign);
    expect(log.classify({'other': 1}), EchoKind.foreign);
    expect(log.classify({'plan': {'time': '18:00'}, 'x': 1}), EchoKind.olderOwn);
    final failed = log.record({'plan': {'time': '21:00'}});
    log.forget(failed);
    expect(log.classify({'plan': {'time': '19:00'}}), EchoKind.latestOwn);
  });
}
