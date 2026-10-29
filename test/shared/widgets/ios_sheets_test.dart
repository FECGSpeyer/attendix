import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/utils/event_list_utils.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/models/user_notification/user_notification.dart';
import 'package:attendix/features/messages/presentation/widgets/notification_bell.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart';
import 'package:attendix/shared/widgets/layout/ion_modal_handle.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// IOS_SHEETS: neutral toolbar segment and the legend sheet in iOS mode.
void main() {
  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      );

  test('"Verspätung gemeldet" uses Ionic --ion-color-rosa (lilac)', () {
    expect(EventListUtils.rosa, const Color(0xFFBE72C0));
    expect(EventListUtils.rosa, AppColors.rosa);
  });

  testWidgets('IonSegment neutral + fitContent: centred, equal widths, '
      'white pill, callback', (tester) async {
    var value = false;
    await tester.pumpWidget(app(StatefulBuilder(
      builder: (context, setState) => Center(
        child: IonSegment<bool>(
          neutral: true,
          fitContent: true,
          items: const [
            IonSegmentItem(value: false, label: Text('Aktuelle Instanz')),
            IonSegmentItem(value: true, label: Text('Alle')),
          ],
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      ),
    )));

    final segment = tester.getSize(find.byType(IonSegment<bool>));
    // Not the full 800px test width: only as wide as the labels
    // (test font: 14.5px per glyph → 2 × (16 × 14.5 + padding)).
    expect(segment.width, lessThan(600));
    expect(tester.getCenter(find.byType(IonSegment<bool>)).dx, 400);
    final a = tester.getSize(find.ancestor(
        of: find.text('Aktuelle Instanz'),
        matching: find.byType(AnimatedContainer)));
    final b = tester.getSize(find.ancestor(
        of: find.text('Alle'), matching: find.byType(AnimatedContainer)));
    expect(a.width, closeTo(b.width, 0.5));

    final pill = tester.widget<AnimatedContainer>(find.ancestor(
        of: find.text('Aktuelle Instanz'),
        matching: find.byType(AnimatedContainer)));
    expect((pill.decoration as BoxDecoration?)?.color, Colors.white);

    await tester.tap(find.text('Alle'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('legend sheet (iOS): grabber, 52pt rows, lilac late pill',
      (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    final ctx = tester.element(find.byType(Scaffold));
    showEventLegendSheet(ctx);
    await tester.pumpAndSettle();

    expect(find.byType(IonModalHandle), findsOneWidget);
    expect(find.text('Legende'), findsOneWidget);
    expect(find.byType(IonItem), findsNWidgets(6));
    for (final e in tester.elementList(find.byType(IonItem))) {
      expect(e.size!.height, greaterThanOrEqualTo(52));
    }
    final late = tester.widget<EventPill>(find.ancestor(
        of: find.text('Verspätung gemeldet'),
        matching: find.byType(EventPill)));
    expect(late.color, AppColors.rosa);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('legend sheet (Android): Material layout without iOS grabber',
      (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    final ctx = tester.element(find.byType(Scaffold));
    showEventLegendSheet(ctx);
    await tester.pumpAndSettle();

    expect(find.byType(IonModalHandle), findsNothing);
    expect(find.byType(EventPill), findsNWidgets(6));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  group('notification sheet', () {
    final notifications = [
      UserNotification(
        id: 'a',
        tenantId: 1,
        body: 'Allgemein\nTreffen am 15.06.',
        read: true,
        createdAt: DateTime(2026, 6, 1, 10),
      ),
      UserNotification(
        id: 'b',
        tenantId: 1,
        body: 'Neue Nachricht',
        createdAt: DateTime(2026, 6, 2, 10),
      ),
    ];

    Future<void> openBell(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userNotificationsProvider
              .overrideWith((ref, all) async => notifications),
          unreadNotificationCountProvider.overrideWith((ref) async => 1),
          userNotificationsRealtimeProvider.overrideWith((ref) {}),
          userTenantsProvider.overrideWith((ref) async => const <Tenant>[]),
        ],
        child: app(const Align(
          alignment: Alignment.topRight,
          child: NotificationBell(),
        )),
      ));
      await tester.pump();
      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
    }

    testWidgets('iOS: grabber, neutral centred segment, glass end buttons, '
        'body whitespace collapsed', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openBell(tester);

      // Ionic sheet: breakpoint 0.75 of (100% - 10px) → top at 852 - 631.5.
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy,
          closeTo(852 - 0.75 * 842, 1));

      expect(find.byType(IonModalHandle), findsOneWidget);
      final segment = tester.widget<IonSegment<bool>>(
          find.byType(IonSegment<bool>));
      expect(segment.neutral, isTrue);
      expect(segment.fitContent, isTrue);
      expect(find.byType(ToolbarButtonGroup), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(ToolbarButtonGroup),
            matching: find.byIcon(Icons.delete_outline)),
        findsOneWidget,
      );
      // HTML-like whitespace: one line "Allgemein Treffen am …".
      expect(find.text('Allgemein Treffen am 15.06.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android: Material header, no iOS grabber', (tester) async {
      await openBell(tester);

      expect(find.byType(IonModalHandle), findsNothing);
      expect(find.byType(ToolbarButtonGroup), findsNothing);
      // IOS_THEME2: Ionic md segment (tab style), not a Material box
      expect(find.byType(IonSegment<bool>), findsOneWidget);
      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(find.text('ALLE'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
