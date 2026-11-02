import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SIDE_NAV (Ionic 4.19.0 `LayoutService`): navigation mode of the app.
/// - phone (< 768 px): tab bar
/// - tablet portrait (768–991 px): side panel as overlay (menu button,
///   swipe from the edge)
/// - from 992 px: fixed side panel next to the content, expanded or
///   collapsed to an icon rail
enum SideNavMode { none, overlay, fixed }

/// From this width the side panel replaces the tab bar (overlay).
const double sidePanelMinWidth = 768;

/// From this width the side panel stays next to the content (split pane).
const double sidePanelFixedMinWidth = 992;

/// Without a stored choice the fixed panel is expanded from this width on.
const double sidePanelExpandedDefaultMinWidth = 1200;

/// Ionic tabs.page.scss: `--side-width` of the fixed panel.
const double sidePanelWidth = 272;

/// Ionic tabs.page.scss: `--side-width` of the collapsed panel (icon rail).
const double sidePanelRailWidth = 72;

/// Ionic `ion-menu.side-nav-menu { --width: 300px; --max-width: 85vw }`.
const double sidePanelOverlayWidth = 300;

SideNavMode sideNavModeFor(double width) {
  if (width >= sidePanelFixedMinWidth) return SideNavMode.fixed;
  if (width >= sidePanelMinWidth) return SideNavMode.overlay;
  return SideNavMode.none;
}

/// Ionic `LayoutService.collapsed`: the fixed panel as an icon rail; the
/// overlay is always expanded. Without a stored choice the panel is
/// collapsed below [sidePanelExpandedDefaultMinWidth].
bool sideNavCollapsed(double width, bool? choice) {
  if (sideNavModeFor(width) != SideNavMode.fixed) return false;
  return choice ?? width < sidePanelExpandedDefaultMinWidth;
}

const _collapsedStorageKey = 'sidePanelCollapsed';

/// The user's collapse choice per device (Ionic localStorage
/// `sidePanelCollapsed`), null = no choice yet.
class SideNavCollapsedChoice extends StateNotifier<bool?> {
  SideNavCollapsedChoice() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_collapsedStorageKey);
      if (stored != null && mounted) state = stored == '1';
    } catch (_) {
      // Storage unavailable (private mode): the choice lasts this session.
    }
  }

  Future<void> set(bool collapsed) async {
    state = collapsed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_collapsedStorageKey, collapsed ? '1' : '0');
    } catch (_) {
      // Storage unavailable: the choice lasts this session.
    }
  }
}

final sideNavCollapsedChoiceProvider =
    StateNotifierProvider<SideNavCollapsedChoice, bool?>(
        (ref) => SideNavCollapsedChoice());

/// Tells the pages of the shell how the side panel is shown, so they can
/// add the menu button (overlay) and drop their own bell (Ionic
/// `body.side-panel-active app-notification-bell:not(.in-side-nav)`).
class SideNavScope extends InheritedWidget {
  const SideNavScope({
    super.key,
    required this.mode,
    required this.openOverlay,
    required super.child,
  });

  final SideNavMode mode;
  final VoidCallback openOverlay;

  static SideNavScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SideNavScope>();

  /// Ionic `layout.sidePanel()`: the side panel replaces the tab bar.
  static bool isActive(BuildContext context) =>
      (maybeOf(context)?.mode ?? SideNavMode.none) != SideNavMode.none;

  @override
  bool updateShouldNotify(SideNavScope oldWidget) => oldWidget.mode != mode;
}

/// Ionic `<ion-menu-button menu="side-nav" autoHide="true">` of the tab
/// root pages: only visible while the side panel is an overlay (tablet
/// portrait).
class SideNavMenuButton extends StatelessWidget {
  const SideNavMenuButton({super.key});

  /// The button for an AppBar `leading`, or null when it would be hidden.
  static Widget? maybe(BuildContext context) =>
      SideNavScope.maybeOf(context)?.mode == SideNavMode.overlay
          ? const SideNavMenuButton()
          : null;

  @override
  Widget build(BuildContext context) {
    final scope = SideNavScope.maybeOf(context);
    if (scope?.mode != SideNavMode.overlay) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: scope!.openOverlay,
    );
  }
}

/// Marks toolbar widgets that the side panel shows itself (the bell), so
/// [ToolbarButtonGroup] can drop them while the panel is visible.
abstract interface class HiddenWithSidePanel {}
