// Golden images of the main pages in the new design (Beta).
// How to add or renew one: test/golden/README.md.
@Tags(['golden'])
library;

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/attendance_rate_filter_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_events_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_event_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_events_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_manage_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_me_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_members_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_today_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_works_page.dart';
import 'package:attendix/features/redesign/presentation/shell/rd_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/golden_harness.dart';
import 'support/golden_world.dart';

const _look = GoldenLook.beta;

Widget _shell(Widget child) => RdShell(child: child);

/// What the leaders' pages show.
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

/// "Heute" shows today's date: a fixed day takes its place.
Map<String, String> _today() => {DateFormat('EEEE, d. MMMM', 'de').format(DateTime.now()): 'Donnerstag, 1. Januar'};

/// A Termin of [worldAttendances] as the member's own list has it.
CrossTenantPersonAttendance _own(int attendanceId, AttendanceStatus status) {
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

const _counts = RdStatusCounts(present: 6, lateAnnounced: 1, excused: 1, open: 2);

void main() {
  testWidgets('Mitglieder', (tester) async {
    await pumpGolden(
      tester,
      const RdMembersPage(),
      look: _look,
      path: '/mitglieder',
      shell: _shell,
      overrides: _leader(),
    );
    await expectGolden(tester, _look, 'mitglieder');
  });

  testWidgets('Heute', (tester) async {
    await pumpGolden(tester, const RdTodayPage(), look: _look, path: '/heute', shell: _shell, overrides: _leader());
    await expectGolden(tester, _look, 'heute', replace: _today());
  });

  testWidgets('Termine', (tester) async {
    await pumpGolden(tester, const RdEventsPage(), look: _look, path: '/termine', shell: _shell, overrides: _leader());
    await expectGolden(tester, _look, 'termine');
  });

  testWidgets('Termin', (tester) async {
    await pumpGolden(
      tester,
      const RdEventPage(attendanceId: 21),
      look: _look,
      path: '/termine/21',
      overrides: [
        ..._leader(),
        attendanceDetailProvider.overrideWith((ref, id) async => worldAttendances.first),
        attendanceTypeForAttendanceProvider.overrideWith((ref, id) async => worldTypes.first),
        personAttendancesForAttendanceProvider.overrideWith((ref, id) async => worldAnswers),
        filteredPersonsForAttendanceProvider.overrideWith((ref, id) async => worldPersons),
        rdOpenPersonsProvider.overrideWith((ref, id) async => rdOpenPersons(worldAnswers, worldPersons)),
      ],
    );
    await expectGolden(tester, _look, 'termin');
  });

  testWidgets('Heute als Mitglied', (tester) async {
    await pumpGolden(
      tester,
      const RdTodayPage(),
      look: _look,
      path: '/heute',
      shell: _shell,
      overrides: [
        ...worldOverrides(role: Role.player),
        currentSelfServicePlayerProvider.overrideWith((ref) async => worldPersons[1]),
        signoutDataProvider.overrideWith((ref) async => SignoutData(
              current: _own(21, AttendanceStatus.neutral),
              upcoming: [_own(22, AttendanceStatus.present), _own(23, AttendanceStatus.excused)],
              percentage: 88,
            )),
      ],
    );
    await expectGolden(tester, _look, 'heute_mitglied', replace: _today());
  });

  testWidgets('Werke', (tester) async {
    await pumpGolden(tester, const RdWorksPage(), look: _look, path: '/werke', shell: _shell, overrides: _leader());
    await expectGolden(tester, _look, 'werke');
  });

  testWidgets('Ich', (tester) async {
    await pumpGolden(tester, const RdMePage(), look: _look, path: '/ich', shell: _shell, overrides: _leader());
    await expectGolden(tester, _look, 'ich');
  });

  testWidgets('Verwaltung', (tester) async {
    await pumpGolden(tester, const RdManagePage(), look: _look, path: '/ich/verwaltung', overrides: _leader());
    await expectGolden(tester, _look, 'verwaltung');
  });
}
