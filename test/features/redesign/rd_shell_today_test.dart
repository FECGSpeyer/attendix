import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/parents/data/providers/parents_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_events_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_today_page.dart';
import 'package:attendix/features/redesign/presentation/shell/rd_shell.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(
      id: 7,
      shortName: 'SO',
      longName: 'Stadtorchester',
      showMembersList: true,
    );
  }
}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

CrossTenantPersonAttendance _own(String id, int dayOffset, AttendanceStatus status) =>
    CrossTenantPersonAttendance(
      id: id,
      attendanceId: int.parse(id),
      status: status,
      date: _day(dayOffset),
      typeInfo: 'Probe $id',
      startTime: '23:30',
      endTime: '23:50',
      place: 'Probenraum',
      tenantId: 7,
      tenantName: 'SO',
      tenantColor: 'primary',
    );

Widget _app(Role role, {RdFarbwelt world = RdFarbwelt.petrol, List<Override> extra = const []}) {
  final router = GoRouter(
    initialLocation: '/heute',
    routes: [
      ShellRoute(
        builder: (context, state, child) => RdShell(child: child),
        routes: [
          GoRoute(path: '/heute', builder: (_, __) => const RdTodayPage()),
          GoRoute(
            path: '/termine/:id',
            builder: (_, state) => Scaffold(body: Text('page termin ${state.uri}')),
          ),
          for (final path in ['/attendance', '/signout', '/people', '/mitglieder', '/members', '/songs-tab', '/werke', '/ich'])
            GoRoute(path: path, builder: (_, __) => Scaffold(body: Text('page $path'))),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(RedesignSettings(enabled: true, world: world)),
      effectiveRoleProvider.overrideWithValue(role),
      isApplicantProvider.overrideWithValue(false),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      userTenantsProvider.overrideWith((ref) async => const []),
      unreadNotificationCountProvider.overrideWith((ref) async => 2),
      userNotificationsRealtimeProvider.overrideWith((ref) {}),
      canAccessFilesProvider.overrideWithValue(false),
      currentSelfServicePlayerProvider.overrideWith(
        (ref) async => TestFactories.createPerson(id: 3, firstName: 'Lea', tenantId: 7),
      ),
      signoutDataProvider.overrideWith((ref) async => SignoutData(
            current: _own('11', 0, AttendanceStatus.neutral),
            upcoming: [
              _own('12', 2, AttendanceStatus.present),
              _own('13', 4, AttendanceStatus.excused),
            ],
          )),
      attendanceTypesProvider.overrideWith((ref) async => const []),
      realtimeAttendanceListProvider.overrideWith((ref) async => [
            TestFactories.createAttendance(id: 21, date: _day(0), typeInfo: 'Gesamtprobe', startTime: '23:30', endTime: '23:50'),
            TestFactories.createAttendance(id: 22, date: _day(2), typeInfo: 'Registerprobe'),
            TestFactories.createAttendance(id: 23, date: _day(-3), typeInfo: 'Vorbei'),
          ]),
      rdAttendanceCountsProvider.overrideWith(
        (ref, id) async => const RdStatusCounts(present: 24, excused: 3, lateAnnounced: 2, open: 5),
      ),
      pendingPlayersProvider.overrideWith(
        (ref) async => [TestFactories.createPerson(id: 9), TestFactories.createPerson(id: 10)],
      ),
      criticalPlayersProvider.overrideWith((ref) async => const []),
      rdUnrecordedProvider.overrideWith((ref) async => const [23]),
      rdOpenPersonsProvider.overrideWith((ref, id) async => [
            TestFactories.createPerson(id: 31, firstName: 'Tim', lastName: 'Maurer', appId: 'app-tim')
                .copyWith(groupName: 'Trompete'),
            TestFactories.createPerson(id: 32, firstName: 'Lukas', lastName: 'Weber').copyWith(groupName: 'Trompete'),
          ]),
      ...extra,
      dashboardBirthdaysProvider.overrideWith((ref) async => const []),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(redesignSettingsProvider);
        return MaterialApp.router(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(s.world, Brightness.light),
          routerConfig: router,
        );
      },
    ),
  );
}

/// Bounded pumps: loading spinners never settle.
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

/// REDESIGN: "Heute" inside the new shell renders without overflow for the
/// main roles, on a phone and with the sidebar.
void main() {
  // No SharedPreferences mock on purpose: CurrentTenantNotifier's restore
  // then never reaches Supabase (as in ios_shell2_test).
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  testWidgets('Spieler on a phone: one-tap answer, next Termine, tab bar', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.player));
    await _settle(tester);

    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Hallo Lea'), findsOneWidget);
    expect(find.text('Probe 11'), findsOneWidget);
    expect(find.text('Bist du dabei?'), findsOneWidget);
    expect(find.text('Bin dabei'), findsOneWidget);
    expect(find.text('Kann nicht'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Abmelden opens the reason chips inline.
    await tester.tap(find.text('Kann nicht'));
    await _settle(tester);
    expect(find.text('Warum kannst du nicht?'), findsOneWidget);
    expect(find.text('Anderer Grund …'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Als Nächstes'), 200);
    expect(find.text('Probe 12'), findsOneWidget);
    expect(find.text('Zugesagt'), findsWidgets);
  });

  testWidgets('Dirigent with the sidebar: answers, attention, this week', (tester) async {
    _size(tester, const Size(1280, 900));
    await tester.pumpWidget(_app(Role.admin));
    await _settle(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Verwaltung'), findsOneWidget);
    expect(find.text('Stadtorchester'), findsWidgets);
    expect(find.text('Gesamtprobe'), findsOneWidget);
    expect(find.text('Anwesenheit erfassen'), findsOneWidget);
    expect(find.textContaining('24 zugesagt'), findsOneWidget);
    expect(find.text('2 neue Anmeldungen'), findsOneWidget);
    expect(find.text('3 Abmeldungen für den nächsten Termin'), findsOneWidget);
    expect(find.text('Registerprobe'), findsOneWidget);
    expect(find.text('Vorbei'), findsNothing);
  });

  testWidgets('Dirigent: past Termine without a status lead to the recording (UX D4)', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.admin));
    await _settle(tester);

    final row = find.text('1 Termin noch nicht erfasst');
    await tester.scrollUntilVisible(row, 200);
    expect(find.textContaining('Vorbei'), findsOneWidget);
    await tester.tap(row);
    await _settle(tester);
    expect(find.textContaining('page termin /termine/23'), findsOneWidget);
    expect(find.textContaining('tab=anwesenheit'), findsOneWidget);
  });

  testWidgets('Dirigent: "5 offen" lists who is open and reminds personally (UX D2)', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.admin));
    await _settle(tester);

    await tester.tap(find.text('5 offen'));
    await _settle(tester);
    expect(find.text('2 noch offen'), findsOneWidget);
    expect(find.text('TROMPETE'), findsOneWidget);
    expect(find.text('Tim Maurer'), findsOneWidget);
    expect(find.text('ohne App'), findsOneWidget, reason: 'Lukas has no app account');
    expect(find.text('Push an 1 Person senden'), findsOneWidget);
    expect(find.text('Als Text teilen'), findsOneWidget);
  });

  testWidgets('Eltern answer per child right on Heute (UX E1)', (tester) async {
    _size(tester, const Size(393, 852));
    final group = ParentAttendanceGroup(
      attendanceId: 40,
      date: _day(2),
      typeInfo: 'Chorprobe',
      startTime: '16:30',
      endTime: '17:30',
      childAttendances: [
        ChildPersonAttendance(id: 'm', childId: 1, childName: 'Mia Wolf', childFirstName: 'Mia', status: AttendanceStatus.present),
        ChildPersonAttendance(id: 'b', childId: 2, childName: 'Ben Wolf', childFirstName: 'Ben'),
      ],
    );
    await tester.pumpWidget(_app(Role.parent, extra: [
      parentChildrenProvider.overrideWith((ref) async => [TestFactories.createPerson(id: 1)]),
      childrenAttendancesProvider.overrideWith((ref) async => const []),
      upcomingParentAttendancesProvider.overrideWithValue([group]),
    ]));
    await _settle(tester);

    expect(find.text('Chorprobe'), findsOneWidget);
    expect(find.text('Dabei'), findsOneWidget);
    expect(find.text('Doch absagen'), findsOneWidget);
    expect(find.text('Ist dabei'), findsOneWidget);
    expect(find.text('Kann nicht'), findsOneWidget);
    expect(find.text('Zu- und absagen'), findsNothing);

    await tester.tap(find.text('Kann nicht'));
    await _settle(tester);
    expect(find.text('Ben · Chorprobe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Eltern: after "kommt später" both Zusage and Absage stay open (UX E1)', (tester) async {
    _size(tester, const Size(393, 852));
    final group = ParentAttendanceGroup(
      attendanceId: 41,
      date: _day(2),
      typeInfo: 'Chorprobe',
      startTime: '16:30',
      endTime: '17:30',
      childAttendances: [
        ChildPersonAttendance(
          id: 'm',
          childId: 1,
          childName: 'Mia Wolf',
          childFirstName: 'Mia',
          status: AttendanceStatus.lateExcused,
        ),
      ],
    );
    await tester.pumpWidget(_app(Role.parent, extra: [
      parentChildrenProvider.overrideWith((ref) async => [TestFactories.createPerson(id: 1)]),
      childrenAttendancesProvider.overrideWith((ref) async => const []),
      upcomingParentAttendancesProvider.overrideWithValue([group]),
    ]));
    await _settle(tester);

    expect(find.text('Doch dabei'), findsOneWidget);
    expect(find.text('Doch absagen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beobachter: a hint once, Termine without dead taps (UX V1)', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.viewer));
    await _settle(tester);

    expect(find.text('Als Beobachter siehst du den Überblick. Einzelne Termine öffnet die Leitung.'), findsOneWidget);
    expect(find.text('Anwesenheit erfassen'), findsNothing);
    expect(find.textContaining('noch nicht erfasst'), findsNothing);
    await tester.scrollUntilVisible(find.text('Registerprobe'), 200);
    await tester.tap(find.text('Registerprobe'));
    await _settle(tester);
    expect(find.textContaining('page'), findsNothing);
    expect(find.text('Registerprobe'), findsOneWidget);
  });

  testWidgets('every Farbwelt renders the phone shell without overflow', (tester) async {
    _size(tester, const Size(320, 640));
    for (final world in RdFarbwelt.values) {
      await tester.pumpWidget(_app(Role.helper, world: world), duration: Duration.zero);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: world.key);
      expect(tester.element(find.byType(RdShell)).rd.primary,
          rdPalette(world, Brightness.light).primary,
          reason: world.key);
    }
    expect(find.text('Deine Zusage'), findsOneWidget);
  });
}
