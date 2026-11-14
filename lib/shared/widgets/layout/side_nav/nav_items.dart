import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../core/constants/enums.dart';
import '../../../../l10n/l10n.dart';

/// SIDE_NAV (Ionic 4.19.0 `tabs/side-nav/nav-items.ts`): what the side
/// panel needs to know about the user and the instance.
class NavContext {
  const NavContext({
    required this.role,
    this.tenantType,
    this.hasMultipleTenants = false,
    this.showMembersList = false,
    this.hasOrganisation = false,
    this.canAccessFiles = false,
    this.showTeam = false,
  });

  final Role role;
  final String? tenantType;
  final bool hasMultipleTenants;
  final bool showMembersList;
  final bool hasOrganisation;
  final bool canAccessFiles;

  /// Team organisation visible (leadership, team circle or own tasks).
  final bool showTeam;
}

enum NavBadge { pendingPersons, openTasks }

/// Opens a modal page instead of a route (Ionic `NavAction`).
enum NavAction { planning, stats }

class NavItem {
  const NavItem({
    required this.id,
    required this.icon,
    required this.label,
    this.route,
    this.action,
    this.badge,
  });

  final String id;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;

  /// Absolute target route; either [route] or [action].
  final String? route;
  final NavAction? action;
  final NavBadge? badge;
}

enum NavGroupId { main, team, account }

class NavGroup {
  const NavGroup({required this.id, this.label, required this.items});

  final NavGroupId id;

  /// Heading; without one no heading is shown.
  final String Function(AppLocalizations l10n)? label;
  final List<NavItem> items;
}

/// Entries of the side panel, grouped and filtered by role. The main areas
/// follow the tab bar ([MainShell]), plus the areas that sit under "Mehr"
/// on the phone. Routes are the Flutter equivalents of Ionic's `/tabs/…`.
List<NavGroup> buildNavGroups(NavContext ctx) {
  final role = ctx.role;
  // Ionic CONDUCTOR_ROLES = ADMIN, VIEWER, RESPONSIBLE
  final isConductor = role.isAdmin || role.isViewer || role.isResponsible;
  final isAdmin = role.isAdmin || role.isResponsible;
  final isHelper = role.isHelperRole;
  final isPlayer = role == Role.player || role == Role.none;
  final isParent = role.isParent;
  final isApplicant = role.isApplicant;
  final isGeneral = ctx.tenantType == 'general';
  final isVoiceLeader = role.isVoiceLeader || role.isVoiceLeaderHelper;
  final membersListRole = role.isHelper ||
      role.isVoiceLeader ||
      role.isVoiceLeaderHelper ||
      role == Role.player ||
      role == Role.none;

  final main = <NavItem>[];
  final team = <NavItem>[];

  if (isAdmin) {
    main.add(NavItem(
        id: 'dashboard',
        icon: AppIcons.gridViewOutlined,
        label: (l) => l.tabsDashboard,
        route: '/home-dashboard'));
  }
  if (isParent) {
    main.add(NavItem(
        id: 'parents',
        icon: AppIcons.personOutline,
        label: (l) => l.tabsEvents,
        route: '/parents'));
  }
  if (!isConductor && !isParent) {
    main.add(NavItem(
        id: 'signout',
        icon: AppIcons.personOutline,
        label: (l) => l.tabsMyEvents,
        route: '/signout'));
  }
  if ((isPlayer || isHelper) && ctx.hasMultipleTenants) {
    main.add(NavItem(
        id: 'overview',
        icon: AppIcons.calendarTodayOutlined,
        label: (l) => l.tabsOverview,
        route: '/overview'));
  }
  if (isHelper || isConductor) {
    main.add(NavItem(
        id: 'attendance',
        icon: AppIcons.checkBoxOutlined,
        label: (l) => l.tabsEvents,
        route: '/attendance'));
  }
  if (isConductor) {
    main.add(NavItem(
        id: 'player',
        icon: AppIcons.peopleOutline,
        label: (l) => l.commonPeople,
        route: '/people',
        badge: isAdmin ? NavBadge.pendingPersons : null));
  }
  if (membersListRole && ctx.showMembersList) {
    main.add(NavItem(
        id: 'members',
        icon: AppIcons.peopleOutline,
        label: (l) => l.tabsMembers,
        route: '/members'));
  }
  if (!isGeneral && !isApplicant && !isParent) {
    main.add(NavItem(
        id: 'songs',
        icon: AppIcons.musicNoteOutlined,
        label: (l) => l.tabsSongs,
        route: '/songs-tab'));
  }
  if (isAdmin) {
    main.add(NavItem(
        id: 'planning',
        icon: AppIcons.descriptionOutlined,
        label: (l) => l.settingsRunSheets,
        action: NavAction.planning));
  }
  if (isVoiceLeader && !isGeneral) {
    main.add(NavItem(
        id: 'voiceLeader',
        icon: AppIcons.musicalNoteOutline,
        label: (l) => l.settingsMyVoice,
        route: '/settings/voice-leader'));
  }

  if (ctx.showTeam) {
    team.add(NavItem(
        id: 'team',
        icon: AppIcons.layersOutlined,
        label: (l) => l.teamOrgTitle,
        route: '/settings/team-organization',
        badge: NavBadge.openTasks));
  }
  if (isAdmin) {
    team.add(NavItem(
        id: 'messages',
        icon: AppIcons.campaignOutlined,
        label: (l) => l.settingsAnnouncements,
        route: '/settings/messages'));
  }
  if (ctx.canAccessFiles) {
    team.add(NavItem(
        id: 'files',
        icon: AppIcons.folderOutlined,
        label: (l) => l.settingsFileStorage,
        route: '/settings/files'));
  }
  if (isAdmin) {
    team.add(NavItem(
        id: 'stats',
        icon: AppIcons.insertChartOutlined,
        label: (l) => l.statsTitle,
        action: NavAction.stats));
  }
  if (isAdmin && ctx.hasOrganisation) {
    team.add(NavItem(
        id: 'organisation',
        icon: AppIcons.businessOutlined,
        label: (l) => l.settingsOrganisation,
        route: '/org-plans-tab'));
  }

  final account = <NavItem>[
    NavItem(
        id: 'settings',
        icon: AppIcons.settingsOutlined,
        label: (l) => l.settingsSettings,
        route: '/settings'),
    NavItem(
        id: 'help',
        icon: AppIcons.helpOutline,
        label: (l) => l.settingsHelp,
        route: '/settings/help'),
  ];

  // Managing roles get three groups with headings. For everybody else a
  // "Team" group with only the file storage would be confusing: their
  // entries stand at the top without heading, only "Konto" is set apart.
  if (isAdmin) {
    return [
      NavGroup(id: NavGroupId.main, label: (l) => l.navGroupOverview, items: main),
      NavGroup(id: NavGroupId.team, label: (l) => l.navGroupTeam, items: team),
      NavGroup(id: NavGroupId.account, label: (l) => l.navGroupAdmin, items: account),
    ].where((g) => g.items.isNotEmpty).toList();
  }
  return [
    NavGroup(id: NavGroupId.main, items: [...main, ...team]),
    NavGroup(id: NavGroupId.account, label: (l) => l.navGroupAccount, items: account),
  ].where((g) => g.items.isNotEmpty).toList();
}

/// Id of the active entry: the longest matching route wins, so "Einstellungen"
/// stays active for all sub pages without an own entry while e.g.
/// `/settings/files` marks the file storage.
String? activeNavItemId(List<NavGroup> groups, String location) {
  final path = location.split('?').first.split('#').first;
  NavItem? best;
  for (final item in groups.expand((g) => g.items)) {
    final route = item.route;
    if (route == null) continue;
    final matches = path == route || path.startsWith('$route/');
    if (matches && (best == null || route.length > best.route!.length)) {
      best = item;
    }
  }
  return best?.id;
}
