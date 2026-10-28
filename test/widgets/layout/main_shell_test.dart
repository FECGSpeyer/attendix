import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/widget_test_helpers.dart';

// Create a simple router for testing
GoRouter _createTestRouter({String initialLocation = '/people'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/people',
            builder: (context, state) => const Placeholder(key: Key('people_page')),
          ),
          GoRoute(
            path: '/overview',
            builder: (context, state) => const Placeholder(key: Key('overview_page')),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const Placeholder(key: Key('attendance_page')),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Placeholder(key: Key('settings_page')),
          ),
          GoRoute(
            path: '/members',
            builder: (context, state) => const Placeholder(key: Key('members_page')),
          ),
          GoRoute(
            path: '/parents',
            builder: (context, state) => const Placeholder(key: Key('parents_page')),
          ),
        ],
      ),
    ],
  );
}

/// Mock notifier for currentTenantProvider
class MockCurrentTenantNotifier extends CurrentTenantNotifier {
  MockCurrentTenantNotifier(super.ref, this._tenant);

  final Tenant? _tenant;

  @override
  Tenant? build() => _tenant;

  @override
  Future<void> setTenant(Tenant? tenant) async {}

  @override
  Future<void> loadFromPrefs() async {}
}

void main() {
  widgetTestGroup('MainShell', () {
    group('navigation destinations for different roles', () {
      widgetTest('admin sees Personen, Termine, Mehr tabs', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/people',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.admin),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Admin (conductor-like role) should see: Personen, Termine, Mehr
        expect(find.text('Personen'), findsOneWidget);
        expect(find.text('Termine'), findsOneWidget);
        expect(find.text('Mehr'), findsOneWidget);
        // But not: Meine Termine (self-service)
        expect(find.text('Meine Termine'), findsNothing);
      });

      widgetTest('player sees Meine Termine, Mehr tabs', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/overview',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.player),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Player should see: Meine Termine, Mehr
        expect(find.text('Meine Termine'), findsOneWidget);
        expect(find.text('Mehr'), findsOneWidget);
        // But not: Personen, Anwesenheit (admin-only)
        expect(find.text('Personen'), findsNothing);
        expect(find.text('Termine'), findsNothing);
      });

      widgetTest('helper sees Meine Termine, Termine, Mehr tabs', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/overview',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.helper),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Helper should see: Meine Termine, Termine, Mehr
        expect(find.text('Meine Termine'), findsOneWidget);
        expect(find.text('Termine'), findsOneWidget);
        expect(find.text('Mehr'), findsOneWidget);
        // But not: Personen (admin-only)
        expect(find.text('Personen'), findsNothing);
      });

      widgetTest('parent sees Termine tab', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/parents',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.parent),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Parent should see: Termine (parents portal), Einstellungen
        expect(find.text('Termine'), findsOneWidget);
        expect(find.text('Mehr'), findsOneWidget);
      });
    });

    group('NavigationBar presence', () {
      widgetTest('renders NavigationBar widget', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/people',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.admin),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
      });

      widgetTest('renders child widget', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/people',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.admin),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // The actual child is from the router
        expect(find.byType(Placeholder), findsOneWidget);
      });
    });

    group('Mitglieder tab visibility', () {
      // Note: Mitglieder tab requires both:
      // 1. role.canSeeMembersTab (player, helper, voiceLeader)
      // 2. tenant?.showMembersList == true
      // This is tested via integration tests since it requires complex provider setup

      widgetTest('player without tenant does not see Mitglieder', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/overview',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.player),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Player without tenant should NOT see Mitglieder
        expect(find.text('Mitglieder'), findsNothing);
      });
    });

    group('navigation icons', () {
      widgetTest('uses correct icons for navigation destinations', (tester) async {
        final router = _createTestRouter(
          initialLocation: '/people',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.admin),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Check for icons
        // Ionic tabs.page.html: people-outline, checkbox-outline,
        // ellipsis-horizontal ("Mehr")
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      });

      widgetTest('admin tab order matches Ionic (Personen, Termine, Mehr)',
          (tester) async {
        final router = _createTestRouter(initialLocation: '/people');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveRoleProvider.overrideWithValue(Role.admin),
              currentTenantProvider.overrideWith((ref) => MockCurrentTenantNotifier(ref, null)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        final labels = tester
            .widgetList<NavigationDestination>(find.byType(NavigationDestination))
            .map((d) => d.label)
            .toList();
        expect(labels, ['Personen', 'Termine', 'Mehr']);
      });
    });
  });
}
