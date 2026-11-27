import 'package:attendix/features/today/data/providers/rd_today_providers.dart';
import 'package:attendix/shared/widgets/redesign/rd_widgets.dart';
import 'package:attendix/features/today/presentation/widgets/rd_today_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/beta_event_alignment_fixture.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await loadBetaEventFixtureFonts();
  });

  for (final size in [
    (width: 390.0, scale: 1.0),
    (width: 320.0, scale: 1.0),
    (width: 320.0, scale: 1.6),
  ]) {
    testWidgets(
      'a type pill aligns with the first title line at ${size.width}px / ${size.scale}x',
      (tester) async {
        tester.view.physicalSize = Size(size.width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          betaEventAlignmentFixture(textScale: size.scale),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final shortTitle = find.text(betaShortEventTitle).last;
        final longTitle = find.text(betaLongEventTitle);
        final shortCard =
            find.ancestor(of: shortTitle, matching: find.byType(RdCard)).first;
        final longCard =
            find.ancestor(of: longTitle, matching: find.byType(RdCard)).first;
        final pill = find.descendant(
          of: longCard,
          matching: find.byType(RdPill),
        );
        expect(pill, findsOneWidget);
        expect(
          tester.getSize(longTitle).height,
          greaterThan(tester.getSize(shortTitle).height),
          reason: 'The fixture must exercise a naturally wrapped title.',
        );
        expect(
          tester.getRect(pill).top,
          closeTo(tester.getRect(longTitle).top, 0.01),
          reason:
              'The chip belongs beside the first line, not in the middle of the title block.',
        );
        expect(tester.getRect(shortTitle).left, tester.getRect(longTitle).left);
        final shortDate = find.descendant(
          of: shortCard,
          matching: find.byType(RdEventDateBox),
        );
        final longDate = find.descendant(
          of: longCard,
          matching: find.byType(RdEventDateBox),
        );
        expect(tester.getRect(shortDate).left, tester.getRect(longDate).left);
        expect(
          tester.getRect(shortDate).center.dy,
          closeTo(tester.getRect(shortCard).center.dy, 0.5),
          reason: 'The date box is vertically centered in the Termin card.',
        );
        expect(
          tester.getRect(longDate).center.dy,
          closeTo(tester.getRect(longCard).center.dy, 0.5),
          reason:
              'The date box stays vertically centered when the title wraps.',
        );
        expect(
          tester.getRect(pill).right,
          lessThanOrEqualTo(tester.getRect(longCard).right),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.6, 2.0]) {
    testWidgets('answer labels stay readable in a narrow card at ${scale}x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        betaEventAlignmentFixture(
          textScale: scale,
          counts: const {
            71: RdStatusCounts(
              present: 0,
              excused: 111,
              lateAnnounced: 22,
              absent: 333,
              open: 44,
            ),
          },
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final counters = find.byType(RdStatusCounters);
      expect(counters, findsOneWidget);
      for (final label in [
        'zugesagt',
        'entschuldigt',
        'später',
        'abwesend',
        'offen',
      ]) {
        expect(
          find.descendant(
            of: counters,
            matching: find.textContaining(label, findRichText: true),
          ),
          findsOneWidget,
        );
      }
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        expect(
          tester.getSemantics(counters).label,
          contains(
            '0 zugesagt · 111 entschuldigt · 22 später · 333 abwesend · 44 offen',
          ),
        );
      } finally {
        semantics.dispose();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
