import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/demo_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart'
    show rootScaffoldMessengerKey;
import 'package:attendix/core/utils/demo_guard.dart';
import 'package:attendix/core/utils/toast_helper.dart';
import 'package:attendix/data/repositories/base_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestRepo extends BaseRepository {
  _TestRepo(super.ref);
}

final _testRepoProvider = Provider<_TestRepo>((ref) => _TestRepo(ref));

User _user(String email) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
      email: email,
    );

void main() {
  const demoMail = 'demo@attendix.de';

  setUp(() {
    DemoGuard.resetForTest();
    DemoGuard.demoMailOverride = demoMail;
  });

  tearDown(DemoGuard.resetForTest);

  group('DemoGuard.isDemoEmail (Ionic isDemo)', () {
    test('matches the demo mail case-insensitively', () {
      expect(DemoGuard.isDemoEmail('demo@attendix.de'), isTrue);
      expect(DemoGuard.isDemoEmail(' Demo@Attendix.DE '), isTrue);
    });

    test('other users and anonymous are not demo', () {
      expect(DemoGuard.isDemoEmail('leon@example.com'), isFalse);
      expect(DemoGuard.isDemoEmail(null), isFalse);
    });

    test('no configured demo mail -> never demo', () {
      DemoGuard.demoMailOverride = '';
      expect(DemoGuard.isDemoEmail(''), isFalse);
      expect(DemoGuard.isDemoEmail('demo@attendix.de'), isFalse);
    });
  });

  group('DemoGuard.check (Ionic checkDemoRestriction)', () {
    test('throws DemoModeException with the Ionic text for the demo user', () {
      expect(
        () => DemoGuard.check(demoMail, 'createPlayer'),
        throwsA(isA<DemoModeException>()
            .having((e) => e.operation, 'operation', 'createPlayer')
            .having((e) => e.toString(), 'text',
                'Diese Funktion ist im Demo-Modus nicht verfügbar.')),
      );
      expect(DemoGuard.recentlyShown, isTrue);
    });

    test('does nothing for normal users', () {
      DemoGuard.check('leon@example.com', 'createPlayer');
      expect(DemoGuard.recentlyShown, isFalse);
    });

    test('blocked() is false when Supabase has no demo session', () {
      // Supabase is not initialised in tests -> no current user.
      expect(DemoGuard.blocked(), isFalse);
    });
  });

  group('BaseRepository', () {
    test('ensureNotDemo is a no-op without a demo session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(_testRepoProvider);
      expect(() => repo.ensureNotDemo('createPlayer'), returnsNormally);
      expect(repo.isDemo, isFalse);
    });

    test('handleError keeps DemoModeException typed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(_testRepoProvider);
      expect(
        () => repo.handleError<void>(
            const DemoModeException('x'), StackTrace.current, 'x'),
        throwsA(isA<DemoModeException>()),
      );
      expect(
        () => repo.handleError<void>(Exception('boom'), StackTrace.current, 'x'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('isDemoProvider', () {
    test('true for the demo account', () async {
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_user(demoMail))),
      ]);
      addTearDown(container.dispose);
      container.listen(isDemoProvider, (_, __) {});
      await container.read(currentUserProvider.future);
      expect(container.read(isDemoProvider), isTrue);
    });

    test('false for other accounts', () async {
      final container = ProviderContainer(overrides: [
        currentUserProvider
            .overrideWith((ref) => Stream.value(_user('leon@example.com'))),
      ]);
      addTearDown(container.dispose);
      container.listen(isDemoProvider, (_, __) {});
      await container.read(currentUserProvider.future);
      expect(container.read(isDemoProvider), isFalse);
    });
  });

  group('Toasts', () {
    Future<BuildContext> pumpApp(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
      return ctx;
    }

    testWidgets('blocked mutation shows the Ionic warning toast',
        (tester) async {
      await pumpApp(tester);
      expect(() => DemoGuard.check(demoMail), throwsA(isA<DemoModeException>()));
      await tester.pump();
      expect(find.text(kDemoRestrictedMessage), findsOneWidget);
    });

    testWidgets('follow-up error/success toasts are swallowed',
        (tester) async {
      final ctx = await pumpApp(tester);
      DemoGuard.showRestrictedToast();
      ToastHelper.showError(ctx, 'Fehler beim Speichern');
      ToastHelper.showSuccess(ctx, 'Gespeichert');
      await tester.pump();
      expect(find.text('Fehler beim Speichern'), findsNothing);
      expect(find.text('Gespeichert'), findsNothing);
      expect(find.text(kDemoRestrictedMessage), findsOneWidget);
    });

    testWidgets('error text containing the demo message shows as warning',
        (tester) async {
      final ctx = await pumpApp(tester);
      ToastHelper.showError(ctx, 'Fehler: $kDemoRestrictedMessage');
      await tester.pump();
      expect(find.text(kDemoRestrictedMessage), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });
  });
}
