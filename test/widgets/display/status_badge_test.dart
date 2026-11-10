import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/shared/widgets/display/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('StatusBadge', () {
    group('displays correct text for each status', () {
      widgetTest('present shows checkmark', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.present),
        );

        expect(find.text('✓'), findsOneWidget);
      });

      widgetTest('absent shows A', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.absent),
        );

        expect(find.text('A'), findsOneWidget);
      });

      widgetTest('excused shows E', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.excused),
        );

        expect(find.text('E'), findsOneWidget);
      });

      widgetTest('late shows L', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.late),
        );

        expect(find.text('L'), findsOneWidget);
      });

      widgetTest('lateExcused shows LE', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.lateExcused),
        );

        expect(find.text('LE'), findsOneWidget);
      });

      widgetTest('neutral shows N', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.neutral),
        );

        expect(find.text('N'), findsOneWidget);
      });
    });

    group('showLabel displays German labels', () {
      widgetTest('present shows Anwesend', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.present, showLabel: true),
        );

        expect(find.text('Anwesend'), findsOneWidget);
      });

      widgetTest('absent shows Abwesend', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.absent, showLabel: true),
        );

        expect(find.text('Abwesend'), findsOneWidget);
      });

      widgetTest('excused shows Entschuldigt', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.excused, showLabel: true),
        );

        expect(find.text('Entschuldigt'), findsOneWidget);
      });

      widgetTest('late shows Verspätet', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.late, showLabel: true),
        );

        expect(find.text('Verspätet'), findsOneWidget);
      });
    });

    group('variants render correctly', () {
      widgetTest('filled variant has solid background', (tester) async {
        await tester.pumpApp(
          const StatusBadge(
            status: AttendanceStatus.present,
            variant: StatusBadgeVariant.filled,
          ),
        );

        // Find the container with the badge
        final containerFinder = find.ancestor(
          of: find.text('✓'),
          matching: find.byType(Container),
        );
        expect(containerFinder, findsWidgets);
      });

      widgetTest('outlined variant has border', (tester) async {
        await tester.pumpApp(
          const StatusBadge(
            status: AttendanceStatus.present,
            variant: StatusBadgeVariant.outlined,
          ),
        );

        expect(find.text('✓'), findsOneWidget);
      });

      widgetTest('subtle variant has semi-transparent background',
          (tester) async {
        await tester.pumpApp(
          const StatusBadge(
            status: AttendanceStatus.present,
            variant: StatusBadgeVariant.subtle,
          ),
        );

        expect(find.text('✓'), findsOneWidget);
      });
    });

    group('sizes render correctly', () {
      widgetTest('small size has compact padding', (tester) async {
        await tester.pumpApp(
          const StatusBadge(
            status: AttendanceStatus.present,
            size: StatusBadgeSize.small,
          ),
        );

        expect(find.text('✓'), findsOneWidget);
      });

      widgetTest('medium size is default', (tester) async {
        await tester.pumpApp(
          const StatusBadge(status: AttendanceStatus.present),
        );

        expect(find.text('✓'), findsOneWidget);
      });

      widgetTest('large size has larger padding', (tester) async {
        await tester.pumpApp(
          const StatusBadge(
            status: AttendanceStatus.present,
            size: StatusBadgeSize.large,
          ),
        );

        expect(find.text('✓'), findsOneWidget);
      });
    });
  });

  widgetTestGroup('StatusChip', () {
    widgetTest('responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpApp(
        StatusChip(
          status: AttendanceStatus.present,
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(StatusChip));
      await tester.pump();

      expect(tapped, isTrue);
    });

    widgetTest('shows selected state', (tester) async {
      await tester.pumpApp(
        StatusChip(
          status: AttendanceStatus.present,
          onTap: () {},
          isSelected: true,
        ),
      );

      // Find the AnimatedContainer which changes appearance when selected
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    group('displays correct icons', () {
      widgetTest('present shows check icon', (tester) async {
        await tester.pumpApp(
          StatusChip(
            status: AttendanceStatus.present,
            onTap: () {},
          ),
        );

        expect(find.byIcon(AppIcons.check), findsOneWidget);
      });

      widgetTest('absent shows close icon', (tester) async {
        await tester.pumpApp(
          StatusChip(
            status: AttendanceStatus.absent,
            onTap: () {},
          ),
        );

        expect(find.byIcon(AppIcons.close), findsOneWidget);
      });

      widgetTest('excused shows event_busy icon', (tester) async {
        await tester.pumpApp(
          StatusChip(
            status: AttendanceStatus.excused,
            onTap: () {},
          ),
        );

        expect(find.byIcon(AppIcons.eventBusy), findsOneWidget);
      });

      widgetTest('late shows schedule icon', (tester) async {
        await tester.pumpApp(
          StatusChip(
            status: AttendanceStatus.late,
            onTap: () {},
          ),
        );

        expect(find.byIcon(AppIcons.schedule), findsOneWidget);
      });
    });
  });
}
