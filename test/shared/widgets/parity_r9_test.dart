// PARITY_R9: visual audit (Ionic vs Flutter preview) – md flat inset
// groups on the attendance detail, shared searchbars, Werke header gap.

import 'dart:io';

import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_accordion.dart';
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart'
    as settings;
import 'package:attendix/features/songs/presentation/pages/songs_list_page.dart'
    show kIosSongsHeaderGap;
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart'
    show IonIos, IonSearchbarGlass;
import 'package:attendix/shared/widgets/layout/ionic_md.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, TargetPlatform platform) => MaterialApp(
      theme: AppTheme.forPlatform(Brightness.light, platform)
          .copyWith(platform: platform),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: body),
    );

void main() {
  group('attendance detail accordion', () {
    testWidgets('md: flat item-group (no shadow, radius 16), not an md card',
        (tester) async {
      await tester.pumpWidget(_app(
        const AttendanceAccordion(title: Text('Allgemein'), children: []),
        TargetPlatform.android,
      ));
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0);
      expect(card.shape, IonMd.insetGroupShape);
      final material = tester.widget<Material>(find
          .descendant(of: find.byType(Card), matching: find.byType(Material))
          .first);
      expect(material.elevation, 0);
    });

    testWidgets('iOS keeps the inset-group radius 28', (tester) async {
      await tester.pumpWidget(_app(
        const AttendanceAccordion(title: Text('Allgemein'), children: []),
        TargetPlatform.iOS,
      ));
      final card = tester.widget<Card>(find.byType(Card));
      expect(
        card.shape,
        const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(IonIos.groupRadius))),
      );
    });

    test('md section radius and the other item-groups of the page', () {
      final page = File(
              'lib/features/attendance/presentation/pages/attendance_detail_page.dart')
          .readAsStringSync();
      expect(page, contains('BorderRadius.circular(IonMd.groupRadius)'));
      for (final f in [
        'lib/features/duty/presentation/widgets/duty_staffing_section.dart',
        'lib/features/team_organization/presentation/widgets/attendance_protocol_section.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('shape: ios ? null : IonMd.insetGroupShape'),
            reason: f);
        expect(src, contains('elevation: ios ? null : 0'), reason: f);
      }
    });
  });

  group('searchbar', () {
    testWidgets('iOS: the settings-lane searchbar is the shared ios27 glass',
        (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        settings.IonSearchbar(controller: c, hint: 'Suchen', onChanged: (_) {}),
        TargetPlatform.iOS,
      ));
      expect(find.byType(IonSearchbarGlass), findsOneWidget);
    });

    testWidgets('md: white field with shadow, no outline', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        settings.IonSearchbar(
            controller: c,
            hint: 'Suchen',
            onChanged: (_) {},
            padding: IonMd.searchbarPadding),
        TargetPlatform.android,
      ));
      expect(find.byType(IonMdSearchbar), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.border, InputBorder.none);
      expect(field.decoration!.enabledBorder, InputBorder.none);
    });

    test('Dateien uses the shared searchbar on both platforms', () {
      final src =
          File('lib/features/settings/presentation/pages/files_page.dart')
              .readAsStringSync();
      final start = src.indexOf('Widget _buildSearch()');
      final end = src.indexOf('List<Widget> _buildList()');
      final search = src.substring(start, end);
      expect(search, contains('IonSearchbar('));
      expect(search, isNot(contains('TextField(')));
    });
  });

  test('Werke: iOS header gap without quick links like Ionic (≈60pt)', () {
    expect(kIosSongsHeaderGap, 35);
  });
}
