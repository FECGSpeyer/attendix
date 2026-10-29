import 'dart:async';
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/redesign/data/rd_event_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_event_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_pult_view.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_split_view.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Person _person(int id, String first, String last, int group, String groupName) =>
    TestFactories.createPerson(id: id, firstName: first, lastName: last, tenantId: 7, instrument: group)
        .copyWith(groupName: groupName);

final _persons = [
  _person(1, 'Sophie', 'Lang', 10, 'Holz'),
  _person(2, 'Anna', 'Berg', 10, 'Holz'),
  _person(3, 'Max', 'Huber', 20, 'Trompete'),
  _person(4, 'Jan', 'Ott', 20, 'Trompete'),
  _person(5, 'Eva', 'Wolf', 30, 'Horn'),
];

List<PersonAttendance> _rows() => [
      TestFactories.createPersonAttendance(id: 'pa-1', attendanceId: 21, personId: 1, status: AttendanceStatus.lateExcused, notes: 'Zug'),
      TestFactories.createPersonAttendance(id: 'pa-2', attendanceId: 21, personId: 2),
      TestFactories.createPersonAttendance(id: 'pa-3', attendanceId: 21, personId: 3, status: AttendanceStatus.excused, notes: 'Krank'),
      TestFactories.createPersonAttendance(id: 'pa-4', attendanceId: 21, personId: 4, status: AttendanceStatus.excused, notes: 'Arbeit'),
      TestFactories.createPersonAttendance(id: 'pa-5', attendanceId: 21, personId: 5),
    ];

/// Online, nothing pending: every write goes straight to the repository.
/// (The real queue serialises through a static lock that outlives a
/// widget test's fake clock.)
class _OnlineQueue extends OfflineQueueNotifier {
  @override
  int build() => 0;

  @override
  Future<bool> enqueueIfOffline(
    String personAttendanceId,
    Map<String, dynamic> payload, {
    int? attendanceId,
    OfflineWriteSession? session,
  }) async {
    (session ?? captureWriteSession()).ensureCurrent();
    return false;
  }
}

class _Harness {
  _Harness({
    this.role = Role.admin,
    this.scope = const AttendanceGroupScope.all(),
    this.valid = true,
    this.canViewNotes = true,
  });

  final Role role;
  final AttendanceGroupScope scope;
  final bool valid;
  final bool canViewNotes;
  final repo = MockAttendanceRepository();
  final writes = <String>[];

  /// When set, every write waits for it after it was recorded.
  Completer<void>? gate;

  Widget app({RdEventTab tab = RdEventTab.overview, bool split = false}) {
    when(() => repo.hasTenantId).thenReturn(true);
    when(() => repo.validatePersonAttendanceTenant(any())).thenAnswer((_) async => valid);
    when(() => repo.updatePersonAttendance(
          any(),
          any(),
          isSessionCurrent: any(named: 'isSessionCurrent'),
          actingUserId: any(named: 'actingUserId'),
        )).thenAnswer((inv) async {
      final id = inv.positionalArguments[0] as String;
      final updates = Map<String, dynamic>.from(inv.positionalArguments[1] as Map);
      writes.add('$id $updates');
      await gate?.future;
      return TestFactories.createPersonAttendance(id: id, attendanceId: 21);
    });

    final authEvents = StreamController<AuthChangeEvent>.broadcast();
    addTearDown(authEvents.close);
    final router = GoRouter(
      initialLocation: '/termine/21',
      routes: [
        GoRoute(
          path: '/termine',
          builder: (_, __) => const Scaffold(body: Text('page termine')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, __) {
                final page = RdEventPage(attendanceId: 21, initialTab: tab);
                return split ? RdSplitScope(isDetail: true, selectedId: 21, child: page) : page;
              },
            ),
          ],
        ),
        GoRoute(
          path: '/attendance/:id',
          builder: (_, state) => Scaffold(body: Text('page attendance ${state.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(enabled: true)),
        effectiveRoleProvider.overrideWithValue(role),
        currentTenantIdProvider.overrideWith((ref) => 7),
        attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
        offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
        offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
        offlineQueueNotifierProvider.overrideWith(_OnlineQueue.new),
        attendanceDetailProvider.overrideWith((ref, id) async => TestFactories.createAttendance(
              id: 21,
              tenantId: 7,
              date: _day(1),
              typeId: 'p',
              typeInfo: 'Gesamtprobe',
              startTime: '19:30',
              endTime: '21:30',
              notes: 'Bitte Konzertmappe mitbringen.',
            )),
        attendanceTypeForAttendanceProvider.overrideWith(
          (ref, id) async => TestFactories.createAttendanceType(id: 'p', name: 'Probe'),
        ),
        personAttendancesForAttendanceProvider.overrideWith((ref, id) async => _rows()),
        filteredPersonsForAttendanceProvider.overrideWith((ref, id) async => _persons),
        groupsProvider.overrideWith((ref) async => [
              TestFactories.createGroup(id: 10, name: 'Holz', index: 1),
              TestFactories.createGroup(id: 20, name: 'Trompete', index: 2),
              TestFactories.createGroup(id: 30, name: 'Horn', index: 3),
            ]),
        mainGroupProvider.overrideWith((ref) async => null),
        attendanceGroupScopeProvider.overrideWith((ref) async => scope),
        canViewAttendanceNotesProvider.overrideWithValue(canViewNotes),
      ],
      child: MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        routerConfig: router,
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

RdMember _m(int id, AttendanceStatus status, {int? group = 1, String? changedAt}) => RdMember(
      person: TestFactories.createPerson(id: id, firstName: 'P$id', lastName: 'X', instrument: group)
          .copyWith(groupName: group == null ? null : 'G$group'),
      status: status,
      changedAt: changedAt,
    );

/// REDESIGN: a Termin in the new design (canvas D4 Überblick, D5 Anwesenheit).
void main() {
  setUpAll(() async {
    registerFallbackValue(<String, dynamic>{});
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Termin logic', () {
    test('register gaps: groups where nobody will be there, biggest first', () {
      final gaps = rdRegisterGaps([
        _m(1, AttendanceStatus.excused, group: 1),
        _m(2, AttendanceStatus.absent, group: 1),
        _m(3, AttendanceStatus.excused, group: 2),
        _m(4, AttendanceStatus.present, group: 2),
        _m(5, AttendanceStatus.excused, group: 3),
        _m(6, AttendanceStatus.excused, group: null),
      ]);
      expect(gaps.map((g) => g.group), ['G1', 'G3']);
      expect(gaps.first.members.map((m) => m.id), [1, 2]);
    });

    test('later counts as there (no gap)', () {
      expect(rdRegisterGaps([_m(1, AttendanceStatus.lateExcused)]), isEmpty);
    });

    test('sign-outs: excused and later, latest change first', () {
      final list = rdSignouts([
        _m(1, AttendanceStatus.excused, changedAt: '2026-10-27T10:00:00'),
        _m(2, AttendanceStatus.present, changedAt: '2026-10-29T10:00:00'),
        _m(3, AttendanceStatus.lateExcused, changedAt: '2026-10-28T10:00:00'),
      ]);
      expect(list.map((m) => m.id), [3, 1]);
    });

    test('tapping the active button undoes it', () {
      const n = AttendanceStatus.neutral, p = AttendanceStatus.present, e = AttendanceStatus.excused;
      expect(rdToggleTarget(n, p), p);
      expect(rdToggleTarget(p, p, initial: n), n);
      expect(rdToggleTarget(p, p, initial: e), e);
      expect(rdToggleTarget(p, p, initial: p), n);
      expect(rdToggleTarget(p, p), n);
    });

    test('search matches first and last name', () {
      final m = _m(1, AttendanceStatus.neutral);
      expect(rdMemberMatches(m, ''), isTrue);
      expect(rdMemberMatches(m, 'p1'), isTrue);
      expect(rdMemberMatches(m, ' x '), isTrue);
      expect(rdMemberMatches(m, 'zz'), isFalse);
    });
  });

  group('RedesignRoutes.roleRedirect', () {
    test('Termin list: parents to their portal, applicants to Heute', () {
      expect(RedesignRoutes.roleRedirect('/termine', Role.parent), '/parents');
      expect(RedesignRoutes.roleRedirect('/termine', Role.applicant), '/heute');
      for (final role in [Role.admin, Role.helper, Role.viewer, Role.player, Role.voiceLeader]) {
        expect(RedesignRoutes.roleRedirect('/termine', role), isNull, reason: role.name);
      }
    });

    test('a Termin only for roles that may open it in the old design', () {
      for (final role in Role.values) {
        final target = RedesignRoutes.roleRedirect('/termine/12', role);
        if (role.isParent) {
          expect(target, '/parents');
        } else if (role.isApplicant) {
          expect(target, '/heute');
        } else if (role.canAddAttendance) {
          expect(target, isNull, reason: role.name);
        } else {
          expect(target, '/termine', reason: role.name);
        }
      }
      expect(RedesignRoutes.roleRedirect('/attendance/12', Role.player), isNull);
    });

    test('event links', () {
      expect(RedesignRoutes.event(5), '/termine/5');
      expect(RedesignRoutes.event(5, record: true), '/termine/5?tab=anwesenheit');
    });
  });

  test('the Termin view writes only through the shared write path', () {
    final source = File('lib/features/redesign/presentation/pages/rd_event_page.dart').readAsStringSync();
    expect(source, isNot(contains('updatePersonAttendance(')));
    expect(source, isNot(contains('.from(')));
    // Serialised per person (_serial), see "Rückgängig during a slow write".
    expect(source, contains('() => writePersonStatus('));
    expect(source, contains('() => writePersonAttendance('));
    expect(RegExp(r'await _serial\(').allMatches(source), hasLength(2));
  });

  testWidgets('Überblick: answers, empty register, sign-outs, notes', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness();
    await tester.pumpWidget(h.app());
    await _settle(tester);

    expect(find.text('Gesamtprobe'), findsOneWidget);
    expect(find.text('Probe'), findsOneWidget);
    expect(find.text('Morgen'), findsOneWidget);
    expect(find.text('5 eingeladen'), findsOneWidget);
    expect(find.text('0 zugesagt'), findsOneWidget);
    expect(find.text('2 entschuldigt'), findsWidgets);
    expect(find.text('2 ohne Antwort'), findsOneWidget);
    expect(find.textContaining('Trompete: 0 von 2 da.'), findsOneWidget);
    expect(find.textContaining('Max Huber, Jan Ott haben abgesagt.'), findsOneWidget);
    expect(find.text('ABMELDUNGEN'), findsOneWidget);
    expect(find.text('Trompete · „Krank“'), findsOneWidget);
    expect(find.text('Holz · „Zug“'), findsOneWidget);
    expect(find.text('Bitte Konzertmappe mitbringen.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(h.writes, isEmpty);

    await tester.tap(find.text('Alle Details'));
    await _settle(tester);
    expect(find.text('page attendance 21'), findsOneWidget);
  });

  testWidgets('Anwesenheit: tap writes the status, Rückgängig writes it back', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness();
    await tester.pumpWidget(h.app(tab: RdEventTab.record));
    await _settle(tester);

    expect(find.text('0 da'), findsOneWidget);
    expect(find.text('2 offen'), findsOneWidget);
    expect(find.text('HOLZ · 2'), findsOneWidget);

    final anna = find.byKey(const ValueKey('rd-record-2'));
    await tester.tap(find.descendant(of: anna, matching: find.bySemanticsLabel('Anwesend')));
    await _settle(tester);
    expect(h.writes, ['pa-2 {status: 1}']);
    expect(find.text('1 da'), findsOneWidget);
    expect(find.text('Anna Berg: Anwesend'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await _settle(tester);
    expect(h.writes.last, 'pa-2 {status: 0}');
    expect(find.text('0 da'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rückgängig during a slow write runs after it, never before', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness()..gate = Completer<void>();
    await tester.pumpWidget(h.app(tab: RdEventTab.record));
    await _settle(tester);

    final anna = find.byKey(const ValueKey('rd-record-2'));
    await tester.tap(find.descendant(of: anna, matching: find.bySemanticsLabel('Anwesend')));
    await _settle(tester);
    expect(h.writes, ['pa-2 {status: 1}']);

    await tester.tap(find.text('Rückgängig'));
    await _settle(tester);
    // The undo waits for the first write of the same person.
    expect(h.writes, ['pa-2 {status: 1}']);
    expect(find.text('0 da'), findsOneWidget);

    h.gate!.complete();
    await _settle(tester);
    expect(h.writes, ['pa-2 {status: 1}', 'pa-2 {status: 0}']);
    expect(find.text('0 da'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Anwesenheit: all open as present, then undo', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness();
    await tester.pumpWidget(h.app(tab: RdEventTab.record));
    await _settle(tester);

    await tester.tap(find.text('Alle Offenen als anwesend'));
    await _settle(tester);
    expect(h.writes.toSet(), {'pa-2 {status: 1}', 'pa-5 {status: 1}'});
    expect(find.text('2 Personen als anwesend'), findsOneWidget);
    expect(find.text('2 da'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await _settle(tester);
    expect(h.writes.skip(2).toSet(), {'pa-2 {status: 0}', 'pa-5 {status: 0}'});
    expect(find.text('2 offen'), findsOneWidget);
  });

  testWidgets('a row of another tenant is not written and reverts', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness(valid: false);
    await tester.pumpWidget(h.app(tab: RdEventTab.record));
    await _settle(tester);

    final eva = find.byKey(const ValueKey('rd-record-5'));
    await tester.tap(find.descendant(of: eva, matching: find.bySemanticsLabel('Anwesend')));
    await _settle(tester);
    expect(h.writes, isEmpty);
    expect(find.text('0 da'), findsOneWidget);
  });

  testWidgets('Helfer only see their own group, without notes', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness(role: Role.helper, scope: const AttendanceGroupScope.group(20), canViewNotes: false);
    await tester.pumpWidget(h.app(tab: RdEventTab.record));
    await _settle(tester);

    expect(find.text('Max Huber'), findsOneWidget);
    expect(find.text('Jan Ott'), findsOneWidget);
    expect(find.text('Anna Berg'), findsNothing);
    expect(find.text('„Krank“'), findsNothing);
  });

  testWidgets('weitere Status: the sheet sets Abwesend and the note', (tester) async {
    _size(tester, const Size(393, 852));
    final h = _Harness();
    await tester.pumpWidget(h.app(tab: RdEventTab.record));
    await _settle(tester);

    await tester.tap(find.bySemanticsLabel('Weitere Status und Notiz für Eva Wolf'));
    await _settle(tester);
    await tester.tap(find.text('Abwesend').last);
    await tester.enterText(find.byType(TextField), 'Nicht erschienen');
    await tester.tap(find.text('Fertig'));
    await _settle(tester);

    expect(h.writes, ['pa-5 {status: 4}', 'pa-5 {notes: Nicht erschienen}']);
  });

  group('Pultmodus', () {
    Future<void> openPult(WidgetTester tester, _Harness h, Size size) async {
      _size(tester, size);
      await tester.pumpWidget(h.app(tab: RdEventTab.record));
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Pultmodus'));
      await _settle(tester);
    }

    testWidgets('tiles per register: tap = present, tap again = back', (tester) async {
      final h = _Harness();
      await openPult(tester, h, const Size(1024, 768));

      expect(find.text('Gesamtprobe · Pultmodus'), findsOneWidget);
      expect(find.textContaining('Antippen = da'), findsOneWidget);
      expect(find.text('Holz'), findsOneWidget);
      expect(find.text('Trompete'), findsOneWidget);
      expect(find.text('0 / 2 da'), findsNWidgets(2));
      expect(find.text('2 offen'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rd-pult-2')));
      await _settle(tester);
      expect(h.writes, ['pa-2 {status: 1}']);
      expect(find.text('1 / 2 da'), findsOneWidget);
      expect(find.text('1 da'), findsOneWidget);
      expect(find.text('Anna Berg: Anwesend'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('rd-pult-2')));
      await _settle(tester);
      expect(h.writes.last, 'pa-2 {status: 0}');
      expect(find.text('0 da'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an excused person who comes anyway, and back', (tester) async {
      final h = _Harness();
      await openPult(tester, h, const Size(1024, 768));

      expect(find.text('Entschuldigt · „Krank“'), findsOneWidget);
      expect(find.text('Entschuldigt · „Arbeit“'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rd-pult-3')));
      await _settle(tester);
      expect(h.writes, ['pa-3 {status: 1}']);
      await tester.tap(find.byKey(const ValueKey('rd-pult-3')));
      await _settle(tester);
      expect(h.writes.last, 'pa-3 {status: 2}');
    });

    testWidgets('all open present with undo, long press for more', (tester) async {
      final h = _Harness();
      await openPult(tester, h, const Size(1024, 768));

      await tester.tap(find.text('Alle Offenen da'));
      await _settle(tester);
      expect(h.writes.toSet(), {'pa-2 {status: 1}', 'pa-5 {status: 1}'});
      await tester.tap(find.text('Rückgängig'));
      await _settle(tester);
      expect(h.writes.skip(2).toSet(), {'pa-2 {status: 0}', 'pa-5 {status: 0}'});

      await tester.ensureVisible(find.byKey(const ValueKey('rd-pult-5')));
      await tester.pump();
      await tester.longPress(find.byKey(const ValueKey('rd-pult-5')));
      await _settle(tester);
      expect(find.text('NOTIZ FÜR DIESEN TERMIN'), findsOneWidget);
    });

    testWidgets('Fertig and the back gesture return to the list', (tester) async {
      final h = _Harness();
      await openPult(tester, h, const Size(1024, 768));
      await tester.tap(find.text('Fertig'));
      await _settle(tester);
      expect(find.text('Alle Offenen als anwesend'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Pultmodus'));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Alle Offenen als anwesend'), findsOneWidget);
      expect(find.text('page termine'), findsNothing);
    });

    testWidgets('grid columns follow the width; fits a 320 px phone', (tester) async {
      expect(RdPultView.columnsFor(300), 2);
      expect(RdPultView.columnsFor(984), 5);
      expect(RdPultView.columnsFor(3000), 8);
      final h = _Harness();
      await openPult(tester, h, const Size(320, 640));
      expect(find.text('Gesamtprobe · Pultmodus'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard (desktop)', () {
    testWidgets('A, V, F set the status and move on; Ctrl+Z undoes', (tester) async {
      _size(tester, const Size(1280, 900));
      final h = _Harness();
      await tester.pumpWidget(h.app(tab: RdEventTab.record));
      await _settle(tester);
      expect(find.textContaining('Tastatur: A anwesend'), findsOneWidget);

      // First row: Anna Berg (Holz, sorted by last name).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await _settle(tester);
      expect(h.writes, ['pa-2 {status: 1}']);

      // Then Sophie Lang (Verspätet entschuldigt).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await _settle(tester);
      expect(h.writes.last, 'pa-1 {status: 4}');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(tester);
      expect(h.writes.last, 'pa-1 {status: 5}');

      // ↑↑ goes back to Anna, V sets her late.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await _settle(tester);
      expect(h.writes.last, 'pa-2 {status: 3}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('typing in the search does not set a status', (tester) async {
      _size(tester, const Size(1280, 900));
      final h = _Harness();
      await tester.pumpWidget(h.app(tab: RdEventTab.record));
      await _settle(tester);

      await tester.tap(find.bySemanticsLabel('Person suchen'));
      await _settle(tester);
      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await _settle(tester);
      expect(h.writes, isEmpty);
    });

    testWidgets('no keyboard hint on phones', (tester) async {
      _size(tester, const Size(393, 852));
      await tester.pumpWidget(_Harness().app(tab: RdEventTab.record));
      await _settle(tester);
      expect(find.textContaining('Tastatur:'), findsNothing);
    });
  });

  testWidgets('on the right of the split view: no back link', (tester) async {
    _size(tester, const Size(880, 800));
    await tester.pumpWidget(_Harness().app(split: true));
    await _settle(tester);
    expect(find.text('Gesamtprobe'), findsOneWidget);
    expect(find.bySemanticsLabel('Termine'), findsNothing);
    expect(find.text('Alle Details'), findsOneWidget);
  });

  testWidgets('fits on a 320 px phone', (tester) async {
    _size(tester, const Size(320, 640));
    for (final tab in RdEventTab.values) {
      await tester.pumpWidget(_Harness().app(tab: tab));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: tab.name);
    }
  });
}
