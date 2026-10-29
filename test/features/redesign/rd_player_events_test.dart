import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_own_event_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_absence_sheet.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_signout_sheet.dart';
import 'package:attendix/features/self_service/presentation/widgets/self_service_event_actions.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO')
        .copyWith(absenceReasons: const ['Krank', 'Urlaub'], lateReasons: const ['Stau']);
  }
}

/// Records the absence instead of writing it.
class _FakeAbsenceNotifier extends PlayerAbsenceNotifier {
  _FakeAbsenceNotifier(this.calls);
  final List<String> calls;

  @override
  Future<int?> addAbsence({
    required int personId,
    required String fromDate,
    required String untilDate,
    required String reason,
  }) async {
    calls.add('$personId $fromDate $untilDate $reason');
    return 1;
  }
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _day(int offset) => _iso(DateTime.now().add(Duration(days: offset)));

CrossTenantPersonAttendance _own(
  String id,
  String date,
  AttendanceStatus status, {
  String? place,
  int tenantId = 7,
  AttendanceType? type,
  String? dutyState,
}) =>
    CrossTenantPersonAttendance(
      attendanceType: type,
      dutyState: dutyState,
      id: id,
      attendanceId: int.parse(id),
      status: status,
      date: date,
      typeInfo: 'Probe $id',
      startTime: '19:30',
      endTime: '21:30',
      place: place,
      tenantId: tenantId,
      tenantName: 'SO',
      tenantColor: 'primary',
    );

SelfServiceEventActions _actions(List<String> calls) => SelfServiceEventActions(
      absenceReasons: const ['Krank', 'Arbeit'],
      lateReasons: const ['Stau'],
      signIn: (att, note) async {
        calls.add('in ${att.id}');
        return true;
      },
      signOut: (att, reason, isLate) async {
        calls.add('out ${att.id} $reason $isLate');
        return true;
      },
      updateNote: (att, note) async => true,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _themed(Widget child) => MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      home: Scaffold(body: child),
    );

/// REDESIGN: own Termin (S3), Abmelden (S4), Abwesenheit (S5).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  group('own Termin', () {
    test('found in upcoming and past by its row id', () {
      final data = SignoutData(
        current: _own('1', _day(0), AttendanceStatus.neutral),
        upcoming: [_own('2', _day(3), AttendanceStatus.present)],
        past: [_own('3', _day(-3), AttendanceStatus.present)],
      );
      expect(rdFindOwnEvent(data, '1')?.attendanceId, 1);
      expect(rdFindOwnEvent(data, '3')?.attendanceId, 3);
      expect(rdFindOwnEvent(data, '9'), isNull);
    });

    test('rows: the card covers yes/no, infos are listed separately', () {
      final actions = _actions([]);
      final split = rdOwnEventActions(actions, _own('1', _day(2), AttendanceStatus.neutral, place: 'Saal'));
      expect(split.answer, isNot(contains(SelfServiceActionType.signIn)));
      expect(split.answer, isNot(contains(SelfServiceActionType.signOut)));
      expect(split.answer, contains(SelfServiceActionType.signInWithNote));
      expect(split.info, [SelfServiceActionType.openNavigation]);
    });
  });

  group('past and duty Termine', () {
    test('past: no answer actions, only an excused one keeps them (like "Meine Termine")', () {
      final actions = _actions([]);
      final present =
          rdOwnEventActions(actions, _own('4', _day(-2), AttendanceStatus.present, place: 'Saal'), past: true);
      expect(present.answer, isEmpty);
      expect(present.info, [SelfServiceActionType.openNavigation]);
      final excused = rdOwnEventActions(actions, _own('5', _day(-2), AttendanceStatus.excused), past: true);
      expect(excused.answer, contains(SelfServiceActionType.undoSignout));

      final data = SignoutData(
        upcoming: [_own('6', _day(2), AttendanceStatus.neutral)],
        past: [_own('4', _day(-2), AttendanceStatus.present)],
      );
      expect(rdIsPastOwnEvent(data, rdFindOwnEvent(data, '4')!), isTrue);
      expect(rdIsPastOwnEvent(data, rdFindOwnEvent(data, '6')!), isFalse);
    });

    test('duty Termine without an own assignment are not listed for an answer', () async {
      final duty = TestFactories.createAttendanceType(id: 'd', name: 'Dienst').copyWith(dutyMode: true);
      final container = ProviderContainer(overrides: [
        signoutDataProvider.overrideWith((ref) async => SignoutData(
              upcoming: [
                _own('7', _day(2), AttendanceStatus.neutral, type: duty),
                _own('8', _day(3), AttendanceStatus.neutral, type: duty, dutyState: 'confirmed'),
                _own('9', _day(4), AttendanceStatus.neutral),
              ],
              past: [_own('10', _day(-4), AttendanceStatus.neutral, type: duty)],
            )),
      ]);
      addTearDown(container.dispose);
      final data = await container.read(rdSignoutDataProvider.future);
      expect(data.allUpcoming.map((a) => a.id), ['8', '9']);
      expect(data.past, isEmpty);
    });

    test('every list of the new design uses the filtered Termine', () {
      for (final path in [
        'lib/features/redesign/presentation/pages/rd_events_page.dart',
        'lib/features/redesign/presentation/pages/rd_own_event_page.dart',
        'lib/features/redesign/presentation/widgets/today/rd_player_today.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('ref.watch(signoutDataProvider)')), reason: path);
        expect(source, contains('ref.watch(rdSignoutDataProvider)'), reason: path);
      }
    });
  });

  group('Abwesenheit helpers', () {
    test('first tap starts, second ends, earlier day swaps, third restarts', () {
      final a = DateTime(2026, 11, 10), b = DateTime(2026, 11, 14), c = DateTime(2026, 11, 8);
      var r = rdNextRange(null, null, a);
      expect((r.from, r.until), (a, null));
      r = rdNextRange(r.from, r.until, b);
      expect((r.from, r.until), (a, b));
      r = rdNextRange(r.from, r.until, c);
      expect((r.from, r.until), (c, null));
      r = rdNextRange(a, null, c);
      expect((r.from, r.until), (c, a));
    });

    test('Termine in the period: own ones of this group, both days included', () {
      final list = [
        _own('1', '2026-11-10', AttendanceStatus.neutral),
        _own('2', '2026-11-14', AttendanceStatus.neutral),
        _own('3', '2026-11-15', AttendanceStatus.neutral),
        _own('4', '2026-11-12', AttendanceStatus.neutral, tenantId: 8),
      ];
      final hit = rdTermineInRange(list, DateTime(2026, 11, 10), DateTime(2026, 11, 14), tenantId: 7);
      expect(hit.map((a) => a.id), ['1', '2']);
    });

    test('an own reason needs at least 5 characters', () {
      expect(rdSignoutReasonValid('Zug'), isFalse);
      expect(rdSignoutReasonValid(' Stau A8 '), isTrue);
    });
  });

  testWidgets('Abmelden: a reason chip signs out through the shared flow', (tester) async {
    final calls = <String>[];
    final att = _own('5', _day(2), AttendanceStatus.neutral);
    await tester.pumpWidget(_themed(Builder(
      builder: (context) => TextButton(
        onPressed: () => showRdSignoutSheet(context, att: att, actions: _actions(calls)),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Ich kann nicht'), findsOneWidget);
    expect(find.text('Ich komme später'), findsOneWidget);
    await tester.tap(find.text('Arbeit'));
    await _settle(tester);
    await tester.tap(find.text('Abmelden'));
    await _settle(tester);
    expect(calls, ['out 5 Arbeit false']);
  });

  testWidgets('Abmelden: "Ich komme später" with an own reason', (tester) async {
    final calls = <String>[];
    final att = _own('6', _day(2), AttendanceStatus.neutral);
    await tester.pumpWidget(_themed(Builder(
      builder: (context) => TextButton(
        onPressed: () => showRdSignoutSheet(context, att: att, actions: _actions(calls), late: true),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Stau'), findsOneWidget);
    await tester.tap(find.text('Anderer Grund'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Zug');
    await _settle(tester);
    await tester.tap(find.text('Verspätung melden'));
    await _settle(tester);
    expect(calls, isEmpty, reason: 'too short');

    await tester.enterText(find.byType(TextField), 'Zug fällt aus');
    await _settle(tester);
    await tester.tap(find.text('Verspätung melden'));
    await _settle(tester);
    expect(calls, ['out 6 Zug fällt aus true']);
  });

  testWidgets('Abwesenheit: period, reason, affected Termine, saved', (tester) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    final next = DateTime(DateTime.now().year, DateTime.now().month + 1);
    final player = TestFactories.createPerson(id: 3, firstName: 'Lea', tenantId: 7);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true)),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        currentSelfServicePlayerProvider.overrideWith((ref) async => player),
        signoutDataProvider.overrideWith((ref) async => SignoutData(
              upcoming: [
                _own('20', _iso(DateTime(next.year, next.month, 11)), AttendanceStatus.neutral),
                _own('21', _iso(DateTime(next.year, next.month, 20)), AttendanceStatus.neutral),
              ],
            )),
        playerAbsenceNotifierProvider.overrideWith(() => _FakeAbsenceNotifier(calls)),
      ],
      child: _themed(Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => showRdAbsenceSheet(context, ref, player, canSelfPause: true),
          child: const Text('open'),
        ),
      )),
    ));
    await _settle(tester);
    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('Zeitraum abwesend'), findsOneWidget);
    expect(find.text('Pausieren'), findsOneWidget);
    await tester.tap(find.byTooltip('Nächster Monat'));
    await _settle(tester);
    await tester.tap(find.text('10'));
    await tester.tap(find.text('12'));
    await _settle(tester);
    expect(find.text('Das betrifft 1 Termin'), findsOneWidget);

    await tester.tap(find.text('Urlaub'));
    await _settle(tester);
    await tester.tap(find.text('Abwesenheit eintragen'));
    await _settle(tester);
    expect(calls, ['3 ${_iso(DateTime(next.year, next.month, 10))} ${_iso(DateTime(next.year, next.month, 12))} Urlaub']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own Termin page: answer card and infos', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/termine/meine/30',
      routes: [
        GoRoute(
          path: '/termine',
          builder: (_, __) => const Scaffold(body: Text('page termine')),
          routes: [
            GoRoute(
              path: 'meine/:paId',
              builder: (_, state) => RdOwnEventPage(personAttendanceId: state.pathParameters['paId']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true)),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        currentSelfServicePlayerProvider.overrideWith(
          (ref) async => TestFactories.createPerson(id: 3, firstName: 'Lea', tenantId: 7),
        ),
        signoutDataProvider.overrideWith((ref) async => SignoutData(
              upcoming: [_own('30', _day(3), AttendanceStatus.neutral, place: 'Stadthalle')],
            )),
      ],
      child: MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        routerConfig: router,
      ),
    ));
    await _settle(tester);

    expect(find.text('Probe 30'), findsOneWidget);
    expect(find.text('Bin dabei'), findsOneWidget);
    expect(find.text('Kann nicht'), findsOneWidget);
    expect(find.text('INFOS ZUM TERMIN'), findsOneWidget);
    expect(find.text('Stadthalle'), findsOneWidget);
    expect(find.text('Mehr zum Termin'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
