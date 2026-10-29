import 'dart:io';

import 'package:attendix/core/router/legacy_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

String? _r(String location) => legacyRouteRedirect(Uri.parse(location));

void main() {
  group('legacyRouteRedirect – Ionic /tabs table', () {
    const table = <String, String>{
      // tabs-routing.module.ts
      '/tabs': kOpenLinkRoute,
      '/tabs/': kOpenLinkRoute,
      '/tabs/signout': '/signout',
      '/tabs/overview': '/overview',
      '/tabs/members': '/members',
      '/tabs/player': '/people',
      '/tabs/attendance': '/attendance',
      '/tabs/attendance/42': '/attendance/42',
      '/tabs/attendance/42/protocol': '/settings/protocol/42',
      '/tabs/songs-tab': '/songs-tab',
      '/tabs/songs-tab/7': '/settings/songs/7',
      '/tabs/settings': '/settings',
      '/tabs/settings/teachers': '/settings/teachers',
      '/tabs/settings/instruments': '/settings/instruments',
      '/tabs/settings/songs': '/settings/songs',
      '/tabs/settings/songs/7': '/settings/songs/7',
      '/tabs/settings/files': '/settings/files',
      '/tabs/settings/meetings': '/settings/team-organization',
      '/tabs/settings/agenda-items': '/settings/team-organization',
      '/tabs/settings/agenda-items/3': '/settings/agenda-items/3',
      '/tabs/settings/tasks': '/settings/team-organization',
      '/tabs/settings/tasks/9': '/settings/tasks/9',
      '/tabs/settings/team-organization': '/settings/team-organization',
      '/tabs/settings/messages': '/settings/messages',
      '/tabs/messages/5': '/messages/5',
      '/tabs/settings/notifications': '/settings/notifications',
      '/tabs/settings/register': '/tenants/new',
      '/tabs/settings/handover': '/settings/handover',
      '/tabs/settings/handover/detail': '/settings/handover/detail',
      '/tabs/settings/general': '/settings/general',
      '/tabs/settings/general/types': '/settings/types',
      '/tabs/settings/general/types/12': '/settings/types/12',
      '/tabs/settings/general/branding': '/settings/general/branding',
      '/tabs/settings/general/extra-fields': '/settings/general/extra-fields',
      '/tabs/settings/voice-leader': '/settings/voice-leader',
      '/tabs/settings/role-permissions': '/settings/role-permissions',
      '/tabs/settings/delete-account': '/settings/delete-account',
      '/tabs/settings/help': '/settings/help',
      '/tabs/settings/help/article/abc': '/settings/help/article/abc',
      '/tabs/settings/help/glossary': '/settings/help/glossary',
      '/tabs/org-plans': '/org-plans-tab',
      '/tabs/org-plans/planung': '/settings/org-plans/planung',
      '/tabs/settings/org-plans': '/settings/org-plans',
      '/tabs/settings/org-plans/planung': '/settings/org-plans/planung',
      '/tabs/settings/org-settings': '/settings/org-settings',
      '/tabs/settings/org-settings/branding': '/settings/org-settings',
      '/tabs/settings/org-settings/planning-templates':
          '/settings/org-settings/planning-templates',
      '/tabs/settings/planung': '/settings/planung',
      '/tabs/settings/administration': '/settings/administration',
      '/tabs/dashboard': '/dashboard',
      '/tabs/home-dashboard': '/home-dashboard',
      '/tabs/settings/dashboard': '/settings/dashboard',
      '/tabs/parents': '/parents',
      '/tabs/unknown-tab': kOpenLinkRoute,
      // links built by supabase/functions
      '/tabs/list': '/attendance', // evaluate-critical-rules
      '/resetPassword': '/new-password', // attendix-user
    };

    for (final entry in table.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(_r(entry.key), entry.value);
      });
    }

    test('keeps query parameters (tenantId, tab)', () {
      expect(_r('/tabs/list?tenantId=3'), '/attendance?tenantId=3');
      expect(_r('/tabs/attendance/42?tenantId=3'), '/attendance/42?tenantId=3');
      expect(_r('/tabs/settings/team-organization?tab=topics'),
          '/settings/team-organization?tab=topics');
    });

    test('non-legacy locations are left alone', () {
      for (final p in [
        '/login',
        '/attendance/1',
        '/open-attendance?id=1&tenantId=2',
        '/abc123',
        '/abc123/song-1',
        '/tabsfoo',
        '/planung',
      ]) {
        expect(_r(p), isNull, reason: p);
      }
    });

    test('every mapped target is a tenant scoped route or a known page', () {
      for (final target in table.values) {
        final path = Uri.parse(target).path;
        expect(
          isTenantScopedRoute(path) ||
              path == kOpenLinkRoute ||
              path == '/new-password' ||
              path == '/tenants/new',
          isTrue,
          reason: target,
        );
      }
    });
  });

  group('tenant link helpers', () {
    test('isTenantScopedRoute', () {
      expect(isTenantScopedRoute('/attendance'), isTrue);
      expect(isTenantScopedRoute('/attendance/5'), isTrue);
      expect(isTenantScopedRoute('/settings/general'), isTrue);
      expect(isTenantScopedRoute('/tenants'), isFalse);
      expect(isTenantScopedRoute('/login'), isFalse);
      expect(isTenantScopedRoute('/open-attendance'), isFalse);
      expect(isTenantScopedRoute('/peoplex'), isFalse);
      expect(isTenantScopedRoute('/abc/def'), isFalse);
    });

    test('isTenantScopedRoute: every tab of the new design with subpages', () {
      for (final path in [
        '/heute',
        '/termine',
        '/termine/12',
        '/termine/meine/pa-1',
        '/mitglieder',
        '/mitglieder/5',
        '/werke',
        '/werke/7',
        '/ich',
        '/ich/darstellung',
        '/ich/verwaltung/proben',
      ]) {
        expect(isTenantScopedRoute(path), isTrue, reason: path);
      }
      expect(isTenantScopedRoute('/mitgliederx'), isFalse);
      expect(isTenantScopedRoute('/werkex'), isFalse);
      expect(sanitizeOpenLinkTarget('/mitglieder/5'), '/mitglieder/5');
      expect(sanitizeOpenLinkTarget('/werke/7?tab=noten'), '/werke/7?tab=noten');
      expect(openLinkLocation(Uri.parse('/werke/7?tenantId=3'), tenantId: '3'),
          openLinkLocation(Uri.parse('/werke/7'), tenantId: '3'));
    });

    test('openLinkLocation moves tenantId out of the target', () {
      final loc = openLinkLocation(Uri.parse('/attendance/5?tenantId=3&x=1'),
          tenantId: '3');
      final uri = Uri.parse(loc);
      expect(uri.path, kOpenLinkRoute);
      expect(uri.queryParameters['tenantId'], '3');
      expect(uri.queryParameters[kOpenLinkTargetParam], '/attendance/5?x=1');
    });

    test('sanitizeOpenLinkTarget only allows in-app paths', () {
      expect(sanitizeOpenLinkTarget('/attendance/5'), '/attendance/5');
      expect(sanitizeOpenLinkTarget('/settings?x=1'), '/settings?x=1');
      expect(sanitizeOpenLinkTarget(null), isNull);
      expect(sanitizeOpenLinkTarget(''), isNull);
      expect(sanitizeOpenLinkTarget('https://evil.example'), isNull);
      expect(sanitizeOpenLinkTarget('//evil.example/attendance'), isNull);
      expect(sanitizeOpenLinkTarget('/login'), isNull);
    });
  });

  group('legacyPathToHashUrl (hash URL strategy)', () {
    String? h(String url) => legacyPathToHashUrl(Uri.parse(url));

    test('path links become hash routes', () {
      expect(h('https://attendix.de/tabs/messages/5'), '/#/tabs/messages/5');
      expect(h('https://attendix.de/tabs/list?tenantId=3'),
          '/#/tabs/list?tenantId=3');
      expect(h('https://attendix.de/open-attendance?id=1&tenantId=2'),
          '/#/open-attendance?id=1&tenantId=2');
      expect(h('https://attendix.de/resetPassword'), '/#/resetPassword');
    });

    test('root, hash routes, auth fragments and files stay untouched', () {
      expect(h('https://attendix.de/'), isNull);
      expect(h('https://attendix.de/?code=abc'), isNull);
      expect(h('https://attendix.de/#/tabs/list'), isNull);
      expect(h('https://attendix.de/resetPassword#access_token=x&type=recovery'),
          isNull);
      expect(h('https://attendix.de/manifest.json'), isNull);
    });

    test('respects a non-root base href', () {
      expect(
        legacyPathToHashUrl(Uri.parse('https://x.de/app/tabs/player'),
            basePath: '/app/'),
        '/app/#/tabs/player',
      );
    });
  });

  group('GoRouter: legacy links win over the public song share routes', () {
    Future<String> open(WidgetTester tester, String location) async {
      final router = GoRouter(
        initialLocation: location,
        redirect: (context, state) => legacyRouteRedirect(state.uri),
        routes: [
          GoRoute(path: '/attendance', builder: (_, s) => Text('list ${s.uri}')),
          GoRoute(
              path: '/attendance/:id',
              builder: (_, s) => Text('detail ${s.pathParameters['id']}')),
          GoRoute(
              path: '/messages/:id',
              builder: (_, s) => Text('message ${s.pathParameters['id']}')),
          GoRoute(path: '/new-password', builder: (_, __) => const Text('pw')),
          GoRoute(
            path: '/:songSharingId',
            builder: (_, __) => const Text('share'),
            routes: [
              GoRoute(path: ':songId', builder: (_, __) => const Text('song')),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router.routerDelegate.currentConfiguration.uri.toString();
    }

    testWidgets('/tabs/list?tenantId= opens the Termine list', (tester) async {
      expect(await open(tester, '/tabs/list?tenantId=3'),
          '/attendance?tenantId=3');
      expect(find.text('list /attendance?tenantId=3'), findsOneWidget);
    });

    testWidgets('/tabs/messages/:id opens the Mitteilung', (tester) async {
      expect(await open(tester, '/tabs/messages/5'), '/messages/5');
      expect(find.text('message 5'), findsOneWidget);
    });

    testWidgets('/tabs/attendance/:id opens the Termin', (tester) async {
      expect(await open(tester, '/tabs/attendance/9'), '/attendance/9');
      expect(find.text('detail 9'), findsOneWidget);
    });

    testWidgets('/resetPassword opens "Neues Passwort"', (tester) async {
      expect(await open(tester, '/resetPassword'), '/new-password');
    });

    testWidgets('song share links still work', (tester) async {
      expect(await open(tester, '/abc/def'), '/abc/def');
      expect(find.text('song'), findsOneWidget);
    });
  });

  group('app_router wiring (source analysis)', () {
    final source = File('lib/core/router/app_router.dart').readAsStringSync();

    test('legacy table runs before the public song routes check', () {
      final legacy = source.indexOf('legacyRouteRedirect(state.uri)');
      final publicSongs = source.indexOf('if (_isPublicSongsRoute(state))');
      expect(legacy, greaterThan(0));
      expect(publicSongs, greaterThan(legacy));
    });

    test('open-link route is registered before /:songSharingId', () {
      final openLink = source.indexOf('path: kOpenLinkRoute');
      final share = source.indexOf("path: '/:songSharingId'");
      expect(openLink, greaterThan(0));
      expect(share, greaterThan(openLink));
    });

    test('?tenantId= on in-app routes goes through the tenant resolver', () {
      expect(source, contains("state.uri.queryParameters['tenantId']"));
      expect(source, contains('openLinkLocation(state.uri, tenantId: linkTenantId)'));
    });
  });
}
