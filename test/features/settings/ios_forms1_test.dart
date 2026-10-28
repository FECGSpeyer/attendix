import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/profile/presentation/widgets/account_dialogs.dart';
import 'package:attendix/features/profile/presentation/widgets/profile_helpers.dart';
import 'package:attendix/features/settings/presentation/widgets/calendar_subscription_dialog.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ion_modal_handle.dart';
import 'package:attendix/shared/widgets/sheets/feedback_sheet.dart';
import 'package:attendix/shared/widgets/sheets/version_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// IOS_FORMS1: page / sheet / dialog bodies of the Mehr sub-screens in the
/// Ionic iOS look.
void main() {
  Widget app(Widget home) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      );

  group('formatIonDateButton (ion-datetime-button)', () {
    setUpAll(() async {
      await initializeDateFormatting('de_DE');
      await initializeDateFormatting('en_GB');
    });
    tearDown(() => setActiveLanguage('de'));

    test('German: "16. Feb. 2002"', () {
      setActiveLanguage('de');
      expect(formatIonDateButton('2002-02-16'), '16. Feb. 2002');
    });

    test('English (en-GB): "16 Feb 2002"', () {
      setActiveLanguage('en');
      expect(formatIonDateButton('2002-02-16'), '16 Feb 2002');
    });

    test('empty / invalid values', () {
      expect(formatIonDateButton(null), '');
      expect(formatIonDateButton(''), '');
      expect(formatIonDateButton('kein Datum'), 'kein Datum');
    });
  });

  group('calendarSubscriptionLink language', () {
    setUpAll(() =>
        dotenv.testLoad(fileInput: 'SUPABASE_URL=https://abc.supabase.co'));

    test('German (server default) adds no lang parameter', () {
      expect(
        calendarSubscriptionLink(tenantId: 1, personId: 2, language: 'de'),
        'https://abc.supabase.co/functions/v1/ical-tenant?tenantId=1&personId=2',
      );
    });

    test('other languages append &lang= like Ionic', () {
      expect(
        calendarSubscriptionLink(tenantId: 1, personId: 2, language: 'en'),
        'https://abc.supabase.co/functions/v1/ical-tenant?tenantId=1&personId=2&lang=en',
      );
    });
  });

  testWidgets('Passwort ändern (iOS): inputs without icons, '
      '"Abbrechen | Ändern" side by side', (tester) async {
    // The test font is far wider than SF: scale it so both labels fit half
    // the alert like on a device (they wrap onto two lines otherwise).
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(const ChangePasswordDialog()));
    await tester.pumpAndSettle();

    expect(find.byType(IosAlertInput), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.visibility), findsNothing);
    final cancel = tester.getCenter(find.text('Abbrechen'));
    final change = tester.getCenter(find.text('Ändern'));
    expect(cancel.dy, change.dy);
    expect(cancel.dx, lessThan(change.dx));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Passwort ändern (md): underline inputs without icons, '
      'uppercase text buttons', (tester) async {
    await tester.pumpWidget(app(const ChangePasswordDialog()));
    await tester.pumpAndSettle();
    expect(find.byType(IosAlertInput), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.visibility), findsNothing);
    expect(find.text('ABBRECHEN'), findsOneWidget);
    expect(find.text('ÄNDERN'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('Was ist neu? (iOS): grabber, centred title, no close button',
      (tester) async {
    await tester.pumpWidget(app(const VersionHistorySheet()));
    await tester.pump();

    expect(find.byType(IonModalHandle), findsOneWidget);
    expect(find.byType(IonModalHeader), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Feedback (iOS): grabber, neutral segment, "Absenden" visible',
      (tester) async {
    // iPhone 15 viewport
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () => showFeedbackSheet(context),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(IonModalHandle), findsOneWidget);
    expect(find.text('Hilfe & Feedback'), findsOneWidget);
    final segment =
        tester.widget<IonSegment<int>>(find.byType(IonSegment<int>));
    expect(segment.neutral, isTrue);
    expect(find.text('Absenden'), findsOneWidget);
    // Submit row lies inside the visible sheet without scrolling.
    expect(tester.getBottomLeft(find.text('Absenden')).dy, lessThan(852));

    // Switch to "Feedback": rating row + submit
    await tester.tap(find.text('Feedback').last);
    await tester.pumpAndSettle();
    expect(find.text('Deine Bewertung'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Absenden'), 100,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Absenden'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
