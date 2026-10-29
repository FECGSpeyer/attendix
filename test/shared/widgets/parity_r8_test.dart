// PARITY_R8: screenshot audit round 6 (iPhone, 393pt) – nested popover of
// the attendance detail ⋮ menu.
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/status_chip.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_status_overview_sheet.dart';
import 'package:attendix/features/planning/presentation/widgets/ion_items.dart'
    as planning;
import 'package:attendix/features/profile/presentation/widgets/profile_hero_card.dart'
    show kMdHeroCardGap;
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/display/ion_badge_text.dart';
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

/// The attendance detail ⋮ menu (Status-Filter and Ansicht open nested
/// popovers).
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
                    for (final s in ['Anwesend', 'Abwesend', 'Entschuldigt'])
                      AppPopoverSubItem(label: s, checked: false, onTap: () {}),
                  ],
                ),
                AppPopoverMenuItem(
                  value: 'view',
                  label: 'Ansicht',
                  icon: Icons.visibility_outlined,
                  submenuItems: () => [
                    AppPopoverSubItem(
                        label: 'Bilder anzeigen', checked: true, onTap: () {}),
                  ],
                ),
                const AppPopoverMenuItem(
                    value: 'add', label: 'Person hinzufügen', icon: Icons.add),
                const AppPopoverMenuItem(
                    value: 'overview',
                    label: 'Übersicht',
                    icon: Icons.bar_chart),
                const AppPopoverMenuItem(
                    value: 'legend', label: 'Legende', icon: Icons.info_outline),
              ],
            ),
          ),
        ),
      ]),
    );

Finder _glassOf(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(IosGlassSurface))
    .first;

void main() {
  const safeTop = 47.0;

  Future<Rect> openMenu(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: safeTop);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_menuHost(), TargetPlatform.iOS));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    return tester.getRect(_glassOf('Status-Filter'));
  }

  for (final trigger in ['Status-Filter', 'Ansicht']) {
    testWidgets('iOS nested popover ($trigger): top right, parent readable',
        (tester) async {
      final parent = await openMenu(tester);
      await tester.tap(find.text(trigger));
      await tester.pumpAndSettle();

      final subLabel = trigger == 'Status-Filter' ? 'Anwesend' : 'Bilder anzeigen';
      final sub = tester.getRect(_glassOf(subLabel));
      // Ionic iPhone: 200 wide, right-aligned with the parent menu, at the
      // top of the screen below the safe area.
      expect(sub.width, 200);
      expect(sub.right, closeTo(parent.right, 0.5));
      expect(sub.top, closeTo(safeTop + kIosNestedPopoverTop, 0.5));
      expect(sub.top, lessThan(parent.top));

      // The parent keeps its place and size; Übersicht and Legende stay
      // visible (hit-testable) below the nested popover.
      for (final label in ['Übersicht', 'Legende']) {
        expect(tester.getRect(find.text(label)).top, greaterThan(sub.bottom));
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      final parentNow = tester.getRect(find
          .ancestor(of: find.text('Legende'), matching: find.byType(CustomPaint))
          .first);
      expect(parentNow, parent);

      // No glass / backdrop blur behind the parent labels while the nested
      // popover is open (no smear); the nested popover keeps the ios27
      // glass (radius 34).
      expect(
        find.ancestor(of: find.text('Legende'), matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      final box = tester.widget<DecoratedBox>(find
          .ancestor(of: find.text('Legende'), matching: find.byType(DecoratedBox))
          .first);
      expect((box.decoration as BoxDecoration).color, Colors.white);
      final glass = tester.widget<IosGlassSurface>(_glassOf(subLabel));
      expect(glass.borderRadius, const BorderRadius.all(Radius.circular(34)));
    });
  }

  testWidgets('iOS parent menu is glass again without a nested popover',
      (tester) async {
    await openMenu(tester);
    expect(
      find.ancestor(of: find.text('Legende'), matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
  });

  // ---------------------------------------------------------------- badges

  TextStyle badgeStyle(WidgetTester tester, Type badge) => tester
      .widget<RichText>(find.descendant(
          of: find.byType(badge), matching: find.byType(RichText)))
      .text
      .style!;

  Widget badges() => const Scaffold(
        body: Column(children: [
          AttendanceStatusBadge(status: AttendanceStatus.present),
          StatusCountBadge(count: 5, color: AppColors.success),
          planning.IonBadge(label: '19:00 Uhr', color: AppColors.primary),
        ]),
      );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('badge labels render bold 700 ($platform)', (tester) async {
      await tester.pumpWidget(_app(badges(), platform));
      for (final t in [
        AttendanceStatusBadge,
        StatusCountBadge,
        planning.IonBadge,
      ]) {
        final style = badgeStyle(tester, t);
        expect(style.fontWeight, FontWeight.w700, reason: '$t');
        // native: the system font (real bold); no web badge font
        expect(style.fontFamily, isNot(kIonBadgeFontFamily), reason: '$t');
      }
    });
  }

  testWidgets('web: badge labels use the bundled real-bold font',
      (tester) async {
    debugIonBadgeUseWebFont = true;
    addTearDown(() => debugIonBadgeUseWebFont = null);
    await tester.pumpWidget(_app(badges(), TargetPlatform.iOS));
    for (final t in [AttendanceStatusBadge, StatusCountBadge, planning.IonBadge]) {
      final style = badgeStyle(tester, t);
      expect(style.fontFamily, kIonBadgeFontFamily, reason: '$t');
      expect(style.fontWeight, FontWeight.w700, reason: '$t');
    }
  });

  test('IonBadge font is bundled (weight 700)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: $kIonBadgeFontFamily'));
    expect(pubspec, contains('asset: assets/fonts/IonBadge-Bold.ttf'));
    expect(File('assets/fonts/IonBadge-Bold.ttf').existsSync(), isTrue);
    // non-bold text never switches to the bold-only font
    debugIonBadgeUseWebFont = true;
    addTearDown(() => debugIonBadgeUseWebFont = null);
    expect(ionBadgeFont(const TextStyle(fontSize: 13)).fontFamily, isNull);
  });

  // ------------------------------------------------------------ Mehr (md)

  testWidgets('md settings list header: 14.4px semibold, 19.2 icon',
      (tester) async {
    await tester.pumpWidget(_app(
      const Scaffold(
        body: SettingsListSection(
          title: 'Werke & Proben',
          icon: Icons.music_note_outlined,
          children: [SizedBox(height: 44)],
        ),
      ),
      TargetPlatform.android,
    ));
    final style = tester.widget<Text>(find.text('Werke & Proben')).style!;
    expect(style.fontSize, 14.4);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.height, isNull);
    expect(tester.widget<Icon>(find.byIcon(Icons.music_note_outlined)).size,
        19.2);
  });

  test('md hero card gap: 8 margin + 16 inset list margin', () {
    expect(kMdHeroCardGap, 24);
  });
}
