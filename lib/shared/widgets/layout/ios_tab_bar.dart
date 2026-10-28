import 'package:flutter/material.dart';

import '../../../core/utils/haptic_helper.dart';
import '../adaptive/adaptive_platform.dart';

/// One tab of [IosTabBar].
class IosTabBarItem {
  const IosTabBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// IOS_LOOK: `ion-tab-bar` in the Ionic iOS 26 theme (as configured in
/// Ionic tabs.page.scss): a floating Liquid Glass pill at the bottom left
/// (16pt from the edge, `max(10, safe-area-bottom − 12)` above the bottom),
/// 60pt high (56pt buttons + 2pt padding) with 40pt corners, leaving 72pt on
/// the right for the page's `ion-fab` (see [TabBarFab]), which sits in the
/// same row, vertically centred with the bar.
/// Tabs show a 26pt icon over a 10pt label (scaled down instead of
/// truncated, e.g. "Meine Termine"); the selected tab gets a soft grey pill
/// and the primary colour, the others use the text colour.
class IosTabBar extends StatelessWidget {
  const IosTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<IosTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// `min-height: 56px` + `padding: 2px` (content-box).
  static const double barHeight = 60;

  /// Right edge of the tab bar row (`ion-fab` `right: 16px + safe-right`).
  static double fabRight(BuildContext context) =>
      16 + MediaQuery.paddingOf(context).right;

  /// `max(10px, var(--ion-safe-area-bottom) - 12px)`
  static double bottomOffset(BuildContext context) =>
      (MediaQuery.paddingOf(context).bottom - 12).clamp(10.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    // calc(100% - (18px + safe-left) * 2 - 60px - 12px), max 474px
    final barWidth = (width - (18 + padding.left) * 2 - 72)
        .clamp(180.0, 474.0)
        .toDouble();
    final bottom = bottomOffset(context);
    final primary = theme.colorScheme.primary;
    final text = theme.colorScheme.onSurface;

    return SizedBox(
      height: barHeight + bottom + 6,
      child: Stack(
        children: [
          Positioned(
            left: 16 + padding.left,
            bottom: bottom,
            width: barWidth,
            height: barHeight,
            child: IosGlassSurface(
              borderRadius: const BorderRadius.all(Radius.circular(40)),
              blur: 6,
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _TabButton(
                        item: items[i],
                        selected: i == selectedIndex,
                        color: i == selectedIndex ? primary : text,
                        pill: IosGlass.selectedPill(b),
                        onTap: () {
                          HapticHelper.light();
                          onSelected(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.color,
    required this.pill,
    required this.onTap,
  });

  final IosTabBarItem item;
  final bool selected;
  final Color color;
  final Color pill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: selected ? pill : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 26, color: color),
              const SizedBox(height: 2),
              // Ionic shows long labels ("Meine Termine") in full: shrink
              // the 10pt label to the button width instead of an ellipsis.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IOS_LOOK: marks the subtree of [MainShell] that shows the floating
/// [IosTabBar]; pages below use it (via [TabBarFab]) to put their `ion-fab`
/// into the tab bar row like the Ionic iOS 26 theme.
class IosTabBarScope extends InheritedWidget {
  const IosTabBarScope({
    super.key,
    required this.bottom,
    required this.right,
    required super.child,
  });

  /// Distance of the tab bar row from the bottom of the screen.
  final double bottom;

  /// Distance of the FAB from the right edge of the screen.
  final double right;

  static IosTabBarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IosTabBarScope>();

  @override
  bool updateShouldNotify(IosTabBarScope oldWidget) =>
      bottom != oldWidget.bottom || right != oldWidget.right;
}

/// IOS_LOOK: wraps a page's `floatingActionButton`. Inside the iOS tab shell
/// ([IosTabBarScope]) the button is rendered in the tab bar row – right of
/// the floating tab bar, vertically centred with it (Ionic iOS 26:
/// `ion-fab` bottom = tab bar bottom, right 16pt) – so it never covers page
/// content. It is only shown while its page is the current route. Outside
/// the iOS shell (Material, desktop) the child is returned unchanged and the
/// Scaffold places it as usual.
class TabBarFab extends StatefulWidget {
  const TabBarFab({super.key, required this.child});

  final Widget child;

  /// `TabBarFab(child: fab)` or null when [fab] is null.
  static Widget? wrap(Widget? fab) => fab == null ? null : TabBarFab(child: fab);

  @override
  State<TabBarFab> createState() => _TabBarFabState();
}

class _TabBarFabState extends State<TabBarFab> {
  final _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _controller.show();
  }

  @override
  Widget build(BuildContext context) {
    final scope = IosTabBarScope.maybeOf(context);
    if (scope == null || !useIosLook(context)) return widget.child;
    // Hide while another route (pushed page, sheet, dialog of the shell
    // navigator) lies on top of this page.
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    return OverlayPortal.targetsRootOverlay(
      controller: _controller,
      overlayChildBuilder: (context) => !visible
          ? const SizedBox.shrink()
          : Positioned(
              right: scope.right,
              bottom: scope.bottom,
              height: IosTabBar.barHeight,
              child: Center(widthFactor: 1, child: widget.child),
            ),
      child: const SizedBox.shrink(),
    );
  }
}
