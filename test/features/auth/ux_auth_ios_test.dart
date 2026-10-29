import 'dart:io';

import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/auth/presentation/widgets/ion_form_list.dart';
import 'package:attendix/features/auth/presentation/widgets/otp_widgets.dart';
import 'package:attendix/features/tenant_selection/presentation/pages/tenant_create_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UX_AUTH (wave 8): auth / registration / tenant screens follow the Ionic
/// iOS layout.
void main() {
  Widget app(Widget child, {TargetPlatform platform = TargetPlatform.iOS}) =>
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          home: child,
        ),
      );

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('AuthModeSegment (Ionic .mode-segment)', () {
    testWidgets('labels only, no icons; tap switches the mode',
        (tester) async {
      var mode = AuthMode.password;
      await tester.pumpWidget(app(Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AuthModeSegment(
            mode: mode,
            onChanged: (m) => setState(() => mode = m),
          ),
        ),
      )));
      expect(find.text('Passwort'), findsOneWidget);
      expect(find.text('Code per E-Mail'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      await tester.tap(find.text('Code per E-Mail'));
      await tester.pump();
      expect(mode, AuthMode.otp);
    });
  });

  group('OtpCodeField (ion-input-otp)', () {
    testWidgets('six boxes, label below, completes after six digits',
        (tester) async {
      await setPhone(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? completed;
      await tester.pumpWidget(app(Scaffold(
        body: Center(
          child: OtpCodeField(
            controller: controller,
            onCompleted: (v) => completed = v,
          ),
        ),
      )));
      expect(find.text('Code aus der E-Mail'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(completed, '123456');
      for (final d in ['1', '2', '3', '4', '5', '6']) {
        expect(find.text(d), findsOneWidget);
      }
    });
  });

  group('Neue Instanz anlegen (Ionic register.page)', () {
    testWidgets('dismissable: close button at the end, no account menu',
        (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const TenantCreatePage()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byKey(const ValueKey('register-account-menu')), findsNothing);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, isNull);
    });

    testWidgets('no instance yet: account menu with Abmelden / Konto löschen',
        (tester) async {
      await setPhone(tester);
      await tester
          .pumpWidget(app(const TenantCreatePage(canDismiss: false)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.tap(find.byKey(const ValueKey('register-account-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Abmelden'), findsOneWidget);
      expect(find.text('Konto löschen'), findsOneWidget);
    });

    testWidgets('step headers and inset groups in Ionic order',
        (tester) async {
      tester.view.physicalSize = const Size(393, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const TenantCreatePage()));
      await tester.pumpAndSettle();
      expect(find.byType(IonListHeader), findsAtLeastNWidgets(3));
      expect(find.byType(IonInsetGroup), findsAtLeastNWidgets(3));
      // the group type is an ion-select item, not a dropdown field
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byKey(const ValueKey('tenant-type-select')), findsOneWidget);
    });
  });

  group('Inset list metrics (iOS 27 theme vs MD)', () {
    testWidgets('iOS: 16 px margin / 28 px radius, MD: 16 / 16',
        (tester) async {
      late double iosMargin, iosRadius, mdMargin, mdRadius;
      await tester.pumpWidget(app(Builder(builder: (context) {
        iosMargin = ionInsetMargin(context);
        iosRadius = ionInsetRadius(context);
        return const SizedBox();
      })));
      await tester.pumpWidget(app(Builder(builder: (context) {
        mdMargin = ionInsetMargin(context);
        mdRadius = ionInsetRadius(context);
        return const SizedBox();
      }), platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      expect([iosMargin, iosRadius], [16, 28]); // IOS27_SWEEP
      expect([mdMargin, mdRadius], [16, 16]);
    });
  });

  group('Source checks', () {
    test('header tenant switcher is left-aligned (ion-buttons slot=start)', () {
      for (final f in [
        'lib/features/attendance/presentation/pages/attendance_list_page.dart',
        'lib/features/settings/presentation/pages/settings_page.dart',
        'lib/features/people/presentation/pages/people_list_page.dart',
      ]) {
        expect(File(f).readAsStringSync(),
            contains('TenantSwitcherTitle.centerTitle(ref)'),
            reason: f);
      }
    });

    test('notification center: danger unread dot, inset list', () {
      final src = File(
              'lib/features/messages/presentation/widgets/notification_bell.dart')
          .readAsStringSync();
      final row = src.substring(src.indexOf('Widget _buildRow('));
      expect(row, contains('color: AppColors.danger,\n                    shape: BoxShape.circle'));
      expect(src, isNot(contains('ListView.separated(')));
    });

    test('tenant selection shows the create page when there is no instance',
        () {
      final src = File(
              'lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart')
          .readAsStringSync();
      expect(src, contains('TenantCreatePage(canDismiss: false)'));
    });
  });
}
