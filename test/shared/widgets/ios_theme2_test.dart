import 'dart:io';

import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/display/avatar.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// IOS_THEME2: global iOS / md theme parity with Ionic.
void main() {
  Widget app(Widget home, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Scaffold(body: home),
      );

  final items = [
    const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
    const DropdownMenuItem(value: 'en', child: Text('English')),
  ];

  group('theme', () {
    test('ion-toggle stays primary on iOS (no system green)', () {
      final ios = AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS);
      final adapted = ios
          .getAdaptation<SwitchThemeData>()!
          .adapt(ios, ios.switchTheme);
      expect(adapted.trackColor!.resolve({WidgetState.selected}),
          AppColors.primary);
      expect(adapted.thumbColor!.resolve({WidgetState.selected}),
          Colors.white);
    });

    test('iOS: no ripple / hover / focus highlight, popovers radius 34', () {
      final ios = AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS);
      expect(ios.splashFactory, NoSplash.splashFactory);
      expect(ios.hoverColor, Colors.transparent);
      expect(ios.focusColor, Colors.transparent);
      expect(ios.popupMenuTheme.position, PopupMenuPosition.under);
      expect(
        (ios.popupMenuTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(34), // IOS27_SWEEP
      );
    });

    test('md: Ionic md toolbar (white, left title, ← back, not teal)', () {
      final md = AppTheme.forPlatform(Brightness.light, TargetPlatform.android);
      expect(md.appBarTheme.centerTitle, isFalse);
      expect(md.appBarTheme.backgroundColor, Colors.white);
      expect(md.appBarTheme.iconTheme!.color, isNot(AppColors.primary));
      final mdDark = AppTheme.forPlatform(Brightness.dark, TargetPlatform.android);
      expect(mdDark.appBarTheme.backgroundColor, AppColors.mdToolbarDark);
    });

    test('dark palette brightens like Ionic dark', () {
      expect(AppColors.forBrightness(AppColors.danger, Brightness.dark),
          const Color(0xFFFF4961));
      expect(AppColors.forBrightness(AppColors.success, Brightness.dark),
          const Color(0xFF25B15D));
      expect(AppColors.forBrightness(AppColors.danger, Brightness.light),
          AppColors.danger);
      final dark = AppTheme.forPlatform(Brightness.dark, TargetPlatform.iOS);
      expect(dark.colorScheme.error, AppColors.dangerOnDark);
    });

    test('main.dart hides tooltips on every platform (Ionic has none)', () {
      expect(File('lib/main.dart').readAsStringSync(),
          contains('TooltipVisibility(\n        visible: false,'));
    });
  });

  group('IonSegment', () {
    testWidgets('iOS: neutral by default – text-colour labels, white pill',
        (tester) async {
      await tester.pumpWidget(app(IonSegment<int>(
        items: const [
          IonSegmentItem(value: 1, label: Text('Eins')),
          IonSegmentItem(value: 2, label: Text('Zwei')),
        ],
        value: 1,
        onChanged: (_) {},
      )));
      final text = tester.widget<RichText>(find.descendant(
          of: find.text('Eins'), matching: find.byType(RichText)).first);
      expect(text.text.style?.color, AppTheme.light.colorScheme.onSurface);
      expect(tester.getSize(find.byType(IonSegment<int>)).height,
          IonSegment.height);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('md: uppercase tabs, primary checked label', (tester) async {
      int? picked;
      await tester.pumpWidget(app(IonSegment<int>(
        items: const [
          IonSegmentItem(value: 1, label: Text('Eins')),
          IonSegmentItem(value: 2, label: Text('Zwei')),
        ],
        value: 1,
        onChanged: (v) => picked = v,
      )));
      expect(find.text('EINS'), findsOneWidget);
      expect(find.byType(SegmentedButton<int>), findsNothing);
      final text = tester.widget<RichText>(find.descendant(
          of: find.text('EINS'), matching: find.byType(RichText)).first);
      expect(text.text.style?.color, AppColors.primary);
      await tester.tap(find.text('ZWEI'));
      expect(picked, 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('ion-select', () {
    testWidgets('iOS popover: right under the value, ✓ on current option',
        (tester) async {
      String? changed;
      await tester.pumpWidget(app(Align(
        alignment: Alignment.topRight,
        child: AppDropdownButton<String>(
          value: 'de',
          items: items,
          onChanged: (v) => changed = v,
        ),
      )));
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.byType(IonSelectIcon), findsOneWidget);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      // popover: both options, a checkmark on the current one only
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      final popoverRight = tester.getTopRight(find.text('English')).dx;
      expect(popoverRight, greaterThan(600));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(changed, 'en');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS alert interface: radios + Abbrechen / OK',
        (tester) async {
      String? changed;
      await tester.pumpWidget(app(AppDropdownFormField<String>(
        value: 'de',
        items: items,
        iosInterface: AppSelectInterface.alert,
        decoration: const InputDecoration(labelText: 'Sprache'),
        onChanged: (v) => changed = v,
      )));
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(find.byType(IosAlertCard), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(changed, 'en');
      expect(find.text('English'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Material keeps the Flutter dropdowns', (tester) async {
      await tester.pumpWidget(app(Column(children: [
        AppDropdownFormField<String>(
            value: 'de', items: items, onChanged: (_) {}),
        AppDropdownButton<String>(
            value: 'de', items: items, onChanged: (_) {}),
      ])));
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNWidgets(2));
      expect(find.byType(IonSelectIcon), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    test('Sprache picker uses the adaptive select popover (source)', () {
      final src = File(
              'lib/features/settings/presentation/widgets/language_picker_tile.dart')
          .readAsStringSync();
      expect(src, contains('showAppSelect<String>('));
    });

    test('app-wide dropdowns go through the adaptive select (source)', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('adaptive/app_select.dart')) continue;
        // songs + create attendance: lane IOS_FORMS2
        if (f.path.contains('features/songs/') ||
            f.path.contains('attendance_create_page.dart')) {
          continue;
        }
        final src = f.readAsStringSync();
        if (RegExp(r'\bDropdownButton(FormField)?<').hasMatch(src)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('misc', () {
    testWidgets('IonInformationIcon paints the plain "i"', (tester) async {
      await tester.pumpWidget(app(const IconTheme(
        data: IconThemeData(size: 24),
        child: IonInformationIcon(),
      )));
      expect(tester.getSize(find.byType(IonInformationIcon)),
          const Size(24, 24));
    });

    testWidgets('IonAvatarPlaceholder sized like the avatar', (tester) async {
      await tester.pumpWidget(app(const Center(
        child: IonAvatarPlaceholder(size: 48),
      )));
      expect(tester.getSize(find.byType(IonAvatarPlaceholder)),
          const Size(48, 48));
    });

    testWidgets('condenseBarColor follows a custom page background',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(app(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      expect(condenseBarColor(ctx, false, pageBackground: Colors.white),
          Colors.white);
      expect(condenseBarColor(ctx, true, pageBackground: Colors.white),
          isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    test('debugDefaultTargetPlatformOverride untouched', () {
      expect(debugDefaultTargetPlatformOverride, isNull);
    });
  });
}
