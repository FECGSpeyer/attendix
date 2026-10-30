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
import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/common/empty_state.dart';
import 'package:attendix/shared/widgets/common/error_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../factories/test_factories.dart';

const _phone = Size(390, 844);

final _modes = {
  'ios': TargetPlatform.iOS,
  'md': TargetPlatform.android,
};

Widget _app(Widget home, TargetPlatform platform) => ProviderScope(
      overrides: [isInTeamsProvider.overrideWithValue(false)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light.copyWith(platform: platform),
        home: home,
      ),
    );

Future<void> _pump(WidgetTester tester, Widget home, TargetPlatform platform) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home, platform));
  // Bounded: spinners and pulse animations never settle.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final mode in _modes.entries) {
    group(mode.key, () {
      testWidgets('Login', (tester) async {
        await _pump(tester, const LoginPage(), mode.value);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${mode.key}_login.png'));
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
        await _pump(
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
          mode.value,
        );
        await expectLater(
            find.byType(MaterialApp), matchesGoldenFile('goldens/${mode.key}_attendance_tiles.png'));
      });

      testWidgets('Leer- und Fehlerzustand', (tester) async {
        await _pump(
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
          mode.value,
        );
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${mode.key}_states.png'));
      });
    });
  }
}
