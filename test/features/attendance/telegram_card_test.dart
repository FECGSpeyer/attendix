import 'dart:convert';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/services/offline_queue_service.dart'
    show rootScaffoldMessengerKey;
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/utils/demo_guard.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/data/repositories/base_repository.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, GoTrueClient, SupabaseClient, User;

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DemoGuard.demoMailOverride = null;
  });

  group('AttendanceRepository.createTelegramCardLink (Ionic 4.19.24)', () {
    SupabaseClient buildClient({
      required List<({String method, String path, String body})> requests,
      required bool attendanceInTenant,
      Map<String, dynamic>? botResponse,
      int botStatus = 200,
    }) {
      final client = MockClient((request) async {
        const jsonHeaders = {'content-type': 'application/json'};
        requests.add((
          method: request.method,
          path: '${request.url.path}?${request.url.query}',
          body: request.body,
        ));

        if (request.method == 'GET' && request.url.path.endsWith('/attendance')) {
          if (!attendanceInTenant) {
            return http.Response(
              jsonEncode({
                'code': 'PGRST116',
                'details': 'The result contains 0 rows',
                'message': 'no rows',
              }),
              406,
              headers: jsonHeaders,
              request: request,
            );
          }
          return http.Response(
            jsonEncode({'id': 77}),
            200,
            headers: jsonHeaders,
            request: request,
          );
        }

        if (request.method.toUpperCase() == 'POST' &&
            request.url.path.endsWith('/functions/v1/attendix-bot')) {
          return http.Response(
            jsonEncode(botResponse ?? const {}),
            botStatus,
            headers: jsonHeaders,
            request: request,
          );
        }

        return http.Response('[]', 200, headers: jsonHeaders, request: request);
      });

      return SupabaseClient(
        'https://api.attendix.de',
        'test-key',
        httpClient: client,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    }

    test('validates attendance tenant and returns signed Telegram https URL', () async {
      final requests = <({String method, String path, String body})>[];
      final supabase = buildClient(
        requests: requests,
        attendanceInTenant: true,
        botResponse: const {'url': 'https://t.me/attendix_bot?startgroup=signed123'},
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(supabase)],
      );
      addTearDown(container.dispose);

      final repo = container.read(attendanceRepositoryForTenantProvider(42));
      final url = await repo.createTelegramCardLink(77);

      expect(url, 'https://t.me/attendix_bot?startgroup=signed123');
      expect(requests, hasLength(2));
      expect(requests[0].method, 'GET');
      expect(requests[0].path, contains('id=eq.77'));
      expect(requests[0].path, contains('tenantId=eq.42'));
      expect(requests[1].method.toUpperCase(), 'POST');
      expect(requests[1].path, contains('/functions/v1/attendix-bot'));
      expect(
        jsonDecode(requests[1].body),
        const {'action': 'card_link', 'attendanceId': 77},
      );
    });

    test('returns null when response omits url', () async {
      final requests = <({String method, String path, String body})>[];
      final supabase = buildClient(
        requests: requests,
        attendanceInTenant: true,
        botResponse: const {'ok': true},
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(supabase)],
      );
      addTearDown(container.dispose);

      final repo = container.read(attendanceRepositoryForTenantProvider(42));
      expect(await repo.createTelegramCardLink(77), isNull);
    });

    test('returns null for non-http(s) url schemes such as javascript:', () async {
      final requests = <({String method, String path, String body})>[];
      final supabase = buildClient(
        requests: requests,
        attendanceInTenant: true,
        botResponse: const {'url': 'javascript:alert(1)'},
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(supabase)],
      );
      addTearDown(container.dispose);

      final repo = container.read(attendanceRepositoryForTenantProvider(42));
      expect(await repo.createTelegramCardLink(77), isNull);
    });

    test('throws without invoking attendix-bot when attendance is outside tenant', () async {
      final requests = <({String method, String path, String body})>[];
      final supabase = buildClient(
        requests: requests,
        attendanceInTenant: false,
        botResponse: const {'url': 'https://t.me/attendix_bot?startgroup=signed123'},
      );
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(supabase)],
      );
      addTearDown(container.dispose);

      final repo = container.read(attendanceRepositoryForTenantProvider(42));
      await expectLater(
        () => repo.createTelegramCardLink(77),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        requests.where((r) => r.path.contains('attendix-bot')),
        isEmpty,
      );
    });

    test('throws DemoModeException without calling DB or attendix-bot in demo mode', () async {
      DemoGuard.demoMailOverride = 'demo@attendix.test';
      final requests = <({String method, String path, String body})>[];
      final rawClient = buildClient(
        requests: requests,
        attendanceInTenant: true,
        botResponse: const {'url': 'https://t.me/attendix_bot?startgroup=signed123'},
      );
      final mockAuth = _MockGoTrueClient();
      when(() => mockAuth.currentUser).thenReturn(
        const User(
          id: 'demo-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          email: 'demo@attendix.test',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      final spyClient = _AuthOverrideSupabaseClient(rawClient, mockAuth);

      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(spyClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(attendanceRepositoryForTenantProvider(42));
      await expectLater(
        () => repo.createTelegramCardLink(77),
        throwsA(isA<DemoModeException>()),
      );
      expect(requests, isEmpty);
    });

    testWidgets('Telegram card confirmation dialog displays localized texts', (tester) async {
      late BuildContext rootContext;
      var opened = false;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                rootContext = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final dialog = showAppDialog<void>(
        context: rootContext,
        builder: (ctx) => AppAlertDialog(
          title: Text(ctx.l10n.attendanceTelegramCard),
          content: Text(ctx.l10n.attendanceTelegramCardHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                opened = true;
                Navigator.of(ctx).pop();
              },
              child: Text(ctx.l10n.attendanceTelegramCardOpen),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Als Telegram-Karte senden'), findsOneWidget);
      expect(find.textContaining('@attendix_bot'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.text('Telegram öffnen'), findsOneWidget);

      await tester.tap(find.text('Telegram öffnen'));
      await tester.pumpAndSettle();
      await dialog;

      expect(opened, isTrue);
    });
  });
}

class _AuthOverrideSupabaseClient extends Fake implements SupabaseClient {
  _AuthOverrideSupabaseClient(this._inner, this._auth);

  final SupabaseClient _inner;
  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;

  @override
  dynamic noSuchMethod(Invocation invocation) => _inner.noSuchMethod(invocation);
}
