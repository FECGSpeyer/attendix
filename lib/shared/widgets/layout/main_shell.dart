import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/providers/debug_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../data/models/tenant/tenant.dart';
import '../audio_player/audio_player_widget.dart';
import '../debug/debug_role_fab.dart';

/// Represents a navigation destination with its route
class _NavDestination {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavDestination({
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

  /// Build navigation destinations based on user role and tenant settings
  List<_NavDestination> _buildDestinations(Role role, Tenant? tenant,
      {bool hasMultipleTenants = false, bool showDashboardTab = false}) {
    final List<_NavDestination> destinations = [];

    // DASHBOARD: first tab for Admin/Responsible when enabled (Ionic tabs.page.html)
    if (showDashboardTab) {
      destinations.add(const _NavDestination(
        route: '/home-dashboard',
        label: 'Dashboard',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
      ));
    }

    // Conductors (Admin, Responsible, Viewer): People tab
    if (role.canSeePeopleTab) {
      destinations.add(const _NavDestination(
        route: '/people',
        label: 'Personen',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
      ));
    }

    // Parents: Parents Portal tab
    if (role.isParent) {
      destinations.add(const _NavDestination(
        route: '/parents',
        label: 'Termine',
        icon: Icons.family_restroom_outlined,
        selectedIcon: Icons.family_restroom,
      ));
    }

    // Players/Helpers: Self-Service tab
    // ATTENDANCE_SIGNOUT: "Meine Termine" (current tenant) and the
    // cross-tenant "Übersicht" when the user is in several tenants.
    if (role.canSeeSelfServiceTab) {
      destinations.add(const _NavDestination(
        route: '/signout',
        label: 'Meine Termine',
        icon: Icons.event_available_outlined,
        selectedIcon: Icons.event_available,
      ));
      if (hasMultipleTenants) {
        destinations.add(const _NavDestination(
          route: '/overview',
          label: 'Übersicht',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
        ));
      }
    }

    // Members tab (if tenant has showMembersList enabled)
    if (role.canSeeMembersTab && tenant?.showMembersList == true) {
      destinations.add(const _NavDestination(
        route: '/members',
        label: 'Mitglieder',
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
      ));
    }

    // Conductors/Helpers: Attendance tab
    if (role.canSeeAttendanceTab) {
      destinations.add(const _NavDestination(
        route: '/attendance',
        label: 'Anwesenheit',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
      ));
    }

    // Everyone: Settings tab
    destinations.add(const _NavDestination(
      route: '/settings',
      label: 'Einstellungen',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
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
    final destinations = _buildDestinations(role, tenant,
        hasMultipleTenants: hasMultipleTenants,
        showDashboardTab: ref.watch(showDashboardTabProvider)); // DASHBOARD
    final selectedIndex = _getSelectedIndex(context, destinations);

    // Safety check: ensure we have at least one destination
    if (destinations.isEmpty) {
      return Scaffold(
        body: child,
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const AudioPlayerWidget(),
        ],
      ),
      // Debug FAB only visible in debug mode
      floatingActionButton: kDebugMode ? const DebugRoleFab() : null,
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
