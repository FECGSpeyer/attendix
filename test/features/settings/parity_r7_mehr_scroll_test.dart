// PARITY_R7: iOS "Mehr" scrolled to the end keeps the last rows above the
// floating tab bar (Ionic ion-content --padding-bottom: tab bar + 16).
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/demo_providers.dart';
import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/app_update_service.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/settings/presentation/pages/settings_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/layout/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Tenant? build() => null;

  @override
  Future<void> setTenant(Tenant? tenant) async {}

  @override
  Future<void> loadFromPrefs() async {}
}

void main() {
  testWidgets('iOS Mehr: Ausloggen fully above the floating tab bar',
      (tester) async {
    // Short screen so the player's Mehr page scrolls.
    tester.view.physicalSize = const Size(393, 520);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34, top: 47);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34, top: 47);
    addTearDown(tester.view.reset);

    final router = GoRouter(initialLocation: '/settings', routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        ],
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        effectiveRoleProvider.overrideWithValue(Role.player),
        currentRoleProvider.overrideWithValue(Role.player),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        appUpdateAvailableProvider.overrideWith((ref) => false),
        canAccessFilesProvider.overrideWithValue(false),
        isSuperDeveloperProvider.overrideWithValue(false),
        isDemoProvider.overrideWithValue(false),
        teamOrgEnabledProvider.overrideWithValue(false),
        isTeamLeaderProvider.overrideWithValue(false),
        inTeamCircleProvider.overrideWithValue(false),
        userTenantsProvider.overrideWith((ref) async => const <Tenant>[]),
        userNotificationsRealtimeProvider.overrideWith((ref) {}),
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        routerConfig: router,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final inset =
        IosTabBar.contentInset(tester.element(find.byType(IosTabBar)));
    final barTop = 520 - inset;
    final logout = tester.getRect(find.text('Ausloggen'));
    final deleteLink = tester.getRect(find.text('Konto löschen'));
    // Ionic: content ends `60px + floating safe area` + 16 above the bottom.
    expect(logout.bottom, lessThan(barTop));
    expect(deleteLink.bottom, lessThanOrEqualTo(barTop - 16));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
