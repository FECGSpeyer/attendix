import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/profile/presentation/widgets/account_dialogs.dart';
import 'package:attendix/features/profile/presentation/widgets/profile_helpers.dart';
import 'package:attendix/features/settings/presentation/widgets/calendar_subscription_dialog.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/sheets/feedback_sheet.dart';
import 'package:attendix/shared/widgets/sheets/version_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  Widget app(Widget home) => ProviderScope(
        child: MaterialApp(
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      );

  group('formatIonDateButton', () {
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

    test('other languages append &lang=', () {
      expect(
        calendarSubscriptionLink(tenantId: 1, personId: 2, language: 'en'),
        'https://abc.supabase.co/functions/v1/ical-tenant?tenantId=1&personId=2&lang=en',
      );
    });
  });

  testWidgets('Passwort ändern sheet renders inputs and primary button', (tester) async {
    await tester.pumpWidget(app(const ChangePasswordDialog()));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Passwort ändern'), findsNWidgets(2));
  });

  testWidgets('Was ist neu? sheet renders cleanly', (tester) async {
    await tester.pumpWidget(app(const VersionHistorySheet()));
    await tester.pump();
    expect(find.byType(VersionHistorySheet), findsOneWidget);
  });

  testWidgets('Feedback sheet switches chips and exposes Senden', (tester) async {
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

    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text('Hilfe/Frage'), findsOneWidget);
    expect(find.text('Senden'), findsOneWidget);

    await tester.tap(find.text('Hilfe/Frage'));
    await tester.pumpAndSettle();
    expect(find.text('Senden'), findsOneWidget);
  });
}
