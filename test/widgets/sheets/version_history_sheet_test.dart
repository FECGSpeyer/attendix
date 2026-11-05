import 'dart:convert';
import 'dart:io';

import 'package:attendix/core/constants/app_constants.dart';
import 'package:attendix/core/models/version_history.dart';
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
        final first = (_userHistory().first
            as Map<String, dynamic>)['changes'] as List;
        final change = first.first as String;
        await _openSheetAndWaitFor(tester, find.text(change));
        final text = tester.widget<Text>(find.text(change).first);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.softWrap, isNot(false));
      });
    });

    group('user history (Ionic history continued)', () {
      widgetTest(
          'loads the user file; top entry is displayVersion, '
          'header without date', (tester) async {
        final versions = _userHistory();
        final top = versions.first as Map<String, dynamic>;
        expect(top['version'], AppConstants.displayVersion);
        expect(top.containsKey('date'), isFalse);
        // every entry of the user file must parse
        VersionHistory.fromJson({'versions': versions});

        final second = versions[1] as Map<String, dynamic>;
        await _openSheetAndWaitFor(
            tester, find.text('Version ${AppConstants.displayVersion}'));
        // no date in parentheses for the top entry (like Ionic) …
        expect(find.text('Version ${AppConstants.displayVersion}'),
            findsOneWidget);
        // … the Ionic entries below keep "Version x (date)"
        expect(
            find.text('Version ${second['version']} (${second['date']})'),
            findsOneWidget);
        // the internal 0.x developer history is not shown
        expect(find.text('Version ${AppConstants.appVersion}'), findsNothing);
        expect(find.textContaining('Version 0.'), findsNothing);
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

/// Entries of the user-facing history the sheet shows.
List<dynamic> _userHistory() {
  final json = jsonDecode(File(versionHistoryUserAsset).readAsStringSync())
      as Map<String, dynamic>;
  return json['versions'] as List;
}

/// Opens the sheet via [showVersionHistorySheet] and waits until the asset
/// is loaded and [finder] shows up.
Future<void> _openSheetAndWaitFor(WidgetTester tester, Finder finder) async {
  // earlier tests leave a cached (never completed) load behind
  rootBundle.evict(versionHistoryUserAsset);
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
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}
