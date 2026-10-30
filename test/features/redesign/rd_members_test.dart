import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/player_absence/player_absence.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart'
    show personProvider, personAttendanceStatsProvider, personHistoryProvider;
import 'package:attendix/features/redesign/data/rd_members_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_members_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_person_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_split_view.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _birthdayToday() {
  final d = DateTime.now();
  return '1990-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// Score order (sort_order) puts Violine before Flöte.
final _groups = [
  TestFactories.createGroup(id: 1, name: 'Violine', index: 0).copyWith(sortOrder: 1),
  TestFactories.createGroup(id: 2, name: 'Flöte', index: 1).copyWith(sortOrder: 2),
];

Person _person(int id, String first, String last, int group,
        {bool leader = false, bool paused = false, String? pausedUntil, String? birthday, bool pending = false}) =>
    TestFactories.createPerson(
      id: id,
      firstName: first,
      lastName: last,
      tenantId: 7,
      instrument: group,
      isLeader: leader,
      paused: paused,
      pausedUntil: pausedUntil,
      birthday: birthday ?? '1990-01-01',
      pending: pending,
      email: '${first.toLowerCase()}@example.org',
    ).copyWith(groupName: group == 1 ? 'Violine' : 'Flöte');

final _anna = _person(1, 'Anna', 'Berg', 1, leader: true, birthday: _birthdayToday());
final _ben = _person(2, 'Ben', 'Clas', 1);
final _clara = _person(3, 'Clara', 'Dorn', 2);
final _dora = _person(4, 'Dora', 'Ernst', 2, paused: true, pausedUntil: _day(10));
final _emil = _person(5, 'Emil', 'Funk', 2, pending: true);

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [finder] into the viewport (finders also see the cache extent)
/// and taps it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

MaterialApp _material(GoRouter router) => MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      routerConfig: router,
    );

List<Override> _common(Role role, MockPlayerRepository repo) => [
      initialRedesignSettingsProvider.overrideWithValue(
        const RedesignSettings(enabled: true, world: RdFarbwelt.petrol),
      ),
      effectiveRoleProvider.overrideWithValue(role),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      playerRepositoryWithTenantProvider.overrideWithValue(repo),
    ];

Widget _membersApp(Role role, MockPlayerRepository repo) {
  final router = GoRouter(
    initialLocation: '/mitglieder',
    routes: [
      GoRoute(
        path: '/mitglieder',
        builder: (_, __) => const RdMembersPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => Scaffold(body: Text('page person ${state.pathParameters['id']}')),
          ),
        ],
      ),
      GoRoute(
        path: '/people/:id',
        builder: (_, state) => Scaffold(body: Text('page old ${state.pathParameters['id']}')),
      ),
      GoRoute(path: '/statistics', builder: (_, __) => const Scaffold(body: Text('page stats'))),
    ],
  );
  return ProviderScope(
    overrides: [
      ..._common(role, repo),
      realtimePlayersProvider.overrideWith((ref) => Stream.value([_anna, _ben, _clara, _dora])),
      realtimePendingPlayersProvider.overrideWith((ref) => Stream.value([_emil])),
      playerAttendancePercentagesProvider.overrideWith((ref) async => const {1: 90, 2: 40, 3: 80, 4: 70}),
      groupsProvider.overrideWith((ref) async => _groups),
      playerAbsencesProvider.overrideWith((ref) async => [
            PlayerAbsence(personId: 3, fromDate: _day(-1), untilDate: _day(3), reason: 'Urlaub'),
          ]),
    ],
    child: _material(router),
  );
}

Widget _personApp(Role role, MockPlayerRepository repo, {Person? person, int id = 1, bool split = false}) {
  final router = GoRouter(
    initialLocation: '/mitglieder/$id',
    routes: [
      GoRoute(
        path: '/mitglieder',
        builder: (_, __) => const Scaffold(body: Text('page members')),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) {
              final page = RdPersonPage(personId: int.parse(state.pathParameters['id']!));
              return split ? RdSplitScope(isDetail: true, selectedId: id, child: page) : page;
            },
          ),
        ],
      ),
      GoRoute(
        path: '/people/:id',
        builder: (_, state) => Scaffold(body: Text('page old ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      ..._common(role, repo),
      personProvider(id).overrideWith((ref) async => person),
      personAttendanceStatsProvider(id).overrideWith(
        (ref) async => {'total': 10, 'attended': 8, 'percentage': 80, 'lateCount': 1, 'lateStatuses': const []},
      ),
      personHistoryProvider(id).overrideWith((ref) async => [
            {'date': _day(-1), 'status': AttendanceStatus.present.value, 'meetingName': 'Probe'},
            {'date': _day(-8), 'status': AttendanceStatus.excused.value, 'meetingName': 'Probe'},
            {'date': _day(-15), 'status': AttendanceStatus.late.value, 'meetingName': 'Probe'},
          ]),
      playerAbsencesByPersonIdProvider(id).overrideWith((ref) async => const <PlayerAbsence>[]),
      realtimePlayersProvider.overrideWith((ref) => Stream.value(const <Person>[])),
      playerAttendancePercentagesProvider.overrideWith((ref) async => const <int, int>{}),
    ],
    child: _material(router),
  );
}

MockPlayerRepository _repo({bool hasTenant = true}) {
  final repo = MockPlayerRepository();
  when(() => repo.hasTenantId).thenReturn(hasTenant);
  when(() => repo.checkAndUnpausePlayers()).thenAnswer((_) async {});
  when(() => repo.unpausePlayer(any(), historyText: any(named: 'historyText'))).thenAnswer((_) async {});
  when(() => repo.archivePlayer(any(), any(), any())).thenAnswer((_) async {});
  return repo;
}

/// REDESIGN: tab "Mitglieder" and the person page (canvas "Menschen",
/// "PersonDetail").
/// Like the router on wide screens: one page for list and detail.
Widget _splitApp(MockPlayerRepository repo) {
  Widget split(int? id) => RdSplitView(
        list: const RdMembersPage(),
        detail: id == null ? null : Scaffold(body: Center(child: Text('detail $id'))),
        selectedId: id,
        emptyText: 'Wähle links eine Person aus.',
      );
  final router = GoRouter(
    initialLocation: '/mitglieder',
    routes: [
      GoRoute(
        path: '/mitglieder',
        builder: (_, __) => split(null),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (_, state) => NoTransitionPage<void>(
              key: const ValueKey('split'),
              child: split(int.parse(state.pathParameters['id']!)),
            ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      ..._common(Role.admin, repo),
      realtimePlayersProvider.overrideWith((ref) => Stream.value([_anna, _ben, _clara, _dora])),
      realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(const <Person>[])),
      playerAttendancePercentagesProvider.overrideWith((ref) async => const {1: 90, 2: 40, 3: 80, 4: 70}),
      groupsProvider.overrideWith((ref) async => _groups),
      playerAbsencesProvider.overrideWith((ref) async => const <PlayerAbsence>[]),
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

void main() {
  setUpAll(() async {
    registerFallbackValue(TestFactories.createPerson());
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  group('rdMemberSections', () {
    test('groups in group order, leaders first, Ø per section', () {
      final sections = rdMemberSections(
        [_ben, _clara, _anna],
        groups: _groups,
        percentages: const {1: 90, 2: 40, 3: 80},
        noGroupLabel: 'Ohne',
      );
      expect(sections.map((s) => s.title), ['Violine', 'Flöte']);
      expect(sections.first.people.map((p) => p.id), [1, 2]);
      expect(sections.first.average, 65);
      expect(sections.first.isRegister, isFalse);
      expect(sections.last.average, 80);
    });

    test('group categories become registers', () {
      const strings = GroupCategory(id: 9, name: 'Streicher');
      final groups = [
        _groups[0].copyWith(categoryData: strings),
        _groups[1].copyWith(categoryData: const GroupCategory(id: 8, name: 'Holz')),
      ];
      final sections = rdMemberSections(
        [_anna, _ben, _clara],
        groups: groups,
        percentages: const {},
        noGroupLabel: 'Ohne',
      );
      expect(sections.map((s) => s.title), ['Streicher', 'Holz']);
      expect(sections.first.isRegister, isTrue);
      expect(sections.first.average, isNull);
    });

    test('register: groups stay together, leaders first within their group', () {
      const strings = GroupCategory(id: 9, name: 'Streicher');
      final groups = [
        _groups[0].copyWith(categoryData: strings),
        _groups[1].copyWith(categoryData: strings),
      ];
      final fluteLeader = _person(6, 'Fritz', 'Zander', 2, leader: true);
      final sections = rdMemberSections(
        [_ben, _clara, fluteLeader, _anna],
        groups: groups,
        percentages: const {},
        noGroupLabel: 'Ohne',
      );
      expect(sections, hasLength(1));
      // Violine: Anna (leader), Ben; then Flöte: Fritz (leader), Clara.
      expect(sections.first.people.map((p) => p.id), [1, 2, 6, 3]);
    });
  });

  group('helpers', () {
    test('search matches name parts, group and register', () {
      expect(rdPersonMatches(_clara, 'clara d'), isTrue);
      expect(rdPersonMatches(_clara, 'flö'), isTrue);
      expect(rdPersonMatches(_clara, 'holz', register: 'Holz'), isTrue);
      expect(rdPersonMatches(_clara, 'anna'), isFalse);
      expect(rdPersonMatches(_clara, '  '), isTrue);
    });

    test('days to the next birthday', () {
      final now = DateTime(2026, 10, 29);
      expect(rdDaysToBirthday('1990-10-29', now: now), 0);
      expect(rdDaysToBirthday('2001-10-30', now: now), 1);
      expect(rdDaysToBirthday('2001-10-28', now: now), 364);
      expect(rdDaysToBirthday(null, now: now), isNull);
    });

    test('current absence: running first, else the next within a week', () {
      final now = DateTime(2026, 10, 29);
      const running = PlayerAbsence(personId: 1, fromDate: '2026-10-27', untilDate: '2026-10-30');
      const soon = PlayerAbsence(personId: 1, fromDate: '2026-11-02', untilDate: '2026-11-04');
      const later = PlayerAbsence(personId: 1, fromDate: '2026-12-01', untilDate: '2026-12-04');
      const other = PlayerAbsence(personId: 2, fromDate: '2026-10-27', untilDate: '2026-10-30');
      expect(rdCurrentAbsence([soon, running], 1, now: now), running);
      expect(rdCurrentAbsence([later, soon], 1, now: now), soon);
      expect(rdCurrentAbsence([later, other], 1, now: now), isNull);
    });

    test('last statuses oldest first, rows without status skipped', () {
      final statuses = rdLastStatuses([
        {'status': 1},
        {'status': null},
        {'status': 2},
        {'status': 4},
      ], count: 2);
      expect(statuses, [AttendanceStatus.excused, AttendanceStatus.present]);
    });
  });

  group('RedesignRoutes Mitglieder', () {
    test('only roles with the old people tab', () {
      for (final role in [Role.admin, Role.responsible, Role.viewer]) {
        expect(RedesignRoutes.roleRedirect('/mitglieder', role), isNull, reason: role.name);
        expect(RedesignRoutes.roleRedirect('/mitglieder/3', role), isNull, reason: role.name);
      }
      for (final role in Role.values.where((r) => !r.canSeePeopleTab)) {
        expect(RedesignRoutes.roleRedirect('/mitglieder', role), '/heute', reason: role.name);
        expect(RedesignRoutes.roleRedirect('/mitglieder/3', role), '/heute', reason: role.name);
      }
      expect(RedesignRoutes.person(3), '/mitglieder/3');
      expect(RedesignRoutes.isRedesignRoute('/mitglieder/3'), isTrue);
    });
  });

  group('RdMembersPage', () {
    testWidgets('Aktiv: sections with Ø, leader, birthday, absence, low percent', (tester) async {
      await tester.pumpWidget(_membersApp(Role.admin, _repo()));
      await _settle(tester);

      expect(find.text('Aktiv · 3'), findsOneWidget);
      expect(find.text('Pausiert · 1'), findsOneWidget);
      expect(find.text('Wartet · 1'), findsOneWidget);
      expect(find.text('VIOLINE · 2'), findsOneWidget);
      expect(find.text('Ø 65 %'), findsOneWidget);
      expect(find.text('FLÖTE · 1'), findsOneWidget);
      expect(find.text('Stimmführung'), findsOneWidget);
      expect(find.text('Geburtstag heute'), findsOneWidget);
      expect(find.textContaining('abwesend bis'), findsOneWidget);
      expect(find.text('40 %'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Dora Ernst'), findsNothing);
      // Leader first in the section.
      expect(tester.getTopLeft(find.text('Anna Berg')).dy, lessThan(tester.getTopLeft(find.text('Ben Clas')).dy));
    });

    testWidgets('Pausiert lists paused persons with their end date', (tester) async {
      await tester.pumpWidget(_membersApp(Role.admin, _repo()));
      await _settle(tester);
      await tester.tap(find.text('Pausiert · 1'));
      await _settle(tester);
      expect(find.text('Dora Ernst'), findsOneWidget);
      expect(find.textContaining('pausiert bis'), findsOneWidget);
      expect(find.text('Anna Berg'), findsNothing);
    });

    testWidgets('swiping the list switches Aktiv and Pausiert', (tester) async {
      await tester.pumpWidget(_membersApp(Role.admin, _repo()));
      await _settle(tester);
      await tester.timedDrag(find.text('Ben Clas'), const Offset(-250, 0), const Duration(milliseconds: 600));
      await _settle(tester);
      expect(find.text('Dora Ernst'), findsOneWidget);
      expect(find.text('Ben Clas'), findsNothing);
      await tester.timedDrag(find.text('Dora Ernst'), const Offset(250, 0), const Duration(milliseconds: 600));
      await _settle(tester);
      expect(find.text('Ben Clas'), findsOneWidget);
    });

    testWidgets('search filters by group and shows a hint without match', (tester) async {
      await tester.pumpWidget(_membersApp(Role.admin, _repo()));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'flö');
      await _settle(tester);
      expect(find.text('Clara Dorn'), findsOneWidget);
      expect(find.text('Anna Berg'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await _settle(tester);
      expect(find.text('Niemand passt zur Suche.'), findsOneWidget);
    });

    testWidgets('a row opens the new person page', (tester) async {
      await tester.pumpWidget(_membersApp(Role.admin, _repo()));
      await _settle(tester);
      await tester.tap(find.text('Ben Clas'));
      await _settle(tester);
      expect(find.text('page person 2'), findsOneWidget);
    });

    testWidgets('Wartet opens the old page to review and approve', (tester) async {
      await tester.pumpWidget(_membersApp(Role.admin, _repo()));
      await _settle(tester);
      await tester.tap(find.text('Wartet · 1'));
      await _settle(tester);
      expect(find.text('Tippe auf eine Person, um sie zu prüfen und freizugeben.'), findsOneWidget);
      expect(find.text('emil@example.org'), findsOneWidget);
      await tester.tap(find.text('Emil Funk'));
      await _settle(tester);
      expect(find.text('page old 5'), findsOneWidget);
    });

    testWidgets('admin lifts expired pauses on open and may add persons', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_membersApp(Role.admin, repo));
      await _settle(tester);
      verify(() => repo.checkAndUnpausePlayers()).called(1);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.bySemanticsLabel('Auswertung'), findsOneWidget);
    });

    testWidgets('Beobachter reads only: no add, no Auswertung, no Wartet', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_membersApp(Role.viewer, repo));
      await _settle(tester);
      verifyNever(() => repo.checkAndUnpausePlayers());
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.bySemanticsLabel('Auswertung'), findsNothing);
      expect(find.text('Wartet · 1'), findsNothing);
      expect(find.text('Anna Berg'), findsOneWidget);
    });
  });

  group('RdPersonPage', () {
    final anna = _anna.copyWith(phone: '+49 151 2345678', notes: 'Spielt auch Bratsche');

    testWidgets('attendance, last Termine, contact and info', (tester) async {
      await tester.pumpWidget(_personApp(Role.admin, _repo(), person: anna));
      await _settle(tester);

      expect(find.text('Anna Berg'), findsOneWidget);
      expect(find.text('Violine · Stimmführung · seit 2020'), findsOneWidget);
      expect(find.text('Anrufen'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('E-Mail'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget);
      expect(find.text('8 von 10 Terminen'), findsOneWidget);
      expect(find.text('Letzte 3 Termine, neuester rechts'), findsOneWidget);
      // Newest right: late (oldest) left of present (newest).
      final late = tester.getCenter(find.byTooltip(AttendanceStatus.late.label));
      final present = tester.getCenter(find.byTooltip(AttendanceStatus.present.label));
      expect(late.dx, lessThan(present.dx));
      expect(find.text('Gesamt'), findsOneWidget);

      await tester.ensureVisible(find.text('Spielt auch Bratsche'));
      expect(find.text('Geburtstag'), findsOneWidget);
      expect(find.textContaining('heute'), findsWidgets);
      expect(find.text('Dabei seit'), findsOneWidget);
      expect(find.text('Notiz'), findsOneWidget);
    });

    testWidgets('admin: Bearbeiten opens the old page, Pausieren and Archivieren shown', (tester) async {
      await tester.pumpWidget(_personApp(Role.admin, _repo(), person: anna));
      await _settle(tester);
      expect(find.text('Archivieren'), findsOneWidget);
      expect(find.text('Pausieren'), findsOneWidget);
      await _tapVisible(tester, find.text('Bearbeiten'));
      await _settle(tester);
      expect(find.text('page old 1'), findsOneWidget);
    });

    testWidgets('Beobachter sees no edit actions', (tester) async {
      await tester.pumpWidget(_personApp(Role.viewer, _repo(), person: anna));
      await _settle(tester);
      expect(find.text('Bearbeiten'), findsNothing);
      // The internal note stays with Admins and Verantwortliche.
      expect(find.text('Notiz'), findsNothing);
      expect(find.text('Spielt auch Bratsche'), findsNothing);
      expect(find.text('Pausieren'), findsNothing);
      expect(find.text('Archivieren'), findsNothing);
    });

    testWidgets('paused person: Wieder aktiv unpauses via the tenant repository', (tester) async {
      final repo = _repo();
      final paused = _dora.copyWith(id: 1);
      await tester.pumpWidget(_personApp(Role.admin, repo, person: paused));
      await _settle(tester);
      expect(find.text('Pausiert'), findsOneWidget);
      await _tapVisible(tester, find.text('Wieder aktiv'));
      await _settle(tester);
      verify(() => repo.unpausePlayer(paused, historyText: any(named: 'historyText'))).called(1);
    });

    testWidgets('Archivieren asks for date and reason, then archives and goes back', (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_personApp(Role.admin, repo, person: anna));
      await _settle(tester);
      await _tapVisible(tester, find.text('Archivieren'));
      await _settle(tester);
      expect(find.text('Anna Berg Archivieren'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Umzug');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Archivieren')));
      await _settle(tester);
      final captured = verify(() => repo.archivePlayer(anna, captureAny(), 'Umzug')).captured;
      expect((captured.single as String).substring(0, 10), _day(0));
      expect(find.text('page members'), findsOneWidget);
    });

    testWidgets('pending person: review on the old page, no attendance', (tester) async {
      await tester.pumpWidget(_personApp(Role.admin, _repo(), person: _emil.copyWith(id: 1)));
      await _settle(tester);
      expect(find.text('Wartet auf Freigabe.'), findsOneWidget);
      expect(find.text('8 von 10 Terminen'), findsNothing);
      expect(find.text('Pausieren'), findsNothing);
      await tester.tap(find.text('Prüfen und freigeben'));
      await _settle(tester);
      expect(find.text('page old 1'), findsOneWidget);
    });

    testWidgets('unknown person shows a hint', (tester) async {
      await tester.pumpWidget(_personApp(Role.admin, _repo(), person: null, id: 99));
      await _settle(tester);
      expect(find.text('Diese Person gibt es hier nicht mehr.'), findsOneWidget);
    });
  });

  group('split view (tablet, desktop)', () {
    test('from 1100 pt wide', () {
      expect(rdSplitBreakpoint, 1100);
    });

    testWidgets('list stays, the person opens on the right and replaces the last one', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_splitApp(_repo()));
      await _settle(tester);
      expect(find.text('Wähle links eine Person aus.'), findsOneWidget);

      await tester.tap(find.text('Anna Berg'));
      await _settle(tester);
      expect(find.text('detail 1'), findsOneWidget);
      expect(find.text('Ben Clas'), findsOneWidget);
      bool selected(String name) => tester
          .widgetList<Semantics>(find.ancestor(of: find.text(name), matching: find.byType(Semantics)))
          .any((w) => w.properties.selected == true);
      expect(selected('Anna Berg'), isTrue);
      expect(selected('Ben Clas'), isFalse);

      await tester.tap(find.text('Ben Clas'));
      await _settle(tester);
      expect(find.text('detail 2'), findsOneWidget);
      expect(find.text('detail 1'), findsNothing);

      // Replaced, not stacked: back leads to the list, not to Anna.
      GoRouter.of(tester.element(find.text('detail 2'))).pop();
      await _settle(tester);
      expect(find.text('Wähle links eine Person aus.'), findsOneWidget);
    });

    testWidgets('the person page has no back link on the right', (tester) async {
      await tester.pumpWidget(_personApp(Role.admin, _repo(), person: _anna, split: true));
      await _settle(tester);
      expect(find.text('Anna Berg'), findsOneWidget);
      expect(find.bySemanticsLabel('Mitglieder'), findsNothing);
    });

    test('the router uses the split for Termine, Mitglieder and Werke', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(RegExp('RdSplitView\\(').allMatches(router).length, 6);
      expect(router, contains("ValueKey('rd-events-split')"));
      expect(router, contains("ValueKey('rd-members-split')"));
      expect(router, contains("ValueKey('rd-works-split')"));
    });
  });

  group('security (source)', () {
    final members = File('lib/features/redesign/presentation/pages/rd_members_page.dart').readAsStringSync();
    final person = File('lib/features/redesign/presentation/pages/rd_person_page.dart').readAsStringSync();

    test('no direct Supabase access in the new pages', () {
      for (final src in [members, person]) {
        expect(src, isNot(contains('supabase')));
        expect(src, isNot(contains('.from(')));
      }
    });

    test('writes only through the tenant repository', () {
      for (final src in [members, person]) {
        expect(src, isNot(contains('playerRepositoryProvider')));
      }
      expect(person, contains('ref.read(playerRepositoryWithTenantProvider)'));
      expect(person, contains('repo.archivePlayer('));
      expect(person, contains('repo.unpausePlayer('));
    });

    test('router: Mitglieder routes and tab', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(router, contains("name: 'redesignMembers'"));
      expect(router, contains("name: 'redesignPerson'"));
    });
  });
}
