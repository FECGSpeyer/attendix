import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/widgets/today/rd_remind_open_sheet.dart';
import 'package:attendix/l10n/generated/app_localizations_de.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../factories/test_factories.dart';
import '../../mocks/repository_mocks.dart';

/// REDESIGN: review fixes of the UX package 2 (D2 duty detection, partial
/// send failures, shared text).
void main() {
  final l10n = AppLocalizationsDe();

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  group('D2: duty Termin is detected from the current list', () {
    final tim = TestFactories.createPerson(id: 1, firstName: 'Tim');
    final eva = TestFactories.createPerson(id: 2, firstName: 'Eva');
    const rows = [
      PersonAttendance(personId: 1, status: AttendanceStatus.neutral, dutyState: 'requested'),
      PersonAttendance(personId: 2, status: AttendanceStatus.neutral),
    ];

    Future<List<int?>> openFor(List<Attendance> list) async {
      final repo = MockAttendanceRepository();
      when(() => repo.hasTenantId).thenReturn(true);
      when(() => repo.getPersonAttendancesForAttendances(any())).thenAnswer((_) async => rows);
      final container = ProviderContainer(overrides: [
        attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
        realtimePlayersProvider.overrideWith((ref) => Stream.value([tim, eva])),
        attendanceTypesProvider.overrideWith((ref) async => [
              TestFactories.createAttendanceType(id: 'd', name: 'Dienst').copyWith(dutyMode: true),
              TestFactories.createAttendanceType(id: 'p', name: 'Probe'),
            ]),
        realtimeAttendanceListProvider.overrideWith((ref) async => list),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(rdOpenPersonsProvider(5), (_, __) {});
      addTearDown(sub.close);
      final open = await container.read(rdOpenPersonsProvider(5).future);
      return open.map((p) => p.id).toList();
    }

    test('duty type: stand-ins are left out', () async {
      expect(await openFor([TestFactories.createAttendance(id: 5, date: '2026-11-02', typeId: 'd')]), [1]);
    });

    test('normal type and Termine without a type: everybody open', () async {
      expect(await openFor([TestFactories.createAttendance(id: 5, date: '2026-11-02', typeId: 'p')]), [2, 1]);
      expect(await openFor([TestFactories.createAttendance(id: 5, date: '2026-11-02')]), [2, 1]);
    });

    test('unknown Termin or type counts as duty', () async {
      expect(await openFor(const []), [1]);
      expect(await openFor([TestFactories.createAttendance(id: 5, date: '2026-11-02', typeId: 'x')]), [1]);
    });
  });

  group('D2: shared text', () {
    const defaultBody = 'für „Probe“ am Mo 2.11. fehlt noch deine Antwort.';

    test('standard text while the message is unchanged', () {
      expect(
        rdRemindShareText(l10n, body: '$defaultBody ', defaultBody: defaultBody, title: 'Probe', when: 'Mo 2.11.'),
        l10n.redesignRemindShareText('Probe', 'Mo 2.11.'),
      );
    });

    test('the edited message after "Hallo zusammen,"', () {
      expect(
        rdRemindShareText(l10n, body: 'Bitte bis Freitag antworten.', defaultBody: defaultBody, title: 'Probe', when: ''),
        'Hallo zusammen,\nBitte bis Freitag antworten.',
      );
    });
  });

  testWidgets('D2: after a partial failure only the others are offered again', (tester) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tim = TestFactories.createPerson(id: 1, firstName: 'Tim', lastName: 'Maurer', appId: 'a1');
    final eva = TestFactories.createPerson(id: 2, firstName: 'Eva', lastName: 'Kurz', appId: 'a2');
    final repo = MockAttendanceRepository();
    final sentTo = <String?>[];
    when(() => repo.sendAdHocReminder(
          attendanceId: any(named: 'attendanceId'),
          title: any(named: 'title'),
          message: any(named: 'message'),
          playerAppId: any(named: 'playerAppId'),
        )).thenAnswer((inv) async {
      final appId = inv.namedArguments[#playerAppId] as String?;
      sentTo.add(appId);
      if (appId == 'a2' && sentTo.where((id) => id == 'a2').length == 1) throw Exception('push down');
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        attendanceRepositoryWithTenantProvider.overrideWithValue(repo),
        rdOpenPersonsProvider.overrideWith((ref, id) async => <Person>[eva, tim]),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.values.first, Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRdRemindOpenSheet(context, attendanceId: 5, title: 'Probe', when: 'Mo 2.11.'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('Push an 2 Personen senden'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sentTo, ['a2', 'a1']);
    expect(find.text('1 gesendet, 1 fehlgeschlagen'), findsOneWidget);
    expect(find.text('erinnert'), findsOneWidget, reason: 'Tim was reached');
    expect(find.text('Push an 1 Person senden'), findsOneWidget);

    await tester.tap(find.text('Push an 1 Person senden'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sentTo, ['a2', 'a1', 'a2'], reason: 'Tim is not reminded twice');
    expect(tester.takeException(), isNull);
  });
}
