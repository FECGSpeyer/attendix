// Ionic 4.17.14: Termine the person is not invited to ("Alle Termine für
// Mitglieder sichtbar") are grey, dashed and carry a "Nicht eingeladen" pill
// on the current card and in the upcoming list of the self-service overview.
import 'dart:io';

import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart';
import 'package:attendix/shared/widgets/layout/dashed_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Column(children: [child])));

bool _hasDashed(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((p) => p.foregroundPainter is DashedRRectPainter);

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  testWidgets('pill shows eye icon and "Nicht eingeladen"', (tester) async {
    await tester.pumpWidget(_wrap(const EventNotInvitedPill()));
    expect(find.text('Nicht eingeladen'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('EventRow notInvited: grey background, dashed tile, grey title', (tester) async {
    await tester.pumpWidget(_wrap(const EventRow(
      date: '2026-11-03T18:00:00',
      title: 'Probe',
      notInvited: true,
      trailing: [EventNotInvitedPill()],
    )));
    expect(_hasDashed(tester), isTrue);
    expect(find.byType(ColoredBox), findsWidgets);
    final title = tester.widget<Text>(find.text('Probe'));
    expect(title.style?.color, const Color(0xFF808289));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('EventRow of an own Termin has no dashed tile', (tester) async {
    await tester.pumpWidget(_wrap(const EventRow(date: '2026-11-03T18:00:00', title: 'Probe')));
    expect(_hasDashed(tester), isFalse);
  });

  testWidgets('EventTodayCard notInvited: dashed card and tile, no primary border', (tester) async {
    await tester.pumpWidget(_wrap(const EventTodayCard(
      date: '2026-11-03T18:00:00',
      title: 'Konzert',
      bordered: true,
      notInvited: true,
      status: EventNotInvitedPill(),
    )));
    final dashed = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.foregroundPainter is DashedRRectPainter)
        .toList();
    expect(dashed, hasLength(2)); // card + date tile
    final shape = tester.widget<Card>(find.byType(Card)).shape! as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
    expect(find.text('Nicht eingeladen'), findsOneWidget);
  });

  test('signout page uses the not-invited look on current card and upcoming list', () {
    final src = File('lib/features/self_service/presentation/pages/signout_page.dart').readAsStringSync();
    expect(src, contains('const EventNotInvitedPill()'));
    expect('notInvited: '.allMatches(src).length, 2);
  });
}
