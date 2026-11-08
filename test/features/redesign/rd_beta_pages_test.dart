import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
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
import 'package:attendix/features/redesign/data/providers/rd_stats_providers.dart';
import 'package:attendix/features/redesign/data/rd_manage_logic.dart';
import 'package:attendix/features/redesign/data/rd_stats_logic.dart';
import 'package:attendix/features/redesign/presentation/widgets/members/rd_member_bulk.dart' show rdApplyToAll;
import 'package:attendix/features/redesign/presentation/pages/rd_message_compose_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

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
        attendanceTypesProvider.overrideWith((ref) async => [TestFactories.createAttendanceType(id: 'p', name: 'Probe')]),
        filteredAttendancesForStatsProvider.overrideWith((ref) async => [
              for (var i = 1; i <= 8; i++)
                TestFactories.createAttendance(id: i, typeId: 'p', date: '2026-10-${(i + 10).toString()}', percentage: 50.0 + i * 5),
            ]),
        allPersonAttendancesForStatsProvider.overrideWith((ref) async => [
              for (var i = 1; i <= 8; i++) ...[
                PersonAttendance(attendanceId: i, personId: 1, status: AttendanceStatus.present),
                PersonAttendance(attendanceId: i, personId: 2, status: i < 7 ? AttendanceStatus.absent : AttendanceStatus.present),
                PersonAttendance(attendanceId: i, personId: 3, status: AttendanceStatus.present),
              ],
            ]),
        activePlayersForStatsProvider.overrideWith((ref) async => _people),
        rdStatsPreviousDataProvider.overrideWith((ref) async => null),
        playersProvider.overrideWith((ref) async => _people),
        archivedPlayersProvider.overrideWith((ref) async => const <Person>[]),
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

    test('one way of counting: shown Terminarten, Register filter, Dirigent no Register', () {
      final types = [
        TestFactories.createAttendanceType(id: 'p', name: 'Probe'),
        TestFactories.createAttendanceType(id: 'f', name: 'Feier').copyWith(includeInAverage: false),
      ];
      final groups = [
        TestFactories.createGroup(id: 1, name: 'Viola'),
        TestFactories.createGroup(id: 2, name: 'Cello'),
        TestFactories.createGroup(id: 9, name: 'Dirigent', maingroup: true),
      ];
      final anna = TestFactories.createPerson(id: 1, firstName: 'Anna').copyWith(instrument: 1);
      final ben = TestFactories.createPerson(id: 2, firstName: 'Ben').copyWith(instrument: 1);
      final clara = TestFactories.createPerson(id: 3, firstName: 'Clara').copyWith(instrument: 2);
      final dirk = TestFactories.createPerson(id: 4, firstName: 'Dirk').copyWith(instrument: 9);
      final attendances = [
        for (var i = 1; i <= 4; i++) TestFactories.createAttendance(id: i, typeId: 'p', date: '2026-10-0$i'),
        TestFactories.createAttendance(id: 5, typeId: 'f', date: '2026-10-05'),
      ];
      PersonAttendance pa(int att, int person, AttendanceStatus status, [String? notes]) =>
          PersonAttendance(attendanceId: att, personId: person, status: status, notes: notes);
      final rows = [
        for (var i = 1; i <= 5; i++) ...[
          // Anna is always there, Dirk too.
          pa(i, 1, AttendanceStatus.present),
          pa(i, 4, AttendanceStatus.present),
          // Ben: late once, absent twice, neutral once (counts as not there,
          // like the Mitglieder percentages) → 1 of 4.
          pa(i, 2, [AttendanceStatus.late, AttendanceStatus.absent, AttendanceStatus.absent, AttendanceStatus.neutral, AttendanceStatus.absent][i - 1]),
          // Clara is excused for work: there only with the group setting.
          pa(i, 3, AttendanceStatus.excused, 'Arbeitsbedingt'),
        ],
      ];
      RdStatsResult run(RdStatsFilter filter, {bool shift = false}) => rdComputeStats(
            attendances: attendances,
            personAttendances: rows,
            types: types,
            players: [anna, ben, clara, dirk],
            groups: groups,
            filter: filter,
            shiftExcusedAsPresent: shift,
          );

      // Default: only the Terminarten that count (no Feier).
      final all = run(const RdStatsFilter());
      expect(all.events.map((e) => e.attendance.id), [1, 2, 3, 4]);
      expect(all.events.first.percent, 75); // Anna, Ben (late), Dirk of 4
      expect(all.groups.map((g) => g.group.name), ['Viola', 'Cello']); // no Dirigent
      expect(all.groups.first.percent, 63); // Viola: 5 of 8
      expect(all.low().map((p) => p.person.firstName), ['Clara', 'Ben']);
      expect(all.counts.late, 1);
      expect(all.counts.open, 1);
      // Work-excused counts as there when the group says so.
      expect(run(const RdStatsFilter(), shift: true).low().map((p) => p.person.firstName), ['Ben']);
      // Register filter: the Termine count only the chosen Register.
      final viola = run(const RdStatsFilter(groupIds: {1}));
      expect(viola.events.first.percent, 100);
      expect(viola.people.map((p) => p.person.firstName), ['Anna', 'Ben']);
      // Terminart filter: the Feier on its own.
      final party = run(const RdStatsFilter(typeIds: {'f'}));
      expect(party.events.single.attendance.id, 5);
      expect(rdStatsTypeIds(const RdStatsFilter(), types), {'p'});
      // Both Terminarten shown: one row each; Probe alone again = no filter.
      final both = run(rdStatsFilterWithTypes(const RdStatsFilter(), {'p', 'f'}, types));
      expect(rdStatsByType(both.events).map((t) => (t.type.name, t.events)), [('Probe', 4), ('Feier', 1)]);
      expect(rdStatsFilterWithTypes(const RdStatsFilter(typeIds: {'p', 'f'}), {'p'}, types).typeIds, isNull);
      // Termine level: weakest first, same percentage newest first.
      expect(rdSortStatsEvents(all.events, RdStatsEventSort.weakest).map((e) => e.attendance.id), [4, 3, 2, 1]);
      // "ggü. davor": the same number of days right before; the Register
      // that lost most (Cello was at 100 % before).
      final prev = rdStatsPreviousPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 10, 18));
      expect((prev!.start, prev.end), (DateTime(2026, 9, 21), DateTime(2026, 10, 1)));
      expect(rdStatsPreviousPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 3)), isNull);
      // March has 31 days also across the change to summer time.
      expect(rdStatsPreviousPeriod(DateTime(2026, 3, 1), DateTime(2026, 3, 31))?.start, DateTime(2026, 1, 29));
      final before = run(const RdStatsFilter(), shift: true);
      expect(rdStatsBiggestDrop(all, before)?.$1.group.name, 'Cello');
      expect(rdStatsBiggestDrop(before, all), isNull);
      // Personen level: most often absent first; Register curve per month.
      expect(rdSortStatsPeople(all.people, RdStatsPersonSort.absent).first.person.firstName, 'Ben');
      expect(all.groups.first.months, [(DateTime(2026, 10), 63)]);
      expect(rdStatsAgeDecades([anna.copyWith(birthday: '2000-12-31'), ben.copyWith(birthday: '1979-01-01')], DateTime(2026, 11, 8)),
          [(20, 1), (30, 0), (40, 1)]);
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

    test('the Verwaltung search finds it for leads only (now in the Mitglieder tab)', () {
      expect(RdManageEntry.bulkMembers.home, RdManageHome.members);
      expect(rdManageVisible(RdManageEntry.bulkMembers, const RdManageAccess(isAdmin: true)), isTrue);
      expect(rdManageVisible(RdManageEntry.bulkMembers, const RdManageAccess()), isFalse);
      expect(rdManageVisible(RdManageEntry.announcements, const RdManageAccess(isAdmin: true)), isTrue);
      expect(rdManageVisible(RdManageEntry.announcements, const RdManageAccess()), isFalse);
    });
  });

  group('routes', () {
    test('lead pages send everyone else back to Ich', () {
      for (final route in [RedesignRoutes.stats, RedesignRoutes.compose]) {
        expect(RedesignRoutes.roleRedirect(route, Role.admin), isNull, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.responsible), isNull, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.helper), RedesignRoutes.me, reason: route);
        expect(RedesignRoutes.roleRedirect(route, Role.player), RedesignRoutes.me, reason: route);
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
    testWidgets('Auswertung: Überblick, Termine, Personen and Register', (tester) async {
      await _pump(tester, const RdStatsPage());
      expect(find.text('Auswertung'), findsOneWidget);
      expect(find.text('Saison'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ben Bach'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('1 Person unter 50 %'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Alle Termine'), -200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Alle Termine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Neueste zuerst'), findsOneWidget);
      // "Fällt auf" leads to the Personen, weakest first, with Mitglieder.
      await tester.tap(find.text('Überblick'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('1 Person unter 50 %'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('1 Person unter 50 %'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wenigste zuerst'), findsOneWidget);
      expect(find.text('Holz · 6 abwesend'), findsOneWidget);
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Holz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
