import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// IOS_LOOK: adaptive helpers render Ionic iOS mode on iOS and keep the
/// Material widgets elsewhere, with unchanged return values.
void main() {
  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: home),
      );

  group('AppAlertDialog', () {
    testWidgets('iOS: frosted card, two pill buttons side by side',
        (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showAppDialog<bool>(
        context: ctx,
        builder: (c) => AppAlertDialog(
          title: const Text('Löschen?'),
          content: const Text('Wirklich?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Nein')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Weg'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(IosAlertCard), findsOneWidget);
      expect(find.byType(IosAlertButton), findsNWidgets(2));
      final buttons = tester
          .widgetList<IosAlertButton>(find.byType(IosAlertButton))
          .toList();
      expect(buttons[0].destructive, isFalse);
      expect(buttons[1].destructive, isTrue);
      // (the test font is wide: labels must be short to fit half the card)
      // PARITY_R3: two buttons side by side (Ionic iOS alert-button-group)
      expect(tester.getCenter(find.text('Nein')).dy,
          tester.getCenter(find.text('Weg')).dy);
      expect(tester.getCenter(find.text('Nein')).dx,
          lessThan(tester.getCenter(find.text('Weg')).dx));
      await tester.tap(find.text('Weg'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: two long labels wrap onto two lines', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      showAppDialog<void>(
        context: ctx,
        builder: (c) => AppAlertDialog(
          title: const Text('T'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Abbrechen')),
            TextButton(onPressed: () {}, child: const Text('Herunterladen')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Abbrechen')).dy,
          lessThan(tester.getTopLeft(find.text('Herunterladen')).dy));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS: three buttons are stacked', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      showAppDialog<void>(
        context: ctx,
        builder: (c) => AppAlertDialog(
          title: const Text('T'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Eins')),
            TextButton(onPressed: () {}, child: const Text('Zwei')),
            TextButton(onPressed: () {}, child: const Text('Drei')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Eins')).dy,
          lessThan(tester.getTopLeft(find.text('Zwei')).dy));
      expect(tester.getTopLeft(find.text('Zwei')).dy,
          lessThan(tester.getTopLeft(find.text('Drei')).dy));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('md: uppercase text buttons, right-aligned; 3+ stacked',
        (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      showAppDialog<void>(
        context: ctx,
        builder: (c) => AppAlertDialog(
          title: const Text('T'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Abbrechen')),
            ElevatedButton(onPressed: () {}, child: const Text('Ändern')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABBRECHEN'), findsOneWidget);
      expect(find.text('ÄNDERN'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.getCenter(find.text('ABBRECHEN')).dy,
          tester.getCenter(find.text('ÄNDERN')).dy);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      showAppDialog<void>(
        context: ctx,
        builder: (c) => AppAlertDialog(
          title: const Text('T'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Eins')),
            TextButton(onPressed: () {}, child: const Text('Zwei')),
            TextButton(onPressed: () {}, child: const Text('Drei')),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('EINS')).dy,
          lessThan(tester.getTopLeft(find.text('ZWEI')).dy));
      // right-aligned labels
      expect(tester.getTopRight(find.text('EINS')).dx,
          moreOrLessEquals(tester.getTopRight(find.text('DREI')).dx,
              epsilon: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Android: plain Material AlertDialog', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      showAppDialog<void>(
        context: ctx,
        builder: (c) => const AppAlertDialog(title: Text('Titel')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(IosAlertCard), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS: text fields in the content keep working',
        (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showAppPrompt(ctx, title: 'Name', initialValue: 'A');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Neu');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, 'Neu');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('showAppActionSheet', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('returns the tapped value on $platform', (tester) async {
        await tester.pumpWidget(app(const SizedBox()));
        final ctx = tester.element(find.byType(Scaffold));
        final result = showAppActionSheet<String>(
          ctx,
          title: 'Datei',
          actions: const [
            AppActionSheetAction(value: 'open', label: 'Öffnen'),
            AppActionSheetAction(
                value: 'delete', label: 'Löschen', destructive: true),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.text('Abbrechen'), findsOneWidget);
        await tester.tap(find.text('Löschen'));
        await tester.pumpAndSettle();
        expect(await result, 'delete');
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets('cancel returns null (iOS)', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showAppActionSheet<String>(
        ctx,
        actions: const [AppActionSheetAction(value: 'a', label: 'A')],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('AppSpinner: iOS activity indicator, Material elsewhere',
      (tester) async {
    await tester.pumpWidget(app(const Center(child: AppSpinner())));
    final ios = debugDefaultTargetPlatformOverride == TargetPlatform.iOS;
    expect(find.byType(CupertinoActivityIndicator),
        ios ? findsOneWidget : findsNothing);
    expect(find.byType(CircularProgressIndicator),
        ios ? findsNothing : findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('AppSegmentedButton: ion-segment on iOS, same callback',
      (tester) async {
    Set<int>? changed;
    await tester.pumpWidget(app(AppSegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 1, label: Text('Eins')),
        ButtonSegment(value: 2, label: Text('Zwei')),
      ],
      selected: const {1},
      onSelectionChanged: (s) => changed = s,
    )));
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(IonSegment<int>), findsOneWidget);
    await tester.tap(find.text('Zwei'));
    expect(changed, {2});
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('IosTabBar: tap selects the tab', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: IosTabBar(
          selectedIndex: 0,
          onSelected: (i) => tapped = i,
          items: const [
            IosTabBarItem(icon: Icons.people_outline, label: 'Personen'),
            IosTabBarItem(icon: Icons.more_horiz, label: 'Mehr'),
          ],
        ),
      ),
    ));
    await tester.tap(find.text('Mehr'));
    expect(tapped, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('AppTheme iOS: 24pt button radius, round checkboxes, Ionic colours', () {
    final ios = AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS);
    final md = AppTheme.forPlatform(Brightness.light, TargetPlatform.android);
    // IOS27_SWEEP: ionic-theme-ios27 `ion-button { --border-radius: 24px }`
    expect(
        (ios.filledButtonTheme.style!.shape!.resolve({})!
                as RoundedRectangleBorder)
            .borderRadius,
        BorderRadius.circular(AppTheme.iosButtonRadius));
    expect(md.filledButtonTheme.style!.shape!.resolve({}),
        isA<RoundedRectangleBorder>());
    expect(ios.checkboxTheme.shape, isA<CircleBorder>());
    expect(ios.scaffoldBackgroundColor, const Color(0xFFF4F5F8));
    final iosDark = AppTheme.forPlatform(Brightness.dark, TargetPlatform.iOS);
    // IOS_R4: grouped page = ion-content color="light" in dark (#222428);
    // plain pages set black themselves, cards stay #1c1c1d.
    expect(iosDark.scaffoldBackgroundColor, const Color(0xFF222428));
    expect(iosDark.colorScheme.surface, const Color(0xFF1C1C1D));
    // md dark = Ionic md dark (#121212 page, #1e1e1e items).
    final mdDark = AppTheme.forPlatform(Brightness.dark, TargetPlatform.android);
    expect(mdDark.scaffoldBackgroundColor, const Color(0xFF121212));
    expect(mdDark.colorScheme.surface, const Color(0xFF1E1E1E));
  });
}
