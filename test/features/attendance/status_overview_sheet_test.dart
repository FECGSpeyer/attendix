import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_status_overview_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PARITY_R3: ⋮ → Status-Übersicht is the Ionic StatusInfoComponent.
void main() {
  Widget app() => MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox()),
      );

  Future<void> open(
    WidgetTester tester,
    Map<AttendanceStatus, int> counts,
    int total,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    showStatusOverviewSheet(
      tester.element(find.byType(Scaffold)),
      statusCounts: counts,
      total: total,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('total header, only non-zero statuses with count badges, close',
      (tester) async {
    await open(tester, {
      AttendanceStatus.present: 5,
      AttendanceStatus.excused: 1,
      AttendanceStatus.late: 0,
      AttendanceStatus.absent: 0,
      AttendanceStatus.neutral: 0,
    }, 6);

    expect(find.text('Status-Übersicht'), findsOneWidget);
    expect(find.text('Gesamt: 6 Personen'), findsOneWidget);
    expect(find.byType(StatusCountBadge), findsNWidgets(2));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Anwesend'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Entschuldigt'), findsOneWidget);
    expect(find.text('Abwesend'), findsNothing);
    expect(find.text('Neutral'), findsNothing);
    // No progress bars / percentages any more.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    // Ionic order: Anwesend before Entschuldigt.
    expect(
      tester.getTopLeft(find.text('Anwesend')).dy,
      lessThan(tester.getTopLeft(find.text('Entschuldigt')).dy),
    );
    // Badge: Ionic min-width 32, black text on warning.
    final badges = tester.widgetList<StatusCountBadge>(
        find.byType(StatusCountBadge)).toList();
    expect(badges.map((b) => b.color),
        [AppColors.success, AppColors.warning]);
    expect(tester.getSize(find.byType(StatusCountBadge).first).width,
        greaterThanOrEqualTo(32));

    await tester.tap(find.byType(IonCloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(StatusOverviewSheet), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS: same rows with the ✕ circle', (tester) async {
    await open(tester, {AttendanceStatus.lateExcused: 2}, 2);
    expect(find.text('Gesamt: 2 Personen'), findsOneWidget);
    expect(find.text('Verspätet (entsch.)'), findsOneWidget);
    expect(find.byType(IosCircleIcon), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no people: one centred grey row', (tester) async {
    await open(tester, const {}, 0);
    expect(find.text('Keine Personen vorhanden'), findsOneWidget);
    expect(find.byType(StatusCountBadge), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
