import 'dart:io';

import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_accordion.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/dialogs/ion_modal.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PARITY_R3: Ionic md/desktop parity of shared widgets.
void main() {
  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => IonModalTheme(child: child!),
        home: Scaffold(body: home),
      );

  // BottomSheet spans the width; its Material is the constrained sheet.
  Finder sheetMaterial() => find
      .descendant(of: find.byType(BottomSheet), matching: find.byType(Material))
      .first;

  Future<Size> sheetSize(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Scaffold));
    showModalBottomSheet<void>(
      context: ctx,
      builder: (_) => const SizedBox(
          key: Key('sheet'), width: double.infinity, height: 100),
    );
    await tester.pumpAndSettle();
    return tester.getSize(sheetMaterial());
  }

  group('IonModalTheme (ion-modal sheet sizes)', () {
    testWidgets('desktop: 600 px wide sheet, 2 px radius (md)',
        (tester) async {
      await setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(app(const SizedBox()));
      final size = await sheetSize(tester);
      expect(size.width, 600);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      final theme = Theme.of(tester.element(find.byKey(const Key('sheet'))));
      expect(sheet.shape ?? theme.bottomSheetTheme.shape,
          const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(2))));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('tablet below 768: full width like Ionic (no 640 cap)',
        (tester) async {
      await setSize(tester, const Size(700, 1000));
      await tester.pumpWidget(app(const SizedBox()));
      final size = await sheetSize(tester);
      expect(size.width, 700);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('md action sheet is at most 500 wide', (tester) async {
      await setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(app(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      showAppActionSheet<int>(
        ctx,
        actions: const [AppActionSheetAction(value: 1, label: 'Eins')],
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(sheetMaterial()).width, 500);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  testWidgets('IonSegment forceMd: md tabs (UPPERCASE) on iOS too',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: IonSegment<String>(
          forceMd: true,
          value: 'a',
          onChanged: (_) {},
          items: const [
            IonSegmentItem(value: 'a', label: Text('Spieler')),
            IonSegmentItem(value: 'b', label: Text('Anwesenheit')),
          ],
        ),
      ),
    ));
    expect(find.text('SPIELER'), findsOneWidget);
    expect(find.text('ANWESENHEIT'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('md segment buttons are at most 360 wide, centred',
      (tester) async {
    await setSize(tester, const Size(1440, 900));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: IonSegment<String>(
          value: 'a',
          onChanged: (_) {},
          items: const [
            IonSegmentItem(value: 'a', label: Text('A')),
            IonSegmentItem(value: 'b', label: Text('B')),
          ],
        ),
      ),
    ));
    final a = tester.getCenter(find.text('A'));
    final b = tester.getCenter(find.text('B'));
    expect(b.dx - a.dx, 360);
    expect((a.dx + b.dx) / 2, 720);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('accordion uses the ionicon chevron-down ($platform)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AttendanceAccordion(
            title: Text('Allgemein'),
            children: [Text('Inhalt')],
          ),
        ),
      ));
      expect(find.byType(IonChevronDownIcon), findsOneWidget);
      final icon =
          tester.widget<IonChevronDownIcon>(find.byType(IonChevronDownIcon));
      expect(icon.size, platform == TargetPlatform.iOS ? 20 : 24);
      await tester.tap(find.text('Allgemein'));
      await tester.pumpAndSettle();
      expect(find.text('Inhalt'), findsOneWidget);
      expect(
          tester
              .widget<AnimatedRotation>(find.byType(AnimatedRotation))
              .turns,
          0.5);
    }, variant: TargetPlatformVariant.only(platform));
  }

  test('md dark page is #121212 (Ionic md dark)', () {
    expect(
      AppTheme.forPlatform(Brightness.dark, TargetPlatform.android)
          .scaffoldBackgroundColor,
      const Color(0xFF121212),
    );
  });

  testWidgets('isKeyboardOpen follows the bottom view inset', (tester) async {
    bool? open;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
      child: Builder(builder: (c) {
        open = isKeyboardOpen(c);
        return const SizedBox();
      }),
    ));
    expect(open, isTrue);
  });

  test('tab bar hidden while the keyboard is open (source)', () {
    final src =
        File('lib/shared/widgets/layout/main_shell.dart').readAsStringSync();
    expect(src, contains('if (!keyboardOpen)'));
    expect(src, contains('bottomNavigationBar: isKeyboardOpen(context)'));
  });

  test('main.dart wraps the navigator in IonModalTheme', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, matches(RegExp(r'IonModalTheme\(\s*(//[^\n]*\s*)?child:')));
  });
}
