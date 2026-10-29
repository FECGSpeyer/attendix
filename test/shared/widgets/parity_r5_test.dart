import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_status_overview_sheet.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ion_modal_handle.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PARITY_R5: ionic-theme-ios27 metrics (alert width / input, modal toolbar,
/// sheet handle, translucent header, close button) and the Ionic
/// Status-Übersicht counts.
void main() {
  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: home),
      );

  group('IosAlertCard width (ios27 280–320, shrink to fit)', () {
    test('short title / inputs only → min width 280', () {
      expect(IosAlertCard.widthFor(title: 'Hi', screenWidth: 393), 280);
      expect(IosAlertCard.widthFor(screenWidth: 393), 280);
    });

    test('long message → max width 320', () {
      expect(
        IosAlertCard.widthFor(
          title: 'Löschen?',
          message: 'Willst du diesen Termin wirklich unwiderruflich löschen?',
          screenWidth: 393,
        ),
        320,
      );
    });

    test('never wider than the screen minus 16pt per side', () {
      expect(
        IosAlertCard.widthFor(
            message: 'x' * 200, screenWidth: 300),
        268,
      );
    });

    test('text sizes: title 17, message 16, input 17', () {
      expect(IosAlertCard.titleFontSize, 17);
      expect(IosAlertCard.messageFontSize, 16);
      expect(IosAlertInput.fontSize, 17);
    });
  });

  testWidgets('iOS prompt: alert with IosAlertInput (17pt)', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    final ctx = tester.element(find.byType(Scaffold));
    final result = showAppPrompt(ctx, title: 'Name', hint: 'Name eingeben');
    await tester.pumpAndSettle();
    expect(find.byType(IosAlertCard), findsOneWidget);
    expect(find.byType(IosAlertInput), findsOneWidget);
    final field = tester.widget<TextField>(find.descendant(
        of: find.byType(IosAlertInput), matching: find.byType(TextField)));
    expect(field.style?.fontSize, 17);
    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await result, 'Anna');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('modal toolbar height', () {
    testWidgets('iOS: 64pt for sheet / card modal headers', (tester) async {
      double? height;
      await tester.pumpWidget(app(Builder(builder: (context) {
        height = ionModalToolbarHeight(context);
        return const IonModalHeader(title: Text('Titel'));
      })));
      expect(height, kIonModalToolbarHeight);
      expect(kIonModalToolbarHeight, 64);
      expect(tester.getSize(find.byType(IonModalHeader)).height, 64);
      expect(const IonModalHeader(title: Text('x')).preferredSize.height, 64);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('md: theme default (null)', (tester) async {
      double? height = -1;
      await tester.pumpWidget(app(Builder(builder: (context) {
        height = ionModalToolbarHeight(context);
        return const SizedBox();
      })));
      expect(height, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS sheet header 64pt', (tester) async {
      await tester.pumpWidget(app(const IonSheetHeader(title: 'Titel')));
      // header (64) + hairline (0.5)
      expect(tester.getSize(find.byType(IonSheetHeader)).height, 64.5);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  test('ios27 sheet handle and radius', () {
    expect(IonModalHandle.size, const Size(60, 4));
    expect(IonModalHandle.top, 6);
    expect(kIonModalSheetRadius, 32);
    expect(AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS)
        .bottomSheetTheme
        .dragHandleSize, const Size(60, 4));
  });

  testWidgets('iOS close button: white glass circle, not a grey disc',
      (tester) async {
    await tester.pumpWidget(app(const IonCloseButton()));
    final icon = tester.widget<IosCircleIcon>(find.byType(IosCircleIcon));
    expect(icon.filled, isFalse);
    expect(icon.size, 44);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('IonTranslucentBarBackground', () {
    testWidgets('iOS condensed: blur + 20 % tint', (tester) async {
      await tester.pumpWidget(
          app(const IonTranslucentBarBackground(visible: true)));
      expect(find.byType(BackdropFilter), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('large title visible or md: nothing', (tester) async {
      await tester.pumpWidget(
          app(const IonTranslucentBarBackground(visible: false)));
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  test('Status-Übersicht counts every person row (missing → Neutral)', () {
    final result = statusOverviewCounts(
      [1, 2, 3, 4],
      {
        1: AttendanceStatus.present,
        2: AttendanceStatus.present,
        3: AttendanceStatus.absent,
        // 4 has no status yet; 9 is not part of the list
        9: AttendanceStatus.excused,
      },
    );
    expect(result.total, 4);
    expect(result.counts[AttendanceStatus.present], 2);
    expect(result.counts[AttendanceStatus.absent], 1);
    expect(result.counts[AttendanceStatus.neutral], 1);
    expect(result.counts[AttendanceStatus.excused], 0);
  });
}
