// Extended golden images: Dark Mode, Desktop Split-Views, Subpages/Forms, and
// critical Sheets & Modals (16 screenshots alongside pages_beta_test.dart).
// How to add or renew one: test/golden/README.md.
@Tags(['golden'])
library;

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_rate_filter_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/holiday_providers.dart';
import 'package:attendix/core/providers/org_song_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/person_detail_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/services/holiday_service.dart';
import 'package:attendix/data/models/church/church.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/data/models/song/org_song.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/org_song_repository.dart';
import 'package:attendix/features/attendance/data/providers/events_providers.dart';
import 'package:attendix/features/attendance/presentation/pages/event_create_page.dart';
import 'package:attendix/features/attendance/presentation/pages/events_page.dart';
import 'package:attendix/features/attendance/presentation/pages/events_split_home.dart';
import 'package:attendix/features/attendance/presentation/widgets/event/event_create_menu.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/features/organisation/presentation/pages/org_settings_page.dart';
import 'package:attendix/features/organisation/presentation/widgets/org_info_sheet.dart';
import 'package:attendix/features/organisation/presentation/widgets/org_song_copy_sheet.dart';
import 'package:attendix/features/people/presentation/pages/members_page.dart';
import 'package:attendix/features/people/presentation/pages/person_page.dart';
import 'package:attendix/features/profile/presentation/pages/me_page.dart';
import 'package:attendix/features/songs/presentation/pages/work_page.dart';
import 'package:attendix/features/songs/presentation/pages/works_page.dart';
import 'package:attendix/features/today/data/providers/today_providers.dart';
import 'package:attendix/features/today/presentation/pages/today_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/shell/app_shell.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/components/overview.dart';
import 'package:attendix/shared/widgets/components/split_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/golden_harness.dart';
import 'support/golden_world.dart';

const _look = GoldenLook.beta;
const _desktopSize = Size(1280, 800);
const _counts = RdStatusCounts(present: 6, lateAnnounced: 1, excused: 1, open: 2);

Widget _shell(Widget child) => RdShell(child: child);

/// "Heute" shows today's date: a fixed day takes its place.
Map<String, String> _today() => {
  DateFormat('EEEE, d. MMMM', 'de').format(DateTime.now()): 'Donnerstag, 1. Januar',
};

/// Base leader overrides shared across the extended golden pages.
List<Override> _leader() => [
  ...worldOverrides(),
  realtimeAttendanceListProvider.overrideWith((ref) async => worldAttendances),
  realtimePlayersProvider.overrideWith((ref) => Stream.value(worldPersons)),
  realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(const [])),
  playersProvider.overrideWith((ref) async => worldPersons),
  playerAttendancePercentagesProvider.overrideWith((ref) async => worldPercentages),
  listAttendancePercentagesProvider.overrideWith((ref) async => worldPercentages),
  playerAbsencesProvider.overrideWith((ref) async => const []),
  currentSelfServicePlayerProvider.overrideWith((ref) async => worldPersons.first),
  rdAttendanceCountsProvider.overrideWith((ref, id) async => _counts),
  rdUpcomingCountsProvider.overrideWith((ref) async => const {21: _counts, 22: RdStatusCounts(present: 2, open: 1)}),
  songsProvider.overrideWith((ref) async => worldSongs),
];

/// Detail overrides needed when event #21 is shown in the desktop split view.
List<Override> _event21Overrides() => [
  attendanceDetailProvider.overrideWith((ref, id) async => worldAttendances.first),
  attendanceTypeForAttendanceProvider.overrideWith((ref, id) async => worldTypes.first),
  personAttendancesForAttendanceProvider.overrideWith((ref, id) async => worldAnswers),
  filteredPersonsForAttendanceProvider.overrideWith((ref, id) async => worldPersons),
  rdOpenPersonsProvider.overrideWith((ref, id) async => rdOpenPersons(worldAnswers, worldPersons)),
];

final _detailedWork = worldSongs.first.copyWith(
  categoryIds: const ['k'],
  lastSung: '2024-11-21',
  nextPlanned: '2099-03-05',
  conductor: 'Anna Berg',
  files: const [
    SongFile(fileName: 'violine.pdf', fileType: 'application/pdf', url: 'https://x/violine.pdf', instrumentId: 1),
    SongFile(fileName: 'floete.pdf', fileType: 'application/pdf', url: 'https://x/floete.pdf', instrumentId: 2),
    SongFile(fileName: 'partitur.pdf', fileType: 'application/pdf', url: 'https://x/partitur.pdf', note: 'Partitur'),
    SongFile(
      fileName: 'probe.mp3',
      fileType: 'audio/mpeg',
      url: 'https://x/probe.mp3',
      instrumentId: 1,
      createdAt: '2026-10-23T19:00:00Z',
    ),
  ],
);

class _FakeOrgSongRepository extends Fake implements OrgSongRepository {
  @override
  Future<List<Map<String, dynamic>>> getLibrarySongRows(int libraryId) async => const [
    {
      'id': 100,
      'tenantId': 10,
      'name': 'Vorhandenes Werk',
      'number': 1,
      'prefix': 'A',
      'link': 'https://old.example',
      'files': <Map<String, dynamic>>[],
    },
  ];

  @override
  Future<List<Group>> getLibraryGroups(int libraryId) async => const [
    Group(id: 1, name: 'Violine'),
    Group(id: 2, name: 'Flöte'),
  ];
}

const _copyOrgTenants = [
  OrgSongTenant(id: 10, shortName: 'SO', longName: 'Stadtorchester'),
  OrgSongTenant(id: 20, shortName: 'KC', longName: 'Kammerchor'),
];

final _copyTargets = [
  OrgSongCopyTarget(tenant: _copyOrgTenants[0], libraryId: 10),
  OrgSongCopyTarget(tenant: _copyOrgTenants[1], libraryId: 20, libraryName: 'Gemeinsame Bibliothek'),
];

const _copySourceSong = OrgSongResult(
  id: 50,
  tenantId: 99,
  tenantName: 'Kammerchor',
  name: 'Choral in Es',
  number: 5,
  prefix: 'A',
  difficulty: 2,
  withChoir: true,
  link: 'https://example.org/choral',
  categoryNames: ['Choral', 'Festlich'],
  files: [
    OrgSongFile(
      storageName: 'p.pdf',
      fileName: 'Partitur.pdf',
      url: 'https://example/p.pdf',
      instrumentId: 1,
      groupName: 'Violine',
    ),
    OrgSongFile(
      storageName: 'rec.mp3',
      fileName: 'Aufnahme.mp3',
      url: 'https://example/rec.mp3',
      instrumentId: 1,
    ),
  ],
);

/// Minimal host page with a single button to trigger modal sheets inside
/// [MaterialApp] so `find.byType(MaterialApp)` captures the open sheet.
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.onOpen});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (btnContext) => TextButton(
          key: const Key('golden-open-sheet'),
          onPressed: () => onOpen(btnContext),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester, Finder trigger) async {
  await tester.tap(trigger);
  await settle(tester);
  expect(find.descendant(of: find.byType(MaterialApp), matching: find.byType(BottomSheet)), findsOneWidget);
}

void main() {
  group('Dark Mode', () {
    testWidgets('dark_heute', (tester) async {
      await pumpGolden(
        tester,
        const RdTodayPage(),
        look: _look,
        path: '/heute',
        shell: _shell,
        brightness: Brightness.dark,
        overrides: _leader(),
      );
      await expectGolden(tester, _look, 'dark_heute', replace: _today());
    });

    testWidgets('dark_termine', (tester) async {
      await pumpGolden(
        tester,
        const RdEventsPage(),
        look: _look,
        path: '/termine',
        shell: _shell,
        brightness: Brightness.dark,
        overrides: _leader(),
      );
      await expectGolden(tester, _look, 'dark_termine');
    });

    testWidgets('dark_werke', (tester) async {
      await pumpGolden(
        tester,
        const RdWorksPage(),
        look: _look,
        path: '/werke',
        shell: _shell,
        brightness: Brightness.dark,
        overrides: _leader(),
      );
      await expectGolden(tester, _look, 'dark_werke');
    });

    testWidgets('dark_ich', (tester) async {
      await pumpGolden(
        tester,
        const RdMePage(),
        look: _look,
        path: '/ich',
        shell: _shell,
        brightness: Brightness.dark,
        overrides: _leader(),
      );
      await expectGolden(tester, _look, 'dark_ich');
    });
  });

  group('Desktop Split-View', () {
    testWidgets('desktop_termine', (tester) async {
      await pumpGolden(
        tester,
        const RdEventsSplitHome(),
        look: _look,
        path: '/termine',
        shell: _shell,
        size: _desktopSize,
        pixelRatio: 1,
        overrides: [..._leader(), ..._event21Overrides()],
      );
      await expectGolden(tester, _look, 'desktop_termine');
    });

    testWidgets('desktop_mitglieder', (tester) async {
      await pumpGolden(
        tester,
        Builder(
          builder: (context) => RdSplitView(
            list: const RdMembersPage(),
            detail: null,
            selectedId: null,
            emptyText: context.l10n.redesignSplitMembersEmpty,
            empty: const RdMembersOverviewPanel(),
          ),
        ),
        look: _look,
        path: '/mitglieder',
        shell: _shell,
        size: _desktopSize,
        pixelRatio: 1,
        overrides: _leader(),
      );
      await expectGolden(tester, _look, 'desktop_mitglieder');
    });

    testWidgets('desktop_werke', (tester) async {
      await pumpGolden(
        tester,
        Builder(
          builder: (context) => RdSplitView(
            list: const RdWorksPage(),
            detail: null,
            selectedId: null,
            emptyText: context.l10n.redesignSplitWorksEmpty,
            emptyIcon: Icons.library_music_outlined,
            empty: const RdWorksOverviewPanel(),
          ),
        ),
        look: _look,
        path: '/werke',
        shell: _shell,
        size: _desktopSize,
        pixelRatio: 1,
        overrides: _leader(),
      );
      await expectGolden(tester, _look, 'desktop_werke');
    });
  });

  group('Subpages & Forms', () {
    testWidgets('page_org_settings', (tester) async {
      final tenants = worldTenants(Role.admin);
      await pumpGolden(
        tester,
        const RdOrgSettingsPage(),
        look: _look,
        path: '/settings/org-settings',
        overrides: [
          ..._leader(),
          currentOrganisationProvider.overrideWith((ref) async => const Organisation(id: 42, name: 'Stadtorchester Org')),
          linkedTenantsProvider.overrideWith((ref) async => tenants),
          allLinkedTenantsProvider.overrideWith((ref) async => tenants),
        ],
      );
      await expectGolden(tester, _look, 'page_org_settings');
    });

    testWidgets('page_event_create', (tester) async {
      await pumpGolden(
        tester,
        RdEventCreatePage(initialDate: DateTime(2099, 3, 5)),
        look: _look,
        path: '/termine/neu',
        overrides: [
          ..._leader(),
          canCreateAttendanceProvider.overrideWithValue(true),
          holidaysProvider.overrideWith((ref) async => const HolidayData()),
          protocolTypesProvider.overrideWith((ref) async => const []),
          typeCirclePersonsProvider.overrideWith((ref) async => const {}),
          personExtraFieldsProvider.overrideWith((ref) async => const []),
        ],
      );
      await expectGolden(tester, _look, 'page_event_create');
    });

    testWidgets('page_person_detail', (tester) async {
      await pumpGolden(
        tester,
        const RdPersonPage(personId: 1),
        look: _look,
        path: '/mitglieder/1',
        overrides: [
          ..._leader(),
          personProvider(1).overrideWith((ref) async => worldPersons.first),
          personAttendanceStatsProvider(1).overrideWith(
            (ref) async => {'total': 10, 'attended': 9, 'counted': 10, 'percentage': 90},
          ),
          personHistoryProvider(1).overrideWith(
            (ref) async => [
              {'date': '2024-11-21', 'status': AttendanceStatus.present.value, 'meetingName': 'Gesamtprobe'},
              {'date': '2024-11-14', 'status': AttendanceStatus.excused.value, 'meetingName': 'Gesamtprobe'},
              {'date': '2024-11-07', 'status': AttendanceStatus.present.value, 'meetingName': 'Registerprobe'},
            ],
          ),
          playerAbsencesByPersonIdProvider(1).overrideWith((ref) async => const []),
          personExtraFieldsProvider.overrideWith((ref) async => const []),
          churchesProvider.overrideWith((ref) async => const <Church>[]),
        ],
      );
      await expectGolden(tester, _look, 'page_person_detail');
    });

    testWidgets('page_work_detail', (tester) async {
      await pumpGolden(
        tester,
        const RdWorkPage(songId: 1),
        look: _look,
        path: '/werke/1',
        overrides: [
          ..._leader(),
          songsProvider.overrideWith((ref) async => [_detailedWork, ...worldSongs.skip(1)]),
          songDetailDataProvider((songId: 1, sharingId: null)).overrideWith(
            (ref) async => SongDetailData(
              song: _detailedWork,
              tenantType: 'orchestra',
              instruments: worldGroups,
              categories: const [SongCategory(id: 'k', name: 'Konzert', index: 0)],
              additionalFields: const [],
              history: const [],
              readOnly: false,
              songSharingId: 'abc',
            ),
          ),
          songCollectionsProvider.overrideWith((ref) async => null),
          missingGroupsPlayerCountsProvider.overrideWithValue(null),
        ],
      );
      await expectGolden(tester, _look, 'page_work_detail');
    });

    testWidgets('page_login', (tester) async {
      await pumpGolden(
        tester,
        const LoginPage(),
        look: _look,
        path: '/login',
      );
      await expectGolden(tester, _look, 'page_login');
    });
  });

  group('Sheets & Modals', () {
    testWidgets('sheet_org_song_copy', (tester) async {
      await pumpGolden(
        tester,
        _SheetHost(
          onOpen: (ctx) => showOrgSongCopySheet(
            ctx,
            source: _copySourceSong,
            targets: _copyTargets,
            orgTenants: _copyOrgTenants,
          ),
        ),
        look: _look,
        path: '/sheet-org-song-copy',
        overrides: [
          ..._leader(),
          orgSongRepositoryWithTenantProvider.overrideWithValue(_FakeOrgSongRepository()),
        ],
      );
      await _openSheet(tester, find.byKey(const Key('golden-open-sheet')));
      await expectGolden(tester, _look, 'sheet_org_song_copy');
    });

    testWidgets('sheet_event_create_menu', (tester) async {
      await pumpGolden(
        tester,
        const Scaffold(floatingActionButton: RdEventCreateMenu()),
        look: _look,
        path: '/sheet-event-create-menu',
        overrides: [
          ..._leader(),
          canCreateAttendanceProvider.overrideWithValue(true),
          isTeamLeaderProvider.overrideWithValue(true),
        ],
      );
      await _openSheet(tester, find.byKey(const Key('rd-events-add')));
      await expectGolden(tester, _look, 'sheet_event_create_menu');
    });

    testWidgets('sheet_org_info', (tester) async {
      await pumpGolden(
        tester,
        _SheetHost(onOpen: (ctx) => showRdOrgInfoSheet(ctx)),
        look: _look,
        path: '/sheet-org-info',
        overrides: [
          ..._leader(),
          currentOrganisationProvider.overrideWith((ref) async => const Organisation(id: 42, name: 'Stadtorchester Org')),
          allLinkedTenantsProvider.overrideWith((ref) async => worldTenants(Role.admin)),
        ],
      );
      await _openSheet(tester, find.byKey(const Key('golden-open-sheet')));
      await expectGolden(tester, _look, 'sheet_org_info');
    });

    testWidgets('sheet_action_sheet', (tester) async {
      await pumpGolden(
        tester,
        _SheetHost(
          onOpen: (ctx) => showAppActionSheet<String>(
            ctx,
            title: 'Aktionen für dieses Werk',
            message: 'Wähle eine Aktion für das ausgewählte Werk aus.',
            actions: const [
              AppActionSheetAction(
                value: 'edit',
                icon: Icons.edit_outlined,
                label: 'Bearbeiten',
                subtitle: 'Titel, Nummer und Besetzung ändern',
              ),
              AppActionSheetAction(
                value: 'share',
                icon: Icons.ios_share,
                label: 'Link teilen',
                subtitle: 'Öffentlichen Noten-Link kopieren',
              ),
              AppActionSheetAction(
                value: 'delete',
                icon: Icons.delete_outline,
                label: 'Löschen',
                subtitle: 'Werk unwiderruflich entfernen',
                destructive: true,
              ),
            ],
          ),
        ),
        look: _look,
        path: '/sheet-action-sheet',
        overrides: _leader(),
      );
      await _openSheet(tester, find.byKey(const Key('golden-open-sheet')));
      await expectGolden(tester, _look, 'sheet_action_sheet');
    });
  });
}
