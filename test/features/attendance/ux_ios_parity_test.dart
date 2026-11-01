import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/status_chip.dart';
import 'package:attendix/features/attendance/presentation/widgets/ios_condense_header.dart';
import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_ATT wave 8: Ionic iOS look of the Termine tab and attendance detail.
void main() {
  Widget app(Widget child, {TargetPlatform platform = TargetPlatform.android}) => MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(body: child),
      );

  group('EventTodayFilledCard (ev-today--filled)', () {
    testWidgets('shows title, stat bubbles and both CTAs', (tester) async {
      var recorded = 0;
      await tester.pumpWidget(app(EventTodayFilledCard(
        date: '2026-10-28',
        title: 'Probe',
        meta: '19:00–21:00',
        place: 'Kirche',
        stats: const [EventTodayStat('80 %', strong: true), EventTodayStat('12 anwesend')],
        ctas: [
          EventTodayCta(label: 'Anwesenheit', icon: Icons.check_box_outlined, onTap: () => recorded++),
          EventTodayCta(label: 'Ablaufplan', icon: Icons.description_outlined, secondary: true, onTap: () {}),
        ],
      )));
      expect(find.text('Probe'), findsOneWidget);
      expect(find.text('80 %'), findsOneWidget);
      expect(find.text('12 anwesend'), findsOneWidget);
      expect(find.text('Kirche'), findsOneWidget);
      await tester.tap(find.text('Anwesenheit'));
      expect(recorded, 1);
      // Filled card: primary background
      final material = tester.widgetList<Material>(find.byType(Material))
          .where((m) => m.color == AppColors.primary);
      expect(material, isNotEmpty);
    });
  });

  group('EventDateTile (ev-tile)', () {
    testWidgets('upper-case weekday, highlighted tile is solid primary', (tester) async {
      await tester.pumpWidget(app(const EventDateTile(date: '2026-10-27', highlight: true)));
      expect(find.text('DI'), findsOneWidget);
      final box = tester.widget<Container>(
          find.descendant(of: find.byType(EventDateTile), matching: find.byType(Container)).first);
      expect((box.decoration as BoxDecoration).color, AppColors.primary);
    });
  });

  group('EventListCard', () {
    testWidgets('no inset line next to the summary row and the more link', (tester) async {
      await tester.pumpWidget(app(EventListCard(children: [
        const EventSummaryRow(label: 'Durchschnitt', pill: EventPill(label: '80%', color: AppColors.success)),
        const EventRow(date: '2026-10-01', title: 'A'),
        const EventRow(date: '2026-10-02', title: 'B'),
        EventMoreLink(label: 'Alle 5 anzeigen', onTap: () {}),
      ])));
      // only between the two rows
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('AttendanceStatusBadge (ion-badge)', () {
    testWidgets('black text on the warning (Entschuldigt) badge', (tester) async {
      await tester.pumpWidget(app(const AttendanceStatusBadge(status: AttendanceStatus.excused)));
      final text = tester.widget<Text>(find.text('E'));
      expect(text.style?.color, Colors.black);
    });
  });

  group('iOS helpers', () {
    testWidgets('IonFabButton is the 61 pt theme glass circle on iOS only', (tester) async {
      await tester.pumpWidget(app(IonFabButton(onPressed: () {}, icon: Icons.add),
          platform: TargetPlatform.iOS));
      expect(tester.getSize(find.byType(FloatingActionButton)), const Size(61, 61));

      await tester.pumpWidget(app(IonFabButton(onPressed: () {}, icon: Icons.add)));
      await tester.pumpAndSettle(); // MaterialApp animates the theme change
      expect(tester.getSize(find.byType(FloatingActionButton)), const Size(56, 56));
    });

    testWidgets('large title hides the toolbar title until scrolled', (tester) async {
      final condense = CondenseHeaderController();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          appBar: AppBar(title: condense.toolbarTitle(enabled: true, title: const Text('Termine'))),
          body: condense.listen(
            child: ListView(children: [
              const IosLargeTitle('Termine'),
              for (var i = 0; i < 40; i++) SizedBox(height: 50, child: Text('row $i')),
            ]),
          ),
        ),
      ));
      double opacity() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(opacity(), 0);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      condense.dispose();
    });
  });

  group('Termine tab source', () {
    final src = File('lib/features/attendance/presentation/pages/attendance_list_page.dart').readAsStringSync();

    test('no Flutter-only calendar header button', () {
      expect(src.contains('_showCalendarView'), isFalse);
      expect(src.contains('Icons.calendar_today'), isFalse);
    });

    test('Durchschnitt row lives inside the past list (Ionic ev-summary)', () {
      expect(src.contains('EventSummaryRow('), isTrue);
      expect(src.contains('context.l10n.attListAverage'), isTrue);
    });

    test('today card is the filled variant', () {
      expect(src.contains('EventTodayFilledCard('), isTrue);
    });
  });
}
