import 'dart:async';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_rate_filter_providers.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/holiday_providers.dart';
import 'package:attendix/core/providers/org_song_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/services/holiday_service.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/song/org_song.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/org_song_repository.dart';
import 'package:attendix/features/attendance/data/providers/events_providers.dart';
import 'package:attendix/features/attendance/presentation/pages/event_create_page.dart';
import 'package:attendix/features/attendance/presentation/pages/events_page.dart';
import 'package:attendix/features/organisation/presentation/pages/org_settings_page.dart';
import 'package:attendix/features/organisation/presentation/widgets/org_song_copy_sheet.dart';
import 'package:attendix/features/people/presentation/pages/members_page.dart';
import 'package:attendix/features/profile/presentation/pages/me_page.dart';
import 'package:attendix/features/songs/presentation/pages/works_page.dart';
import 'package:attendix/features/today/presentation/pages/today_page.dart';
import 'package:attendix/shared/widgets/components/components.dart';
import 'package:attendix/shared/widgets/components/split_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support/golden_world.dart';
import 'ui_layout_invariants.dart';

class _FakeOrgSongRepository extends Fake implements OrgSongRepository {
  @override
  Future<List<Map<String, dynamic>>> getLibrarySongRows(int libraryId) async => [
        {
          'id': 100,
          'tenantId': libraryId,
          'name': 'Vorhandenes Werk',
          'number': 1,
          'prefix': 'A',
          'link': '',
          'files': <Map<String, dynamic>>[],
        },
      ];

  @override
  Future<List<Group>> getLibraryGroups(int libraryId) async => [
        const Group(id: 11, name: 'Violine'),
      ];
}

List<Override> _emptyBase({Role role = Role.admin}) => [
      ...worldOverrides(role: role),
      realtimeAttendanceListProvider.overrideWith((ref) async => const <Attendance>[]),
      realtimePlayersProvider.overrideWith((ref) => Stream.value(const <Person>[])),
      realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(const <Person>[])),
      playersProvider.overrideWith((ref) async => const <Person>[]),
      playerAttendancePercentagesProvider.overrideWith((ref) async => const <int, int>{}),
      listAttendancePercentagesProvider.overrideWith((ref) async => const <int, int>{}),
      playerAbsencesProvider.overrideWith((ref) async => const []),
      currentSelfServicePlayerProvider.overrideWith((ref) async => null),
      signoutDataProvider.overrideWith((ref) async => const SignoutData()),
      songsProvider.overrideWith((ref) async => const <Song>[]),
      songCategoriesProvider.overrideWith((ref) async => const []),
      songCollectionsProvider.overrideWith((ref) async => const []),
      currentOrganisationProvider.overrideWith((ref) async => null),
      orgPlansProvider.overrideWith((ref) async => const []),
      myTasksProvider.overrideWith((ref) async => const []),
    ];

List<Override> _populatedBase({Role role = Role.admin}) => [
      ...worldOverrides(role: role),
      realtimeAttendanceListProvider.overrideWith((ref) async => worldAttendances),
      realtimePlayersProvider.overrideWith((ref) => Stream.value(worldPersons)),
      realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(const [])),
      playersProvider.overrideWith((ref) async => worldPersons),
      playerAttendancePercentagesProvider.overrideWith((ref) async => worldPercentages),
      listAttendancePercentagesProvider.overrideWith((ref) async => worldPercentages),
      playerAbsencesProvider.overrideWith((ref) async => const []),
      currentSelfServicePlayerProvider.overrideWith((ref) async => worldPersons.first),
      signoutDataProvider.overrideWith((ref) async => const SignoutData()),
      rdUpcomingCountsProvider.overrideWith((ref) async => const {}),
      songsProvider.overrideWith((ref) async => worldSongs),
      songCategoriesProvider.overrideWith((ref) async => const []),
      songCollectionsProvider.overrideWith((ref) async => const []),
      currentOrganisationProvider.overrideWith(
        (ref) async => const Organisation(id: 42, name: 'Stadtorchester Org'),
      ),
      orgPlansProvider.overrideWith((ref) async => const []),
      myTasksProvider.overrideWith((ref) async => const []),
    ];

void main() {
  group('1. Empty states', () {
    testWidgets('RdTodayPage (leader) with 0 events shows empty state without overflow', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdTodayPage(),
          profile: UiViewportProfile.iphone,
          path: '/heute',
          overrides: _emptyBase(role: Role.admin),
        );
        expect(find.text('Gerade stehen keine Termine an.'), findsOneWidget);
        expect(find.text('Alle Termine'), findsOneWidget);
      });
    });

    testWidgets('RdTodayPage (member) with 0 events shows empty state without overflow', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdTodayPage(),
          profile: UiViewportProfile.iphone,
          path: '/heute',
          overrides: [
            ..._emptyBase(role: Role.player),
            currentSelfServicePlayerProvider.overrideWith((ref) async => worldPersons[1]),
          ],
        );
        expect(find.text('Gerade stehen keine Termine an.'), findsOneWidget);
        expect(find.text('Danach ist noch nichts geplant.'), findsOneWidget);
      });
    });

    testWidgets('RdEventsPage with 0 events shows empty state without overflow', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdEventsPage(),
          profile: UiViewportProfile.iphone,
          path: '/termine',
          overrides: _emptyBase(role: Role.admin),
        );
        expect(find.text('Noch keine Termine. Leg die erste Probe an.'), findsOneWidget);
      });
    });

    testWidgets('RdMembersPage with 0 members shows empty invite state without overflow', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdMembersPage(),
          profile: UiViewportProfile.iphone,
          path: '/mitglieder',
          overrides: _emptyBase(role: Role.admin),
        );
        expect(
          find.text('Noch keine Mitglieder. Über „+“ teilst du den Einladungslink oder zeigst den QR-Code in der nächsten Probe.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('RdWorksPage with 0 songs shows empty state without overflow', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdWorksPage(),
          profile: UiViewportProfile.iphone,
          path: '/werke',
          overrides: _emptyBase(role: Role.admin),
        );
        expect(find.text('Noch keine Werke.'), findsOneWidget);
      });
    });

    testWidgets('RdOrgSettingsPage with no org shows empty org state without overflow', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdOrgSettingsPage(),
          profile: UiViewportProfile.iphone,
          path: '/settings/org-settings',
          overrides: _emptyBase(role: Role.admin),
        );
        expect(find.text('Keine Organisation'), findsOneWidget);
      });
    });
  });

  group('2. Error states', () {
    testWidgets('RdTodayPage (leader) shows error fallback when attendance list fails', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdTodayPage(),
          profile: UiViewportProfile.iphone,
          path: '/heute',
          overrides: [
            ..._emptyBase(role: Role.admin),
            realtimeAttendanceListProvider.overrideWith((ref) => Future<List<Attendance>>.error(Exception('network'))),
          ],
        );
        expect(find.text('Das konnte nicht geladen werden.'), findsOneWidget);
        expect(find.text('Erneut versuchen'), findsOneWidget);
      });
    });

    testWidgets('RdEventsPage shows error fallback when attendance list fails', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdEventsPage(),
          profile: UiViewportProfile.iphone,
          path: '/termine',
          overrides: [
            ..._emptyBase(role: Role.admin),
            realtimeAttendanceListProvider.overrideWith((ref) => Future<List<Attendance>>.error(Exception('network'))),
          ],
        );
        expect(find.text('Das konnte nicht geladen werden.'), findsOneWidget);
        expect(find.text('Erneut versuchen'), findsOneWidget);
      });
    });

    testWidgets('RdMembersPage shows error fallback when players stream fails', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdMembersPage(),
          profile: UiViewportProfile.iphone,
          path: '/mitglieder',
          overrides: [
            ..._emptyBase(role: Role.admin),
            realtimePlayersProvider.overrideWith((ref) => Stream<List<Person>>.error(Exception('network'))),
          ],
        );
        expect(find.text('Das konnte nicht geladen werden.'), findsOneWidget);
        expect(find.text('Erneut versuchen'), findsOneWidget);
      });
    });

    testWidgets('RdWorksPage shows error fallback when songs provider fails', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdWorksPage(),
          profile: UiViewportProfile.iphone,
          path: '/werke',
          overrides: [
            ..._emptyBase(role: Role.admin),
            songsProvider.overrideWith((ref) => Future<List<Song>>.error(Exception('network'))),
          ],
        );
        expect(find.text('Das konnte nicht geladen werden.'), findsOneWidget);
        expect(find.text('Erneut versuchen'), findsOneWidget);
      });
    });
  });

  group('3. Role permission UI matrix', () {
    testWidgets('Role.admin sees event creation sheet with Orchestertermin and Besprechung', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdEventsPage()),
          profile: UiViewportProfile.desktop,
          path: '/termine',
          overrides: [
            ..._populatedBase(role: Role.admin),
            canCreateAttendanceProvider.overrideWithValue(true),
            isTeamLeaderProvider.overrideWithValue(true),
          ],
        );
        expect(find.byKey(const Key('rd-events-add')), findsOneWidget);
        await tester.tap(find.byKey(const Key('rd-events-add')));
        await settleUi(tester, steps: 5);
        expect(find.text('Orchestertermin'), findsOneWidget);
        expect(find.text('Besprechung'), findsOneWidget);
      });
    });

    testWidgets('Role.admin sees members add/more, works add, and Verwaltung entry', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdMembersPage()),
          profile: UiViewportProfile.desktop,
          path: '/mitglieder',
          overrides: _populatedBase(role: Role.admin),
        );
        expect(find.byKey(const Key('rd-members-add')), findsOneWidget);
        expect(find.byKey(const Key('rd-members-more')), findsOneWidget);
      });
    });

    testWidgets('Role.admin sees works add button and Verwaltung on RdMePage', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdWorksPage()),
          profile: UiViewportProfile.desktop,
          path: '/werke',
          overrides: _populatedBase(role: Role.admin),
        );
        expect(find.byKey(const Key('rd-works-add')), findsOneWidget);
      });
    });

    testWidgets('Role.admin sees Verwaltung entry on RdMePage', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdMePage(),
          profile: UiViewportProfile.iphone,
          path: '/ich',
          overrides: _populatedBase(role: Role.admin),
        );
        expect(find.text('Verwaltung'), findsOneWidget);
      });
    });

    testWidgets('Role.helper goes straight to new event (no meeting choice)', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdEventsPage()),
          profile: UiViewportProfile.desktop,
          path: '/termine',
          overrides: [
            ..._populatedBase(role: Role.helper),
            canCreateAttendanceProvider.overrideWithValue(true),
            isTeamLeaderProvider.overrideWithValue(false),
          ],
        );
        expect(find.byKey(const Key('rd-events-add')), findsOneWidget);
        await tester.tap(find.byKey(const Key('rd-events-add')));
        await settleUi(tester, steps: 5);
        expect(find.text('Orchestertermin'), findsNothing);
        expect(find.text('route:/termine/neu'), findsOneWidget);
      });
    });

    testWidgets('Role.helper hides members add, works add, and Verwaltung', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdMembersPage()),
          profile: UiViewportProfile.desktop,
          path: '/mitglieder',
          overrides: _populatedBase(role: Role.helper),
        );
        expect(find.byKey(const Key('rd-members-add')), findsNothing);
      });
    });

    testWidgets('Role.helper hides works add and Verwaltung on RdMePage', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdWorksPage()),
          profile: UiViewportProfile.desktop,
          path: '/werke',
          overrides: _populatedBase(role: Role.helper),
        );
        expect(find.byKey(const Key('rd-works-add')), findsNothing);
      });
    });

    testWidgets('Role.helper hides Verwaltung entry on RdMePage', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdMePage(),
          profile: UiViewportProfile.iphone,
          path: '/ich',
          overrides: _populatedBase(role: Role.helper),
        );
        expect(find.text('Verwaltung'), findsNothing);
      });
    });

    testWidgets('Role.player hides event creation button', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdEventsPage()),
          profile: UiViewportProfile.desktop,
          path: '/termine',
          overrides: [
            ..._populatedBase(role: Role.player),
            canCreateAttendanceProvider.overrideWithValue(false),
          ],
        );
        expect(find.byKey(const Key('rd-events-add')), findsNothing);
      });
    });

    testWidgets('Role.player hides members add, works add, and Verwaltung', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdMembersPage()),
          profile: UiViewportProfile.desktop,
          path: '/mitglieder',
          overrides: _populatedBase(role: Role.player),
        );
        expect(find.byKey(const Key('rd-members-add')), findsNothing);
      });
    });

    testWidgets('Role.player hides works add button', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdWorksPage()),
          profile: UiViewportProfile.desktop,
          path: '/werke',
          overrides: _populatedBase(role: Role.player),
        );
        expect(find.byKey(const Key('rd-works-add')), findsNothing);
      });
    });

    testWidgets('Role.player hides Verwaltung entry on RdMePage', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdMePage(),
          profile: UiViewportProfile.iphone,
          path: '/ich',
          overrides: _populatedBase(role: Role.player),
        );
        expect(find.text('Verwaltung'), findsNothing);
      });
    });

    testWidgets('Role.viewer shows observer hint on Today and hides creation buttons', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdTodayPage(),
          profile: UiViewportProfile.iphone,
          path: '/heute',
          overrides: _populatedBase(role: Role.viewer),
        );
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });

    testWidgets('Role.viewer hides event creation button', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdEventsPage()),
          profile: UiViewportProfile.desktop,
          path: '/termine',
          overrides: [
            ..._populatedBase(role: Role.viewer),
            canCreateAttendanceProvider.overrideWithValue(false),
          ],
        );
        expect(find.byKey(const Key('rd-events-add')), findsNothing);
      });
    });

    testWidgets('Role.viewer hides members add/more and works add', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdMembersPage()),
          profile: UiViewportProfile.desktop,
          path: '/mitglieder',
          overrides: _populatedBase(role: Role.viewer),
        );
        expect(find.byKey(const Key('rd-members-add')), findsNothing);
        expect(find.byKey(const Key('rd-members-more')), findsNothing);
      });
    });

    testWidgets('Role.viewer hides works add button', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdSplitScope(isDetail: false, child: RdWorksPage()),
          profile: UiViewportProfile.desktop,
          path: '/werke',
          overrides: _populatedBase(role: Role.viewer),
        );
        expect(find.byKey(const Key('rd-works-add')), findsNothing);
      });
    });

    testWidgets('Role.applicant shows applicant waiting view on Today', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdTodayPage(),
          profile: UiViewportProfile.iphone,
          path: '/heute',
          overrides: _populatedBase(role: Role.applicant),
        );
        expect(find.byKey(const Key('rd-applicant-other-group')), findsOneWidget);
        expect(find.byKey(const Key('rd-events-add')), findsNothing);
      });
    });
  });

  group('4. Interactive user flows', () {
    testWidgets('RdMembersPage live search filtering & clearing restores full list', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdMembersPage(),
          profile: UiViewportProfile.iphone,
          path: '/mitglieder',
          overrides: _populatedBase(role: Role.admin),
        );
        expect(find.text('Anna Berg'), findsOneWidget);
        expect(find.text('Felix Graf'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Felix');
        await settleUi(tester, steps: 3);
        expect(find.text('Felix Graf'), findsOneWidget);
        expect(find.text('Anna Berg'), findsNothing);

        await tester.tap(find.byIcon(Icons.close));
        await settleUi(tester, steps: 3);
        expect(find.text('Anna Berg'), findsOneWidget);
        expect(find.text('Felix Graf'), findsOneWidget);
      });
    });

    testWidgets('RdWorksPage live search filtering & clearing restores full list', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdWorksPage(),
          profile: UiViewportProfile.iphone,
          path: '/werke',
          overrides: _populatedBase(role: Role.admin),
        );
        expect(find.text('Festliche Ouvertüre'), findsOneWidget);
        expect(find.text('Ave verum corpus'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Ave');
        await settleUi(tester, steps: 3);
        expect(find.text('Ave verum corpus'), findsOneWidget);
        expect(find.text('Festliche Ouvertüre'), findsNothing);

        await tester.tap(find.byIcon(Icons.close));
        await settleUi(tester, steps: 3);
        expect(find.text('Festliche Ouvertüre'), findsOneWidget);
        expect(find.text('Ave verum corpus'), findsOneWidget);
      });
    });

    testWidgets('RdEventsPage switches segments between Kommend, Vergangen, and Org-Pläne', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdEventsPage(),
          profile: UiViewportProfile.iphone,
          path: '/termine',
          overrides: _populatedBase(role: Role.admin),
        );
        expect(find.text('Frühjahrskonzert'), findsOneWidget);

        await tester.tap(find.text('Vergangen'));
        await settleUi(tester, steps: 5);
        expect(find.text('Frühjahrskonzert'), findsNothing);
        expect(find.text('Gesamtprobe'), findsWidgets);

        await tester.tap(find.text('Org-Pläne'));
        await settleUi(tester, steps: 5);
        expect(find.text('Org-Pläne'), findsOneWidget);

        await tester.tap(find.text('Kommend'));
        await settleUi(tester, steps: 5);
        expect(find.text('Frühjahrskonzert'), findsOneWidget);
      });
    });

    testWidgets('RdEventCreatePage disables submit while saving/checking permission and hides it when no types exist', (
      tester,
    ) async {
      await runCapturingFlutterErrors(() async {
        final permission = Completer<bool>();
        await pumpUiApp(
          tester,
          const RdEventCreatePage(),
          profile: UiViewportProfile.iphone,
          path: '/termine/neu',
          overrides: [
            ..._populatedBase(role: Role.admin),
            canCreateAttendanceProvider.overrideWithValue(true),
            canCreateAttendanceConfirmedProvider.overrideWith((ref) => permission.future),
            protocolTypesProvider.overrideWith((ref) async => const []),
            typeCirclePersonsProvider.overrideWith((ref) async => const {}),
            holidaysProvider.overrideWith((ref) async => const HolidayData()),
          ],
        );
        final submitBtn = find.descendant(
          of: find.byKey(const ValueKey('rd-create-submit')),
          matching: find.byType(FilledButton),
        );
        expect(tester.widget<FilledButton>(submitBtn).onPressed, isNotNull);

        await tester.tap(submitBtn);
        await tester.pump();
        expect(tester.widget<FilledButton>(submitBtn).onPressed, isNull);

        permission.complete(false);
        await settleUi(tester, steps: 5);
        expect(tester.widget<FilledButton>(submitBtn).onPressed, isNotNull);
      });
    });

    testWidgets('RdEventCreatePage hides submit and shows empty-types state when no event types exist', (tester) async {
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          const RdEventCreatePage(),
          profile: UiViewportProfile.iphone,
          path: '/termine/neu',
          overrides: [
            ..._populatedBase(role: Role.admin),
            canCreateAttendanceProvider.overrideWithValue(true),
            attendanceTypesProvider.overrideWith((ref) async => const <AttendanceType>[]),
            protocolTypesProvider.overrideWith((ref) async => const []),
            typeCirclePersonsProvider.overrideWith((ref) async => const {}),
            holidaysProvider.overrideWith((ref) async => const HolidayData()),
          ],
        );
        expect(find.byKey(const ValueKey('rd-create-submit')), findsNothing);
      });
    });

    testWidgets('OrgSongCopySheet disables submit when number is taken or cleared', (tester) async {
      final repo = _FakeOrgSongRepository();
      const orgTenants = [OrgSongTenant(id: 10, shortName: 'PC', longName: 'Posaunenchor')];
      final targets = [OrgSongCopyTarget(tenant: orgTenants[0], libraryId: 10)];
      const sourceSong = OrgSongResult(
        id: 50,
        tenantId: 99,
        tenantName: 'Bezirkschor',
        name: 'Choral in Es',
        number: 5,
        prefix: 'A',
      );
      await runCapturingFlutterErrors(() async {
        await pumpUiApp(
          tester,
          Scaffold(
            body: OrgSongCopySheet(
              source: sourceSong,
              targets: targets,
              orgTenants: orgTenants,
            ),
          ),
          profile: UiViewportProfile.iphone,
          overrides: [orgSongRepositoryWithTenantProvider.overrideWithValue(repo)],
        );

        final submitFinder = find.byKey(const Key('org-copy-submit'));
        await tester.scrollUntilVisible(
          submitFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await settleUi(tester, steps: 3);
        expect(tester.widget<RdPrimaryButton>(submitFinder).onPressed, isNotNull);

        await tester.scrollUntilVisible(
          find.byKey(const Key('org-copy-number')),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byKey(const Key('org-copy-number')), '1');
        await settleUi(tester, steps: 5);
        await tester.scrollUntilVisible(
          submitFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await settleUi(tester, steps: 3);
        expect(tester.widget<RdPrimaryButton>(submitFinder).onPressed, isNull);

        await tester.scrollUntilVisible(
          find.byKey(const Key('org-copy-number')),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byKey(const Key('org-copy-number')), '');
        await settleUi(tester, steps: 3);
        await tester.scrollUntilVisible(
          submitFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await settleUi(tester, steps: 3);
        expect(tester.widget<RdPrimaryButton>(submitFinder).onPressed, isNull);
      });
    });
  });
}
