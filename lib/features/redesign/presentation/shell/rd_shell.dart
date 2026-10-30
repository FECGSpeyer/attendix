import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/audio_player/audio_player_widget.dart';
import '../../../../shared/widgets/debug/debug_role_fab.dart';
import '../../../../shared/widgets/dialogs/native_app_ad.dart';
import '../../../../shared/widgets/layout/root_back_button_scope.dart';
import '../../../../shared/widgets/layout/route_leave_guard.dart';
import '../../data/rd_manage_logic.dart';
import '../widgets/manage/rd_manage_entries.dart';
import '../widgets/rd_group_switch.dart';
import '../widgets/rd_logo.dart';
import '../widgets/rd_widgets.dart';
import 'rd_destinations.dart';

/// REDESIGN: adaptive shell of the new design (Phase 1 "Fundament").
///
/// * below 600 px: tab bar at the bottom (iPhone),
/// * 600–839 px: navigation rail (iPad upright),
/// * from 840 px: sidebar with the group at the top (iPad landscape, Mac).
class RdShell extends ConsumerWidget {
  const RdShell({super.key, required this.child});

  final Widget child;

  static const double railBreakpoint = 600;
  static const double sidebarBreakpoint = 840;

  static String labelOf(AppLocalizations l10n, RdTab tab) => switch (tab) {
        RdTab.today => l10n.redesignTabToday,
        RdTab.events => l10n.redesignTabEvents,
        RdTab.members => l10n.redesignTabMembers,
        RdTab.works => l10n.redesignTabWorks,
        RdTab.me => l10n.redesignTabMe,
      };

  /// Leave guards of the open page run first (unsaved Ablaufplan etc.),
  /// like in the old shell.
  static Future<void> navigate(BuildContext context, WidgetRef ref, String route) async {
    final guards = ref.read(routeLeaveGuardRegistryProvider);
    if (guards.hasGuards && !await guards.canLeave()) return;
    if (!context.mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    final tenant = ref.watch(currentTenantProvider);
    final destinations = rdDestinationsFor(
      role,
      showMembersList: tenant?.showMembersList ?? false,
      tenantType: tenant?.type ?? '',
    );
    final location = GoRouterState.of(context).matchedLocation;
    final selected = rdSelectedIndex(destinations, location);
    final width = MediaQuery.sizeOf(context).width;
    final page = NativeAppAdGate(child: child);
    final p = context.rd;

    void onSelect(int index) =>
        navigate(context, ref, destinations[index].route);

    final Widget body;
    Widget? bottomBar;
    if (width >= sidebarBreakpoint) {
      body = Row(
        children: [
          _RdSidebar(
            destinations: destinations,
            selectedIndex: selected,
            onSelected: onSelect,
            showAdmin: rdShowsManage(ref.watch(rdManageAccessProvider)),
          ),
          Expanded(child: _withPlayer(page)),
        ],
      );
    } else if (width >= railBreakpoint) {
      body = Row(
        children: [
          _RdRail(
            destinations: destinations,
            selectedIndex: selected,
            onSelected: onSelect,
          ),
          VerticalDivider(width: 1, thickness: 1, color: p.line),
          Expanded(child: _withPlayer(page)),
        ],
      );
    } else {
      body = _withPlayer(page);
      // Hidden while the keyboard is open, like the old tab bar.
      if (MediaQuery.viewInsetsOf(context).bottom <= 0) {
        bottomBar = _RdBottomBar(
          destinations: destinations,
          selectedIndex: selected,
          onSelected: onSelect,
        );
      }
    }

    return RootBackButtonScope(
      child: Scaffold(
        backgroundColor: p.bg,
        body: body,
        bottomNavigationBar: bottomBar,
        floatingActionButton: kDebugMode ? const DebugRoleFab() : null,
      ),
    );
  }

  /// Page plus the mini audio player (and on iOS the update notice) above
  /// the bar.
  Widget _withPlayer(Widget page) => Column(
        children: [
          Expanded(child: page),
          const AudioPlayerWidget(),
          const _RdUpdateBar(),
        ],
      );
}

/// Closed "Neue Version verfügbar" notice (until the next start).
final _rdUpdateDismissedProvider = StateProvider<bool>((ref) => false);

/// "Neue Version verfügbar" above the tab bar. Only on iOS: elsewhere
/// main.dart shows it as a SnackBar, like with the old shell.
class _RdUpdateBar extends ConsumerWidget {
  const _RdUpdateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = Theme.of(context).platform == TargetPlatform.iOS &&
        ref.watch(appUpdateAvailableProvider) &&
        !ref.watch(_rdUpdateDismissedProvider);
    if (!show) return const SizedBox.shrink();
    final p = context.rd;
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Material(
          color: p.toastBg,
          borderRadius: BorderRadius.circular(p.buttonRadius),
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Row(
              children: [
                Icon(Icons.cloud_download_outlined, size: 20, color: p.toastText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.coreFlutterNewVersionAvailable,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.toastText),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(appUpdateServiceProvider).applyUpdate(),
                  style: TextButton.styleFrom(
                    foregroundColor: p.toastAction,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    l10n.coreFlutterUpdate,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonClose,
                  icon: Icon(Icons.close, size: 18, color: p.toastText),
                  onPressed: () =>
                      ref.read(_rdUpdateDismissedProvider.notifier).state = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RdBottomBar extends StatelessWidget {
  const _RdBottomBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      // Large text would wrap the labels ("Mitgliede r"); iOS tab bars
      // grow their labels only a little, too.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: NavigationBarTheme(
          data: _barTheme(p),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: RdShell.labelOf(l10n, d.tab),
                  tooltip: '',
                ),
            ],
          ),
        ),
      ),
    );
  }

  static NavigationBarThemeData _barTheme(RdPalette p) => NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 62,
        indicatorColor: p.soft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? p.softText : p.text2,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? p.softText : p.text2,
          );
        }),
      );
}

class _RdRail extends StatelessWidget {
  const _RdRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<RdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return NavigationRail(
      backgroundColor: p.surface,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      indicatorColor: p.soft,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: p.softText, size: 22),
      unselectedIconTheme: IconThemeData(color: p.text2, size: 22),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: p.softText,
      ),
      unselectedLabelTextStyle: TextStyle(fontSize: 12, color: p.text2),
      groupAlignment: -0.85,
      leading: const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 4),
        child: RdLogo(size: 36, semanticLabel: 'Attendix'),
      ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(RdShell.labelOf(l10n, d.tab)),
          ),
      ],
    );
  }
}

/// Sidebar of the desktop layout (canvas T2/T3).
class _RdSidebar extends ConsumerWidget {
  const _RdSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.showAdmin,
  });

  final List<RdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// "Verwaltung" for everyone with something to manage (`rdShowsManage`).
  final bool showAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final name = tenant?.longName.isNotEmpty == true
        ? tenant!.longName
        : (tenant?.shortName ?? '');
    final role = ref.watch(effectiveRoleProvider);
    final pending = showAdmin && (role.isAdmin || role.isResponsible)
        ? (ref.watch(pendingPlayersProvider).valueOrNull?.length ?? 0)
        : 0;
    final location = GoRouterState.of(context).matchedLocation;
    final adminSelected = location == RedesignRoutes.manage ||
        location.startsWith('${RedesignRoutes.manage}/') ||
        location == '/settings' ||
        (location.startsWith('/settings/') &&
            rdTabForLocation(location) == RdTab.me &&
            !location.startsWith('/settings/notifications') &&
            !location.startsWith('/settings/help'));

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                label: l10n.redesignGroupsSwitchHint(name),
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showRdGroupSwitchSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        RdInitials(
                          rdInitialsOf(tenant?.shortName.isNotEmpty == true
                              ? tenant!.shortName
                              : name),
                          size: 36,
                          square: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                        ),
                        Icon(Icons.unfold_more, size: 18, color: p.text2),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < destinations.length; i++)
                _SidebarItem(
                  icon: i == selectedIndex && !adminSelected
                      ? destinations[i].selectedIcon
                      : destinations[i].icon,
                  label: RdShell.labelOf(l10n, destinations[i].tab),
                  selected: i == selectedIndex && !adminSelected,
                  onTap: () => onSelected(i),
                ),
              if (showAdmin) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Divider(height: 1, thickness: 1, color: p.line),
                ),
                _SidebarItem(
                  icon: Icons.tune,
                  label: l10n.redesignAdminTitle,
                  selected: adminSelected,
                  badge: pending,
                  onTap: () => RdShell.navigate(context, ref, RedesignRoutes.manage),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const RdLogo(size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Attendix',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? p.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: selected ? p.softText : p.text2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
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
                        decoration: BoxDecoration(
                          color: p.absent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$badge',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.onStatus,
                          ),
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
