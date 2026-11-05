import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/push_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../features/messages/presentation/widgets/notification_bell.dart';
import '../../../../features/statistics/presentation/pages/statistics_page.dart'
    show showStatisticsModal;
import '../../../../features/planning/presentation/pages/planning_page.dart'
    show showPlanningModal;
import '../../../../l10n/l10n.dart';
import '../../tenant/tenant_switcher_title.dart' show switchTenant;
import '../route_leave_guard.dart';
import 'nav_items.dart';
import 'side_nav_layout.dart';

/// SIDE_NAV (Ionic 4.19.0 `app-side-nav`): the side panel that replaces the
/// tab bar on tablets and computers. Top: collapse toggle (overlay: close)
/// and the bell; the instance (switcher with several instances); the
/// grouped, role-dependent entries with badges; foot: profile and log out.
class SideNav extends ConsumerStatefulWidget {
  const SideNav({
    super.key,
    required this.mode,
    required this.collapsed,
    required this.onClose,
  });

  final SideNavMode mode;

  /// Fixed panel as icon rail (Ionic `layout.collapsed()`).
  final bool collapsed;

  /// Closes the overlay (no-op for the fixed panel).
  final VoidCallback onClose;

  @override
  ConsumerState<SideNav> createState() => _SideNavState();
}

class _SideNavState extends ConsumerState<SideNav> {
  bool get _fixed => widget.mode == SideNavMode.fixed;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Ionic: Ctrl/⌘ + B collapses and expands the fixed panel (as in
  /// Notion, VS Code) – not inside text fields, where it means "bold".
  bool _onKey(KeyEvent event) {
    if (!_fixed || event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyB) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed) ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        (focus.widget is EditableText ||
            focus.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    _toggleCollapsed();
    return true;
  }

  void _toggleCollapsed() {
    ref.read(sideNavCollapsedChoiceProvider.notifier).set(!widget.collapsed);
  }

  Future<bool> _leaveAllowed() async {
    final guards = ref.read(routeLeaveGuardRegistryProvider);
    return !guards.hasGuards || await guards.canLeave();
  }

  /// The overlay closes after the step ran: its context (and `ref`) is gone
  /// once the drawer is closed.
  void _closeOverlay() {
    if (!_fixed) widget.onClose();
  }

  Future<void> _onItem(NavItem item) async {
    final action = item.action;
    if (action != null) {
      // Modal pages: opened right away (they capture the navigator), the
      // overlay closes underneath.
      _closeOverlay();
      switch (action) {
        case NavAction.planning:
          // Ionic side-nav: PlanningPage as modal (cssClass planningModal).
          showPlanningModal(context);
        case NavAction.stats:
          showStatisticsModal(context);
      }
      return;
    }
    final route = item.route;
    if (route == null) return;
    await _go(route);
  }

  Future<void> _go(String route) async {
    final router = GoRouter.of(context);
    if (!await _leaveAllowed()) return;
    router.go(route);
    if (mounted) _closeOverlay();
  }

  Future<void> _onTenant(Tenant tenant) async {
    await switchTenant(context, ref, tenant);
    if (mounted) _closeOverlay();
  }

  Future<void> _logout() async {
    // Same steps as the settings page (Ionic logs out without asking).
    final router = GoRouter.of(context);
    final supabase = ref.read(supabaseClientProvider);
    final tenantNotifier = ref.read(currentTenantProvider.notifier);
    await removePushTokenBeforeSignOut(ref);
    await supabase.auth.signOut();
    await tenantNotifier.clearTenant();
    router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final tenant = ref.watch(currentTenantProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final isAdmin = role.isAdmin || role.isResponsible;

    // Ionic: no entries, badges or profile without an instance.
    final hasTenant = tenant != null;
    final teamOrgEnabled = hasTenant && ref.watch(teamOrgEnabledProvider);
    final myTasks =
        teamOrgEnabled ? (ref.watch(myTasksProvider).valueOrNull ?? const []) : const [];
    final showTeam = teamOrgEnabled &&
        (ref.watch(isTeamLeaderProvider) ||
            ref.watch(inTeamCircleProvider) ||
            myTasks.isNotEmpty);

    final groups = tenant == null
        ? const <NavGroup>[]
        : buildNavGroups(NavContext(
            role: role,
            tenantType: tenant.type,
            hasMultipleTenants: tenants.length > 1,
            showMembersList: tenant.showMembersList == true,
            hasOrganisation: isAdmin &&
                ref.watch(currentOrganisationProvider).valueOrNull != null,
            canAccessFiles: ref.watch(canAccessFilesProvider),
            showTeam: showTeam,
          ));

    final badges = <NavBadge, int>{
      NavBadge.pendingPersons: hasTenant && isAdmin
          ? (ref.watch(realtimePendingPlayersProvider).valueOrNull?.length ?? 0)
          : 0,
      NavBadge.openTasks: myTasks.where((t) => t.status != 'completed').length,
    };

    final location = GoRouterState.of(context).uri.path;
    final activeId = activeNavItemId(groups, location);
    final collapsed = widget.collapsed;
    final colors = _SideNavColors.of(context);

    final nav = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (collapsed) {
        if (i > 0) nav.add(_Separator(colors: colors));
      } else if (group.label != null) {
        nav.add(_SectionHeader(text: group.label!(l10n), colors: colors));
      } else if (i > 0) {
        nav.add(_Separator(colors: colors));
      }
      for (final item in group.items) {
        nav.add(_NavButton(
          icon: item.icon,
          label: item.label(l10n),
          active: item.id == activeId,
          collapsed: collapsed,
          count: item.badge == null ? 0 : (badges[item.badge] ?? 0),
          colors: colors,
          onTap: () => _onItem(item),
        ));
      }
    }

    final mq = MediaQuery.of(context);
    return Semantics(
      container: true,
      label: l10n.navLabel,
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(right: BorderSide(color: colors.line)),
        ),
        padding: EdgeInsets.only(
          top: mq.padding.top,
          bottom: mq.padding.bottom,
          left: mq.padding.left,
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTop(context, colors, hasTenant),
              _TenantButton(
                tenant: tenant,
                tenants: tenants,
                collapsed: collapsed,
                colors: colors,
                onSelected: _onTenant,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(collapsed ? 8 : 10, 2, collapsed ? 8 : 10, 8),
                  children: nav,
                ),
              ),
              _buildFoot(context, colors, role, hasTenant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTop(BuildContext context, _SideNavColors colors, bool hasTenant) {
    final l10n = context.l10n;
    final collapsed = widget.collapsed;
    final Widget toggle = _fixed
        ? _IconBtn(
            tooltip:
                '${collapsed ? l10n.navExpand : l10n.navCollapse} (${l10n.navShortcut})',
            colors: colors,
            onTap: _toggleCollapsed,
            child: Icon(Icons.view_sidebar_outlined,
                size: 22, color: colors.muted, textDirection: TextDirection.rtl),
          )
        : _IconBtn(
            tooltip: l10n.navClose,
            colors: colors,
            onTap: widget.onClose,
            child: Icon(Icons.close, size: 24, color: colors.muted),
          );
    final Widget bell = hasTenant
        ? IconTheme.merge(
            data: IconThemeData(color: colors.muted),
            child: const NotificationBell(inSideNav: true),
          )
        : const SizedBox(width: 40, height: 40);
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Column(children: [toggle, const SizedBox(height: 4), bell]),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [toggle, bell],
        ),
      ),
    );
  }

  Widget _buildFoot(
      BuildContext context, _SideNavColors colors, Role role, bool hasTenant) {
    final l10n = context.l10n;
    final collapsed = widget.collapsed;
    final person =
        hasTenant ? ref.watch(ownProfileProvider).valueOrNull?.person : null;
    final email = hasTenant
        ? ref.watch(supabaseClientProvider).auth.currentUser?.email ?? ''
        : '';
    final name = person != null ? '${person.firstName} ${person.lastName}'.trim() : email;
    final roleLabel = _roleLabel(l10n, role);
    final img = person?.img;

    final avatar = _Avatar(name: name, url: img, colors: colors);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
      padding: EdgeInsets.fromLTRB(collapsed ? 8 : 10, 8, collapsed ? 8 : 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: name,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: colors.hover,
                onTap: () => _go('/settings'),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 8, vertical: 6),
                  child: collapsed
                      ? Center(child: avatar)
                      : Row(children: [
                          avatar,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w700)),
                                if (roleLabel != null)
                                  Text(roleLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: colors.muted)),
                              ],
                            ),
                          ),
                        ]),
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.logout,
            label: l10n.settingsLogout,
            active: false,
            collapsed: collapsed,
            count: 0,
            colors: colors,
            color: AppColors.danger,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  /// Ionic `roleKey()`.
  static String? _roleLabel(AppLocalizations l10n, Role role) => switch (role) {
        Role.admin => l10n.rolesAdministrator,
        Role.responsible => l10n.rolesResponsible,
        Role.helper => l10n.rolesHelper,
        Role.voiceLeader => l10n.settingsVoiceLeader,
        Role.voiceLeaderHelper => l10n.rolesVoiceLeaderHelper,
        Role.player => l10n.rolesMember,
        Role.viewer => l10n.settingsViewers,
        Role.parent => l10n.rolesParent,
        Role.applicant => l10n.rolesApplicant,
        Role.none => null,
      };
}

/// Ionic side-nav.component.scss colours.
class _SideNavColors {
  const _SideNavColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.hover,
    required this.activeBg,
    required this.line,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color hover;
  final Color activeBg;
  final Color line;

  static _SideNavColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).colorScheme.onSurface;
    return _SideNavColors(
      // --ion-color-step-50 (fallback #f7f7f9), dark one step above the page
      background: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF7F7F9),
      surface: dark ? Colors.black : Colors.white,
      text: text,
      muted: AppColors.medium,
      hover: text.withValues(alpha: 0.06),
      activeBg: AppColors.primary.withValues(alpha: 0.14),
      // --ion-color-step-150 (fallback #e5e5ea)
      line: dark ? const Color(0xFF333333) : const Color(0xFFE5E5EA),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.tooltip,
    required this.colors,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final _SideNavColors colors;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: colors.hover,
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text, required this.colors});

  final String text;
  final _SideNavColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.66,
          color: colors.muted,
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.colors});

  final _SideNavColors colors;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        color: colors.line,
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.count,
    required this.colors,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool collapsed;
  final int count;
  final _SideNavColors colors;
  final VoidCallback onTap;

  /// Text and icon colour (log out: danger).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : (color ?? colors.text);
    final iconColor = active ? AppColors.primary : (color ?? colors.muted);
    final countText = count > 99 ? '99+' : '$count';
    final badge = count > 0
        ? Container(
            constraints: BoxConstraints(minWidth: collapsed ? 16 : 20),
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 4 : 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              countText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: collapsed ? 10 : 11.5,
                fontWeight: FontWeight.w600,
                height: collapsed ? 1.6 : 1.56,
              ),
            ),
          )
        : null;

    final Widget content = collapsed
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 40,
                child: Center(child: Icon(icon, size: 21, color: iconColor)),
              ),
              if (badge != null) Positioned(top: 2, right: 4, child: badge),
            ],
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                Icon(icon, size: 21, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: fg,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badge != null) badge,
              ]),
            ),
          );

    return Semantics(
      button: true,
      selected: active,
      label: count > 0 ? '$label ($count)' : label,
      excludeSemantics: true,
      child: Tooltip(
        message: collapsed ? label : '',
        child: Material(
          color: active ? colors.activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: colors.hover,
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _TenantButton extends StatelessWidget {
  const _TenantButton({
    required this.tenant,
    required this.tenants,
    required this.collapsed,
    required this.colors,
    required this.onSelected,
  });

  final Tenant? tenant;
  final List<Tenant> tenants;
  final bool collapsed;
  final _SideNavColors colors;
  final ValueChanged<Tenant> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final multiple = tenants.length > 1;
    final longName = tenant?.longName ?? '';
    final short = tenant?.shortName ?? '';
    final logo = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        _initials(short.isNotEmpty ? short : longName),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );

    final Widget face = collapsed
        ? Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 6), child: Center(child: logo))
        : Container(
            margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.line),
            ),
            child: Row(children: [
              logo,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(longName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    if (multiple)
                      Text(l10n.navInstances(tenants.length),
                          style: TextStyle(fontSize: 12, color: colors.muted)),
                  ],
                ),
              ),
              if (multiple) Icon(Icons.keyboard_arrow_down, color: colors.muted),
            ]),
          );

    if (!multiple) {
      return Tooltip(message: longName, child: face);
    }
    return Semantics(
      button: true,
      label: '${l10n.settingsSwitchTenant}: $longName',
      excludeSemantics: true,
      child: PopupMenuButton<Tenant>(
        tooltip: longName,
        position: PopupMenuPosition.under,
        offset: collapsed ? const Offset(sidePanelRailWidth - 8, -40) : Offset.zero,
        constraints: const BoxConstraints.tightFor(width: 240),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final t in tenants)
            PopupMenuItem<Tenant>(
              value: t,
              child: Row(children: [
                Expanded(
                  child: Text(t.longName.isNotEmpty ? t.longName : t.shortName,
                      overflow: TextOverflow.ellipsis),
                ),
                if (t.id == tenant?.id)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.settingsCurrent,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
              ]),
            ),
        ],
        child: face,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url, required this.colors});

  final String name;
  final String? url;
  final _SideNavColors colors;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
    final src = url;
    if (src == null || src.isEmpty || !src.startsWith('http')) return fallback;
    return ClipOval(
      child: Image.network(
        src,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Ionic `initials()`: two letters of one word, else first + last initial.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return (p.length > 2 ? p.substring(0, 2) : p).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
