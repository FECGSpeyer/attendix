import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/statistics_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_stats_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_manage_entries.dart'
    show rdManagePendingProvider;
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/utils/tiptap_converter.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/redesign/data/rd_manage_logic.dart';
import 'package:attendix/features/redesign/data/rd_stats_logic.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_bulk_members_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_message_compose_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

PersonAttendance _pa(int personId, AttendanceStatus status) =>
    PersonAttendance(attendanceId: 1, personId: personId, status: status);

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO');
  }
}

final _people = [
  TestFactories.createPerson(id: 1, firstName: 'Anna', lastName: 'Alt').copyWith(instrument: 1),
  TestFactories.createPerson(id: 2, firstName: 'Ben', lastName: 'Bach').copyWith(instrument: 1),
  TestFactories.createPerson(id: 3, firstName: 'Clara', lastName: 'Cello').copyWith(instrument: 2),
];

Widget _app(Widget home) => ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        groupsProvider.overrideWith((ref) async => [
              TestFactories.createGroup(id: 1, name: 'Holz'),
              TestFactories.createGroup(id: 2, name: 'Streicher'),
            ]),
        attendanceTypesProvider.overrideWith((ref) async => const []),
        filteredAttendancesForStatsProvider.overrideWith((ref) async => [
              for (var i = 1; i <= 8; i++)
                TestFactories.createAttendance(id: i, date: '2026-10-${(i + 10).toString()}', percentage: 50.0 + i * 5),
            ]),
        allPersonAttendancesForStatsProvider.overrideWith((ref) async => [
              for (var i = 1; i <= 8; i++) ...[
                PersonAttendance(attendanceId: i, personId: 1, status: AttendanceStatus.present),
                PersonAttendance(attendanceId: i, personId: 2, status: i < 7 ? AttendanceStatus.absent : AttendanceStatus.present),
                PersonAttendance(attendanceId: i, personId: 3, status: AttendanceStatus.present),
              ],
            ]),
        activePlayersForStatsProvider.overrideWith((ref) async => _people),
        realtimePlayersProvider.overrideWith((ref) => Stream.value(_people)),
        rdManagePendingProvider.overrideWith((ref) => const <Person>[]),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: home,
      ),
    );

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// REDESIGN: Auswertung, Mitteilung schreiben, Mitglieder bearbeiten and
/// Benachrichtigungen of the new design.
void main() {
  group('Auswertung', () {
    final today = DateTime(2026, 10, 30);

    test('ranges: season from the tenant, else 1 Jan 2023 like Ionic', () {
      expect(rdStatsRangeStart(RdStatsRange.season, today, seasonStart: '2026-09-01'), DateTime(2026, 9, 1));
      expect(rdStatsRangeStart(RdStatsRange.season, today), DateTime(2023, 1, 1));
      expect(rdStatsRangeStart(RdStatsRange.threeMonths, today), DateTime(2026, 7, 30));
      expect(rdStatsRangeStart(RdStatsRange.twelveMonths, today), DateTime(2025, 10, 30));
    });

    test('people below 50 %: lowest first, neutral and few Termine ignored', () {
      final anna = TestFactories.createPerson(id: 1, firstName: 'Anna');
      final ben = TestFactories.createPerson(id: 2, firstName: 'Ben');
      final clara = TestFactories.createPerson(id: 3, firstName: 'Clara');
      final paused = TestFactories.createPausedPerson().copyWith(id: 4);
      final pas = [
        // Anna 1 of 4 = 25 %
        _pa(1, AttendanceStatus.present),
        _pa(1, AttendanceStatus.absent),
        _pa(1, AttendanceStatus.absent),
        _pa(1, AttendanceStatus.excused),
        // Ben 1 of 3 = 33 %, the neutral entries do not count
        _pa(2, AttendanceStatus.late),
        _pa(2, AttendanceStatus.absent),
        _pa(2, AttendanceStatus.absent),
        _pa(2, AttendanceStatus.neutral),
        _pa(2, AttendanceStatus.neutral),
        // Clara only 2 Termine: left out
        _pa(3, AttendanceStatus.absent),
        _pa(3, AttendanceStatus.absent),
        // paused people are not listed
        _pa(4, AttendanceStatus.absent),
        _pa(4, AttendanceStatus.absent),
        _pa(4, AttendanceStatus.absent),
      ];
      final low = rdLowAttendance(pas, [anna, ben, clara, paused]);
      expect(low.map((e) => e.person.firstName), ['Anna', 'Ben']);
      expect(low.map((e) => e.percent), [25, 33]);
    });
  });

  group('Mitteilung schreiben', () {
    test('plain text becomes one Tiptap paragraph per line', () {
      final doc = rdPlainTextDoc('Hallo zusammen,\nbitte zusagen.\n\n');
      expect(doc['type'], 'doc');
      final paragraphs = (doc['content'] as List).where((n) => (n as Map)['type'] == 'paragraph').toList();
      expect(paragraphs, hasLength(2));
      expect(TiptapConverter.hasText(doc), isTrue);
    });
  });

  group('Mitglieder bearbeiten', () {
    test('one failing person does not stop the others', () async {
      final persons = [
        TestFactories.createPerson(id: 1),
        TestFactories.createPerson(id: 2),
        TestFactories.createPerson(id: 3),
      ];
      final done = <int>[];
      final result = await rdApplyToAll(persons, (p) async {
        if (p.id == 2) throw Exception('RLS');
        done.add(p.id!);
      });
      expect(result.ok, 2);
      expect(result.failed, 1);
      expect(done, [1, 3]);
    });

    test('Verwaltung lists it for leads, never for applicants', () {
      expect(rdManageVisible(RdManageEntry.bulkMembers, const RdManageAccess(isAdmin: true)), isTrue);
      expect(rdManageVisible(RdManageEntry.bulkMembers, const RdManageAccess()), isFalse);
      expect(
        rdManageVisible(RdManageEntry.bulkMembers, const RdManageAccess(isAdmin: true, isApplicant: true)),
        isFalse,
      );
      expect(rdManageVisible(RdManageEntry.writeMessage, const RdManageAccess(isAdmin: true)), isTrue);
      expect(rdManageVisible(RdManageEntry.writeMessage, const RdManageAccess(isHelper: true)), isFalse);
    });
  });

  group('routes', () {
    test('lead pages redirect everyone else to the Verwaltung', () {
      for (final route in [RedesignRoutes.stats, RedesignRoutes.compose, RedesignRoutes.bulkMembers]) {
        expect(RedesignRoutes.roleRedirect(route, Role.admin), isNull, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.responsible), isNull, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.helper), RedesignRoutes.manage, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.player), RedesignRoutes.manage, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.parent), RedesignRoutes.me, reason: route);
      }
    });

    test('Benachrichtigungen is open to everyone with the Ich tab', () {
      expect(RedesignRoutes.notifications, '/ich/benachrichtigungen');
      expect(RedesignRoutes.isRedesignRoute(RedesignRoutes.notifications), isTrue);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.notifications, Role.player), isNull);
    });
  });

  group('pages render', () {
    testWidgets('Auswertung: figures, Register and the people below 50 %', (tester) async {
      await _pump(tester, const RdStatsPage());
      expect(find.text('Auswertung'), findsOneWidget);
      expect(find.text('Saison'), findsOneWidget);
      expect(find.text('Holz'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ben Bach'), 200);
      expect(find.text('1 Person unter 50 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mitglieder bearbeiten: selection shows the action bar', (tester) async {
      await _pump(tester, const RdBulkMembersPage());
      expect(find.text('Mitglieder bearbeiten'), findsOneWidget);
      expect(find.text('Archivieren'), findsNothing);
      await tester.tap(find.text('Anna Alt'));
      await tester.pump();
      expect(find.text('1 ausgewählt'), findsOneWidget);
      expect(find.text('Archivieren'), findsOneWidget);
      await tester.tap(find.text('Alle in Holz'));
      await tester.pump();
      expect(find.text('2 ausgewählt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
