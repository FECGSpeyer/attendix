// IOS27_SWEEP: key metrics of @rdlabo/ionic-theme-ios27 1.1.0 (with the
// Ionic core iOS styles underneath and the app's global.scss /
// variables.scss / tabs.page.scss overrides on top). On the iPhone Ionic
// uses `-apple-system-body` as root font, so 1rem = 17px.
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/adaptive/ion_toolbar_segment.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _light = Brightness.light;
const _dark = Brightness.dark;

Widget _ios(Widget child, {Brightness brightness = _light}) => MaterialApp(
      theme: AppTheme.forPlatform(brightness, TargetPlatform.iOS)
          .copyWith(platform: TargetPlatform.iOS),
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

BorderRadius _glassRadius(WidgetTester tester) => tester
    .widget<IosGlassSurface>(find.byType(IosGlassSurface).first)
    .borderRadius;

void main() {
  group('lists and items', () {
    test('inset list, items, header', () {
      expect(IonIos.rem, 17);
      expect(IonIos.insetMargin, 16);
      expect(IonIos.groupRadius, 28);
      expect(IonIos.listRadius, 10);
      expect(IonIos.itemMinHeight, 52);
      expect(IonIos.plainItemMinHeight, 44);
      expect(IonIos.itemPaddingEnd, 18);
      expect(IonIos.itemFontSize, 17);
      expect(IonIos.itemLineHeight, 1.29);
      expect(IonIos.listHeaderMinHeight, 40);
      expect(IonIos.listHeaderFontSize, 17);
      expect(IonIos.listHeaderStart, 36);
      expect(IonIos.noteFontSize, 17);
      expect(IonIos.h2FontSize, closeTo(18.06, 0.01));
      expect(IonIos.pFontSize, closeTo(14.875, 0.001));
      expect(IonIos.detailIconSize, closeTo(21.25, 0.001));
      expect(IonIos.largeTitleFontSize, closeTo(36.125, 0.001));
      expect(IonIos.largeTitle.fontWeight, FontWeight.w700);
      expect(IonIos.largeTitle.letterSpacing, isNull);
    });

    test('Ionic 9 colours (light / app dark)', () {
      expect(IonIos.medium(_light), const Color(0xFF636469));
      expect(IonIos.medium(_dark), const Color(0xFF989AA2));
      expect(IonIos.line(_light), const Color(0xFFE8E8E8));
      expect(IonIos.line(_dark), const Color(0xFF1A1A1A));
      expect(IonIos.note(_light), const Color(0xFFA6A6A6));
      expect(IonIos.note(_dark), const Color(0xFF595959));
      expect(IonIos.labelP(_light), const Color(0xFF999999));
      expect(IonIos.labelP(_dark), const Color(0xFF666666));
      expect(IonIos.listHeaderColor(_light).a, closeTo(0.75, 0.01));
      expect(IonIos.listHeaderColor(_dark).a, closeTo(0.93, 0.01));
      expect(IonIos.detailIconColor(_light).a, closeTo(0.38, 0.01));
      expect(IonIos.detailIconColor(_dark).a, closeTo(0.5, 0.01));
    });

    testWidgets('detail chevron is 21.25pt in rgba(medium, .38)',
        (tester) async {
      await tester.pumpWidget(_ios(const IonDetailChevron()));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, closeTo(21.25, 0.001));
      expect(icon.color, IonIos.detailIconColor(_light));
    });
  });

  group('controls', () {
    test('segment: 32pt, flat medium track, white / #5a5b60 pill', () {
      expect(IonSegment.height, 32);
      expect(IonSegment.iosFontSize, closeTo(13.77, 0.001));
      expect(IonSegment.iosTrack(_light).a, closeTo(0.11, 0.01));
      expect(IonSegment.iosTrack(_dark).a, closeTo(0.19, 0.01));
      expect(IonSegment.iosIndicator(_light), Colors.white);
      expect(IonSegment.iosIndicator(_dark), const Color(0xFF5A5B60));
      expect(IonSegment.iosDisabledOpacity(_light), 0.2);
      expect(IonSegment.iosDisabledOpacity(_dark), 0.15);
    });

    testWidgets('toolbar segment: 48pt track with radius 24', (tester) async {
      await tester.pumpWidget(_ios(IonToolbarSegment<int>(
        items: const [
          IonSegmentItem(value: 0, label: Text('Eins')),
          IonSegmentItem(value: 1, label: Text('Zwei')),
        ],
        value: 0,
        onChanged: (_) {},
      )));
      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      final track = decorations
          .where((d) => d.borderRadius == BorderRadius.circular(24))
          .toList();
      expect(track, hasLength(1));
      expect(track.single.color, IonSegment.iosTrack(_light));
      // the selected 44pt pill
      expect(
          decorations.where((d) =>
              d.color == IonSegment.iosIndicator(_light) &&
              d.borderRadius == BorderRadius.circular(22)),
          hasLength(1));
      final label = tester.widget<Text>(find.text('Eins'));
      expect(
          DefaultTextStyle.of(tester.element(find.text('Eins'))).style.fontSize ??
              label.style?.fontSize,
          closeTo(0.94 * 17, 0.01));
    });

    test('buttons, fab, chips, toolbar', () {
      final ios = AppTheme.forPlatform(_light, TargetPlatform.iOS);
      final shape = ios.elevatedButtonTheme.style!.shape!.resolve({})!
          as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
      expect(AppTheme.iosButtonMinHeight, closeTo(55.335, 0.001));
      expect(ios.elevatedButtonTheme.style!.textStyle!.resolve({})!.fontSize,
          closeTo(17.85, 0.001));
      expect(AppTheme.iosFabSize, 61);
      expect(ios.floatingActionButtonTheme.elevation, 0);
      expect(ios.chipTheme.shape, isA<RoundedRectangleBorder>());
      expect(
          (ios.chipTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
      expect(ios.appBarTheme.titleTextStyle!.fontSize, kIonTitleFontSize);
      expect(kIonTitleFontSize, 18.0625);
      expect(IonToolbarButtonMetrics.size, 44);
      expect(IonToolbarButtonMetrics.iconSize, closeTo(23.8, 0.001));
      expect(IonSearchbar.height, 44);
      expect(IonSearchbar.fontSize, closeTo(18.06, 0.01));
    });

    test('md look keeps its own values', () {
      final md = AppTheme.forPlatform(_light, TargetPlatform.android);
      // MD_SWEEP: chip.md.css is radius 16 as well; md differs in the
      // rgba(text, .12) fill instead.
      expect(md.chipTheme.backgroundColor,
          Colors.black.withValues(alpha: 0.12));
      expect(md.floatingActionButtonTheme.sizeConstraints?.minWidth,
          isNot(61));
    });
  });

  group('tab bar', () {
    test('62pt bar, radius 31, 27pt buttons, .59rem labels', () {
      expect(IosTabBar.barHeight, 62);
      expect(IosTabBar.barRadius, 31);
      expect(IosTabBar.buttonRadius, 27);
      expect(IosTabBar.labelFontSize, closeTo(10.03, 0.001));
      expect(IosTabBar.contentPadding, 60);
      expect(IosTabBar.unselectedColor(_light), const Color(0xFF0D0D0D));
      expect(IosTabBar.unselectedColor(_dark), Colors.white);
      expect(IosTabBar.background(_light).a, closeTo(0.53, 0.01));
      expect(IosGlass.selectedPill(_light).a, closeTo(0.095, 0.001));
      expect(IosGlass.selectedPill(_dark).a, closeTo(0.72, 0.001));
    });

    test('width by tab count (393pt iPhone)', () {
      double w(int n, [double screen = 393]) =>
          IosTabBar.barWidthFor(screenWidth: screen, tabCount: n);
      expect(w(2), 188);
      expect(w(4), 393 - 36 - 75 + 8);
      expect(w(5), 393 - 36 - 72 + 8);
      expect(w(4, 1024), 328 + 8);
      expect(w(3, 2000), 266 + 8);
    });
  });

  group('overlays', () {
    test('glass colours', () {
      expect(IosGlass.overlayOpacity(_light), 0.67);
      expect(IosGlass.overlayOpacity(_dark), 0.52);
      expect(IosGlass.overlayBorder(_light).a, closeTo(0.18, 0.01));
      expect(IosGlass.overlayButton(_light), const Color(0xFFCCCCCC));
      expect(IosGlass.overlayButton(_dark), const Color(0xFF333333));
      expect(IosGlass.destructive(_light), const Color(0xFFEA292D));
      expect(IosGlass.destructive(_dark), const Color(0xFFFF686B));
      expect(IosGlass.overlayShadow().single.blurRadius, 32);
      expect(IosGlass.overlayShadow().single.offset, const Offset(0, 12));
      expect(IosAlertButton.radiusFor(48), 24);
      expect(kIosPopoverRadius, 34);
    });

    test('theme dialog 36, popup menu 34', () {
      final ios = AppTheme.forPlatform(_light, TargetPlatform.iOS);
      expect(
          (ios.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(36));
      expect(
          (ios.popupMenuTheme.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(34));
    });

    testWidgets('action sheet: glass card radius 36, 48pt buttons',
        (tester) async {
      await tester.pumpWidget(_ios(Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppActionSheet<int>(
            context,
            title: 'Titel',
            showCancel: false,
            actions: const [AppActionSheetAction(label: 'Eins', value: 1)],
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_glassRadius(tester), BorderRadius.circular(36));
      expect(tester.getSize(find.ancestor(
              of: find.text('Eins'), matching: find.byType(ConstrainedBox))
          .first).height, greaterThanOrEqualTo(48));
    });

    testWidgets('popover glass: radius 34, .42 / .08 background',
        (tester) async {
      await tester.pumpWidget(_ios(IosGlassSurface.popover(
        brightness: _light,
        child: const SizedBox(width: 100, height: 40),
      )));
      final glass = tester.widget<IosGlassSurface>(find.byType(IosGlassSurface));
      expect(glass.borderRadius, BorderRadius.circular(34));
      expect(glass.opacity, 0.42);
      expect(glass.backdropBrightness, 1.35);
      expect(glass.overlay, isTrue);
    });
  });
}
