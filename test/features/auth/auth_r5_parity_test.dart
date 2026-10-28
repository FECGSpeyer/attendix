import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/features/auth/presentation/pages/register_page.dart';
import 'package:attendix/features/auth/presentation/widgets/ion_buttons.dart';
import 'package:attendix/features/auth/presentation/widgets/ion_input_decoration.dart';
import 'package:attendix/features/auth/presentation/widgets/otp_widgets.dart';
import 'package:attendix/features/profile/presentation/widgets/account_dialogs.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// AUTH_R5: login / register / reset alert measured against the Ionic
/// pages (iOS mode with 1rem = 17px on the iPhone, md mode on desktop).
void main() {
  Widget app(Widget child) => ProviderScope(
        overrides: [isInTeamsProvider.overrideWithValue(false)],
        child: MaterialApp(
          theme: AppTheme.forPlatform(Brightness.light, defaultTargetPlatform),
          home: child,
        ),
      );

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Top of the white login card (the decorated container behind the form).
  double cardTop(WidgetTester tester) => tester
      .getTopLeft(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).boxShadow != null &&
          (w.decoration as BoxDecoration).shape == BoxShape.rectangle))
      .dy;

  group('Login card metrics', () {
    testWidgets('iOS: logo, segment and items at the Ionic offsets',
        (tester) async {
      await setSize(tester, const Size(393, 852));
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();

      final top = cardTop(tester);
      final segment = tester.getRect(find.byType(AuthModeSegment));
      final items = find.byType(IonStackedItem);
      final mail = tester.getRect(items.at(0));
      final password = tester.getRect(items.at(1));
      // Ionic (iPhone): avatar -55, segment +98.8, e-mail item 77 high,
      // password item 57 high, 17 between the items.
      expect(segment.top - top, closeTo(98.75, 1));
      expect(segment.height, 44);
      expect(mail.top - segment.bottom, closeTo(9, 0.5));
      expect(mail.height, closeTo(77, 0.5));
      expect(password.top - mail.bottom, closeTo(17, 0.5));
      expect(password.height, closeTo(57, 0.5));
      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.height, 44);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('md: items 65 / 57 high, 36px uppercase button',
        (tester) async {
      await setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();

      final top = cardTop(tester);
      final segment = tester.getRect(find.byType(AuthModeSegment));
      final items = find.byType(IonStackedItem);
      expect(segment.top - top, closeTo(100, 1));
      expect(segment.height, 52);
      expect(tester.getSize(items.at(0)).height, closeTo(65, 0.5));
      expect(tester.getSize(items.at(1)).height, closeTo(57, 0.5));
      expect(tester.getSize(find.byType(ElevatedButton)).height, 36);
      expect(find.text('ANMELDEN'), findsOneWidget);
      expect(find.text('REGISTRIEREN'), findsOneWidget);
      expect(find.text('PASSWORT VERGESSEN?'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('iOS: mixed-case labels, disabled "Anmelden" teal at .5',
        (tester) async {
      await setSize(tester, const Size(393, 852));
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();

      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Registrieren'), findsOneWidget);
      final opacity = tester.widget<Opacity>(find
          .ancestor(
              of: find.byType(ElevatedButton), matching: find.byType(Opacity))
          .first);
      expect(opacity.opacity, 0.5);
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byType(ElevatedButton), matching: find.byType(Material))
          .first);
      expect(material.color, AppColors.primary);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('footer is one flowing text (wraps between words)',
        (tester) async {
      await setSize(tester, const Size(393, 852));
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();
      final rich = find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('Demo starten') &&
          w.text.toPlainText().contains('Impressum'));
      expect(rich, findsOneWidget);
      expect(tester.widget<RichText>(rich).textAlign, TextAlign.center);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('Passwort vergessen', () {
    testWidgets('iOS: plain bordered alert input, two side-by-side buttons',
        (tester) async {
      await setSize(tester, const Size(393, 852));
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'a@b.de');
      await tester.tap(find.text('Passwort vergessen?'));
      await tester.pumpAndSettle();

      expect(find.byType(IosAlertInput), findsOneWidget);
      expect(find.byType(IosAlertButton), findsNWidgets(2));
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Zurücksetzen'), findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(IosAlertInput), matching: find.byType(TextField)));
      expect(field.controller!.text, 'a@b.de');
      expect(field.decoration!.focusedBorder, field.decoration!.enabledBorder);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('Register modal', () {
    testWidgets('iOS: ✕ in a toolbar button group (Liquid Glass circle)',
        (tester) async {
      await setSize(tester, const Size(393, 852));
      await tester.pumpWidget(app(const RegisterPage(isModal: true)));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(ToolbarButtonGroup),
              matching: find.byIcon(Icons.close)),
          findsOneWidget);
      expect(find.byType(IosGlassSurface), findsWidgets);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('md desktop: full-width form, all of it reachable',
        (tester) async {
      await setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showRegisterModal(context),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final dialog = tester.getRect(find
          .descendant(of: find.byType(Dialog), matching: find.byType(Scaffold))
          .first);
      expect(dialog.size, const Size(600, 600));
      // ion-padding only: the fields span the modal width.
      final field = tester.getRect(find.byType(IonStackedItem).first);
      expect(field.left - dialog.left, 16);
      expect(field.width, 568);
      // terms checkbox and REGISTRIEREN are reachable (scrolling if needed)
      await tester.scrollUntilVisible(find.text('ABBRECHEN'), 100,
          scrollable: find
              .descendant(
                  of: find.byType(Dialog), matching: find.byType(Scrollable))
              .first);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('REGISTRIEREN'), findsOneWidget);
      final button = tester.getRect(find.byType(IonBlockButton).first);
      expect(button.height, 36);
      expect(button.bottom, lessThanOrEqualTo(dialog.bottom));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}
