// MD_SWEEP: Ionic md mode (desktop / Android) metrics – @ionic/core 9.0.10
// *.md.css, src/theme/variables.scss and the md-ion-list-inset part of
// @rdlabo/ionic-theme-ios27 – against the Flutter md theme and the shared
// md widgets. iOS stays untouched (spot checks at the end).

import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/utils/toast_helper.dart';
import 'package:attendix/features/planning/presentation/widgets/ion_items.dart'
    as planning;
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart'
    as settings;
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/adaptive/ion_toolbar_segment.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:attendix/shared/widgets/layout/ionic_md.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _md([Brightness b = Brightness.light]) =>
    AppTheme.forPlatform(b, TargetPlatform.android, web: false);

ThemeData _ios([Brightness b = Brightness.light]) =>
    AppTheme.forPlatform(b, TargetPlatform.iOS, web: false)
        .copyWith(platform: TargetPlatform.iOS);

Widget _app(Widget home, {Brightness b = Brightness.light}) => MaterialApp(
      theme: _md(b),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  group('md theme', () {
    test('colours: text #000, page #f4f5f8 / dark #222428, md lines', () {
      final light = _md();
      final dark = _md(Brightness.dark);
      expect(light.colorScheme.onSurface, Colors.black);
      expect(light.scaffoldBackgroundColor, const Color(0xFFF4F5F8));
      // ion-content color="light" in md dark = --ion-color-light #222428
      expect(dark.scaffoldBackgroundColor, const Color(0xFF222428));
      expect(dark.colorScheme.surface, const Color(0xFF1E1E1E));
      expect(light.dividerTheme.color, const Color(0x21000000));
      expect(dark.dividerTheme.color, const Color(0xFF222222));
      expect(light.dividerTheme.thickness, 1);
    });

    test('ion-item: 48 min height, 16 padding, label 16 / p 14 #666', () {
      final t = _md().listTileTheme;
      expect(t.minTileHeight, 48);
      expect(t.contentPadding, const EdgeInsets.symmetric(horizontal: 16));
      expect(t.minVerticalPadding, 10);
      // 40px leading slot + 16 gap = label at 72 (16 + 24 icon + 32)
      expect(t.minLeadingWidth, 40);
      expect(t.horizontalTitleGap, 16);
      expect(t.titleTextStyle?.fontSize, 16);
      expect(t.titleTextStyle?.color, Colors.black);
      expect(t.subtitleTextStyle?.fontSize, 14);
      expect(t.subtitleTextStyle?.color, const Color(0xFF666666));
      expect(_md(Brightness.dark).listTileTheme.subtitleTextStyle?.color,
          const Color(0xFFA0A0A0));
      expect(t.iconColor, Colors.black.withValues(alpha: 0.54));
    });

    testWidgets('one-line ListTile is 48 high', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
          body: Column(children: [ListTile(title: Text('Eintrag'))]))));
      expect(tester.getSize(find.byType(ListTile)).height, 48);
    });

    test('ion-toolbar / ion-title: 20px medium #424242, .0125em', () {
      final a = _md().appBarTheme;
      expect(a.titleTextStyle?.fontSize, 20);
      expect(a.titleTextStyle?.fontWeight, FontWeight.w500);
      expect(a.titleTextStyle?.color, const Color(0xFF424242));
      expect(a.titleTextStyle?.letterSpacing, 0.25);
      expect(_md(Brightness.dark).appBarTheme.titleTextStyle?.color,
          Colors.white);
      expect(a.titleSpacing, 20);
      expect(a.centerTitle, isFalse);
      expect(a.elevation, 4);
      expect(a.actionsIconTheme?.size, 25.2);
      expect(a.actionsPadding, const EdgeInsets.only(right: 4));
    });

    test('ion-card: radius 4, margin 10, elevation 2', () {
      final c = _md().cardTheme;
      expect(c.elevation, 2);
      expect(c.margin, const EdgeInsets.all(10));
      expect((c.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(4));
    });

    test('ion-button: 36 high, radius 4, 14px medium, .06em, 8 / 1.1em', () {
      final e = _md().elevatedButtonTheme.style!;
      expect(e.minimumSize?.resolve({}), const Size(64, 36));
      expect(e.padding?.resolve({}),
          const EdgeInsets.symmetric(horizontal: 15.4, vertical: 8));
      expect(e.elevation?.resolve({}), 2);
      final text = e.textStyle?.resolve({});
      expect(text?.fontSize, 14);
      expect(text?.fontWeight, FontWeight.w500);
      expect(text?.letterSpacing, 0.84);
      expect(
          (e.shape?.resolve({})! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(4));
      final o = _md().outlinedButtonTheme.style!;
      expect(o.side?.resolve({})?.width, 2);
      final tb = _md().textButtonTheme.style!;
      expect(tb.minimumSize?.resolve({}), const Size(64, 36));
      // clear button hover: primary at .04
      expect(tb.overlayColor?.resolve({WidgetState.hovered}),
          AppColors.primary.withValues(alpha: 0.04));
    });

    test('ion-fab-button: primary, elevation 6', () {
      final f = _md().floatingActionButtonTheme;
      expect(f.backgroundColor, AppColors.primary);
      expect(f.elevation, 6);
      expect(f.highlightElevation, 12);
    });

    test('ion-tab-bar: 56 high, 22px icons, 12px labels, step-650', () {
      final n = _md().navigationBarTheme;
      expect(n.height, 56);
      expect(n.iconTheme?.resolve({})?.size, 22);
      expect(n.iconTheme?.resolve({})?.color, const Color(0xFF595959));
      expect(n.labelTextStyle?.resolve({})?.fontSize, 12);
      expect(n.labelTextStyle?.resolve({})?.letterSpacing, 0.36);
      expect(IonMd.tabBarBorder(Brightness.light), const Color(0x12000000));
    });

    test('ion-chip: rgba(text, .12), radius 16, 14px .87', () {
      final c = _md().chipTheme;
      expect(c.backgroundColor, Colors.black.withValues(alpha: 0.12));
      expect(c.labelStyle?.fontSize, 14);
      expect(c.labelStyle?.color, Colors.black.withValues(alpha: 0.87));
      expect((c.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
    });

    test('ion-toggle / checkbox / radio colours', () {
      final t = _md();
      expect(t.switchTheme.trackColor?.resolve({WidgetState.selected}),
          AppColors.primary.withValues(alpha: 0.5));
      expect(t.switchTheme.thumbColor?.resolve({WidgetState.selected}),
          AppColors.primary);
      expect(t.switchTheme.trackColor?.resolve({}),
          Colors.black.withValues(alpha: 0.39));
      expect(
          WidgetStateProperty.resolveAs<BorderSide?>(t.checkboxTheme.side, {})
              ?.width,
          2);
      expect((t.checkboxTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(2.25));
      expect(t.radioTheme.fillColor?.resolve({}),
          Colors.black.withValues(alpha: 0.6));
    });

    test('overlays: alert radius 4, #fff / #121212, backdrop .32', () {
      expect(_md().dialogTheme.backgroundColor, Colors.white);
      expect(_md(Brightness.dark).dialogTheme.backgroundColor,
          const Color(0xFF121212));
      expect((_md().dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(4));
      expect(_md().dialogTheme.barrierColor, const Color(0x52000000));
      expect(_md().bottomSheetTheme.modalBarrierColor, const Color(0x52000000));
      expect(_md().popupMenuTheme.elevation, 8);
      expect(_md().snackBarTheme.backgroundColor, const Color(0xFF333333));
    });
  });

  group('md shared widgets', () {
    testWidgets('IonMdSearchbar: 42 high, white, radius 2, no border',
        (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(Scaffold(
          body: IonSearchbar(
              controller: c, hintText: 'Suchen', onChanged: (_) {}))));
      expect(find.byType(IonMdSearchbar), findsOneWidget);
      final box = tester.widget<Container>(find.descendant(
          of: find.byType(IonMdSearchbar), matching: find.byType(Container)));
      final d = box.decoration! as BoxDecoration;
      expect(d.color, Colors.white);
      expect(d.borderRadius, BorderRadius.circular(2));
      expect(d.border, isNull);
      expect(d.boxShadow, IonMd.elevation2);
      expect(
          tester
              .getSize(find.descendant(
                  of: find.byType(IonMdSearchbar),
                  matching: find.byType(Container)))
              .height,
          42);
      final hint = tester.widget<TextField>(find.byType(TextField));
      expect(hint.decoration?.hintStyle?.color,
          const Color(0xFF262626).withValues(alpha: 0.6));
    });

    testWidgets('feature searchbar copies use the md searchbar',
        (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(Scaffold(
          body: Column(children: [
        settings.IonSearchbar(controller: c, hint: 'A', onChanged: (_) {}),
        planning.IonSearchbar(placeholder: 'B', onChanged: (_) {}),
      ]))));
      expect(find.byType(IonMdSearchbar), findsNWidgets(2));
    });

    testWidgets('inset list header: 16px semibold medium-tint, 36px in',
        (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
          body: Column(children: [IonListHeader('Allgemein')]))));
      final text = tester.widget<Text>(find.text('Allgemein'));
      expect(text.style?.fontSize, 16);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.color, const Color(0xFF737478));
      expect(tester.getTopLeft(find.text('Allgemein')).dx, 36);
      expect(tester.getSize(find.byType(IonListHeader)).height,
          greaterThanOrEqualTo(45));
    });

    testWidgets('inset list radius: groups 16, plain 2', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      expect(IonInsetList.radiusOf(ctx), 16);
      expect(IonInsetList.radiusOf(ctx, grouped: false), 2);
    });

    testWidgets('ion-segment in a toolbar: 56px row', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      expect(IonToolbarSegment.toolbarHeight(ctx), 56);
    });

    testWidgets('settings badge: padding 3 4 4 4, radius 4', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
          body: Center(child: settings.IonBadge(text: '3')))));
      final box = tester.widget<Container>(find.descendant(
          of: find.byType(settings.IonBadge),
          matching: find.byType(Container)));
      expect(box.padding, IonMd.badgePadding);
      expect((box.decoration! as BoxDecoration).borderRadius,
          BorderRadius.circular(4));
    });

    testWidgets('item note: 11px step-600', (tester) async {
      await tester.pumpWidget(
          _app(const Scaffold(body: settings.IonNote('Nicht verknüpft'))));
      final t = tester.widget<Text>(find.text('Nicht verknüpft'));
      expect(t.style?.fontSize, 11);
      expect(t.style?.color, const Color(0xFF666666));
    });

    testWidgets('action sheet: white, 52px buttons, no red destructive',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: Builder(
        builder: (c) => TextButton(
          onPressed: () => showAppActionSheet<int>(c,
              title: 'Aktion',
              actions: const [
                AppActionSheetAction(label: 'Löschen', value: 1,
                    destructive: true),
              ]),
          child: const Text('open'),
        ),
      ))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final label = tester.widget<Text>(find.text('Löschen'));
      expect(label.style?.color, const Color(0xFF262626));
      final row = find.ancestor(
          of: find.text('Löschen'), matching: find.byType(InkWell)).first;
      expect(tester.getSize(row).height, 52);
      final title = tester.widget<Text>(find.text('Aktion'));
      expect(title.style?.color, Colors.black.withValues(alpha: 0.54));
    });

    testWidgets('toast: Ionic md toast at the top in the Ionic colour',
        (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: Builder(
        builder: (c) => TextButton(
          onPressed: () => ToastHelper.showSuccess(c, 'Gespeichert'),
          child: const Text('go'),
        ),
      ))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(IonMdToast), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.getTopLeft(find.text('Gespeichert')).dy, 8 + 14);
      final m = tester.widget<Material>(find.descendant(
          of: find.byType(IonMdToast), matching: find.byType(Material)));
      expect(m.color, AppColors.success);
      expect(m.borderRadius, BorderRadius.circular(4));
      expect(find.byIcon(Icons.check_circle), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(IonMdToast), findsNothing);
    });
  });

  group('iOS untouched', () {
    test('card / title / list tile keep the iOS values', () {
      final t = _ios();
      expect(t.cardTheme.elevation, 0);
      expect((t.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(12));
      expect(t.appBarTheme.titleSpacing, isNull);
      expect(t.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w600);
      expect(t.listTileTheme.minTileHeight, isNull);
      expect(t.dividerTheme.thickness, 0.5);
      expect(t.floatingActionButtonTheme.elevation, 0);
      expect(t.dialogTheme.barrierColor, isNull);
    });
  });
}
