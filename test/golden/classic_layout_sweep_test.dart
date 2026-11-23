// Layout, overflow and theme/text-scaling sweep across all core classic
// ("normal") pages. Runs with real app fonts (flutter_test_config.dart) across:
// - 375x667 iOS & MD (small phone: catches narrow overflows & clipping)
// - 390x844 iOS Dark + textScale 1.3 (dark contrast + large system font)
// - 768x1024 iOS (tablet portrait)
// - 1280x800 MD (desktop / wide split layout + side panel)
@Tags(['golden'])
library;

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/admin_providers.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_rate_filter_providers.dart';
import 'package:attendix/core/providers/auto_message_providers.dart';
import 'package:attendix/core/providers/conductor_providers.dart';
import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/history_providers.dart';
import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/statistics_providers.dart';
import 'package:attendix/core/providers/teacher_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/providers/viewer_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/auto_message/auto_message.dart';
import 'package:attendix/data/models/dashboard/dashboard_event.dart';
import 'package:attendix/data/models/dashboard/dashboard_models.dart';
import 'package:attendix/data/models/history/history_entry.dart';
import 'package:attendix/data/models/message/message.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/shift/shift_definition.dart';
import 'package:attendix/data/models/shift/shift_plan.dart';
import 'package:attendix/data/models/storage/storage_entry.dart';
import 'package:attendix/data/models/teacher/teacher.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_list_page.dart';
import 'package:attendix/features/dashboard/presentation/pages/home_dashboard_page.dart';
import 'package:attendix/features/export/presentation/pages/export_page.dart';
import 'package:attendix/features/history/presentation/pages/history_page.dart';
import 'package:attendix/features/instruments/presentation/pages/instruments_list_page.dart';
import 'package:attendix/features/messages/presentation/pages/auto_message_list_page.dart';
import 'package:attendix/features/messages/presentation/pages/message_list_page.dart';
import 'package:attendix/features/parents/data/providers/parents_providers.dart';
import 'package:attendix/features/parents/presentation/pages/parents_portal_page.dart';
import 'package:attendix/features/people/presentation/pages/people_list_page.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart';
import 'package:attendix/features/self_service/presentation/pages/self_service_overview_page.dart';
import 'package:attendix/features/self_service/presentation/pages/signout_page.dart';
import 'package:attendix/features/settings/presentation/pages/attendance_types_page.dart';
import 'package:attendix/features/settings/presentation/pages/files_page.dart';
import 'package:attendix/features/settings/presentation/pages/general_settings_page.dart';
import 'package:attendix/features/settings/presentation/pages/left_players_page.dart'
    show leftPlayersProvider;
import 'package:attendix/features/settings/presentation/pages/settings_page.dart';
import 'package:attendix/features/shifts/presentation/pages/shifts_list_page.dart';
import 'package:attendix/features/songs/presentation/pages/songs_list_page.dart';
import 'package:attendix/features/statistics/presentation/pages/statistics_page.dart';
import 'package:attendix/features/teachers/presentation/pages/teachers_list_page.dart';
import 'package:attendix/features/tenant_selection/presentation/pages/tenant_selection_page.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:attendix/shared/widgets/layout/side_nav/side_nav.dart';
import 'package:attendix/shared/widgets/layout/side_nav/side_nav_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../factories/test_factories.dart';
import 'support/golden_harness.dart';
import 'support/golden_world.dart';

class _SweepConfig {
  const _SweepConfig({
    required this.label,
    required this.look,
    required this.size,
    this.brightness = Brightness.light,
    this.textScaler,
  });

  final String label;
  final GoldenLook look;
  final Size size;
  final Brightness brightness;
  final TextScaler? textScaler;
}

const _sweepMatrix = <_SweepConfig>[
  _SweepConfig(label: 'phone375-ios', look: GoldenLook.classicIos, size: Size(375, 667)),
  _SweepConfig(label: 'phone375-md', look: GoldenLook.classicMd, size: Size(375, 667)),
  _SweepConfig(
    label: 'phone390-dark-1.3x',
    look: GoldenLook.classicIos,
    size: Size(390, 844),
    brightness: Brightness.dark,
    textScaler: TextScaler.linear(1.3),
  ),
  _SweepConfig(label: 'tablet768-ios', look: GoldenLook.classicIos, size: Size(768, 1024)),
  _SweepConfig(label: 'desktop1280-md', look: GoldenLook.classicMd, size: Size(1280, 800)),
];

class _PageCase {
  const _PageCase({
    required this.name,
    required this.path,
    required this.buildPage,
    required this.overrides,
    this.inShell = false,
  });

  final String name;
  final String path;
  final Widget Function() buildPage;
  final List<Override> Function() overrides;
  final bool inShell;
}

class _FakeFilesRepository extends Fake implements FilesRepository {
  @override
  bool get hasTenantId => true;

  @override
  int get currentTenantId => worldTenantId;

  @override
  Future<List<StorageEntry>> listEntries([String relativePath = '']) async => [
        StorageEntry(
          name: 'Konzertprogramme 2099',
          path: 'Konzertprogramme 2099',
          isFolder: true,
          updatedAt: DateTime(2099, 2, 1),
        ),
        StorageEntry(
          name: 'Sehr_langer_Dateiname_Probenplan_Fruehjahrskonzert_2099_v3_final.pdf',
          path: 'Sehr_langer_Dateiname_Probenplan_Fruehjahrskonzert_2099_v3_final.pdf',
          isFolder: false,
          size: 2457600,
          updatedAt: DateTime(2099, 2, 15, 19, 30),
        ),
        StorageEntry(
          name: 'Stimmprobe_Violine_Aufnahme.mp3',
          path: 'Stimmprobe_Violine_Aufnahme.mp3',
          isFolder: false,
          size: 8388608,
          updatedAt: DateTime(2099, 2, 18, 20, 15),
        ),
      ];

  @override
  Future<int> getUsedBytes() async => 42 * 1024 * 1024;
}

Widget _shell(Widget child) => MainShell(child: child);

final _longPersons = <Person>[
  ...worldPersons,
  TestFactories.createPerson(
    id: 99,
    firstName: 'Maximilian-Alexander',
    lastName: 'Freiherr von und zu Langenbach-Westerstetten',
    tenantId: worldTenantId,
    instrument: 1,
    isLeader: true,
    isCritical: true,
    email: 'maximilian.langenbach@example.org',
    joined: '2018-03-01',
  ).copyWith(
    groupName: 'Violine 1 (Konzertmeister)',
    criticalReasonText: 'Mehrfach unentschuldigt gefehlt bei Hauptproben',
  ),
];

final _longAttendances = <Attendance>[
  TestFactories.createAttendance(
    id: 21,
    tenantId: worldTenantId,
    date: '2099-03-05',
    typeId: 't-probe',
    typeInfo: 'Große Gesamtprobe mit Registeraufteilung und anschließendem Stimmcheck',
    startTime: '19:30',
    endTime: '21:30',
  ).copyWith(place: 'Großer Gemeindesaal Hauptstraße 123'),
  ...worldAttendances.skip(1),
];

final _crossUpcoming = [
  CrossTenantPersonAttendance(
    id: 'pa-cross-1',
    personId: 1,
    attendanceId: 21,
    status: AttendanceStatus.present,
    date: '2099-03-05',
    typeInfo: 'Große Gesamtprobe mit langem Titel für Überlauf-Prüfung',
    startTime: '19:30',
    endTime: '21:30',
    deadline: '2099-03-04T18:00:00Z',
    tenantId: worldTenantId,
    tenantName: 'Stadtorchester Speyer',
    tenantColor: '#438E96',
    place: 'Großer Saal',
    attendanceType: worldTypes.first,
  ),
  CrossTenantPersonAttendance(
    id: 'pa-cross-2',
    personId: 2,
    attendanceId: 22,
    status: AttendanceStatus.neutral,
    date: '2099-03-12',
    typeInfo: 'Registerprobe Streicher',
    startTime: '19:30',
    endTime: '21:30',
    tenantId: 8,
    tenantName: 'Kammerchor',
    tenantColor: '#5B6DCD',
    attendanceType: worldTypes.first,
  ),
];

final _crossPast = [
  CrossTenantPersonAttendance(
    id: 'pa-cross-past-1',
    personId: 1,
    attendanceId: 11,
    status: AttendanceStatus.present,
    date: '2024-11-21',
    typeInfo: 'Gesamtprobe',
    startTime: '19:30',
    endTime: '21:30',
    tenantId: worldTenantId,
    tenantName: 'Stadtorchester Speyer',
    tenantColor: '#438E96',
    attendanceType: worldTypes.first,
  ),
];

List<Override> _staffOverrides({Role role = Role.admin}) => [
      ...worldOverrides(role: role),
      realtimeAttendanceListProvider.overrideWith((ref) async => _longAttendances),
      realtimePlayersProvider.overrideWith((ref) => Stream.value(_longPersons)),
      realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(const [])),
      playersProvider.overrideWith((ref) async => _longPersons),
      playerAttendancePercentagesProvider.overrideWith((ref) async => {...worldPercentages, 99: 42}),
      listAttendancePercentagesProvider.overrideWith((ref) async => {...worldPercentages, 99: 42}),
      songsProvider.overrideWith((ref) async => worldSongs),
      conductorsProvider.overrideWith((ref) async => [_longPersons.first]),
      activeConductorsProvider.overrideWith((ref) => [_longPersons.first]),
      adminsProvider.overrideWith((ref) async => const []),
      parentsProvider.overrideWith((ref) async => const []),
      viewersProvider.overrideWith((ref) async => const []),
      leftPlayersProvider.overrideWith((ref) async => const []),
      teachersProvider.overrideWith((ref) async => [
            const Teacher(
              id: 1,
              name: 'Prof. Dr. Katharina Musiklehrerin-Beispielname',
              instruments: [1, 2],
              number: '+49 170 1234567',
              notes: 'Unterricht montags und mittwochs',
              tenantId: worldTenantId,
              insNames: 'Violine, Flöte',
              playerCount: 4,
            ),
          ]),
      enrichedTeachersProvider.overrideWith((ref) async => [
            const Teacher(
              id: 1,
              name: 'Prof. Dr. Katharina Musiklehrerin-Beispielname',
              instruments: [1, 2],
              number: '+49 170 1234567',
              notes: 'Unterricht montags und mittwochs',
              tenantId: worldTenantId,
              insNames: 'Violine, Flöte',
              playerCount: 4,
            ),
          ]),
      groupCategoriesProvider.overrideWith((ref) async => [
            TestFactories.createGroupCategory(id: 1, tenantId: worldTenantId, name: 'Streicher'),
          ]),
      playerCountsForGroupsProvider.overrideWith((ref) async => {1: 4, 2: 2, 3: 3, 4: 2}),
      myTasksProvider.overrideWith((ref) async => const []),
      visibleDashboardCardsProvider.overrideWith((ref) => [
            for (final id in DashboardCardIds.all) DashboardCardConfig(id: id),
          ]),
      dashboardNextEventProvider.overrideWith((ref) async => NextEventSummary(
            nextEvent: DashboardEvent(attendance: _longAttendances.first, persons: const []),
            nextTotal: 11,
            nextPresent: 8,
            nextExcused: 2,
            nextNeutral: 1,
            nextPerc: 73,
          )),
      dashboardPersonsProvider.overrideWith((ref) async => _longPersons),
      dashboardAbsencesProvider.overrideWith((ref) async => const []),
      dashboardCurrentSongsProvider.overrideWith((ref) async => const []),
      dashboardCurrentPlanProvider.overrideWith((ref) async => null),
      attendanceDetailProvider.overrideWith((ref, id) async => _longAttendances.first),
      attendanceTypeForAttendanceProvider.overrideWith((ref, id) async => worldTypes.first),
      personAttendancesForAttendanceProvider.overrideWith((ref, id) async => worldAnswers),
      filteredPersonsForAttendanceProvider.overrideWith((ref, id) async => _longPersons),
      allPersonsForAttendanceProvider.overrideWith((ref) async => _longPersons),
      personProvider(1).overrideWith((ref) async => _longPersons.first),
      filteredAttendancesForStatsProvider.overrideWith((ref) async => _longAttendances),
      allPersonAttendancesForStatsProvider.overrideWith((ref) async => worldAnswers),
      activePlayersForStatsProvider.overrideWith((ref) async => _longPersons),
      performanceHistoryProvider.overrideWith((ref) async => [
            HistoryEntry(
              id: 1,
              songId: 1,
              songName: 'Festliche Ouvertüre (Sehr lange Konzertfassung)',
              songNumber: '12',
              conductorName: 'Anna Berg',
              date: '2024-11-21',
              attendanceId: 11,
              count: 4,
            ),
          ]),
      filesRepositoryWithTenantProvider.overrideWithValue(_FakeFilesRepository()),
      filesUsedBytesProvider.overrideWith((ref) async => 42 * 1024 * 1024),
      canAccessFilesProvider.overrideWithValue(true),
      canEditFilesProvider.overrideWithValue(true),
      messagesProvider.overrideWith((ref) async => [
            MessageWithStats(
              message: Message(
                id: 'msg-1',
                tenantId: worldTenantId,
                senderName: 'Anna Berg',
                title: 'Wichtige Information zur Generalprobe am kommenden Wochenende',
                bodyText: 'Bitte Notenpult, Stimmgerät und Konzertkleidung mitbringen.',
                channels: const ['push', 'email'],
                recipientCount: 28,
                sentAt: DateTime(2099, 2, 20, 18, 0),
              ),
              stats: const MessageStats(read: 19, problems: 0),
            ),
          ]),
      activeAutoMessageRulesCountProvider.overrideWith((ref) async => 2),
      autoMessageRulesProvider.overrideWith((ref) async => [
            AutoMessageRule(
              id: 'rule-1',
              tenantId: worldTenantId,
              name: 'Unentschuldigt nach Probe erinnern',
              enabled: true,
              statuses: const [4],
              delayMinutes: 120,
              channels: const ['push', 'telegram'],
            ),
          ]),
      autoMessageLastWeekProvider.overrideWith((ref) async => (sent: 3, people: 7)),
      shiftsProvider.overrideWith((ref) async => [
            const ShiftPlan(
              id: 'shift-1',
              name: '3-Schicht-System Industrie (Früh / Spät / Nacht)',
              description: 'Wöchentlicher Wechsel Montag bis Freitag',
              tenantId: worldTenantId,
              definition: [
                ShiftDefinition(id: 1, startTime: '06:00', duration: 8, index: 0),
                ShiftDefinition(id: 2, startTime: '14:00', duration: 8, index: 1),
              ],
            ),
          ]),
    ];

List<Override> _selfServiceOverrides({Role role = Role.player}) => [
      ..._staffOverrides(role: role),
      currentSelfServicePlayerProvider.overrideWith((ref) async => _longPersons.first),
      allPersonAttendancesAcrossTenantsProvider.overrideWith((ref) async => [..._crossUpcoming, ..._crossPast]),
      signoutDataProvider.overrideWith((ref) async => SignoutData(
            current: _crossUpcoming.first,
            upcoming: _crossUpcoming.sublist(1),
            past: _crossPast,
            percentage: 92,
            lateCount: 1,
          )),
      myDutyOverviewProvider.overrideWith((ref) async => const MyDutyOverview()),
      currentTenantUserProvider.overrideWith((ref) async => TenantUser(
            id: 1,
            tenantId: worldTenantId,
            userId: '00000000-0000-4000-8000-000000000001',
            role: role.value,
            parentId: role == Role.parent ? 1 : null,
          )),
      parentChildrenProvider.overrideWith((ref) async => [_longPersons[1], _longPersons[2]]),
      childrenAttendancesProvider.overrideWith((ref) async => [
            ChildPersonAttendance(
              id: 'cpa-1',
              personId: 2,
              attendanceId: 21,
              status: AttendanceStatus.present,
              date: '2099-03-05',
              typeInfo: 'Große Gesamtprobe mit Registeraufteilung',
              startTime: '19:30',
              endTime: '21:30',
              typeId: 't-probe',
              childId: 2,
              childName: 'Ben Claasen',
              childFirstName: 'Ben',
            ),
            ChildPersonAttendance(
              id: 'cpa-2',
              personId: 3,
              attendanceId: 21,
              status: AttendanceStatus.excused,
              notes: 'Klassenfahrt',
              date: '2099-03-05',
              typeInfo: 'Große Gesamtprobe mit Registeraufteilung',
              startTime: '19:30',
              endTime: '21:30',
              typeId: 't-probe',
              childId: 3,
              childName: 'Clara Dorn',
              childFirstName: 'Clara',
            ),
          ]),
      parentAttendanceSongsProvider.overrideWith((ref) async => const {}),
    ];

final _cases = <_PageCase>[
  _PageCase(name: 'HomeDashboardPage', path: '/home-dashboard', inShell: true, buildPage: () => const HomeDashboardPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'PeopleListPage', path: '/people', inShell: true, buildPage: () => const PeopleListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'PersonDetailPage', path: '/people/1', buildPage: () => const PersonDetailPage(personId: 1), overrides: () => _staffOverrides()),
  _PageCase(name: 'AttendanceListPage', path: '/attendance', inShell: true, buildPage: () => const AttendanceListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'AttendanceDetailPage', path: '/attendance/21', buildPage: () => const AttendanceDetailPage(attendanceId: 21), overrides: () => _staffOverrides()),
  _PageCase(name: 'SongsListPage', path: '/songs-tab', inShell: true, buildPage: () => const SongsListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'SettingsPage', path: '/settings', inShell: true, buildPage: () => const SettingsPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'TenantSelectionPage', path: '/tenants', buildPage: () => const TenantSelectionPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'SelfServiceOverviewPage', path: '/overview', inShell: true, buildPage: () => const SelfServiceOverviewPage(), overrides: () => _selfServiceOverrides()),
  _PageCase(name: 'SignoutPage', path: '/signout', inShell: true, buildPage: () => const SignoutPage(), overrides: () => _selfServiceOverrides()),
  _PageCase(name: 'ParentsPortalPage', path: '/parents', inShell: true, buildPage: () => const ParentsPortalPage(), overrides: () => _selfServiceOverrides(role: Role.parent)),
  _PageCase(name: 'StatisticsPage', path: '/statistics', buildPage: () => const StatisticsPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'HistoryPage', path: '/history', buildPage: () => const HistoryPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'FilesPage', path: '/settings/files', buildPage: () => const FilesPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'GeneralSettingsPage', path: '/settings/general', buildPage: () => const GeneralSettingsPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'AttendanceTypesPage', path: '/settings/types', buildPage: () => const AttendanceTypesPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'InstrumentsListPage', path: '/settings/instruments', buildPage: () => const InstrumentsListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'TeachersListPage', path: '/settings/teachers', buildPage: () => const TeachersListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'MessageListPage', path: '/settings/messages', buildPage: () => const MessageListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'AutoMessageListPage', path: '/settings/auto-messages', buildPage: () => const AutoMessageListPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'ExportPage', path: '/export', buildPage: () => const ExportPage(), overrides: () => _staffOverrides()),
  _PageCase(name: 'ShiftsListPage', path: '/settings/shifts', buildPage: () => const ShiftsListPage(), overrides: () => _staffOverrides()),
];

void main() {
  for (final c in _cases) {
    group(c.name, () {
      for (final cfg in _sweepMatrix) {
        testWidgets(
          cfg.label,
          (tester) async {
          final errors = <FlutterErrorDetails>[];
          final previousOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
          };

          try {
            await pumpGolden(
              tester,
              c.buildPage(),
              look: cfg.look,
              path: c.path,
              shell: c.inShell ? _shell : null,
              size: cfg.size,
              pixelRatio: 1,
              brightness: cfg.brightness,
              textScaler: cfg.textScaler,
              overrides: c.overrides(),
            );
          } finally {
            FlutterError.onError = previousOnError;
          }

          expect(tester.takeException(), isNull, reason: '${c.name} (${cfg.label}) threw exception');
          expect(find.byType(Scaffold), findsWidgets, reason: '${c.name} (${cfg.label}) rendered no Scaffold');
          expect(
            errors.map((e) => e.exceptionAsString()).toList(),
            isEmpty,
            reason: '${c.name} (${cfg.label}) reported Flutter layout/render errors',
          );
        });
      }
    });
  }

  group('MainShell Responsive Breakpoint (Parity Ionic 4.19.14 Check)', () {
    testWidgets('768x1024 portrait keeps TabBar instead of SideNav', (tester) async {
      await pumpGolden(
        tester,
        const PeopleListPage(),
        look: GoldenLook.classicIos,
        path: '/people',
        shell: _shell,
        size: const Size(768, 1024),
        pixelRatio: 1,
        overrides: _staffOverrides(),
      );
      final scaffoldCtx = tester.element(find.byType(PeopleListPage));
      expect(SideNavScope.maybeOf(scaffoldCtx), isNull);
      expect(find.byType(IosTabBar), findsOneWidget);
    });

    testWidgets('900x700 landscape activates SideNav overlay', (tester) async {
      await pumpGolden(
        tester,
        const PeopleListPage(),
        look: GoldenLook.classicIos,
        path: '/people',
        shell: _shell,
        size: const Size(900, 700),
        pixelRatio: 1,
        overrides: _staffOverrides(),
      );
      final scaffoldCtx = tester.element(find.byType(PeopleListPage));
      expect(SideNavScope.maybeOf(scaffoldCtx)?.mode, SideNavMode.overlay);
      expect(find.byType(IosTabBar), findsNothing);
    });

    testWidgets('1280x800 wide activates fixed SideNav', (tester) async {
      await pumpGolden(
        tester,
        const PeopleListPage(),
        look: GoldenLook.classicMd,
        path: '/people',
        shell: _shell,
        size: const Size(1280, 800),
        pixelRatio: 1,
        overrides: _staffOverrides(),
      );
      final scaffoldCtx = tester.element(find.byType(PeopleListPage));
      expect(SideNavScope.maybeOf(scaffoldCtx)?.mode, SideNavMode.fixed);
      expect(find.byType(SideNav), findsOneWidget);
    });
  });
}
