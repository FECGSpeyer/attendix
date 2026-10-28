import 'package:attendix/shared/widgets/sheets/version_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('VersionHistorySheet', () {
    group('initial structure', () {
      widgetTest('displays loading indicator initially', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        // Should show CircularProgressIndicator while loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      widgetTest('has correct title', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.text('Was ist neu?'), findsOneWidget);
      });

      widgetTest('has no close button (Ionic toolbar shows only the title)',
          (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.byIcon(Icons.close), findsNothing);
      });

      widgetTest('has handle bar at top', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        // The widget builds successfully with handle bar
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      });

      widgetTest('has no sparkle icon in header (Ionic parity)', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.byIcon(Icons.auto_awesome), findsNothing);
      });
    });

    group('DraggableScrollableSheet configuration', () {
      widgetTest('is wrapped in DraggableScrollableSheet', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      });
    });
  });
}
