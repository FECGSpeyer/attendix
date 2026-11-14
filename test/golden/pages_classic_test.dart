// Golden images of the main pages in the classic design (the Ionic look).
// How to add or renew one: test/golden/README.md.
@Tags(['golden'])
library;

import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_list_page.dart';
import 'package:attendix/features/people/presentation/pages/people_list_page.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart';
import 'package:attendix/features/settings/presentation/pages/settings_page.dart';
import 'package:attendix/features/songs/presentation/pages/songs_list_page.dart';
import 'package:attendix/features/tenant_selection/presentation/pages/tenant_selection_page.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_harness.dart';
import 'support/golden_world.dart';

Widget _shell(Widget child) => MainShell(child: child);

/// What the leaders' pages show.
List<Override> _leader() => [
      ...worldOverrides(),
      realtimeAttendanceListProvider.overrideWith((ref) async => worldAttendances),
      realtimePlayersProvider.overrideWith((ref) => Stream.value(worldPersons)),
      realtimePendingPlayersProvider.overrideWith((ref) => Stream.value(const [])),
      playersProvider.overrideWith((ref) async => worldPersons),
      playerAttendancePercentagesProvider.overrideWith((ref) async => worldPercentages),
      songsProvider.overrideWith((ref) async => worldSongs),
    ];

void main() {
  for (final look in const [GoldenLook.classicIos, GoldenLook.classicMd]) {
    group(look.prefix, () {
      testWidgets('Personen', (tester) async {
        await pumpGolden(tester, const PeopleListPage(), look: look, path: '/people', shell: _shell, overrides: _leader());
        await expectGolden(tester, look, 'personen');
      });

      testWidgets('Termin', (tester) async {
        await pumpGolden(
          tester,
          const AttendanceDetailPage(attendanceId: 21),
          look: look,
          path: '/attendance/21',
          overrides: [
            ..._leader(),
            attendanceDetailProvider.overrideWith((ref, id) async => worldAttendances.first),
            attendanceTypeForAttendanceProvider.overrideWith((ref, id) async => worldTypes.first),
            personAttendancesForAttendanceProvider.overrideWith((ref, id) async => worldAnswers),
            filteredPersonsForAttendanceProvider.overrideWith((ref, id) async => worldPersons),
          ],
        );
        await expectGolden(tester, look, 'termin');
      });

      testWidgets('Mehr', (tester) async {
        await pumpGolden(tester, const SettingsPage(), look: look, path: '/settings', shell: _shell, overrides: _leader());
        await expectGolden(tester, look, 'mehr');
      });

      // The md look differs most on the pages above; these four only get
      // the iOS look.
      if (look != GoldenLook.classicIos) return;

      testWidgets('Gruppen', (tester) async {
        await pumpGolden(tester, const TenantSelectionPage(), look: look, path: '/tenants', overrides: _leader());
        await expectGolden(tester, look, 'gruppen');
      });

      testWidgets('Person', (tester) async {
        await pumpGolden(
          tester,
          const PersonDetailPage(personId: 1),
          look: look,
          path: '/people/1',
          overrides: [
            ..._leader(),
            personProvider(1).overrideWith((ref) async => worldPersons.first),
          ],
        );
        await expectGolden(tester, look, 'person');
      });

      testWidgets('Termine', (tester) async {
        await pumpGolden(tester, const AttendanceListPage(), look: look, path: '/attendance', shell: _shell, overrides: _leader());
        await expectGolden(tester, look, 'termine');
      });

      testWidgets('Werke', (tester) async {
        await pumpGolden(tester, const SongsListPage(), look: look, path: '/songs-tab', shell: _shell, overrides: _leader());
        await expectGolden(tester, look, 'werke');
      });
    });
  }
}
