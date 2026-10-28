import 'dart:async';
import 'dart:io';

import 'package:attendix/core/providers/legal_providers.dart';
import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:attendix/core/theme/app_colors.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/auth/presentation/pages/login_page.dart';
import 'package:attendix/features/auth/presentation/pages/register_page.dart';
import 'package:attendix/features/legal/presentation/widgets/legal_content_view.dart';
import 'package:attendix/features/planning/presentation/pages/public_planning_page.dart';
import 'package:attendix/shared/widgets/common/error_state_view.dart';
import 'package:attendix/shared/widgets/dialogs/ion_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_PRELOGIN: pre-login screens behave like the Ionic login / register
/// modal / legal modal / public planner.
void main() {
  Widget app(Widget child) => ProviderScope(
        overrides: [isInTeamsProvider.overrideWithValue(false)],
        child: MaterialApp(theme: AppTheme.light, home: child),
      );

  ElevatedButton button(WidgetTester tester, String label) =>
      tester.widget<ElevatedButton>(
          find.ancestor(of: find.text(label), matching: find.byType(ElevatedButton)));

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('Login (Ionic login.page)', () {
    testWidgets('"Anmelden" is disabled until e-mail and password are filled',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();

      expect(button(tester, 'Anmelden').onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.de');
      await tester.pump();
      expect(button(tester, 'Anmelden').onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.pump();
      expect(button(tester, 'Anmelden').onPressed, isNotNull);
    });

    testWidgets('"Code senden" is disabled until the e-mail is filled',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code per E-Mail'));
      await tester.pumpAndSettle();

      expect(button(tester, 'Code senden').onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).first, 'a@b.de');
      await tester.pump();
      expect(button(tester, 'Code senden').onPressed, isNotNull);
    });

    testWidgets('"Passwort vergessen?" opens the reset alert with the e-mail',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const LoginPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'a@b.de');
      await tester.tap(find.text('Passwort vergessen?'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Passwort zurücksetzen'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Zurücksetzen'), findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField)));
      expect(field.controller!.text, 'a@b.de');

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('errors are toasts, no inline error box; reset is a dialog', () {
      final src =
          File('lib/features/auth/presentation/pages/login_page.dart').readAsStringSync();
      expect(src, isNot(contains('_errorMessage')));
      expect(src, isNot(contains("'/forgot-password")));
      expect(src, contains('showRegisterModal('));
      final reg = File('lib/features/auth/presentation/pages/register_page.dart')
          .readAsStringSync();
      expect(reg, isNot(contains('_errorMessage')));
      expect(reg, isNot(contains('_registrationSuccess')));
    });

    test('/forgot-password redirects to the login reset alert', () {
      final src = File('lib/core/router/app_router.dart').readAsStringSync();
      final start = src.indexOf("path: '/forgot-password'");
      final block = src.substring(start, src.indexOf('),', start));
      expect(block, contains("'/login'"));
      expect(block, contains("'reset': '1'"));
      expect(src, isNot(contains('ForgotPasswordPage(')));
    });
  });

  group('Register modal (Ionic register-modal)', () {
    testWidgets('submit is disabled until all fields + privacy are set',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const RegisterPage(isModal: true)));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(button(tester, 'Registrieren').onPressed, isNull);
      await tester.enterText(fields.at(0), 'a@b.de');
      await tester.enterText(fields.at(1), 'secret1');
      await tester.enterText(fields.at(2), 'secret1');
      await tester.pump();
      expect(button(tester, 'Registrieren').onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(button(tester, 'Registrieren').onPressed, isNotNull);
    });

    testWidgets('content is top-aligned on phones (no vertical centring)',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const RegisterPage(isModal: true)));
      await tester.pumpAndSettle();
      final welcomeTop =
          tester.getTopLeft(find.text('Willkommen bei Attendix!')).dy;
      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(welcomeTop - appBarBottom, lessThan(40));
    });
  });

  group('showIonModal (ion-modal sizes)', () {
    Future<void> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showIonModal<void>(context,
                  builder: (_) => const Scaffold(body: Text('modal-body'))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('desktop: centred 600x500 card', (tester) async {
      await open(tester, const Size(1440, 900));
      expect(find.byType(Dialog), findsOneWidget);
      final size = tester.getSize(find.descendant(
          of: find.byType(Dialog), matching: find.byType(Scaffold)));
      expect(size, const Size(600, 500));
    });

    testWidgets('phone: full screen', (tester) async {
      await open(tester, const Size(390, 844));
      expect(find.byType(Dialog), findsNothing);
      expect(tester.getSize(find.ancestor(
              of: find.text('modal-body'), matching: find.byType(Scaffold))),
          const Size(390, 844));
    });
  });

  group('Theme: disabled buttons (Ionic opacity .5)', () {
    testWidgets('disabled ElevatedButton/FilledButton use primary at 50%',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(children: [
            ElevatedButton(onPressed: null, child: Text('e')),
            FilledButton(onPressed: null, child: Text('f')),
          ]),
        ),
      ));
      for (final label in ['e', 'f']) {
        final material = tester.widget<Material>(find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first);
        expect(material.color, AppColors.primary.withValues(alpha: 0.5));
      }
    });
  });

  group('Public planner (Ionic public-planning)', () {
    testWidgets('IonDatetimeChip shows the plain value', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IonDatetimeChip(text: '09:35', onTap: () => tapped = true),
        ),
      ));
      expect(find.text('09:35'), findsOneWidget);
      await tester.tap(find.text('09:35'));
      expect(tapped, isTrue);
    });

    test('times without "Uhr", add menu is an anchored popover', () {
      final src = File(
              'lib/features/planning/presentation/pages/public_planning_page.dart')
          .readAsStringSync();
      expect(src, isNot(contains('attendanceTimeOClock')));
      final addMenu = src.substring(src.indexOf('Future<void> _showAddMenu('));
      expect(addMenu.substring(0, addMenu.indexOf('if (action == null')),
          allOf(contains('showMenu<String>('), isNot(contains('showPlanActionSheet'))));
    });
  });

  group('Legal content (Ionic legal-content)', () {
    testWidgets('retry shows the spinner instead of the stale error',
        (tester) async {
      var calls = 0;
      final completer = Completer<String>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          legalContentProvider.overrideWith((ref) async {
            calls++;
            if (calls == 1) throw Exception('offline');
            return completer.future;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: LegalContentView())),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ErrorStateView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(find.byType(ErrorStateView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete('<p>Impressum</p>');
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
