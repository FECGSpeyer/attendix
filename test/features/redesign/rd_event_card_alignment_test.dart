import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:attendix/features/redesign/presentation/widgets/today/rd_today_common.dart';
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
          tester.getRect(shortTitle).top - tester.getRect(shortDate).top,
          tester.getRect(longTitle).top - tester.getRect(longDate).top,
        );
        expect(
          tester.getRect(pill).right,
          lessThanOrEqualTo(tester.getRect(longCard).right),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
