import 'dart:async';

import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/features/auth/data/auth_flow_service.dart';
import 'package:attendix/features/auth/data/auth_link_listener.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mocks/supabase_mocks.dart';

class _NativeLinks extends AppLinksPlatform {
  final events = StreamController<Uri>.broadcast();
  int consumers = 0;

  @override
  Stream<Uri> get uriLinkStream {
    consumers++;
    return events.stream;
  }
}

void main() {
  testWidgets('the app alone handles cold-start and later native auth links', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final originalPlatform = AppLinksPlatform.instance;
    final links = _NativeLinks();
    AppLinksPlatform.instance = links;
    addTearDown(() => AppLinksPlatform.instance = originalPlatform);
    dotenv.testLoad(
      fileInput:
          'SUPABASE_URL=http://127.0.0.1:1\nSUPABASE_ANON_KEY=local-test-only',
    );
    await tester.runAsync(SupabaseConfig.initialize);
    expect(
      links.consumers,
      0,
      reason: 'Supabase must not race the app for a single-use code',
    );

    final auth = MockGoTrueClient();
    final session = Session(
      accessToken: 'local-token',
      tokenType: 'bearer',
      user: User(
        id: 'test-user',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
    when(() => auth.exchangeCodeForSession('cold-code')).thenAnswer(
      (_) async =>
          AuthSessionUrlResponse(session: session, redirectType: 'signedIn'),
    );
    when(() => auth.exchangeCodeForSession('later-code')).thenAnswer(
      (_) async =>
          AuthSessionUrlResponse(session: session, redirectType: 'signedIn'),
    );
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/tenants',
          builder: (_, __) => const Scaffold(body: Text('Instanzen')),
        ),
      ],
    );
    late WidgetRef ref;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authFlowServiceProvider.overrideWithValue(AuthFlowService(auth)),
          ],
          child: Consumer(
            builder: (context, widgetRef, _) {
              ref = widgetRef;
              return MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      initAuthLinkHandling(ref, router);
      expect(links.consumers, 1);
      // app_links emits the cold-start link as the first stream event.
      links.events.add(Uri.parse('https://attendix.de/login?code=cold-code'));
      await tester.pumpAndSettle();
      expect(find.text('Instanzen'), findsOneWidget);
      verify(() => auth.exchangeCodeForSession('cold-code')).called(1);
      router.go('/login');
      await tester.pumpAndSettle();
      links.events.add(Uri.parse('https://attendix.de/login?code=later-code'));
      await tester.pumpAndSettle();
      expect(find.text('Instanzen'), findsOneWidget);
      verify(() => auth.exchangeCodeForSession('later-code')).called(1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.runAsync(() async {
        await links.events.close();
        await Supabase.instance.dispose();
      });
    }
  });
}
