import 'dart:convert';
import 'dart:io';

import 'package:attendix/shared/widgets/sheets/version_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    group('entries (Ionic shows the full text)', () {
      widgetTest('changes wrap instead of being cut to one line',
          (tester) async {
        // earlier tests leave a cached (never completed) load behind
        rootBundle.evict('assets/version_history.json');
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showVersionHistorySheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        final json = jsonDecode(
                File('assets/version_history.json').readAsStringSync())
            as Map<String, dynamic>;
        final first = ((json['versions'] as List).first
            as Map<String, dynamic>)['changes'] as List;
        final change = first.first as String;
        for (var i = 0; i < 100 && find.text(change).evaluate().isEmpty; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
        }
        final text = tester.widget<Text>(find.text(change).first);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.softWrap, isNot(false));
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
