// IOS_ATT_PAGES: Übersicht numbers like Ionic OverviewPage, Meine Termine
// row titles like Ionic signout, iOS look of the Termin pages.
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/services/cross_tenant_service.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/adaptive/ion_toolbar_segment.dart';
import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _uebung = AttendanceType(id: 'u', name: 'Übung', hideName: true);
const _konzert = AttendanceType(id: 'k', name: 'Konzert');
const _noAvg = AttendanceType(id: 'x', name: 'Sitzung', includeInAverage: false);

CrossTenantPersonAttendance _att(
  String date, {
  AttendanceStatus status = AttendanceStatus.present,
  AttendanceType? type = _konzert,
  int tenantId = 1,
  int? durationDays,
  String? notes,
  bool honorHideName = true,
}) =>
    CrossTenantPersonAttendance(
      id: '$tenantId-$date',
      date: date,
      status: status,
      notes: notes,
      attendanceType: type,
      includeInAverage: type?.includeInAverage ?? true,
      durationDays: durationDays,
      tenantId: tenantId,
      tenantName: 'T$tenantId',
      tenantColor: '#000000',
      honorHideName: honorHideName,
    );

void main() {
  final now = DateTime(2026, 10, 28, 12);
  setUpAll(() => initializeDateFormatting());

  group('buildOverviewData (Ionic processAttendances / calculateStats)', () {
    test('splits past (newest first) and upcoming (ascending)', () {
      final data = buildOverviewData([
        _att('2026-06-01T19:00:00'),
        _att('2026-11-02T19:00:00'),
        _att('2026-06-15T19:00:00'),
        _att('2026-10-28T19:00:00'), // today → upcoming
        _att('2026-10-30T19:00:00'),
      ], now: now);
      expect(data.past.map((a) => a.date), [
        '2026-06-15T19:00:00',
        '2026-06-01T19:00:00',
      ]);
      expect(data.upcoming.map((a) => a.date), [
        '2026-10-28T19:00:00',
        '2026-10-30T19:00:00',
        '2026-11-02T19:00:00',
      ]);
    });

    test('percentage over include_in_average types, rounded like Math.round', () {
      // 31 past Termine, 20 attended → 65 % (Ionic screenshot numbers)
      final atts = [
        for (var i = 0; i < 31; i++)
          _att(
            DateTime(2026, 1, 1).add(Duration(days: i * 5)).toIso8601String(),
            status: i < 20 ? AttendanceStatus.present : AttendanceStatus.absent,
          ),
        // not counted for the average
        _att('2026-07-01T19:00:00', type: _noAvg, status: AttendanceStatus.absent),
      ];
      final data = buildOverviewData(atts, now: now);
      expect(data.past.length, 32);
      expect(data.stats.totalCount, 31);
      expect(data.stats.presentCount, 20);
      expect(data.stats.percentage, 65);
    });

    test('late and late excused count as attended; late count = Verspätet only', () {
      final data = buildOverviewData([
        _att('2026-09-01', status: AttendanceStatus.late),
        _att('2026-09-02', status: AttendanceStatus.lateExcused),
        _att('2026-09-03', status: AttendanceStatus.excused),
        _att('2026-09-04', status: AttendanceStatus.neutral),
      ], now: now);
      expect(data.stats.presentCount, 2);
      expect(data.stats.percentage, 50);
      expect(data.stats.lateCount, 1);
    });

    test('shift_excused_as_present counts work-excused absences', () {
      final atts = [
        _att('2026-09-01', status: AttendanceStatus.excused, notes: 'Schichtbedingt'),
        _att('2026-09-02', status: AttendanceStatus.excused, notes: 'Krank'),
      ];
      expect(buildOverviewData(atts, now: now).stats.percentage, 0);
      expect(
        buildOverviewData(atts, now: now, shiftExcusedAsPresent: true).stats.percentage,
        50,
      );
    });

    test('no Termin for the average → 0 % and no late count', () {
      final data = buildOverviewData([
        _att('2026-09-01', type: _noAvg, status: AttendanceStatus.late),
      ], now: now);
      expect(data.past.length, 1);
      expect(data.stats.percentage, 0);
      expect(data.stats.lateCount, 0);
    });

    test('multi-day Termin stays upcoming until its last day (own duration_days)', () {
      final data = buildOverviewData([
        _att('2026-10-26', durationDays: 3), // 26.–28.10.
        _att('2026-10-25', durationDays: 3), // 25.–27.10.
      ], now: now);
      expect(data.upcoming.map((a) => a.date), ['2026-10-26']);
      expect(data.past.map((a) => a.date), ['2026-10-25']);
    });
  });

  test('groupOverviewByTenant: first-seen order, upcoming asc then past desc', () {
    final groups = groupOverviewByTenant([
      _att('2026-01-01', tenantId: 2),
      _att('2026-02-01', tenantId: 1),
      _att('2026-11-05', tenantId: 2),
      _att('2026-03-01', tenantId: 2),
      _att('2026-11-01', tenantId: 2),
    ], now: now);
    expect(groups.length, 2);
    expect(groups.first.map((a) => a.date),
        ['2026-11-01', '2026-11-05', '2026-03-01', '2026-01-01']);
    expect(groups.last.single.tenantId, 1);
  });

  group('row titles', () {
    test('Meine Termine ignores hide_name like Ionic (attType without hide_name)', () {
      final signout = _att('2026-09-01', type: _uebung, honorHideName: false);
      expect(signout.title, 'Übung');
      expect(signout.eventTitle, 'Übung');
      expect(signout.readableDate, isNot('Übung'));
    });

    test('Übersicht honours hide_name (full attendance_types)', () {
      final overview = _att('2026-09-01', type: _uebung);
      expect(overview.title, '');
      expect(overview.eventTitle, overview.readableDate);
    });
  });

  group('cross-tenant loader matches Ionic scope (source analysis)', () {
    late String src;
    late String body;
    setUpAll(() {
      src = File('lib/data/repositories/sign_in_out_repository.dart').readAsStringSync();
      final start = src.indexOf('Future<List<CrossTenantPersonAttendance>> getAllPersonAttendancesAcrossTenants()');
      final end = src.indexOf('static String tenantDisplayName', start);
      body = src.substring(start, end);
    });

    test('tenants come from the own tenantUsers memberships', () {
      expect(body, contains(".from('tenantUsers')"));
      expect(body, contains(".eq('userId', userId)"));
    });

    test('one person per tenant (tenantId + appId), several → the active one',
        () {
      expect(body, contains(".eq('tenantId', tenantId)"));
      expect(body, contains(".eq('appId', userId)"));
      // SOL_FIX14: archived + active rows must not empty the tenant's list.
      expect(body, isNot(contains('.length != 1')));
      expect(body, contains(".select('id, pending, left')"));
      expect(body, contains('CrossTenantService.pickPersonIdForTenant('));
    });

    test('SOL_FIX14: the active row wins over archived / pending rows', () {
      expect(
        CrossTenantService.pickPersonIdForTenant([
          {'id': 1, 'pending': false, 'left': '2025-01-01T00:00:00'},
          {'id': 2, 'pending': true, 'left': null},
          {'id': 3, 'pending': false, 'left': null},
        ]),
        3,
      );
      expect(
        CrossTenantService.pickPersonIdForTenant([
          {'id': 9, 'pending': false, 'left': null},
        ]),
        9,
      );
    });

    test('person_attendances are restricted to the tenant and the season', () {
      expect(body, contains('attendance_id!inner'));
      expect(body, contains(".eq('attendance.tenantId', tenantId)"));
      expect(body, contains(".gt('attendance.date', overviewSeasonStart("));
    });

    test('tenant label is longName before shortName', () {
      expect(body, contains("select('id, shortName, longName, seasonStart')"));
    });
  });

  group('iOS look of the Termin pages', () {
    Widget app(Widget body) => MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: eventPageBackground(context),
              body: body,
            ),
          ),
        );

    testWidgets('iOS: plain rows on the white page, no card', (tester) async {
      await tester.pumpWidget(app(const EventListCard(
        plain: true,
        children: [Text('a'), Text('b')],
      )));
      expect(find.byType(Card), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Material: plain white list on the white page (Ionic md)',
        (tester) async {
      await tester.pumpWidget(app(const EventListCard(
        plain: true,
        children: [Text('a')],
      )));
      expect(find.byType(Card), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Material: non-plain list keeps the card', (tester) async {
      await tester.pumpWidget(app(const EventListCard(
        children: [Text('a')],
      )));
      expect(find.byType(Card), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    Widget segment(ValueChanged<String> onChanged) => IonToolbarSegment<String>(
          items: const [
            IonSegmentItem(value: 'chronological', label: Text('Chronologisch')),
            IonSegmentItem(value: 'byTenant', label: Text('Nach Instanz')),
          ],
          value: 'chronological',
          onChanged: onChanged,
        );

    testWidgets('iOS: neutral centred toolbar segment', (tester) async {
      String? picked;
      await tester.pumpWidget(app(Align(
        alignment: Alignment.topCenter,
        child: segment((v) => picked = v),
      )));
      expect(find.byType(SegmentedButton<String>), findsNothing);
      final a = tester.getRect(find.text('Chronologisch'));
      final b = tester.getRect(find.text('Nach Instanz'));
      // centred and narrower than the screen
      final mid = (a.left + b.right) / 2;
      expect(mid, closeTo(400, 30));
      // (test font: 1em glyphs, 15pt labels + 13pt padding → ≈420 of 800)
      expect(b.right - a.left, lessThan(500));
      // black labels
      final style = tester.widget<RichText>(find.descendant(
          of: find.text('Chronologisch'), matching: find.byType(RichText)).first);
      expect(style.text.style?.color, AppTheme.light.colorScheme.onSurface);
      await tester.tap(find.text('Nach Instanz'));
      expect(picked, 'byTenant');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Material: full-width Ionic md segment', (tester) async {
      await tester.pumpWidget(app(segment((_) {})));
      // IOS_THEME2: Ionic md segment – uppercase tabs, no Material box.
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.byType(IonSegment<String>), findsOneWidget);
      expect(find.text('CHRONOLOGISCH'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
