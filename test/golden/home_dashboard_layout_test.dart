// The classic home dashboard must lay out without errors. In a release build
// a layout error (e.g. an unbounded height) is not reported: the whole list
// stays empty, which is what users saw on the "Dashboard" tab. Lives here for
// the real fonts (flutter_test_config.dart), so text widths are realistic.
import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/data/models/dashboard/dashboard_event.dart';
import 'package:attendix/data/models/dashboard/dashboard_models.dart';
import 'package:attendix/features/dashboard/presentation/pages/home_dashboard_page.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../factories/test_factories.dart';
import 'support/golden_harness.dart';
import 'support/golden_world.dart';

void main() {
  final next = DashboardEvent(
    attendance: TestFactories.createAttendance(
      id: 21,
      tenantId: worldTenantId,
      date: '2099-03-05',
      typeInfo: 'Gesamtprobe',
      startTime: '19:30',
      endTime: '21:30',
    ),
    persons: const [],
  );

  final today = DateTime.now();
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final persons = [
    for (final (i, p) in worldPersons.indexed)
      p.copyWith(
        birthday: iso(DateTime(1990, today.month, today.day).add(Duration(days: i))),
        joined: i.isEven ? iso(today.subtract(const Duration(days: 5))) : p.joined,
        isCritical: i == 1,
        criticalReasonText: i == 1 ? 'Dreimal unentschuldigt gefehlt' : null,
      ),
  ];

  for (final look in const [GoldenLook.classicIos, GoldenLook.classicMd]) {
    for (final size in const [goldenPhone, Size(1024, 1366), Size(1400, 900)]) {
      testWidgets('Dashboard ${look.prefix} ${size.width.toInt()}: cards are laid out', (tester) async {
        await pumpGolden(
          tester,
          const HomeDashboardPage(),
          look: look,
          size: size,
          pixelRatio: 1,
          path: '/dashboard',
          shell: (child) => MainShell(child: child),
          overrides: [
            ...worldOverrides(),
            visibleDashboardCardsProvider.overrideWith((ref) => [
                  for (final id in DashboardCardIds.all) DashboardCardConfig(id: id),
                ]),
            dashboardNextEventProvider.overrideWith((ref) async => NextEventSummary(
                  nextEvent: next,
                  nextTotal: 12,
                  nextPresent: 8,
                  nextExcused: 2,
                  nextNeutral: 2,
                  nextPerc: 67,
                )),
            dashboardPersonsProvider.overrideWith((ref) async => persons),
            dashboardAbsencesProvider.overrideWith((ref) async => const []),
            dashboardCurrentSongsProvider.overrideWith((ref) async => const []),
            dashboardCurrentPlanProvider.overrideWith((ref) async => null),
          ],
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Gesamtprobe'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
      });
    }
  }
}
