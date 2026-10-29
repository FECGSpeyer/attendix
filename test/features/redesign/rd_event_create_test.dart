import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/holiday_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/holiday_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/profile_repository.dart';
import 'package:attendix/features/redesign/data/rd_create_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_event_create_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/route_leave_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

const _probe = AttendanceType(id: 'p', name: 'Probe', startTime: '19:30', endTime: '21:30', placeEnabled: true);
const _konzert = AttendanceType(id: 'k', name: 'Konzert', startTime: '18:00', endTime: '20:00');
const _hidden = AttendanceType(id: 'h', name: 'Alt', visible: false);

Attendance _att(int id, String date, String typeId, {String? info, String? place, String? start}) => Attendance(
      id: id,
      date: date,
      typeId: typeId,
      typeInfo: info,
      place: place,
      startTime: start,
    );

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app({bool canCreate = true, List<Attendance>? history}) {
  final router = GoRouter(
    initialLocation: '/termine/neu',
    routes: [
      GoRoute(
        path: '/termine',
        builder: (_, __) => const Scaffold(body: Text('page termine')),
        routes: [
          GoRoute(path: 'neu', builder: (_, __) => const RdEventCreatePage()),
          GoRoute(
            path: ':id',
            builder: (_, state) => Scaffold(body: Text('page termin ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      initialRedesignSettingsProvider.overrideWithValue(
        const RedesignSettings(enabled: true, world: RdFarbwelt.petrol),
      ),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      canCreateAttendanceProvider.overrideWithValue(canCreate),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      attendanceTypesProvider.overrideWith((ref) async => const [_probe, _konzert, _hidden]),
      realtimeAttendanceListProvider.overrideWith((ref) async =>
          history ??
          [
            _att(1, '2026-10-01', 'p', info: 'Gesamtprobe', place: 'Probenraum 2', start: '19:00'),
            _att(2, '2026-10-08', 'p', info: 'Gesamtprobe', place: 'Probenraum 2', start: '19:30'),
            _att(3, '2026-10-10', 'k', place: 'Stadthalle'),
          ]),
      holidaysProvider.overrideWith((ref) async => const HolidayData()),
      playersProvider.overrideWith((ref) async => [
            TestFactories.createPerson(id: 1, tenantId: 7, instrument: 1),
            TestFactories.createPerson(id: 2, tenantId: 7, instrument: 2),
            TestFactories.createPerson(id: 3, tenantId: 7, instrument: 2, paused: true),
          ]),
      personExtraFieldsProvider.overrideWith((ref) async => const <ProfileExtraField>[]),
      groupsMapProvider.overrideWith((ref) async => const {1: 'Violine', 2: 'Flöte'}),
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

/// REDESIGN: "Termin anlegen" (canvas TerminAnlegen).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  group('rdRepeatDates', () {
    test('every Thursday from 6.11. to 18.12. = 7 Termine', () {
      final dates = rdRepeatDates(DateTime(2026, 11, 6), DateTime(2026, 12, 18));
      expect(dates.length, 7);
      expect(dates.first, DateTime(2026, 11, 6));
      expect(dates.last, DateTime(2026, 12, 18));
      expect(dates.every((d) => d.weekday == DateTime.friday), isTrue);
    });

    test('every two weeks, across the DST change, capped', () {
      final two = rdRepeatDates(DateTime(2026, 10, 1), DateTime(2026, 11, 30), everyWeeks: 2);
      expect(two.map((d) => d.day), [1, 15, 29, 12, 26]);
      expect(two.every((d) => d.hour == 0), isTrue);
      expect(rdRepeatDates(DateTime(2026, 1, 1), DateTime(2030, 1, 1)).length, rdMaxCreateDates);
      expect(rdRepeatDates(DateTime(2026, 1, 8), DateTime(2026, 1, 1)), isEmpty);
    });
  });

  test('rdMovedSeriesEnd keeps the series length in calendar days', () {
    // Over the change to summer time (Europe/Berlin: 47 h between the days).
    expect(rdMovedSeriesEnd(DateTime(2026, 3, 28), DateTime(2026, 3, 30), DateTime(2026, 5, 9)),
        DateTime(2026, 5, 11));
    // Back to winter time (49 h), and moving the start earlier.
    expect(rdMovedSeriesEnd(DateTime(2026, 10, 24), DateTime(2026, 10, 26), DateTime(2026, 12, 5)),
        DateTime(2026, 12, 7));
    expect(rdMovedSeriesEnd(DateTime(2026, 3, 30), DateTime(2026, 3, 28), DateTime(2026, 5, 11)),
        DateTime(2026, 5, 9));
    // Never before the new first day.
    expect(rdMovedSeriesEnd(DateTime(2026, 5, 1), DateTime(2026, 6, 1), DateTime(2026, 4, 1)),
        DateTime(2026, 6, 1));
    // The page moves the end only this way.
    final page = File('lib/features/redesign/presentation/pages/rd_event_create_page.dart').readAsStringSync();
    expect(page, contains('rdMovedSeriesEnd(_date, day, _until)'));
    expect(page, isNot(contains('.difference(_date)')));
  });

  test('rdHolidayOn: school holidays are a range, public holidays one day', () {
    final data = HolidayData(
      publicHolidays: [
        Holiday(id: 'a', name: 'Weihnachten', startDate: DateTime(2026, 12, 25), endDate: DateTime(2026, 12, 25)),
      ],
      schoolHolidays: [
        Holiday(id: 'b', name: 'Herbstferien', startDate: DateTime(2026, 10, 26), endDate: DateTime(2026, 10, 31)),
      ],
    );
    expect(rdHolidayOn(data, DateTime(2026, 10, 26, 12)), 'Herbstferien');
    expect(rdHolidayOn(data, DateTime(2026, 10, 31)), 'Herbstferien');
    expect(rdHolidayOn(data, DateTime(2026, 11, 1)), isNull);
    expect(rdHolidayOn(data, DateTime(2026, 12, 25)), 'Weihnachten');
  });

  group('rdDeadlineFor', () {
    final now = DateTime(2026, 11, 1, 10);
    final day = DateTime(2026, 11, 12, 12);

    test('relative to the start of the Termin', () {
      expect(rdDeadlineFor(RdDeadline.none, day, '19:30', now: now), isNull);
      expect(rdDeadlineFor(RdDeadline.hours24, day, '19:30', now: now), DateTime(2026, 11, 11, 19, 30));
      expect(rdDeadlineFor(RdDeadline.days2, day, null, now: now), DateTime(2026, 11, 10, 19));
      expect(rdDeadlineFor(RdDeadline.week, day, '18:00', now: now), DateTime(2026, 11, 5, 18));
    });

    test('a deadline already over means none (signouts stay possible)', () {
      expect(rdDeadlineFor(RdDeadline.week, DateTime(2026, 11, 3), '19:00', now: now), isNull);
    });
  });

  test('rdInvitedPersons mirrors the create write path', () {
    final type = AttendanceType(
      id: 'p',
      name: 'Probe',
      relevantGroups: const [1, 2],
      additionalFieldsFilter: const {'key': 'chor', 'option': true},
    );
    final players = [
      TestFactories.createPerson(id: 1, instrument: 1),
      TestFactories.createPerson(id: 2, instrument: 3),
      TestFactories.createPerson(id: 3, instrument: 2, paused: true),
      TestFactories.createPerson(id: 4, instrument: 2, pending: true),
      TestFactories.createPerson(id: 5, instrument: 2, left: '2026-01-01'),
      TestFactories.createPerson(id: 6, instrument: 2).copyWith(additionalFields: {'chor': false}),
    ];
    const field = ProfileExtraField(id: 'chor', name: 'Chor', type: 'boolean', defaultValue: true);
    expect(rdInvitedPersons(players, type, const [field]).map((p) => p.id), [1]);
    // Unknown filter field: everyone in the groups (like the write path).
    expect(rdInvitedPersons(players, type, const []).map((p) => p.id), [1, 6]);
  });

  group('rdTemplates', () {
    test('most created kinds first, newest one gives time and place', () {
      final t = rdTemplates([
        _att(1, '2026-09-01', 'p', info: 'Gesamtprobe', place: 'Saal', start: '19:00'),
        _att(2, '2026-10-01', 'p', info: 'Gesamtprobe', place: 'Probenraum 2', start: '19:30'),
        _att(3, '2026-10-02', 'p', info: 'Registerprobe'),
        _att(4, '2026-10-03', 'k'),
        _att(5, '2026-10-04', 'k'),
        _att(6, '2026-10-05', 'h', info: 'Versteckt'),
        _att(7, '2026-10-06', 'p', info: ' gesamtprobe '),
      ], const [_probe, _konzert]);
      expect(t.map((x) => x.title), ['Konzert', 'Gesamtprobe', 'Registerprobe']);
      final gesamt = t[1];
      expect(gesamt.type.id, 'p');
      expect(gesamt.typeInfo, 'Gesamtprobe');
      expect(gesamt.startTime, '19:30');
      expect(gesamt.place, 'Probenraum 2');
      expect(t.first.typeInfo, isNull);
      expect(t.first.startTime, '18:00');
    });

    test('without earlier Termine the types are the templates', () {
      final t = rdTemplates(const [], const [_probe, _konzert]);
      expect(t.map((x) => x.title), ['Probe', 'Konzert']);
      expect(t.first.startTime, '19:30');
    });
  });

  test('rdRecentPlaces: most used first, case-insensitive', () {
    expect(
      rdRecentPlaces([
        _att(1, '2026-10-01', 'p', place: 'Saal'),
        _att(2, '2026-10-02', 'p', place: 'Kirche'),
        _att(3, '2026-10-03', 'p', place: 'saal'),
        _att(4, '2026-10-04', 'p', place: ' '),
      ]),
      ['Saal', 'Kirche'],
    );
  });

  group('page', () {
    testWidgets('starts with the most used template, weekly series shows the summary', (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await _settle(tester);

      expect(find.text('Neuer Termin'), findsOneWidget);
      expect(find.text('Gesamtprobe'), findsWidgets);
      // Template applied: title, place, time.
      final title = tester.widget<TextField>(find.byType(TextField).first);
      expect(title.controller!.text, 'Gesamtprobe');
      expect(find.text('Probenraum 2'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
      // Invited: everyone active (the paused person is left out).
      expect(find.text('Alle · 2'), findsOneWidget);
      expect(find.text('Termin anlegen'), findsOneWidget);

      // Konzert template: no place field (place not enabled), its time.
      await tester.tap(find.text('Konzert').first);
      await _settle(tester);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('Ort'), findsNothing);

      // Weekly series.
      await tester.tap(find.text('Weitere Daten'));
      await _settle(tester);
      await tester.tap(find.text('Jede Woche'));
      await _settle(tester);
      expect(find.text('7 Termine'), findsOneWidget);
      await tester.tap(find.text('Fertig'));
      await _settle(tester);
      expect(find.textContaining('Es werden 7 Termine angelegt'), findsOneWidget);
      expect(find.textContaining('jeden '), findsOneWidget);
      expect(find.text('7 Termine anlegen'), findsOneWidget);
    });

    testWidgets('without permission only a hint, Anlegen disabled', (tester) async {
      await tester.pumpWidget(_app(canCreate: false));
      await _settle(tester);
      expect(find.text('Du darfst keine Termine anlegen.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Abbrechen after a change asks before discarding', (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(history: const []));
      await _settle(tester);
      // No history: the first visible type, its time, no template chips row
      // for a single kind is still shown for two types.
      expect(find.text('Probe'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Sonderprobe');
      await _settle(tester);
      await tester.tap(find.text('Abbrechen'));
      await _settle(tester);
      expect(find.text('Termin verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Weiter bearbeiten'));
      await _settle(tester);
      expect(find.text('Neuer Termin'), findsOneWidget);
    });
  });

  testWidgets('a tab switch asks the leave guard before discarding input', (tester) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(history: const []));
    await _settle(tester);
    final guards = ProviderScope.containerOf(tester.element(find.byType(RdEventCreatePage)))
        .read(routeLeaveGuardRegistryProvider);
    expect(guards.hasGuards, isTrue);

    // Untouched: the tab switch goes ahead without asking.
    expect(await guards.canLeave(), isTrue);

    await tester.enterText(find.byType(TextField).first, 'Sonderprobe');
    await _settle(tester);
    var leave = guards.canLeave();
    await _settle(tester);
    expect(find.text('Termin verwerfen?'), findsOneWidget);
    await tester.tap(find.text('Weiter bearbeiten'));
    await _settle(tester);
    expect(await leave, isFalse);

    leave = guards.canLeave();
    await _settle(tester);
    await tester.tap(find.text('Verwerfen'));
    await _settle(tester);
    expect(await leave, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(guards.hasGuards, isFalse);
  });

  group('source', () {
    final page = File('lib/features/redesign/presentation/pages/rd_event_create_page.dart').readAsStringSync();
    final writes = File('lib/features/attendance/presentation/attendance_create_writes.dart').readAsStringSync();
    final oldPage = File('lib/features/attendance/presentation/pages/attendance_create_page.dart').readAsStringSync();
    final router = File('lib/core/router/app_router.dart').readAsStringSync();

    test('both UIs create through the shared write path with permission check', () {
      for (final src in [page, oldPage]) {
        expect(src, contains('AttendanceCreateWriter(ref)'));
        expect(src, contains('confirmCanCreateAttendance('));
        expect(src, contains('DemoGuard.blocked()'));
      }
    });

    test('writes are tenant-scoped', () {
      expect(writes, contains("'tenantId': tenant.id,"));
      expect(writes, contains(".eq('tenantId', tenant.id!)"));
      expect(writes, isNot(contains("'created_by':")));
    });

    test('route "neu" is matched before ":id"', () {
      expect(RedesignRoutes.newEvent, '/termine/neu');
      final neu = router.indexOf("path: 'neu',\n                name: 'redesignEventCreate'");
      final id = router.indexOf("name: 'redesignEvent',");
      expect(neu, isNot(-1));
      expect(neu, lessThan(id));
    });
  });
}
