import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/holiday_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/data/repositories/profile_repository.dart';
import 'package:attendix/features/attendance/data/rd_create_logic.dart';
import 'package:attendix/features/attendance/presentation/pages/rd_event_create_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/route_leave_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, AuthClientOptions;

import '../../factories/test_factories.dart';
import '../../helpers/source_reader.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  void switchGroup() {
    state = TestFactories.createTenant(id: 8, shortName: 'X', longName: 'Andere Gruppe');
  }

  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester');
  }
}

const _probe = AttendanceType(
  id: 'p',
  name: 'Probe',
  startTime: '19:30',
  endTime: '21:30',
  placeEnabled: true,
);
const _konzert = AttendanceType(id: 'k', name: 'Konzert', startTime: '18:00', endTime: '20:00');
const _hidden = AttendanceType(id: 'h', name: 'Alt', visible: false);

Attendance _att(int id, String date, String typeId, {String? info, String? place, String? start}) =>
    Attendance(id: id, date: date, typeId: typeId, typeInfo: info, place: place, startTime: start);

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget eventCreateTestApp({
  bool canCreate = true,
  List<Attendance>? history,
  List<AttendanceType> types = const [_probe, _konzert, _hidden],
  List<ProtocolType> protocols = const [],
  bool protocolLoadFails = false,
  Future<bool>? permission,
  double textScale = 1,
  ThemeData? theme,
}) {
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
      initialRedesignSettingsProvider.overrideWithValue(const RedesignSettings(world: RdFarbwelt.petrol)),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      canCreateAttendanceProvider.overrideWithValue(canCreate),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      attendanceTypesProvider.overrideWith((ref) async => types),
      protocolTypesProvider.overrideWith((ref) async {
        if (protocolLoadFails) throw StateError('offline');
        return protocols;
      }),
      typeCirclePersonsProvider.overrideWith((ref) async => const {}),
      currentAuthUserIdProvider.overrideWithValue('test-user'),
      supabaseClientProvider.overrideWith((ref) {
        final client = SupabaseClient(
          'https://example.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        ref.onDispose(() {
          client.dispose();
        });
        return client;
      }),
      if (permission != null) canCreateAttendanceConfirmedProvider.overrideWith((ref) => permission),
      realtimeAttendanceListProvider.overrideWith(
        (ref) async =>
            history ??
            [
              _att(1, '2026-10-01', 'p', info: 'Gesamtprobe', place: 'Probenraum 2', start: '19:00'),
              _att(2, '2026-10-08', 'p', info: 'Gesamtprobe', place: 'Probenraum 2', start: '19:30'),
              _att(3, '2026-10-10', 'k', place: 'Stadthalle'),
            ],
      ),
      holidaysProvider.overrideWith((ref) async => const HolidayData()),
      playersProvider.overrideWith(
        (ref) async => [
          TestFactories.createPerson(id: 1, tenantId: 7, instrument: 1),
          TestFactories.createPerson(id: 2, tenantId: 7, instrument: 2),
          TestFactories.createPerson(id: 3, tenantId: 7, instrument: 2, paused: true),
        ],
      ),
      personExtraFieldsProvider.overrideWith((ref) async => const <ProfileExtraField>[]),
      groupsMapProvider.overrideWith((ref) async => const {1: 'Violine', 2: 'Flöte'}),
    ],
    child: MaterialApp.router(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      routerConfig: router,
    ),
  );
}

/// REDESIGN: "Termin anlegen" (canvas TerminAnlegen).
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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
    expect(
      rdMovedSeriesEnd(DateTime(2026, 3, 28), DateTime(2026, 3, 30), DateTime(2026, 5, 9)),
      DateTime(2026, 5, 11),
    );
    // Back to winter time (49 h), and moving the start earlier.
    expect(
      rdMovedSeriesEnd(DateTime(2026, 10, 24), DateTime(2026, 10, 26), DateTime(2026, 12, 5)),
      DateTime(2026, 12, 7),
    );
    expect(
      rdMovedSeriesEnd(DateTime(2026, 3, 30), DateTime(2026, 3, 28), DateTime(2026, 5, 11)),
      DateTime(2026, 5, 9),
    );
    // Never before the new first day.
    expect(
      rdMovedSeriesEnd(DateTime(2026, 5, 1), DateTime(2026, 6, 1), DateTime(2026, 4, 1)),
      DateTime(2026, 6, 1),
    );
    // The page moves the end only this way.
    final page =
        readDartLibrary('lib/features/attendance/presentation/pages/rd_event_create_page.dart');
    expect(page, contains('rdMovedSeriesEnd(_date, day, _until)'));
    expect(page, isNot(contains('.difference(_date)')));
  });

  test('rdHolidayOn: school holidays are a range, public holidays one day', () {
    final data = HolidayData(
      publicHolidays: [
        Holiday(
          id: 'a',
          name: 'Weihnachten',
          startDate: DateTime(2026, 12, 25),
          endDate: DateTime(2026, 12, 25),
        ),
      ],
      schoolHolidays: [
        Holiday(
          id: 'b',
          name: 'Herbstferien',
          startDate: DateTime(2026, 10, 26),
          endDate: DateTime(2026, 10, 31),
        ),
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

    test('rdDeadlinePassedOn names the first day whose deadline is over', () {
      final soon = DateTime(2026, 11, 3);
      expect(rdDeadlinePassedOn(RdDeadline.week, [day, soon], '19:00', now: now), soon);
      expect(rdDeadlinePassedOn(RdDeadline.hours24, [day, soon], '19:00', now: now), isNull);
      expect(rdDeadlinePassedOn(RdDeadline.none, [soon], '19:00', now: now), isNull);
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
      final t = rdTemplates(
        [
          _att(1, '2026-09-01', 'p', info: 'Gesamtprobe', place: 'Saal', start: '19:00'),
          _att(2, '2026-10-01', 'p', info: 'Gesamtprobe', place: 'Probenraum 2', start: '19:30'),
          _att(3, '2026-10-02', 'p', info: 'Registerprobe'),
          _att(4, '2026-10-03', 'k'),
          _att(5, '2026-10-04', 'k'),
          _att(6, '2026-10-05', 'h', info: 'Versteckt'),
          _att(7, '2026-10-06', 'p', info: ' gesamtprobe '),
        ],
        const [_probe, _konzert],
      );
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
    testWidgets('landscape keyboard leaves a visible create action without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventCreateTestApp(history: const [], textScale: 1.6));
      await _settle(tester);
      final submit = find.byKey(const ValueKey('rd-create-submit'));
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(140));
      expect(tester.takeException(), isNull);
    });

    testWidgets('manually changed time pair survives changing the type', (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventCreateTestApp(history: const []));
      await _settle(tester);
      await tester.tap(find.text('19:30'));
      await _settle(tester);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop(const TimeOfDay(hour: 20, minute: 15));
      await _settle(tester);
      await tester.tap(find.text('Konzert'));
      await _settle(tester);
      expect(find.text('20:15'), findsOneWidget);
      expect(find.text('21:30'), findsOneWidget);
      expect(find.text('18:00'), findsNothing);
    });

    testWidgets('changing type shows its default end beside a custom start', (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        eventCreateTestApp(
          history: const [],
          permission: Future.value(true),
          types: const [AttendanceType(id: 'open-end', name: 'Offenes Ende', startTime: '19:00'), _konzert],
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('19:00'));
      await _settle(tester);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop(const TimeOfDay(hour: 22, minute: 0));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('rd-create-type-k')));
      await _settle(tester);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('–'), findsNothing);

      // The invalid pair is visible and the existing save validation still blocks it.
      await tester.tap(find.byKey(const ValueKey('rd-create-submit')));
      await _settle(tester);
      expect(find.text('Das Ende kann nicht vor dem Beginn liegen.'), findsOneWidget);
      expect(find.text('page termine'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing type shows its default start beside a custom end', (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        eventCreateTestApp(
          history: const [],
          types: const [AttendanceType(id: 'open-start', name: 'Offener Beginn', endTime: '21:30'), _konzert],
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('21:30'));
      await _settle(tester);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop(const TimeOfDay(hour: 20, minute: 15));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('rd-create-type-k')));
      await _settle(tester);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('20:15'), findsOneWidget);
      expect(find.text('20:00'), findsNothing);
      expect(find.text('–'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all-day duration and duty staffing remain editable', (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        eventCreateTestApp(
          history: const [],
          types: const [
            AttendanceType(
              id: 'd',
              name: 'Probenwochenende',
              allDay: true,
              durationDays: 2,
              dutyMode: true,
              dutyRequired: 3,
            ),
          ],
        ),
      );
      await _settle(tester);
      expect(find.text('Beginn'), findsNothing);
      expect(find.text('2 Tage'), findsOneWidget);
      await tester.tap(find.byTooltip('Einen Tag mehr'));
      await _settle(tester);
      expect(find.text('3 Tage'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byTooltip('Mehr'));
      await _settle(tester);
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rd-create-type-d')));
      await _settle(tester);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed meeting classification offers retry instead of unfiltered creation', (tester) async {
      await tester.pumpWidget(eventCreateTestApp(protocolLoadFails: true));
      await _settle(tester);
      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('rd-create-submit')), findsNothing);
    });

    testWidgets('switching groups while permission is pending does not resume the old draft', (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final permission = Completer<bool>();
      await tester.pumpWidget(eventCreateTestApp(history: const [], permission: permission.future));
      await _settle(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(RdEventCreatePage)));
      await tester.tap(find.byKey(const ValueKey('rd-create-submit')));
      await tester.pump();
      (container.read(currentTenantProvider.notifier) as _TenantNotifier).switchGroup();
      permission.complete(true);
      await _settle(tester);
      expect(find.textContaining('Die Gruppe oder Anmeldung hat sich geändert'), findsOneWidget);
      expect(find.byKey(const ValueKey('rd-create-submit')), findsNothing);
      expect(find.text('page termine'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('manual title and place survive changing the event type', (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventCreateTestApp(history: const []));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Registerprobe');
      await tester.enterText(find.byType(TextField).last, 'Raum 4');
      await tester.tap(find.text('Konzert').first);
      await _settle(tester);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Registerprobe');
      expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'Raum 4');
      expect(find.text('18:00'), findsOneWidget);
    });

    testWidgets('meeting types cannot be chosen in regular event creation', (tester) async {
      await tester.pumpWidget(
        eventCreateTestApp(
          history: const [],
          types: const [_probe, AttendanceType(id: 'm', name: 'Vorstand')],
          protocols: const [ProtocolType(id: 'm', name: 'Vorstand', enableProtocol: true)],
        ),
      );
      await _settle(tester);
      expect(find.text('Vorstand'), findsNothing);
      expect(find.text('Besprechung planen'), findsNothing);
    });

    testWidgets('one bottom create action stays visible at narrow width and large text', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventCreateTestApp(history: const [], textScale: 1.6));
      await _settle(tester);
      final submit = find.byKey(const ValueKey('rd-create-submit'));
      expect(submit, findsOneWidget);
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(740));
      final before = tester.getTopLeft(submit);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await _settle(tester);
      expect(tester.getTopLeft(submit), before);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _settle(tester);
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(440));
      expect(tester.takeException(), isNull);
    });

    testWidgets('submission locks the draft before permission resolves and unlocks on denial', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final permission = Completer<bool>();
      await tester.pumpWidget(eventCreateTestApp(history: const [], permission: permission.future));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('rd-create-submit')));
      await tester.pump();
      final page = tester.element(find.byType(RdEventCreatePage));
      final guards = ProviderScope.containerOf(page).read(routeLeaveGuardRegistryProvider);
      expect(await guards.canLeave(), isFalse);
      expect(
        tester
            .stateList<EditableTextState>(find.byType(EditableText))
            .any((s) => s.widget.focusNode.canRequestFocus),
        isFalse,
      );
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          tester
              .stateList<EditableTextState>(find.byType(EditableText))
              .any((s) => s.widget.focusNode.hasFocus),
          isFalse,
        );
      }
      final button = find.descendant(
        of: find.byKey(const ValueKey('rd-create-submit')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      permission.complete(false);
      await _settle(tester);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(await guards.canLeave(), isTrue);
    });
    testWidgets('type selection, optional fields and weekly series remain available', (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventCreateTestApp());
      await _settle(tester);

      expect(find.text('Neuer Termin'), findsOneWidget);
      expect(find.text('Gesamtprobe'), findsNothing);
      // Start with the selected type's defaults.
      final title = tester.widget<TextField>(find.byType(TextField).first);
      expect(title.controller!.text, 'Probe');
      expect(find.text('Probenraum 2'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
      // Invited: everyone active (the paused person is left out).
      expect(find.text('Eingeladen: Alle · 2'), findsOneWidget);
      // A single create action stays outside the scrolling form.
      expect(find.text('Termin anlegen'), findsOneWidget);
      await tester.tap(find.text('Weitere Optionen'));
      await _settle(tester);
      expect(find.text('Antwort bis'), findsOneWidget);
      expect(find.text('Werke'), findsOneWidget);

      // Changing the type still sets its time; Ort is offered at every Art.
      await tester.tap(find.byKey(const ValueKey('rd-create-type-k')));
      await _settle(tester);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('Ort'), findsOneWidget);

      // Weekly series.
      await tester.tap(find.text('Wiederholen'));
      await _settle(tester);
      await tester.tap(find.text('Jede Woche'));
      await _settle(tester);
      expect(find.text('7 Termine'), findsOneWidget);
      await tester.tap(find.text('Fertig'));
      await _settle(tester);
      expect(find.textContaining('Es werden 7 Termine angelegt'), findsOneWidget);
      expect(find.textContaining('jeden '), findsOneWidget);
    });

    testWidgets('without permission only a hint, Anlegen disabled', (tester) async {
      await tester.pumpWidget(eventCreateTestApp(canCreate: false));
      await _settle(tester);
      expect(find.text('Du darfst keine Termine anlegen.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Abbrechen after a change asks before discarding', (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventCreateTestApp(history: const []));
      await _settle(tester);
      // Without history, start with the first visible type and its time.
      expect(find.text('Probe'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Sonderprobe');
      await _settle(tester);
      await tester.tap(find.byTooltip('Abbrechen'));
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
    await tester.pumpWidget(eventCreateTestApp(history: const []));
    await _settle(tester);
    final guards = ProviderScope.containerOf(
      tester.element(find.byType(RdEventCreatePage)),
    ).read(routeLeaveGuardRegistryProvider);
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
    final page =
        readDartLibrary('lib/features/attendance/presentation/pages/rd_event_create_page.dart');
    final writes =
        readDartLibrary('lib/features/attendance/presentation/attendance_create_writes.dart');
    final router = readDartLibrary('lib/core/router/app_router.dart');

    test('creates through the shared write path with permission check', () {
      expect(page, contains('AttendanceCreateWriter(ref)'));
      expect(page, contains('confirmCanCreateAttendance('));
      expect(page, contains('DemoGuard.blocked()'));
    });

    test('writes are tenant-scoped', () {
      expect(writes, contains("'tenantId': tenant.id,"));
      expect(writes, contains(".eq('tenantId', tenant.id!)"));
      expect(writes, isNot(contains("'created_by':")));
    });

    test('route "neu" is matched before ":id"', () {
      expect(RedesignRoutes.newEvent, '/termine/neu');
      final neu = router.indexOf(
        RegExp(r"path:\s*'neu',\s*name:\s*'redesignEventCreate'"),
      );
      final id = router.indexOf("name: 'redesignEvent',");
      expect(neu, isNot(-1));
      expect(neu, lessThan(id));
    });
  });
}
