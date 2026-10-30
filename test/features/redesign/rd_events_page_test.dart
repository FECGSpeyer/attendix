import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/redesign/data/providers/rd_events_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_events_page.dart';
import 'package:attendix/features/redesign/presentation/shell/rd_shell.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
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

String _day(int offset, {DateTime? from}) {
  final d = (from ?? DateTime.now()).add(Duration(days: offset));
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

Widget _app(Role role, {bool canCreate = true, List<AttendanceType> types = const [], int? pending}) {
  final router = GoRouter(
    initialLocation: '/termine',
    routes: [
      ShellRoute(
        builder: (context, state, child) => RdShell(child: child),
        routes: [
          GoRoute(
            path: '/termine',
            builder: (_, __) => const RdEventsPage(),
            routes: [
              GoRoute(
                path: 'meine/:paId',
                builder: (_, state) => Scaffold(body: Text('page own ${state.pathParameters['paId']}')),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => Scaffold(body: Text('page termin ${state.pathParameters['id']}')),
              ),
            ],
          ),
          for (final path in ['/heute', '/people', '/mitglieder', '/members', '/songs-tab', '/werke', '/ich'])
            GoRoute(path: path, builder: (_, __) => Scaffold(body: Text('page $path'))),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(
        const RedesignSettings(enabled: true, world: RdFarbwelt.petrol),
      ),
      effectiveRoleProvider.overrideWithValue(role),
      isApplicantProvider.overrideWithValue(false),
      canCreateAttendanceProvider.overrideWithValue(canCreate),
      canSelfReportAbsenceProvider.overrideWithValue(true),
      canSelfPauseProvider.overrideWithValue(false),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      userTenantsProvider.overrideWith((ref) async => const []),
      unreadNotificationCountProvider.overrideWith((ref) async => 0),
      userNotificationsRealtimeProvider.overrideWith((ref) {}),
      canAccessFilesProvider.overrideWithValue(false),
      currentSelfServicePlayerProvider.overrideWith(
        (ref) async => TestFactories.createPerson(id: 3, firstName: 'Lea', tenantId: 7),
      ),
      signoutDataProvider.overrideWith((ref) async => SignoutData(
            current: _own('11', 0, AttendanceStatus.neutral),
            upcoming: [
              _own('12', 2, AttendanceStatus.present),
              _own('13', 40, AttendanceStatus.excused),
            ],
            past: [_own('10', -2, AttendanceStatus.present)],
            percentage: 92,
          )),
      attendanceTypesProvider.overrideWith((ref) async => types),
      if (pending != null) pendingAttendanceIdProvider.overrideWith((ref) => pending),
      realtimeAttendanceListProvider.overrideWith((ref) async => [
            TestFactories.createAttendance(
              id: 21,
              date: _day(0),
              typeId: 'p',
              typeInfo: 'Gesamtprobe',
              startTime: '23:30',
              endTime: '23:50',
            ),
            TestFactories.createAttendance(id: 22, date: _day(2), typeId: 'k', typeInfo: 'Konzert'),
            TestFactories.createAttendance(id: 24, date: _day(45), typeId: 'p', typeInfo: 'Herbstprobe'),
            TestFactories.createAttendance(id: 23, date: _day(-3), typeInfo: 'Vorbei', percentage: 80),
          ]),
      rdUpcomingCountsProvider.overrideWith((ref) async => const {
            21: RdStatusCounts(present: 24, excused: 3, lateAnnounced: 2, open: 5),
          }),
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

/// REDESIGN: tab "Termine" (canvas D2, S2).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  group('rdUpcoming / rdPast', () {
    final now = DateTime(2026, 10, 29, 12);
    final list = [
      TestFactories.createAttendance(id: 1, date: _day(3, from: now)),
      TestFactories.createAttendance(id: 2, date: _day(-1, from: now), percentage: 90),
      TestFactories.createAttendance(id: 3, date: _day(0, from: now), startTime: '18:00'),
      TestFactories.createAttendance(id: 4, date: _day(-10, from: now), percentage: 70),
      TestFactories.createAttendance(id: 5, date: _day(-20, from: now)),
    ];

    test('upcoming: not ended, soonest first', () {
      expect(rdUpcoming(list, now: now).map((a) => a.id), [3, 1]);
    });

    test('past: ended, newest first', () {
      expect(rdPast(list, now: now).map((a) => a.id), [2, 4, 5]);
    });

    test('average only over Termine with a percentage', () {
      expect(rdAveragePercentage(rdPast(list, now: now)), 80);
      expect(rdAveragePercentage(const []), isNull);
    });
  });

  group('rdGroupEvents', () {
    final now = DateTime(2026, 10, 29, 12);

    test('upcoming: the coming 7 days, then one section per month', () {
      final dates = [_day(0, from: now), _day(6, from: now), _day(7, from: now), _day(40, from: now)];
      final sections = rdGroupEvents(dates, (d) => d, now: now);
      expect(sections.map((s) => s.thisWeek), [true, false, false]);
      expect(sections.first.items, dates.take(2));
      expect(sections[1].month, DateTime(2026, 11));
      expect(sections[1].items, [dates[2]]);
      expect(sections[2].month, DateTime(2026, 12));
    });

    test('a running multi-day Termin that started earlier stays in this week', () {
      final sections = rdGroupEvents([_day(-1, from: now)], (d) => d, now: now);
      expect(sections.single.thisWeek, isTrue);
    });

    test('past: the last 7 days, then months', () {
      final dates = [_day(-1, from: now), _day(-7, from: now), _day(-8, from: now)];
      final sections = rdGroupEvents(dates, (d) => d, past: true, now: now);
      expect(sections.map((s) => s.thisWeek), [true, false]);
      expect(sections.first.items, dates.take(2));
      expect(sections.last.month, DateTime(2026, 10));
    });

    test('Termine without a date are left out', () {
      expect(rdGroupEvents<String?>([null, ''], (d) => d, now: now), isEmpty);
    });
  });

  testWidgets('Dirigent: upcoming Termine with answers, past with Ø, new Termin', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.admin));
    await _settle(tester);

    expect(find.text('Kommend'), findsOneWidget);
    expect(find.text('Vergangen · Ø 80 %'), findsOneWidget);
    expect(find.text('DIESE WOCHE'), findsOneWidget);
    expect(find.text('Gesamtprobe'), findsOneWidget);
    expect(find.text('Konzert'), findsOneWidget);
    expect(find.text('Herbstprobe'), findsOneWidget);
    expect(find.text('Vorbei'), findsNothing);
    expect(find.textContaining('24 zugesagt'), findsOneWidget);
    expect(find.byTooltip('Neuer Termin'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Vergangen · Ø 80 %'));
    await _settle(tester);
    expect(find.text('Vorbei'), findsOneWidget);
    expect(find.text('80 % anwesend'), findsOneWidget);
    expect(find.text('Gesamtprobe'), findsNothing);
    expect(find.text('LETZTE 7 TAGE'), findsOneWidget);

    await tester.tap(find.text('Vorbei'));
    await _settle(tester);
    expect(find.text('page termin 23'), findsOneWidget);
  });

  testWidgets('Dirigent: swiping the list switches Kommend and Vergangen', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.admin));
    await _settle(tester);

    // While dragging, the thumb of the segments follows the finger.
    final gesture = await tester.startGesture(tester.getCenter(find.text('Konzert')));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final thumb = tester.widget<AnimatedPositioned>(
      find.descendant(of: find.byType(RdSegmented<bool>), matching: find.byType(AnimatedPositioned)),
    );
    expect(thumb.left, greaterThan(0));
    await gesture.up();
    await _settle(tester);
    expect(find.text('Vorbei'), findsOneWidget);
    expect(find.text('Gesamtprobe'), findsNothing);

    // Past the last segment it bounces back.
    await tester.timedDrag(find.text('Vorbei'), const Offset(-200, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(find.text('Vorbei'), findsOneWidget);

    // From the left screen edge it is the system back gesture.
    final y = tester.getCenter(find.text('Vorbei')).dy;
    await tester.timedDragFrom(Offset(8, y), const Offset(200, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(find.text('Vorbei'), findsOneWidget);

    // A short slow drag snaps back.
    await tester.timedDrag(find.text('Vorbei'), const Offset(50, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(find.text('Vorbei'), findsOneWidget);

    await tester.timedDrag(find.text('Vorbei'), const Offset(200, 0), const Duration(milliseconds: 600));
    await _settle(tester);
    expect(find.text('Gesamtprobe'), findsOneWidget);
    expect(find.text('Vorbei'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dirigent: type chips and search filter the list', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(
      Role.admin,
      types: [
        TestFactories.createAttendanceType(id: 'p', name: 'Probe'),
        TestFactories.createAttendanceType(id: 'k', name: 'Konzert'),
      ],
    ));
    await _settle(tester);

    await tester.tap(find.widgetWithText(RdChoiceChip, 'Probe'));
    await _settle(tester);
    expect(find.text('Gesamtprobe'), findsOneWidget);
    expect(find.text('Herbstprobe'), findsOneWidget);
    expect(find.text('Konzert'), findsOneWidget, reason: 'only the chip is left');

    await tester.tap(find.byIcon(Icons.search));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'herbst');
    await _settle(tester);
    expect(find.text('Gesamtprobe'), findsNothing);
    expect(find.text('Herbstprobe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beobachter: no new Termin, cards do not open the Termin', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.viewer, canCreate: false));
    await _settle(tester);

    expect(find.byTooltip('Neuer Termin'), findsNothing);
    await tester.tap(find.text('Gesamtprobe'));
    await _settle(tester);
    expect(find.text('page termin 21'), findsNothing);
  });

  testWidgets('Spieler: a notification for a Termin opens its own Termin page', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.player, pending: 12));
    await _settle(tester);
    expect(find.text('page own 12'), findsOneWidget);
  });

  testWidgets('Spieler: a notification for an unknown Termin says so once', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.player, pending: 99));
    await _settle(tester);
    expect(find.text('Dieser Termin wurde nicht gefunden.'), findsOneWidget);
    expect(find.text('Probe 11'), findsOneWidget, reason: 'the list stays');
    final container = ProviderScope.containerOf(tester.element(find.byType(RdEventsPage)));
    expect(container.read(pendingAttendanceIdProvider), isNull, reason: 'consumed once');
  });

  testWidgets('Spieler: answer open Termine right in the list', (tester) async {
    _size(tester, const Size(393, 852));
    await tester.pumpWidget(_app(Role.player));
    await _settle(tester);

    expect(find.text('Vergangen · 92 % da'), findsOneWidget);
    expect(find.text('Abwesend …'), findsOneWidget);
    expect(find.text('1 Termin wartet auf deine Antwort'), findsOneWidget);
    expect(find.text('Probe 11'), findsOneWidget);
    expect(find.text('Dabei'), findsOneWidget);
    expect(find.text('Abmelden'), findsOneWidget);
    expect(find.text('Probe 12'), findsOneWidget);
    expect(find.text('Zugesagt'), findsOneWidget);
    expect(find.text('Probe 13'), findsOneWidget);
    expect(find.byTooltip('Neuer Termin'), findsNothing);

    await tester.tap(find.text('1 Termin wartet auf deine Antwort'));
    await _settle(tester);
    expect(find.text('Probe 11'), findsOneWidget);
    expect(find.text('Probe 12'), findsNothing);
    expect(find.text('Wieder alle Termine zeigen'), findsOneWidget);

    await tester.tap(find.text('Abmelden'));
    await _settle(tester);
    expect(find.text('Ich kann nicht'), findsOneWidget);
    expect(find.text('Anderer Grund'), findsOneWidget);
    expect(find.text('Deinen Grund sieht nur die Leitung.'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await _settle(tester);

    await tester.tap(find.text('Vergangen · 92 % da'));
    await _settle(tester);
    expect(find.text('Probe 10'), findsOneWidget);
    expect(find.text('Probe 11'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Probe 10'));
    await _settle(tester);
    expect(find.text('page own 10'), findsOneWidget);
  });

  testWidgets('Spieler and Dirigent fit on a 320 px phone', (tester) async {
    _size(tester, const Size(320, 640));
    for (final role in [Role.player, Role.admin]) {
      await tester.pumpWidget(_app(role));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: role.name);
    }
  });
}
