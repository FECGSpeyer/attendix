import 'dart:convert';
import 'dart:io';

import 'package:attendix/core/constants/app_constants.dart';
import 'package:attendix/core/models/version_history.dart';
import 'package:attendix/shared/widgets/sheets/version_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('VersionHistorySheet', () {
    group('initial structure', () {
      widgetTest('displays loading indicator initially', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      widgetTest('has correct title', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.text('Neu in dieser Version'), findsOneWidget);
      });

      widgetTest('has no close button in header', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.byIcon(Icons.close), findsNothing);
      });

      widgetTest('has no sparkle icon in header', (tester) async {
        await tester.pumpApp(
          const VersionHistorySheet(),
        );

        expect(find.byIcon(Icons.auto_awesome), findsNothing);
      });
    });

    group('entries (shows the full text)', () {
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

    group('user history', () {
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
            tester, find.text(AppConstants.displayVersion));
        expect(find.text(AppConstants.displayVersion), findsOneWidget);
        expect(
            find.text('${second['version']} · ${second['date']}'),
            findsOneWidget);
        // the internal 0.x developer history is not shown
        expect(find.text(AppConstants.appVersion), findsNothing);
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
