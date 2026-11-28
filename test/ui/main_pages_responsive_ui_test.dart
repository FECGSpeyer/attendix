import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_rate_filter_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/features/attendance/data/providers/events_providers.dart';
import 'package:attendix/features/attendance/presentation/pages/event_page.dart';
import 'package:attendix/features/attendance/presentation/pages/events_page.dart';
import 'package:attendix/features/organisation/presentation/pages/org_settings_page.dart';
import 'package:attendix/features/people/data/members_logic.dart';
import 'package:attendix/features/people/presentation/pages/members_page.dart';
import 'package:attendix/features/profile/presentation/pages/me_page.dart';
import 'package:attendix/features/settings/presentation/pages/manage_page.dart';
import 'package:attendix/features/songs/presentation/pages/works_page.dart';
import 'package:attendix/features/today/data/providers/today_providers.dart';
import 'package:attendix/features/today/presentation/pages/today_page.dart';
import 'package:attendix/features/today/presentation/widgets/player_today.dart';
import 'package:attendix/shared/shell/app_shell.dart';
import 'package:attendix/shared/widgets/components/group_switch.dart';
import 'package:attendix/shared/widgets/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support/golden_world.dart';
import 'ui_layout_invariants.dart';

const _profiles = [
  UiViewportProfile.narrowPhoneLargeText,
  UiViewportProfile.iphone,
  UiViewportProfile.iphoneDark,
  UiViewportProfile.desktop,
];

const _counts = RdStatusCounts(present: 6, lateAnnounced: 1, excused: 1, open: 2);

Widget _shell(Widget child) => RdShell(child: child);

CrossTenantPersonAttendance _ownAttendance(int attendanceId, AttendanceStatus status) {
  final attendance = worldAttendances.firstWhere((a) => a.id == attendanceId);
  return CrossTenantPersonAttendance(
    id: '$attendanceId',
    attendanceId: attendanceId,
    status: status,
    date: attendance.date,
    typeInfo: attendance.typeInfo,
    startTime: attendance.startTime,
    endTime: attendance.endTime,
    place: 'Probenraum',
    tenantId: worldTenantId,
    tenantName: 'SO',
    tenantColor: 'primary',
  );
}

List<Override> _leaderOverrides() => [
  ...worldOverrides(role: Role.admin),
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

List<Override> _memberOverrides() => [
  ...worldOverrides(role: Role.player),
  currentSelfServicePlayerProvider.overrideWith((ref) async => worldPersons[1]),
  signoutDataProvider.overrideWith(
    (ref) async => SignoutData(
      current: _ownAttendance(21, AttendanceStatus.neutral),
      upcoming: [
        _ownAttendance(22, AttendanceStatus.present),
        _ownAttendance(23, AttendanceStatus.excused),
      ],
      percentage: 88,
    ),
  ),
];

Finder _pageHeading(String title, {Type scope = RdPage}) => find.descendant(
  of: find.byType(scope),
  matching: find.byWidgetPredicate(
    (w) => w is Text && w.data == title && (w.style?.fontSize ?? 0) >= 28,
    description: 'large page heading "$title"',
  ),
);

Finder _pageWidget(Finder finder) => find.descendant(
  of: find.byType(RdPage),
  matching: finder,
);

void main() {
  for (final profile in _profiles) {
    group('Responsive layout [${profile.name}]', () {
      testWidgets('RdTodayPage (leader) renders without overflow or header collision', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdTodayPage(),
            profile: profile,
            path: '/heute',
            shell: _shell,
            overrides: _leaderOverrides(),
          );
          final heading = _pageHeading('Heute');
          final bell = _pageWidget(find.byIcon(Icons.notifications_outlined));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, bell, profile.size);
          if (profile.size.width < 840) {
            final chip = _pageWidget(find.byType(RdGroupChip));
            expectWithinViewport(tester, chip, profile.size);
            expectNoOverlaps(tester, [chip, bell]);
          }
          expectNoOverlaps(tester, [heading, bell]);
        });
      });

      testWidgets('RdTodayPage (member) renders without overflow or header collision', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdTodayPage(),
            profile: profile,
            path: '/heute',
            shell: _shell,
            overrides: _memberOverrides(),
          );
          final heading = _pageHeading('Heute');
          final bell = _pageWidget(find.byIcon(Icons.notifications_outlined));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, bell, profile.size);
          if (profile.size.width < 840) {
            final chip = _pageWidget(find.byType(RdGroupChip));
            expectWithinViewport(tester, chip, profile.size);
            expectNoOverlaps(tester, [chip, bell]);
          }
          expectNoOverlaps(tester, [heading, bell]);
          expectHorizontallyWithinViewport(tester, find.byType(RdOwnAnswerSection), profile.size);
        });
      });

      testWidgets('RdEventsPage (leader) renders and switches segments cleanly', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdEventsPage(),
            profile: profile,
            path: '/termine',
            shell: _shell,
            overrides: [
              ..._leaderOverrides(),
              currentOrganisationProvider.overrideWith((ref) async => const Organisation(id: 42, name: 'Stadtorchester Org')),
              orgPlansProvider.overrideWith((ref) async => const []),
            ],
          );
          final heading = _pageHeading('Termine');
          final searchBtn = _pageWidget(find.byIcon(Icons.search));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, searchBtn, profile.size);
          expectNoOverlaps(tester, [heading, searchBtn]);

          // Leaders with an organisation always get all three segments; a
          // missing one is a regression, not a reason to skip the check.
          Finder segment(String label) => find.descendant(
                of: find.byType(RdSegmented<RdEventsSegment>),
                matching: find.text(label),
              );
          final pastSegment = segment('Vergangen');
          expect(pastSegment, findsOneWidget);
          await tester.tap(pastSegment);
          await settleUi(tester, steps: 5);
          expect(find.text('Frühjahrskonzert'), findsNothing);

          final orgSegment = segment('Org-Pläne');
          expect(orgSegment, findsOneWidget);
          await tester.tap(orgSegment);
          await settleUi(tester, steps: 5);
          final orgEmpty = find.textContaining('Keine bevorstehenden Org-Pläne');
          expect(orgEmpty, findsOneWidget);
          expectHorizontallyWithinViewport(tester, orgEmpty, profile.size);
        });
      });

      testWidgets('RdEventPage(attendanceId: 21) renders without overflow or header collision', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdEventPage(attendanceId: 21),
            profile: profile,
            path: '/termine/21',
            overrides: [
              ..._leaderOverrides(),
              attendanceDetailProvider.overrideWith((ref, id) async => worldAttendances.first),
              attendanceTypeForAttendanceProvider.overrideWith((ref, id) async => worldTypes.first),
              personAttendancesForAttendanceProvider.overrideWith((ref, id) async => worldAnswers),
              filteredPersonsForAttendanceProvider.overrideWith((ref, id) async => worldPersons),
              rdOpenPersonsProvider.overrideWith((ref, id) async => rdOpenPersons(worldAnswers, worldPersons)),
            ],
          );
          final heading = _pageHeading('Gesamtprobe', scope: RdEventPage);
          final back = find.byType(RdBackLink);
          final edit = find.byKey(const Key('rd-event-edit'));
          final menu = find.byKey(const Key('rd-event-menu'));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, back, profile.size);
          expectWithinViewport(tester, edit, profile.size);
          expectWithinViewport(tester, menu, profile.size);
          expectNoOverlaps(tester, [back, edit, menu]);
        });
      });

      testWidgets('RdMembersPage renders without overflow or header collision', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdMembersPage(),
            profile: profile,
            path: '/mitglieder',
            shell: _shell,
            overrides: _leaderOverrides(),
          );
          final heading = _pageHeading('Mitglieder');
          final more = find.byKey(const Key('rd-members-more'));
          final filter = find.byKey(const Key('rd-members-filter'));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, more, profile.size);
          expectWithinViewport(tester, filter, profile.size);
          expectWithinViewport(tester, find.byType(RdSegmented<RdMembersFilter>), profile.size);
          expectNoOverlaps(tester, [heading, more]);
        });
      });

      testWidgets('RdWorksPage renders without overflow or header collision', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdWorksPage(),
            profile: profile,
            path: '/werke',
            shell: _shell,
            overrides: _leaderOverrides(),
          );
          final heading = _pageHeading('Werke');
          final more = _pageWidget(find.byIcon(Icons.more_horiz));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, more, profile.size);
          expectWithinViewport(tester, find.byType(RdFilterLink), profile.size);
          expectHorizontallyWithinViewport(tester, find.byKey(const ValueKey('rd-work-1')), profile.size);
          expectNoOverlaps(tester, [heading, more]);
        });
      });

      testWidgets('RdMePage renders without overflow', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdMePage(),
            profile: profile,
            path: '/ich',
            shell: _shell,
            overrides: _leaderOverrides(),
          );
          final heading = _pageHeading('Ich');
          expectWithinViewport(tester, heading, profile.size);
        });
      });

      testWidgets('RdManagePage renders without overflow', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdManagePage(),
            profile: profile,
            path: '/ich/verwaltung',
            overrides: _leaderOverrides(),
          );
          final heading = _pageHeading('Verwaltung');
          expectWithinViewport(tester, heading, profile.size);
          if (profile.size.width < 840) {
            final back = find.byType(RdBackLink);
            expectWithinViewport(tester, back, profile.size);
            expectNoOverlaps(tester, [back, heading]);
          }
        });
      });

      testWidgets('RdOrgSettingsPage renders without overflow or header collision', (tester) async {
        await runCapturingFlutterErrors(() async {
          await pumpUiApp(
            tester,
            const RdOrgSettingsPage(),
            profile: profile,
            path: '/settings/org-settings',
            overrides: [
              ..._leaderOverrides(),
              currentOrganisationProvider.overrideWith(
                (ref) async => const Organisation(id: 42, name: 'Stadtorchester Organisation'),
              ),
              linkedTenantsProvider.overrideWith((ref) async => worldTenants(Role.admin)),
            ],
          );
          final heading = _pageHeading('Organisation');
          final infoBtn = find.byKey(const Key('rd-org-settings-info'));
          expectWithinViewport(tester, heading, profile.size);
          expectWithinViewport(tester, infoBtn, profile.size);
          expectNoOverlaps(tester, [heading, infoBtn]);
        });
      });
    });
  }
}
