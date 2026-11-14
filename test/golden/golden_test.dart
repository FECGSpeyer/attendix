// Golden images of central screens and building blocks in both Ionic modes
// (iOS and md). They catch unintended visual changes that the many
// behaviour tests do not see (spacing, colours, missing widgets).
//
// After an intended UI change:
//   flutter test test/golden --update-goldens
// and check the new images in test/golden/goldens/ in the diff.
@Tags(['golden'])
library;

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/shared/widgets/common/empty_state.dart';
import 'package:attendix/shared/widgets/common/error_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../factories/test_factories.dart';
import 'support/golden_harness.dart';

const _looks = [GoldenLook.classicIos, GoldenLook.classicMd];

void main() {
  for (final look in _looks) {
    group(look.prefix, () {
      testWidgets('Login', (tester) async {
        // The photo in the background: single resolution keeps the file small.
        await pumpGolden(tester, const LoginPage(), look: look, pixelRatio: 1);
        await expectGolden(tester, look, 'login');
      });

      testWidgets('Anwesenheit: Personen in allen Status', (tester) async {
        final names = ['Anna', 'Ben', 'Clara', 'David', 'Emma', 'Felix'];
        final statuses = [
          AttendanceStatus.present,
          AttendanceStatus.absent,
          AttendanceStatus.excused,
          AttendanceStatus.late,
          AttendanceStatus.lateExcused,
          AttendanceStatus.neutral,
        ];
        await pumpGolden(
          tester,
          Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < names.length; i++)
                  AttendancePersonTile(
                    person: TestFactories.createPerson(id: i + 1, firstName: names[i], lastName: 'Muster'),
                    status: statuses[i],
                    notes: i == 3 ? 'kommt um 19:30' : null,
                    availableStatuses: AttendanceStatus.values,
                    onStatusChanged: (_) {},
                    onNoteChanged: (_) {},
                    onShowModifierInfo: () {},
                    onRemoveFromAttendance: () {},
                  ),
              ],
            ),
          ),
          look: look,
        );
        await expectGolden(tester, look, 'attendance_tiles');
      });

      testWidgets('Leer- und Fehlerzustand', (tester) async {
        await pumpGolden(
          tester,
          Scaffold(
            body: Column(
              children: [
                const Expanded(
                  child: EmptyStateWidget(
                    icon: Icons.event_busy,
                    title: 'Keine Termine',
                    subtitle: 'Lege den ersten Termin an.',
                    animateIcon: false,
                    animateEntrance: false,
                  ),
                ),
                Expanded(child: ErrorStateView(error: Exception('x'), onRetry: () {})),
              ],
            ),
          ),
          look: look,
        );
        await expectGolden(tester, look, 'states');
      });
    });
  }
}
