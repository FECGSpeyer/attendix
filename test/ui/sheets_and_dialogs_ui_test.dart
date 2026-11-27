import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/org_song_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/data/models/song/org_song.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/org_song_repository.dart';
import 'package:attendix/features/attendance/presentation/widgets/event/rd_event_create_menu.dart';
import 'package:attendix/features/organisation/presentation/widgets/org_song_copy_sheet.dart';
import 'package:attendix/features/organisation/presentation/widgets/rd_org_info_sheet.dart';
import 'package:attendix/features/settings/presentation/widgets/manage/rd_settings_sheets.dart';
import 'package:attendix/features/team_organization/presentation/widgets/rd_new_meeting_sheet.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonSheetHeader;
import 'package:attendix/shared/widgets/redesign/rd_split_view.dart';
import 'package:attendix/shared/widgets/redesign/rd_widgets.dart';
import 'package:attendix/shared/widgets/sheets/version_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../factories/test_factories.dart';
import '../golden/support/golden_world.dart';
import 'ui_layout_invariants.dart';

const _profiles = [
  UiViewportProfile.narrowPhone,
  UiViewportProfile.narrowPhoneLargeText,
  UiViewportProfile.iphone,
  UiViewportProfile.iphoneDark,
  UiViewportProfile.desktop,
];

class _FakeOrgSongRepository extends Fake implements OrgSongRepository {
  final Map<int, List<Map<String, dynamic>>> songsByLibrary = {
    10: [
      {
        'id': 100,
        'tenantId': 10,
        'name': 'Vorhandenes Werk',
        'number': 1,
        'prefix': 'A',
        'link': 'https://old.example',
        'files': <Map<String, dynamic>>[],
      },
    ],
    20: [
      {
        'id': 201,
        'tenantId': 20,
        'name': 'Choral in Es',
        'number': 5,
        'prefix': '',
        'link': '',
        'files': [
          {
            'storageName': 'existing.pdf',
            'fileName': 'Partitur.pdf',
            'fileType': 'application/pdf',
            'url': 'https://example/existing.pdf',
          },
        ],
      },
    ],
  };

  final Map<int, List<Group>> groupsByLibrary = {
    10: [const Group(id: 11, name: 'Trompete'), const Group(id: 12, name: 'Posaune', maingroup: true)],
    20: [const Group(id: 21, name: 'Chor')],
  };

  @override
  Future<List<Map<String, dynamic>>> getLibrarySongRows(int libraryId) async =>
      songsByLibrary[libraryId] ?? const [];

  @override
  Future<List<Group>> getLibraryGroups(int libraryId) async =>
      groupsByLibrary[libraryId] ?? const [];

  @override
  Future<List<String>> ensureSongCategories(int libraryId, List<String> names) async => const ['cat-1'];

  @override
  Future<Song> copyOrgSong(OrgSongCopyRequest request, {void Function(int current, int total)? onProgress}) async =>
      Song(id: 999, name: request.source.name, number: (request.fields['number'] as int?) ?? 1);
}

final _orgTenants = [
  const OrgSongTenant(
    id: 10,
    shortName: 'PC',
    longName: 'Posaunenchor',
    songAdditionalFields: [ExtraField(id: 'dur', name: 'Spieldauer', type: 'text')],
  ),
  const OrgSongTenant(id: 20, shortName: 'JC', longName: 'Jugendchor'),
];

final _targets = [
  OrgSongCopyTarget(tenant: _orgTenants[0], libraryId: 10),
  OrgSongCopyTarget(tenant: _orgTenants[1], libraryId: 20, libraryName: 'Gemeinsame Bibliothek'),
];

const _sourceSong = OrgSongResult(
  id: 50,
  tenantId: 99,
  tenantName: 'Bezirkschor',
  name: 'Choral in Es',
  number: 5,
  prefix: 'A',
  difficulty: 2,
  withChoir: true,
  link: 'https://example.org/choral',
  categoryNames: ['Choral', 'Festlich'],
  additionalFields: {'dur': '04:30'},
  files: [
    OrgSongFile(
      storageName: 'p.pdf',
      fileName: 'Partitur.pdf',
      url: 'https://example/p.pdf',
      instrumentId: 30,
      groupName: 'Trompete',
    ),
    OrgSongFile(
      storageName: 'rec.mp3',
      fileName: 'Aufnahme.mp3',
      url: 'https://example/rec.mp3',
      instrumentId: 1,
    ),
  ],
);

void main() {
  for (final profile in _profiles) {
    group('Sheets & dialogs [${profile.name}]', () {
      testWidgets('OrgSongCopySheet (new & duplicate/taken-number + fields/files) has no overlaps or OutlineInputBorder', (
        tester,
      ) async {
        final repo = _FakeOrgSongRepository();
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: OrgSongCopySheet(
                source: _sourceSong,
                targets: _targets,
                orgTenants: _orgTenants,
              ),
            ),
            profile: profile,
            overrides: [orgSongRepositoryWithTenantProvider.overrideWithValue(repo)],
          );

          expect(find.byType(IonSheetHeader), findsNothing);
          expect(find.descendant(of: find.byType(RdCard), matching: find.byType(OutlineInputBorder)), findsNothing);
          expect(find.byType(OutlineInputBorder), findsNothing);

          final cancel = find.text('Abbrechen');
          final title = find.text('Werk kopieren');
          expectHorizontallyWithinViewport(tester, cancel, profile.size);
          expectHorizontallyWithinViewport(tester, title, profile.size);
          expectNoOverlaps(tester, [cancel, title]);

          // Trigger taken-number warning in new mode ("A1" is taken in target 10).
          await tester.enterText(find.byKey(const Key('org-copy-number')), '1');
          await settleUi(tester, steps: 5);
          expect(find.byKey(const Key('org-copy-next-free')), findsOneWidget);

          // Switch target to 20 -> triggers duplicate detection UI + existing/new mode toggle.
          await tester.tap(find.byKey(const Key('org-copy-target')));
          await settleUi(tester, steps: 5);
          await tester.tap(find.text('JC').last);
          await settleUi(tester, steps: 5);
          await tester.scrollUntilVisible(
            find.byKey(const Key('org-copy-mode-new')),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await settleUi(tester, steps: 3);
          expect(find.byKey(const Key('org-copy-mode-existing')), findsOneWidget);
          expect(find.byKey(const Key('org-copy-mode-new')), findsOneWidget);
        });
      });

      testWidgets('IonSheetHeader keeps start, title, and end free of overlaps', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: IonSheetHeader(
                  title: 'Werk kopieren',
                  start: [TextButton(onPressed: () {}, child: const Text('Abbrechen'))],
                  end: [TextButton(onPressed: () {}, child: const Text('Kopieren'))],
                ),
              ),
            ),
            profile: profile,
          );

          final startFinder = find.text('Abbrechen');
          final titleFinder = find.text('Werk kopieren');
          final endFinder = find.text('Kopieren');
          expectNoOverlaps(tester, [startFinder, titleFinder, endFinder]);
          expectHorizontallyWithinViewport(tester, startFinder, profile.size);
          expectHorizontallyWithinViewport(tester, endFinder, profile.size);
        });
      });

      testWidgets('RdSheetHead keeps cancel, long title, and done free of overlaps', (tester) async {
        const longTitle = 'Sehr langer Titel für ein Einstellungsblatt';
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: RdSheetHead(
                  title: longTitle,
                  onDone: () {},
                ),
              ),
            ),
            profile: profile,
          );

          final cancelFinder = find.text('Abbrechen');
          final titleFinder = find.text(longTitle);
          final doneFinder = find.text('Fertig');
          expectNoOverlaps(tester, [cancelFinder, titleFinder, doneFinder]);
          expectHorizontallyWithinViewport(tester, cancelFinder, profile.size);
          expectHorizontallyWithinViewport(tester, titleFinder, profile.size);
          expectHorizontallyWithinViewport(tester, doneFinder, profile.size);
        });
      });

      testWidgets('RdEventCreateMenu opens adaptive bottom sheet (<840px) or popover (>=840px) without overflow', (
        tester,
      ) async {
        final isDesktop = profile.size.width >= 840;
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            RdSplitScope(
              isDetail: false,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RdEventCreateMenu(compact: isDesktop),
                  ),
                ),
              ),
            ),
            profile: profile,
            overrides: [
              ...worldOverrides(role: Role.admin),
              canCreateAttendanceProvider.overrideWithValue(true),
            ],
          );

          await tester.tap(find.byKey(const Key('rd-events-add')));
          await settleUi(tester, steps: 5);

          if (isDesktop) {
            expect(find.byType(BottomSheet), findsNothing);
            expectHorizontallyWithinViewport(tester, find.text('Orchestertermin'), profile.size);
            expectHorizontallyWithinViewport(tester, find.text('Besprechung'), profile.size);
          } else {
            expect(find.byType(BottomSheet), findsOneWidget);
            expectHorizontallyWithinViewport(tester, find.text('Neuer Termin'), profile.size);
            expectHorizontallyWithinViewport(tester, find.text('Abbrechen'), profile.size);
          }
        });
      });

      testWidgets('showRdOrgInfoSheet opens without overflow', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showRdOrgInfoSheet(context),
                    child: const Text('open-org-info'),
                  ),
                ),
              ),
            ),
            profile: profile,
            overrides: [
              ...worldOverrides(role: Role.admin),
              currentOrganisationProvider.overrideWith(
                (ref) async => const Organisation(id: 42, name: 'FECG Speyer'),
              ),
              allLinkedTenantsProvider.overrideWith(
                (ref) async => [
                  TestFactories.createTenant(id: 7, shortName: 'SO', longName: 'Stadtorchester'),
                  TestFactories.createTenant(id: 8, shortName: 'KC', longName: 'Kammerchor'),
                ],
              ),
            ],
          );

          await tester.tap(find.text('open-org-info'));
          await settleUi(tester, steps: 5);

          expect(find.byKey(const Key('rd-org-info-sheet')), findsOneWidget);
          expectHorizontallyWithinViewport(tester, find.byKey(const Key('rd-org-info-manage')), profile.size);
        });
      });

      testWidgets('showNewMeetingSheet opens without overflow', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showNewMeetingSheet(context),
                    child: const Text('open-new-meeting'),
                  ),
                ),
              ),
            ),
            profile: profile,
            overrides: [
              ...worldOverrides(role: Role.admin),
              attendanceTypesProvider.overrideWith((ref) async => worldTypes),
              protocolTypesProvider.overrideWith((ref) async => const []),
              typeCirclePersonsProvider.overrideWith((ref) async => const {}),
            ],
          );

          await tester.tap(find.text('open-new-meeting'));
          await settleUi(tester, steps: 5);

          expect(find.text('Neue Besprechung'), findsOneWidget);
          expect(find.byKey(const ValueKey('rd-new-meeting-day')), findsOneWidget);
          expect(find.byKey(const ValueKey('rd-new-meeting-circle')), findsOneWidget);
          expectHorizontallyWithinViewport(tester, find.byKey(const ValueKey('rd-new-meeting-day')), profile.size);
        });
      });

      testWidgets('showAppActionSheet opens without overflow', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showAppActionSheet<String>(
                      context,
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
                          value: 'delete',
                          icon: Icons.delete_outline,
                          label: 'Löschen',
                          destructive: true,
                        ),
                      ],
                    ),
                    child: const Text('open-action-sheet'),
                  ),
                ),
              ),
            ),
            profile: profile,
          );

          await tester.tap(find.text('open-action-sheet'));
          await settleUi(tester, steps: 5);

          expect(find.text('Aktionen für dieses Werk'), findsOneWidget);
          expect(find.text('Bearbeiten'), findsOneWidget);
          expect(find.text('Löschen'), findsOneWidget);
          expectHorizontallyWithinViewport(tester, find.text('Abbrechen'), profile.size);
        });
      });

      testWidgets('VersionHistorySheet loads user history without overflow', (tester) async {
        rootBundle.evict(versionHistoryUserAsset);
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showVersionHistorySheet(context),
                    child: const Text('open-version-history'),
                  ),
                ),
              ),
            ),
            profile: profile,
          );

          await tester.tap(find.text('open-version-history'));
          await tester.pump();
          for (var i = 0; i < 60 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
            await tester.pump();
          }
          await settleUi(tester, steps: 5);

          expect(find.text('Neu in dieser Version'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expectHorizontallyWithinViewport(tester, find.text('Neu in dieser Version'), profile.size);
        });
      });
    });
  }
}
