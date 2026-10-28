import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/providers/debug_providers.dart';
import '../../../core/providers/optional_tabs_providers.dart'; // SETTINGS2
import '../../../core/providers/tenant_providers.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../l10n/l10n.dart'; // I18N_INFRA
import '../audio_player/audio_player_widget.dart';
import '../debug/debug_role_fab.dart';
import '../dialogs/native_app_ad.dart'; // LINKS_STARTUP
import 'root_back_button_scope.dart'; // NATIVE_MISC

/// Represents a navigation destination with its route
class _NavDestination {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  _NavDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Main shell widget with role-based bottom navigation
class MainShell extends ConsumerWidget {
  const MainShell({
    super.key,
    required this.child,
  });

  final Widget child;

  /// Build navigation destinations based on user role and tenant settings.
  ///
  /// UX_NAV: order, labels, icons and visibility follow Ionic
  /// src/app/tabs/tabs.page.html + tabs.page.ts exactly:
  /// Dashboard · Termine (Eltern) · Meine Termine · Mitglieder · Übersicht ·
  /// Personen · Termine · Werke · Org · Mehr. Ionic keeps the outline icon
  /// when selected and only tints it, hence icon == selectedIcon.
  List<_NavDestination> _buildDestinations(
      AppLocalizations l10n, Role role, Tenant? tenant,
      {bool hasMultipleTenants = false,
      bool showDashboardTab = false,
      bool showSongsTab = false,
      bool showOrgPlansTab = false}) {
    final List<_NavDestination> destinations = [];

    // Ionic isPlayer = PLAYER || NONE, isHelper = HELPER || VOICE_LEADER_HELPER
    final isPlayer = role == Role.player || role == Role.none;
    final isHelper = role.isHelperRole;

    // DASHBOARD: first tab for Admin/Responsible when enabled
    if (showDashboardTab) {
      destinations.add(_NavDestination(
        route: '/home-dashboard',
        label: l10n.tabsDashboard,
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_outlined,
      ));
    }

    // Parents: "Termine" (parents portal)
    if (role.isParent) {
      destinations.add(_NavDestination(
        route: '/parents',
        label: l10n.tabsEvents,
        icon: Icons.person_outline,
        selectedIcon: Icons.person_outline,
      ));
    }

    // !isConductor && !isParent: "Meine Termine" (self-service sign-out)
    if (role.canSeeSelfServiceTab) {
      destinations.add(_NavDestination(
        route: '/signout',
        label: l10n.tabsMyEvents,
        icon: Icons.person_outline,
        selectedIcon: Icons.person_outline,
      ));
    }

    // Members tab: HELPER, VOICE_LEADER, VOICE_LEADER_HELPER, PLAYER, NONE
    // when the tenant shows the members list
    if ((role.canSeeMembersTab || role == Role.none) &&
        tenant?.showMembersList == true) {
      destinations.add(_NavDestination(
        route: '/members',
        label: l10n.tabsMembers,
        icon: Icons.people_outline,
        selectedIcon: Icons.people_outline,
      ));
    }

    // (isPlayer || isHelper) && several tenants: cross-tenant "Übersicht"
    if ((isPlayer || isHelper) && hasMultipleTenants) {
      destinations.add(_NavDestination(
        route: '/overview',
        label: l10n.tabsOverview,
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today_outlined,
      ));
    }

    // Conductors (Admin, Responsible, Viewer): "Personen"
    if (role.canSeePeopleTab) {
      destinations.add(_NavDestination(
        route: '/people',
        label: l10n.commonPeople,
        icon: Icons.people_outline,
        selectedIcon: Icons.people_outline,
      ));
    }

    // Conductors/Helpers: "Termine" (attendance list)
    if (role.canSeeAttendanceTab) {
      destinations.add(_NavDestination(
        route: '/attendance',
        label: l10n.tabsEvents,
        icon: Icons.check_box_outlined,
        selectedIcon: Icons.check_box_outlined,
      ));
    }

    // SETTINGS2: optional "Werke" / "Org" tabs
    if (showSongsTab) {
      destinations.add(_NavDestination(
        route: '/songs-tab',
        label: l10n.tabsSongs,
        icon: Icons.music_note_outlined,
        selectedIcon: Icons.music_note_outlined,
      ));
    }
    if (showOrgPlansTab) {
      destinations.add(_NavDestination(
        route: '/org-plans-tab',
        label: l10n.tabsOrg,
        icon: Icons.business_outlined,
        selectedIcon: Icons.business_outlined,
      ));
    }

    // Everyone: "Mehr" (settings menu, ellipsis-horizontal)
    destinations.add(_NavDestination(
      route: '/settings',
      label: l10n.tabsMore,
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
    ));

    return destinations;
  }

  /// Get selected index based on current route and available destinations
  int _getSelectedIndex(BuildContext context, List<_NavDestination> destinations) {
    final location = GoRouterState.of(context).matchedLocation;

    for (int i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].route)) {
        return i;
      }
    }

    // If current route doesn't match any tab, default to first
    return 0;
  }

  /// Navigate to destination at index
  void _onItemTapped(BuildContext context, int index, List<_NavDestination> destinations) {
    if (index >= 0 && index < destinations.length) {
      context.go(destinations[index].route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use effectiveRoleProvider to support debug role override
    final role = ref.watch(effectiveRoleProvider);
    final tenant = ref.watch(currentTenantProvider);

    // Build destinations based on role
    final hasMultipleTenants =
        (ref.watch(userTenantsProvider).valueOrNull?.length ?? 0) > 1;
    final destinations = _buildDestinations(context.l10n, role, tenant,
        hasMultipleTenants: hasMultipleTenants,
        showDashboardTab: ref.watch(showDashboardTabProvider), // DASHBOARD
        showSongsTab: ref.watch(showSongsTabProvider), // SETTINGS2
        showOrgPlansTab: ref.watch(showOrgPlansTabProvider)); // SETTINGS2
    final selectedIndex = _getSelectedIndex(context, destinations);

    // Safety check: ensure we have at least one destination
    if (destinations.isEmpty) {
      return Scaffold(
        body: child,
      );
    }

    // NATIVE_MISC: Android back at a root tab exits the app (Ionic
    // @capacitor/app backButton → exitApp); nested pages pop normally because
    // go_router pops the inner navigator before this scope is asked.
    return RootBackButtonScope(
      child: Scaffold(
      body: Column(
        children: [
          // LINKS_STARTUP: one-time "Attendix als App verfügbar!" (web)
          Expanded(child: NativeAppAdGate(child: child)),
          const AudioPlayerWidget(),
        ],
      ),
      // Debug FAB only visible in debug mode
      floatingActionButton: kDebugMode ? const DebugRoleFab() : null,
      // UX_NAV: Ionic ion-tab-bar has a hairline on top; no selection pill
      // (see navigationBarTheme in app_theme.dart).
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
        ),
        child: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
        onDestinationSelected: (index) => _onItemTapped(context, index, destinations),
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
        ),
      ),
      ),
    );
  }
}
