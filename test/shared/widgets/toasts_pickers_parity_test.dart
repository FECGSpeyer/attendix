import 'dart:io';

import 'package:attendix/core/utils/toast_helper.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// QUE-26 / QUE-27 / QUE-28: Ionic toasts, the md `ion-datetime` of the
/// shared pickers and the shared `ion-datetime-button`.
void main() {
  Widget app(Widget home, {TargetPlatform platform = TargetPlatform.android}) => MaterialApp(
        theme: ThemeData(platform: platform),
        locale: const Locale('de'),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      );

  test('QUE-26: no raw showSnackBar outside ToastHelper (classic code)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final name = path.split('/').last;
      if (path == 'lib/core/utils/toast_helper.dart') continue;
      // Beta design: out of scope, keeps its SnackBars.
      if (path.contains('/features/redesign/') || name.startsWith('rd_') || name.endsWith('_beta.dart')) continue;
      if (entity.readAsStringSync().contains('showSnackBar(')) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'use ToastHelper.showSuccess/showError/showInfo/showWarning');
  });

  testWidgets('QUE-26: toast button (Ionic `buttons`) runs its handler and closes the toast', (tester) async {
    late BuildContext context;
    var undone = 0;
    await tester.pumpWidget(app(Builder(builder: (c) {
      context = c;
      return const SizedBox.expand();
    })));

    ToastHelper.showSuccess(
      context,
      'Gelöscht',
      action: ToastAction(label: 'Rückgängig', onPressed: () => undone++),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Gelöscht'), findsOneWidget);
    // Ionic md toast at the top of the screen.
    expect(tester.getCenter(find.text('Gelöscht')).dy, lessThan(120));

    await tester.tap(find.text('RÜCKGÄNGIG'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(undone, 1);
    expect(find.text('Gelöscht'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  group('QUE-27: md ion-datetime', () {
    Future<Future<DateTime?>> open(
      WidgetTester tester, {
      IonDatetimeOverlay overlay = IonDatetimeOverlay.button,
      bool preferWheel = false,
    }) async {
      late BuildContext context;
      await tester.pumpWidget(app(Builder(builder: (c) {
        context = c;
        return const SizedBox.expand();
      })));
      final result = showAppDatePicker(
        context: context,
        initialDate: DateTime(2026, 11, 14),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        overlay: overlay,
        preferWheel: preferWheel,
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('datetime-button modal: Ionic grid, stays open, backdrop returns the day', (tester) async {
      final result = await open(tester);
      // No Material date picker dialog.
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.byType(IonMdCalendar), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      // No default buttons.
      expect(find.text('OK'), findsNothing);

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(find.byType(IonMdCalendar), findsOneWidget, reason: 'ion-datetime-button modal stays open');

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(IonMdCalendar), findsNothing);
      expect(await result, DateTime(2026, 11, 20));
    });

    testWidgets('.dateModal closes with the picked day', (tester) async {
      final result = await open(tester, overlay: IonDatetimeOverlay.dateModal);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.byType(IonMdCalendar), findsNothing);
      expect(await result, DateTime(2026, 11, 3));
    });

    testWidgets('showDefaultButtons: backdrop cancels, OK confirms', (tester) async {
      var result = await open(tester, overlay: IonDatetimeOverlay.buttons);
      expect(find.text('ABBRECHEN'), findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await result, isNull);

      result = await open(tester, overlay: IonDatetimeOverlay.buttons);
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, DateTime(2026, 11, 21));
    });

    testWidgets('preferWheel shows the wheel columns instead of the grid', (tester) async {
      final result = await open(tester, overlay: IonDatetimeOverlay.dateModal, preferWheel: true);
      expect(find.byType(IonMdDateWheel), findsOneWidget);
      expect(find.byType(IonMdCalendar), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('time: Ionic wheels, 5-minute steps, null when unchanged', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(app(Builder(builder: (c) {
        context = c;
        return const SizedBox.expand();
      })));
      final result = showAppTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 19, minute: 30),
        minuteInterval: 5,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.byType(IonMdTimeWheel), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      expect(find.text('31'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('iOS look keeps its calendar card', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late BuildContext context;
      await tester.pumpWidget(app(
        Builder(builder: (c) {
          context = c;
          return const SizedBox.expand();
        }),
        platform: TargetPlatform.iOS,
      ));
      final result = showAppDatePicker(
        context: context,
        initialDate: DateTime(2026, 11, 14),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IonMdCalendar), findsNothing);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(await result, DateTime(2026, 11, 20));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('QUE-28: IonDatetimeButton', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('date and time pills open their own picker ($platform)', (tester) async {
        final taps = <String>[];
        await tester.pumpWidget(app(
          Center(
            child: IonDatetimeButton(
              date: '14. Nov. 2026',
              onDateTap: () => taps.add('date'),
              time: '19:30',
              onTimeTap: () => taps.add('time'),
            ),
          ),
          platform: platform,
        ));
        expect(find.text('14. Nov. 2026'), findsOneWidget);
        expect(find.text('19:30'), findsOneWidget);
        // Two pills side by side, grey rounded (radius 8).
        final pills = tester.widgetList<Material>(
          find.descendant(of: find.byType(IonDatetimeButton), matching: find.byType(Material)),
        );
        expect(pills.length, 2);
        for (final pill in pills) {
          expect(pill.color, const Color(0xFFEDEEF0));
          expect(pill.borderRadius, BorderRadius.circular(8));
        }
        await tester.tap(find.text('14. Nov. 2026'));
        await tester.tap(find.text('19:30'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(taps, ['date', 'time']);
      });
    }

    testWidgets('disabled: 40 % and no tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(Center(
        child: IonDatetimeButton(date: '14.11.2026', onDateTap: () => taps++, disabled: true),
      )));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(IonDatetimeButton), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0.4);
      await tester.tap(find.text('14.11.2026'), warnIfMissed: false);
      expect(taps, 0);
    });
  });
}
