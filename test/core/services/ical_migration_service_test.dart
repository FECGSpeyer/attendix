import 'dart:convert';

import 'package:attendix/core/services/ical_migration_service.dart';
import 'package:attendix/core/services/offline_queue_service.dart'
    show rootScaffoldMessengerKey;
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

void main() {
  group('legacy iCal migration helpers', () {
    test('legacyIcalHitId groups variations of the same calendar feed without "null"', () {
      final hitA = LegacyIcalHit(
        fn: 'ical-personal',
        query: 'tenantId=12&personId=99&hideExcused=1&lang=en',
        lastSeen: DateTime.utc(2026, 11, 21, 10),
      );
      final hitB = LegacyIcalHit(
        fn: 'ical-personal',
        query: 'tenantId=12&personId=99',
        lastSeen: DateTime.utc(2026, 11, 22, 10),
      );
      final orgHit = LegacyIcalHit(
        fn: 'ical-tenant',
        query: 'tenantId=12&key=abc&detailed=1',
        lastSeen: DateTime.utc(2026, 11, 21, 10),
      );

      expect(legacyIcalHitId(hitA), 'ical-personal|12|99||');
      expect(legacyIcalHitId(hitB), legacyIcalHitId(hitA));
      expect(legacyIcalHitId(orgHit), 'ical-tenant|12||abc|1');
    });

    test('uniqueLegacyIcalFeeds keeps the newest entry per calendar and caps at 3', () {
      final hits = [
        LegacyIcalHit(
          fn: 'ical-personal',
          query: 'tenantId=1&personId=10&lang=de',
          lastSeen: DateTime.utc(2026, 11, 20),
        ),
        LegacyIcalHit(
          fn: 'ical-personal',
          query: 'tenantId=1&personId=10&lang=en',
          lastSeen: DateTime.utc(2026, 11, 22),
        ),
        LegacyIcalHit(
          fn: 'ical-tenant',
          query: 'tenantId=1',
          lastSeen: DateTime.utc(2026, 11, 21),
        ),
        LegacyIcalHit(
          fn: 'ical-tenant',
          query: 'tenantId=2',
          lastSeen: DateTime.utc(2026, 11, 21),
        ),
        LegacyIcalHit(
          fn: 'ical-tenant',
          query: 'tenantId=3',
          lastSeen: DateTime.utc(2026, 11, 21),
        ),
      ];

      final unique = uniqueLegacyIcalFeeds(hits);
      expect(unique, hasLength(3));
      expect(unique.first.query, 'tenantId=1&personId=10&lang=en');
    });

    test('filterOpenLegacyIcalHits suppresses within 2 days and re-shows afterwards', () {
      final hit = LegacyIcalHit(
        fn: 'ical-personal',
        query: 'tenantId=7&personId=3',
        lastSeen: DateTime.utc(2026, 11, 23, 12),
      );
      final id = legacyIcalHitId(hit);

      expect(filterOpenLegacyIcalHits([hit], const {}), hasLength(1));

      final dismissedRecently =
          hit.lastSeen.subtract(const Duration(hours: 47)).millisecondsSinceEpoch;
      expect(filterOpenLegacyIcalHits([hit], {id: dismissedRecently}), isEmpty);

      final dismissedTwoDaysAgo =
          hit.lastSeen.subtract(kIcalMigrationReshowAfter).millisecondsSinceEpoch;
      expect(
        filterOpenLegacyIcalHits([hit], {id: dismissedTwoDaysAgo}),
        hasLength(1),
      );
    });

    test('legacyIcalReplacementLink points to configured baseUrl', () {
      final hit = LegacyIcalHit(
        fn: 'ical-tenant',
        query: 'tenantId=7',
        lastSeen: DateTime.utc(2026, 11, 22),
      );
      expect(
        legacyIcalReplacementLink(hit, baseUrl: 'https://api.attendix.de'),
        'https://api.attendix.de/functions/v1/ical-tenant?tenantId=7',
      );
    });
  });

  group('IcalMigrationService & dialog', () {
    setUp(() {
      IcalMigrationService.instance.reset();
    });

    testWidgets('checkOnce calls RPC once, copies without closing, saves on Done',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final copiedTexts = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedTexts.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      var rpcCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/rpc/my_ical_legacy_hits')) {
          rpcCalls++;
          return http.Response(
            jsonEncode([
              {
                'fn': 'ical-personal',
                'query': 'tenantId=12&personId=5',
                'last_seen': '2026-11-23T10:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('[]', 200, request: request);
      });
      final supabase = SupabaseClient(
        'https://api.attendix.de',
        'test-key',
        httpClient: client,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final launchedUris = <Uri>[];
      late BuildContext rootContext;

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

      final checkFuture = IcalMigrationService.instance.checkOnce(
        supabase: supabase,
        contextResolver: () => rootContext,
        prefs: prefs,
        baseUrl: 'https://api.attendix.de',
        openGuide: (uri) async => launchedUris.add(uri),
      );
      await tester.pumpAndSettle();

      expect(rpcCalls, 1);
      expect(find.text('Kalender-Abo neu einrichten'), findsOneWidget);
      expect(
        find.textContaining(
          'https://api.attendix.de/functions/v1/ical-personal?tenantId=12&personId=5',
        ),
        findsOneWidget,
      );

      // Copy keeps dialog open.
      await tester.tap(find.text('Link kopieren'));
      await tester.pump();
      expect(
        copiedTexts,
        ['https://api.attendix.de/functions/v1/ical-personal?tenantId=12&personId=5'],
      );
      expect(find.text('Kalender-Abo neu einrichten'), findsOneWidget);

      // Open guide keeps dialog open.
      await tester.tap(find.text('Anleitung öffnen'));
      await tester.pump();
      expect(launchedUris, [Uri.parse('https://support.apple.com/de-de/102301')]);
      expect(find.text('Kalender-Abo neu einrichten'), findsOneWidget);

      // Done persists dismissal and closes dialog.
      await tester.tap(find.text('Erledigt'));
      await tester.pumpAndSettle();
      await checkFuture;

      expect(find.text('Kalender-Abo neu einrichten'), findsNothing);
      final stored =
          jsonDecode(prefs.getString(kIcalMigrationDismissedKey)!) as Map<String, dynamic>;
      expect(stored.containsKey('ical-personal|12|5||'), isTrue);

      // Calling checkOnce a second time in the same session is a no-op.
      await IcalMigrationService.instance.checkOnce(
        supabase: supabase,
        contextResolver: () => rootContext,
        prefs: prefs,
        baseUrl: 'https://api.attendix.de',
      );
      expect(rpcCalls, 1);

      // Wait out GlobalToast 3s auto-hide timer before test teardown.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('showIcalMigrationDialog shows numbered links and copy buttons for multiple feeds',
        (tester) async {
      var dismissedCalled = false;
      late BuildContext rootContext;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.forPlatform(Brightness.light, TargetPlatform.android),
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

      final dialogFuture = showIcalMigrationDialog(
        rootContext,
        [
          LegacyIcalHit(
            fn: 'ical-personal',
            query: 'tenantId=1&personId=2',
            lastSeen: DateTime.utc(2026, 11, 23),
          ),
          LegacyIcalHit(
            fn: 'ical-tenant',
            query: 'tenantId=9',
            lastSeen: DateTime.utc(2026, 11, 23),
          ),
        ],
        baseUrl: 'https://api.attendix.de',
        onDismissed: (_) async {
          dismissedCalled = true;
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Link 1 kopieren'), findsOneWidget);
      expect(find.text('Link 2 kopieren'), findsOneWidget);
      expect(find.textContaining('1. https://api.attendix.de/functions/v1/ical-personal?tenantId=1&personId=2'), findsOneWidget);
      expect(find.textContaining('2. https://api.attendix.de/functions/v1/ical-tenant?tenantId=9'), findsOneWidget);

      await tester.tap(find.text('Später'));
      await tester.pumpAndSettle();
      await dialogFuture;

      expect(dismissedCalled, isFalse);
      expect(find.text('Kalender-Abo neu einrichten'), findsNothing);
    });

    test('checkOnce ignores RPC errors without throwing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'rpc unavailable'}),
          500,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final supabase = SupabaseClient(
        'https://api.attendix.de',
        'test-key',
        httpClient: client,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await IcalMigrationService.instance.checkOnce(
        supabase: supabase,
        contextResolver: () => null,
        prefs: prefs,
      );
      expect(IcalMigrationService.instance.hasChecked, isTrue);
    });
  });
}
