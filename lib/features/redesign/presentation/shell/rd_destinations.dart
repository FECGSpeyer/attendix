import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/router/route_access.dart' show canOpenSongsTab;

/// REDESIGN: the fixed tabs of the new design (concept "Rollen-Matrix").
enum RdTab { today, events, members, works, me }

/// One tab of the new shell.
@immutable
class RdDestination {
  const RdDestination({
    required this.tab,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final RdTab tab;

  /// Where the tab leads. New pages mirror the access rules of the old ones
  /// (`RedesignRoutes.roleRedirect`).
  final String route;
  final IconData icon;
  final IconData selectedIcon;
}

/// Tabs for [role], built only from the existing permission getters, so no
/// role sees more than in the old design:
///
/// * Heute and Ich: everyone.
/// * Termine: the new Termin list (leaders see the group's Termine, everyone
///   else their own), the parents portal for parents.
/// * Mitglieder: the new Mitglieder list for conductors, the members list
///   where the group shows it to players and helpers; never for parents.
/// * Werke: where the Werke tab is allowed today and the group has works.
/// * Applicants only get Heute (waiting page) and Ich.
List<RdDestination> rdDestinationsFor(
  Role role, {
  required bool showMembersList,
  required String tenantType,
}) {
  const today = RdDestination(
    tab: RdTab.today,
    route: RedesignRoutes.today,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  );
  const me = RdDestination(
    tab: RdTab.me,
    route: RedesignRoutes.me,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );
  if (role.isApplicant) return const [today, me];

  // Parents answer for their children in the parents portal.
  final eventsRoute = role.isParent ? '/parents' : RedesignRoutes.events;

  String? membersRoute;
  if (role.canSeePeopleTab) {
    membersRoute = RedesignRoutes.members;
  } else if ((role.canSeeMembersTab || role == Role.none) && showMembersList) {
    membersRoute = '/members';
  }

  final showWorks = canOpenSongsTab(role) && tenantType != 'general';

  return [
    today,
    RdDestination(
      tab: RdTab.events,
      route: eventsRoute,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
    ),
    if (membersRoute != null)
      RdDestination(
        tab: RdTab.members,
        route: membersRoute,
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
      ),
    if (showWorks)
      const RdDestination(
        tab: RdTab.works,
        route: '/songs-tab',
        icon: Icons.music_note_outlined,
        selectedIcon: Icons.music_note,
      ),
    me,
  ];
}

/// Tab that [location] belongs to, so detail pages keep their tab selected.
RdTab rdTabForLocation(String location) {
  bool under(String root) => location == root || location.startsWith('$root/');

  if (under(RedesignRoutes.today) || under('/home-dashboard')) return RdTab.today;
  if (under(RedesignRoutes.events) ||
      under('/attendance') ||
      under('/signout') ||
      under('/parents') ||
      under('/overview') ||
      under('/planning')) {
    return RdTab.events;
  }
  if (under(RedesignRoutes.members) || under('/people') || under('/members')) return RdTab.members;
  if (under('/songs-tab') || under('/settings/songs') || under('/settings/files')) {
    return RdTab.works;
  }
  return RdTab.me;
}

/// Index of the selected tab in [destinations] (Ich when the location's tab
/// is not shown to this role).
int rdSelectedIndex(List<RdDestination> destinations, String location) {
  final tab = rdTabForLocation(location);
  final index = destinations.indexWhere((d) => d.tab == tab);
  if (index >= 0) return index;
  return destinations.length - 1;
}
