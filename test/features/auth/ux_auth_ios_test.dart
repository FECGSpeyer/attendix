import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/auth/presentation/widgets/otp_widgets.dart';
import 'package:attendix/shared/widgets/redesign/rd_widgets.dart';
import 'package:attendix/features/tenant_selection/presentation/pages/tenant_create_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/source_reader.dart';

void main() {
  Widget app(Widget child, {TargetPlatform platform = TargetPlatform.iOS}) =>
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('AuthModeSegment', () {
    testWidgets('labels only, no icons; tap switches the mode', (tester) async {
      var mode = AuthMode.password;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: StatefulBuilder(
              builder:
                  (context, setState) => AuthModeSegment(
                    mode: mode,
                    onChanged: (m) => setState(() => mode = m),
                  ),
            ),
          ),
        ),
      );
      expect(find.text('Passwort'), findsOneWidget);
      expect(find.text('Code per E-Mail'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      await tester.tap(find.text('Code per E-Mail'));
      await tester.pump();
      expect(mode, AuthMode.otp);
    });
  });

  group('OtpCodeField', () {
    testWidgets('six boxes, label below, completes after six digits', (
      tester,
    ) async {
      await setPhone(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? completed;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: OtpCodeField(
                controller: controller,
                onCompleted: (v) => completed = v,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Code aus der E-Mail'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      expect(completed, '123456');
      for (final d in ['1', '2', '3', '4', '5', '6']) {
        expect(find.text(d), findsOneWidget);
      }
    });
  });

  testWidgets(
    'OtpCodeField keeps a text field semantics node (web a11y tree)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await setPhone(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        app(
          Scaffold(body: Center(child: OtpCodeField(controller: controller))),
        ),
      );
      expect(
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().flagsCollection.isTextField,
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  group('Neue Gruppe anlegen', () {
    testWidgets('dismissable: cancel button, no account menu', (tester) async {
      await setPhone(tester);
      await tester.pumpWidget(app(const TenantCreatePage()));
      await tester.pumpAndSettle();
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.byKey(const ValueKey('register-account-menu')), findsNothing);
    });

    testWidgets(
      'guide starts with type cards and reveals grouped identity fields',
      (tester) async {
        tester.view.physicalSize = const Size(393, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(const TenantCreatePage()));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('rd-tenant-type-orchestra')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('rd-tenant-type-choir')), findsOneWidget);
        expect(find.byKey(const Key('rd-tenant-type-general')), findsOneWidget);
        expect(find.byKey(const Key('rd-tenant-new-name')), findsNothing);
        await tester.tap(find.byKey(const Key('rd-tenant-type-orchestra')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rd-tenant-guide-next')));
        await tester.pumpAndSettle();
        expect(find.byType(RdGroupedList), findsOneWidget);
        expect(find.byKey(const Key('rd-tenant-new-name')), findsOneWidget);
        expect(find.byKey(const Key('rd-tenant-new-short')), findsOneWidget);
        expect(find.byKey(const Key('rd-tenant-new-main')), findsNothing);
      },
    );
  });

  test('notification center does not use ListView.separated', () {
    final src = readDartLibrary(
      'lib/features/messages/presentation/widgets/notification_bell.dart',
    );
    expect(src, isNot(contains('ListView.separated(')));
  });
}
