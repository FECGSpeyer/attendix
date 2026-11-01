import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/dashboard_providers.dart';
import '../../../core/providers/debug_providers.dart';
import '../../../core/providers/optional_tabs_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/update_hint.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive_platform.dart';
import '../audio_player/audio_player_widget.dart';
import '../debug/debug_role_fab.dart';
import '../dialogs/native_app_ad.dart';
import 'ios_tab_bar.dart';
import 'root_back_button_scope.dart';
import 'ionic_md.dart' show IonMd;
import 'route_leave_guard.dart';

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
  ///
  /// SOL_FIX25: `context.go` replaces the page without asking its
  /// `PopScope`, so the open page's leave guards (e.g. the Ablaufplan editor
  /// flushing its pending writes) run first; a guard that says stay keeps
  /// the page.
  Future<void> _onItemTapped(BuildContext context, WidgetRef ref, int index,
      List<_NavDestination> destinations) async {
    if (index < 0 || index >= destinations.length) return;
    final route = destinations[index].route;
    final guards = ref.read(routeLeaveGuardRegistryProvider);
    if (guards.hasGuards && !await guards.canLeave()) return;
    if (!context.mounted) return;
    context.go(route);
  }

  /// IOS_SHELL2: Ionic iOS 26 tabs. The pages fill the whole screen and
  /// scroll UNDER the floating Liquid Glass tab bar (with the theme's fade);
  /// the room the bar takes is handed to them as MediaQuery bottom padding,
  /// so scroll views end above the bar and page FABs/footers clear it.
  /// The mini audio player and the update toast float above the bar.
  Widget _buildIos(
    BuildContext context,
    WidgetRef ref,
    Widget page,
    List<_NavDestination> destinations,
    int selectedIndex,
  ) {
    final mq = MediaQuery.of(context);
    final bottomOffset = IosTabBar.bottomOffset(context);
    final barInset = IosTabBar.contentInset(context);
    final showUpdate = showUpdateHint(ref.watch(appUpdateAvailableProvider)) &&
        !ref.watch(_updateToastDismissedProvider);
    final inset =
        barInset + (showUpdate ? _IosUpdateToast.height + _IosUpdateToast.gap : 0);
    // The keyboard covers the bar: like MediaQuery.padding, the inset
    // shrinks by the keyboard height.
    final pagePadding = (inset - mq.viewInsets.bottom).clamp(0.0, inset);
    // PARITY_R3: Ionic `ion-tab-bar` gets `tab-bar-hidden` (display: none)
    // while the keyboard is open (keyboard controller, iOS and md).
    final keyboardOpen = isKeyboardOpen(context);

    final content = MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(bottom: pagePadding),
        viewPadding: mq.viewPadding.copyWith(bottom: inset),
      ),
      child: IosTabBarScope(
        bottom: bottomOffset,
        right: IosTabBar.fabRight(context),
        child: page,
      ),
    );

    return RootBackButtonScope(
      child: Scaffold(
        // Pages handle the keyboard themselves (their Scaffolds get the view
        // insets); the bar stays at the bottom, under the keyboard.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: _IosPageWithFade(
                location: GoRouterState.of(context).uri.toString(),
                fadeHeight: keyboardOpen ? 0 : barInset,
                child: content,
              ),
            ),
            // Ionic `.audio-player-bar`: bottom = tab bar offset + 68px.
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomOffset + IosTabBar.barHeight,
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AudioPlayerWidget(),
                    if (showUpdate)
                      _IosUpdateToast(
                        onUpdate: () =>
                            ref.read(appUpdateServiceProvider).applyUpdate(),
                        onClose: () => ref
                            .read(_updateToastDismissedProvider.notifier)
                            .state = true,
                      ),
                  ],
                ),
              ),
            ),
            if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IosTabBar(
                selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
                onSelected: (index) =>
                    _onItemTapped(context, ref, index, destinations),
                items: [
                  for (final d in destinations)
                    IosTabBarItem(icon: d.icon, label: d.label),
                ],
              ),
            ),
          ],
        ),
        // Debug FAB only visible in debug mode (above the tab bar row, where
        // the page FABs sit)
        floatingActionButton: kDebugMode
            ? Padding(
                padding: EdgeInsets.only(bottom: barInset),
                child: const DebugRoleFab(),
              )
            : null,
      ),
    );
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
        showDashboardTab: ref.watch(showDashboardTabProvider),
        showSongsTab: ref.watch(showSongsTabProvider),
        showOrgPlansTab: ref.watch(showOrgPlansTabProvider));
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
    // IOS_SHELL: pages put their ion-fab into the tab bar row (TabBarFab).
    final ios = useIosLook(context);
    final Widget page = NativeAppAdGate(child: child);
    if (ios) {
      return _buildIos(context, ref, page, destinations, selectedIndex);
    }

    return RootBackButtonScope(
      child: Scaffold(
      body: Column(
        children: [
          // LINKS_STARTUP: one-time "Attendix als App verfügbar!" (web)
          Expanded(child: page),
          const AudioPlayerWidget(),
        ],
      ),
      // Debug FAB only visible in debug mode
      floatingActionButton: kDebugMode ? const DebugRoleFab() : null,
      // IOS_LOOK: ion-tab-bar md; iOS: [_buildIos].
      // PARITY_R3: hidden while the keyboard is open (Ionic tab-bar-hidden).
      bottomNavigationBar: isKeyboardOpen(context)
          ? null
          : _MdTabBar(
              selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
              onSelected: (index) => _onItemTapped(context, ref, index, destinations),
              destinations: destinations,
            ),
      ),
    );
  }
}

/// PARITY_R3: Ionic hides `ion-tab-bar` while the on-screen keyboard is
/// open (`tab-bar-hidden`, keyboard controller). Flutter (native and mobile
/// web) reports the keyboard as bottom view insets.
@visibleForTesting
bool isKeyboardOpen(BuildContext context) =>
    MediaQuery.viewInsetsOf(context).bottom > 0;

/// IOS_SHELL2: Ionic md `ion-tab-bar` (desktop / Android): 56px high, page
/// background (#fff, dark #1f1f1f) with a 1px top border; the tab
/// buttons are at most 168px wide (`ion-tab-button` max-width), so on wide
/// screens they cluster in the centre and on phones they fill the width.
/// 22px icon over a 12px label, unselected `--ion-color-step-650`, selected
/// primary; no tooltips (Ionic has none).
class _MdTabBar extends StatelessWidget {
  const _MdTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  /// `ion-tab-button` max-width.
  static const double tabMaxWidth = 168;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // MD_SWEEP: unselected `--ion-color-step-650` (#595959, md dark
    // #acacac); 1px top border rgba(0,0,0,.07) / dark #222222.
    final background = IonMd.tabBarBackground(theme.brightness);
    final unselected = IonMd.step650(theme.brightness);
    final primary = theme.colorScheme.primary;
    final base = NavigationBarTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: IonMd.tabBarBorder(theme.brightness),
            width: 1,
          ),
        ),
      ),
      // PARITY_R9: `box-sizing: content-box` – the 1px border sits above
      // the 56px bar, so the hairline runs across the full width instead of
      // being painted over by the centred tab cluster.
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: tabMaxWidth * destinations.length),
          child: NavigationBarTheme(
            data: base.copyWith(
              backgroundColor: background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 56,
              indicatorColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              iconTheme: WidgetStateProperty.resolveWith((states) =>
                  IconThemeData(
                    size: 22,
                    color: states.contains(WidgetState.selected)
                        ? primary
                        : unselected,
                  )),
              labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.36,
                    color: states.contains(WidgetState.selected)
                        ? primary
                        : unselected,
                  )),
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                    tooltip: '',
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// IOS_SHELL2: the shell pages plus Ionic's fade behind the tab bar. The fade
/// uses the background of the page on top (Ionic: the `ion-content`
/// colour, e.g. white for Meine Termine, light grey for inset-list pages), so
/// no grey band appears below white pages. The page is looked up after each
/// navigation and when a page's scroll view reports its metrics.
class _IosPageWithFade extends StatefulWidget {
  const _IosPageWithFade({
    required this.location,
    required this.fadeHeight,
    required this.child,
  });

  final String location;
  final double fadeHeight;
  final Widget child;

  @override
  State<_IosPageWithFade> createState() => _IosPageWithFadeState();
}

class _IosPageWithFadeState extends State<_IosPageWithFade> {
  Color? _pageColor;

  @override
  void initState() {
    super.initState();
    _scheduleProbe();
  }

  @override
  void didUpdateWidget(_IosPageWithFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _scheduleProbe();
  }

  void _scheduleProbe() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  /// Background of the outermost Scaffold of the top-most route (routes
  /// below an opaque route have their tickers disabled; a popped route that
  /// is still animating out is no longer active).
  void _probe() {
    if (!mounted) return;
    Color? found;
    void visit(Element e) {
      final w = e.widget;
      if (w is TickerMode && !w.enabled) return;
      if (w is Scaffold) {
        if (ModalRoute.of(e)?.isActive ?? true) {
          found =
              w.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
        }
        return;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    if (found != null && found != _pageColor) {
      setState(() => _pageColor = found);
    }
  }

  bool _onScrollMetrics(ScrollMetricsNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      // The Scaffold around the scroll view paints the page background.
      final scaffold = n.context.findAncestorWidgetOfExactType<Scaffold>();
      if (scaffold != null) {
        final color = scaffold.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor;
        if (color != _pageColor) setState(() => _pageColor = color);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onScrollMetrics,
            child: widget.child,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IosTabBarFade(height: widget.fadeHeight, color: _pageColor),
        ),
      ],
    );
  }
}

/// IOS_SHELL2: "Neue Version verfügbar" closed for this session (iOS toast).
final _updateToastDismissedProvider = StateProvider<bool>((ref) => false);

/// IOS_SHELL2: iOS update notice as an Ionic iOS 26 `ion-toast` (Liquid
/// Glass pill, radius 24, 16pt from the sides) floating right above the tab
/// bar. The shell adds its height to the pages' bottom inset, so it never
/// covers the end of a list. Material keeps the floating SnackBar
/// ([ToastHelper.showUpdateAvailable]).
class _IosUpdateToast extends StatelessWidget {
  const _IosUpdateToast({required this.onUpdate, required this.onClose});

  static const double height = 50;
  static const double gap = 8;

  final VoidCallback onUpdate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, gap),
      child: SizedBox(
        height: height,
        // IOS27_SWEEP: ion-toast glass overlay (rgba(glass, .67), 0.5pt
        // rgba(text, .18) border, .06 shadow), app radius 24 (global.scss).
        child: IosGlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          overlay: true,
          blur: 20,
          shadowOpacity: 0.06,
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Icon(Icons.cloud_download_outlined,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.coreFlutterNewVersionAvailable,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: text),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minSize: 36,
                onPressed: onUpdate,
                child: Text(
                  l10n.coreFlutterUpdate,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.commonClose,
                excludeSemantics: true,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minSize: 36,
                  onPressed: onClose,
                  child: Icon(Icons.close,
                      size: 18, color: text.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
