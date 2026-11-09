import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../data/rd_manage_logic.dart';
import '../widgets/manage/rd_manage_entries.dart';
import '../widgets/rd_desktop.dart';
import '../widgets/rd_group_switch.dart';
import '../widgets/rd_widgets.dart';
import 'rd_destinations.dart';
import 'rd_shell.dart';

/// Entries of the desktop sidebar beside the tabs: the most used pages of
/// the Verwaltung for leads, Team and Hilfe from "Ich".
enum RdSideExtra { stats, messages, manage, team, help }

const _helpRoute = '/settings/help';
const _teamRoot = '/settings/team-organization';

/// The extra entry [location] belongs to, null when a tab is selected.
/// [manage]/[team]: whether the sidebar shows those entries.
RdSideExtra? rdSideExtraFor(String location, {required bool manage, required bool team}) {
  bool under(String root) => location == root || location.startsWith('$root/');
  if (manage && rdIsManageLocation(location)) {
    if (under(RedesignRoutes.stats)) return RdSideExtra.stats;
    if (under(RedesignRoutes.messages) || under(RedesignRoutes.compose)) {
      return RdSideExtra.messages;
    }
    return RdSideExtra.manage;
  }
  if (under(_helpRoute)) return RdSideExtra.help;
  if (team && under(_teamRoot)) return RdSideExtra.team;
  return null;
}

/// Sidebar of the desktop layout (like the old Ionic menu): the group as a
/// card on top, below it the entries in sections (Übersicht, Leitung,
/// Persönlich).
class RdSidebar extends ConsumerWidget {
  const RdSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onOpen,
    this.badges = const {},
  });

  final List<RdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Opens a route of an extra entry (leave guards first).
  final ValueChanged<String> onOpen;
  final Map<RdTab, int> badges;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final access = ref.watch(rdManageAccessProvider);
    // "Verwaltung" for Dirigent and Verantwortliche (`rdShowsManage`).
    final showManage = rdShowsManage(access);
    final showTeam = access.showTeam;
    final location = rdShownLocation(context);
    final extra = rdSideExtraFor(location, manage: showManage, team: showTeam);

    Widget tab(int i) {
      final d = destinations[i];
      final selected = extra == null && i == selectedIndex;
      return _SidebarItem(
        icon: selected ? d.selectedIcon : d.icon,
        label: RdShell.labelOf(l10n, d.tab),
        selected: selected,
        badge: badges[d.tab] ?? 0,
        onTap: () => onSelected(i),
      );
    }

    Widget item(RdSideExtra e, IconData icon, IconData selectedIcon, String label, String route) {
      final selected = extra == e;
      return _SidebarItem(
        icon: selected ? selectedIcon : icon,
        label: label,
        selected: selected,
        onTap: () => onOpen(route),
      );
    }

    final meIndex = destinations.indexWhere((d) => d.tab == RdTab.me);
    final tabs = [
      for (var i = 0; i < destinations.length; i++)
        if (i != meIndex) tab(i),
    ];

    return Container(
      width: rdSidebarWidth,
      decoration: BoxDecoration(color: p.surface, border: Border(right: BorderSide(color: p.line))),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(12, 16, 12, 4), child: _GroupCard()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  _SectionLabel(l10n.rdSidebarOverview),
                  ...tabs,
                  if (showManage) ...[
                    _SectionLabel(l10n.rdSidebarLead),
                    item(
                      RdSideExtra.stats,
                      Icons.insert_chart_outlined,
                      Icons.insert_chart,
                      l10n.redesignStatsTitle,
                      RedesignRoutes.stats,
                    ),
                    item(
                      RdSideExtra.messages,
                      Icons.campaign_outlined,
                      Icons.campaign,
                      l10n.settingsAnnouncements,
                      RedesignRoutes.messages,
                    ),
                    item(
                      RdSideExtra.manage,
                      Icons.settings_outlined,
                      Icons.settings,
                      l10n.redesignAdminTitle,
                      RedesignRoutes.manage,
                    ),
                  ],
                  _SectionLabel(l10n.rdSidebarPersonal),
                  if (meIndex >= 0) tab(meIndex),
                  if (showTeam)
                    item(
                      RdSideExtra.team,
                      Icons.supervised_user_circle_outlined,
                      Icons.supervised_user_circle,
                      l10n.rdAdminTeam,
                      rdTeamRoute,
                    ),
                  item(RdSideExtra.help, Icons.help_outline, Icons.help, l10n.settingsHelp, _helpRoute),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The current group as a card: initials, name, number of groups; a tap
/// opens the group switch.
class _GroupCard extends ConsumerWidget {
  const _GroupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final name = tenant?.longName.isNotEmpty == true ? tenant!.longName : (tenant?.shortName ?? '');
    final count = ref.watch(userTenantsProvider).valueOrNull?.length ?? 0;

    return Semantics(
      button: true,
      label: l10n.redesignGroupsSwitchHint(name),
      excludeSemantics: true,
      child: Material(
        color: p.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showRdGroupSwitchSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                RdInitials(
                  rdInitialsOf(tenant?.shortName.isNotEmpty == true ? tenant!.shortName : name),
                  size: 40,
                  square: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w700, color: p.text),
                      ),
                      if (count > 1) ...[
                        const SizedBox(height: 2),
                        Text(l10n.rdSidebarGroupsCount(count), style: TextStyle(fontSize: 12.5, color: p.text2)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 20, color: p.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small uppercase heading of a sidebar section.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.text2),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? p.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              height: 42,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: selected ? p.softText : p.text2),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? p.softText : p.text,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: p.absent, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '$badge',
                          semanticsLabel: context.l10n.rdAdminPendingBadge(badge),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.onStatus),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
