// AUDIT_R4: screenshot audit round 4 (Ionic vs Flutter), shared widgets.
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_accordion.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home, TargetPlatform platform) => MaterialApp(
      theme: AppTheme.forPlatform(Brightness.light, platform)
          .copyWith(platform: platform),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget _menuHost() => Scaffold(
      appBar: AppBar(actions: [
        Builder(
          builder: (bc) => IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showAppPopoverMenu<String>(
              context: bc,
              items: [
                AppPopoverMenuItem(
                  value: 'filter',
                  label: 'Status-Filter',
                  icon: Icons.filter_list,
                  submenuItems: () => [
                    for (final s in ['Anwesend', 'Abwesend'])
                      AppPopoverSubItem(label: s, checked: false, onTap: () {}),
                  ],
                ),
                const AppPopoverMenuItem(value: 'view', label: 'Ansicht'),
                const AppPopoverMenuItem(value: 'overview', label: 'Übersicht'),
                const AppPopoverMenuItem(value: 'legend', label: 'Legende'),
              ],
            ),
          ),
        ),
      ]),
    );

void main() {
  for (final (platform, alpha) in [
    (TargetPlatform.android, 0.32),
    (TargetPlatform.iOS, 0.0),
  ]) {
    testWidgets('popover backdrop: md dims the page, iOS not ($platform)',
        (tester) async {
      await tester.pumpWidget(_app(_menuHost(), platform));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      final colors = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((b) => b.color)
          .whereType<Color>()
          .where((c) => c.a > 0)
          .toList();
      if (alpha == 0) {
        expect(colors, isEmpty);
      } else {
        expect(colors.single.a, closeTo(alpha, 0.001));
      }
    });
  }

  testWidgets('iOS attendance accordion clips to round corners', (tester) async {
    await tester.pumpWidget(_app(
      const Scaffold(
        body: AttendanceAccordion(
          clipBehavior: Clip.none,
          title: Text('Ablaufplan'),
          children: [ListTile(title: Text('Punkt'))],
        ),
      ),
      TargetPlatform.iOS,
    ));
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.clipBehavior, Clip.antiAlias);
    expect((card.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(IonIos.groupRadius));
  });

  testWidgets('iOS large title: 36.125pt, top 2 / bottom 7', (tester) async {
    await tester.pumpWidget(_app(
      const Scaffold(body: IonLargeTitle('Termine')),
      TargetPlatform.iOS,
    ));
    final padding = tester.widget<Padding>(find
        .ancestor(of: find.text('Termine'), matching: find.byType(Padding))
        .first);
    expect(padding.padding, const EdgeInsets.fromLTRB(16, 2, 16, 7));
    expect(tester.widget<Text>(find.text('Termine')).style!.fontSize,
        closeTo(36.125, 0.001));
  });
}
