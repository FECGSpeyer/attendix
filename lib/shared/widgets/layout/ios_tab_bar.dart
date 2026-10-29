import 'package:flutter/material.dart';

import '../../../core/utils/haptic_helper.dart';
import '../adaptive/adaptive_platform.dart';

/// One tab of [IosTabBar].
class IosTabBarItem {
  const IosTabBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// IOS_LOOK: `ion-tab-bar` in the Ionic iOS theme (IOS27_SWEEP:
/// @rdlabo/ionic-theme-ios27 1.1.0 plus the app's tabs.page.scss): a
/// floating Liquid Glass pill at the bottom left (16pt from the edge,
/// `max(10, safe-area-bottom − 12)` above the bottom), 62pt high (54pt
/// buttons + 4pt padding) with 31pt corners, leaving room on the right for
/// the page's `ion-fab` (see [TabBarFab]), which sits in the same row,
/// vertically centred with the bar.
/// Tabs show a 26pt icon over a 0.59rem (10pt) label, 7pt from the top
/// (labels are scaled down instead of truncated, e.g. "Meine Termine"); the
/// selected tab gets a 27pt-radius pill and the primary colour, the others
/// use `--ion-text-color-step-50` (#0d0d0d; dark: the text colour).
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

  /// ios27 `height: 54px` + `padding: 4px` (content-box).
  static const double barHeight = 62;

  /// ios27 `border-radius: 31px`.
  static const double barRadius = 31;

  /// ios27 `padding: 4px`.
  static const double barPadding = 4;

  /// ios27 `ion-tab-button { height: 54px; border-radius: 27px }`.
  static const double buttonRadius = 27;

  /// ios27 `ion-tab-button { font-size: .59rem }` (1rem = 17px).
  static const double labelFontSize = 0.59 * 17;

  /// Outer width of the bar (content width + 2 × [barPadding]) for
  /// [tabCount] tabs on a screen [screenWidth] wide:
  /// - ios27: `calc(100% - (18px + safe-left) - (18px + safe-right) - 75px)`,
  ///   max 471px; exactly two tabs 180px;
  /// - ≥ 5 tabs: the app's tabs.page.scss `calc(100% - (18px + safe-left) * 2
  ///   - 60px - 12px)`, max 474px;
  /// - from 768px (iPad) the compact platter: max 180 / 266 / 328 / 406px
  ///   for 2 / 3 / 4 / 5 tabs.
  static double barWidthFor({
    required double screenWidth,
    required int tabCount,
    EdgeInsets safeArea = EdgeInsets.zero,
  }) {
    double content;
    double max;
    if (tabCount == 2) {
      content = 180;
      max = 180;
    } else if (tabCount >= 5) {
      content = screenWidth - (18 + safeArea.left) * 2 - 72;
      max = 474;
    } else {
      content = screenWidth - (18 + safeArea.left) - (18 + safeArea.right) - 75;
      max = 471;
    }
    if (screenWidth >= 768) {
      const ipad = {2: 180.0, 3: 266.0, 4: 328.0, 5: 406.0};
      max = ipad[tabCount] ?? max;
    }
    return content.clamp(0.0, max).toDouble() + 2 * barPadding;
  }

  /// ios27 tab bar background: `rgba(glass, .53)`; dark
  /// `color-mix(color-mix(glass 92%, text) 40%, transparent)` ≈ #4D4D4D at
  /// 40 %.
  static Color background(Brightness b) => b == Brightness.dark
      ? const Color(0xFF4D4D4D).withValues(alpha: 0.4)
      : Colors.white.withValues(alpha: 0.53);

  /// ios27 `--color` of the tabs: `--ion-text-color-step-50` (#0d0d0d) in
  /// light mode, the text colour in dark mode.
  static Color unselectedColor(Brightness b) =>
      b == Brightness.dark ? Colors.white : const Color(0xFF0D0D0D);

  /// Right edge of the tab bar row (`ion-fab` `right: 16px + safe-right`).
  static double fabRight(BuildContext context) =>
      16 + MediaQuery.paddingOf(context).right;

  /// `max(10px, var(--ion-safe-area-bottom) - 12px)`
  static double bottomOffset(BuildContext context) =>
      (MediaQuery.paddingOf(context).bottom - 12).clamp(10.0, double.infinity);

  /// IOS_SHELL2: room the floating bar takes at the bottom of the page
  /// (ionic-theme-ios27 `ion-content.content-fullscreen`
  /// `--padding-bottom: calc(60px + floating-safe-area-bottom)` – 60, not
  /// the 62pt bar height). Pages scroll under the bar; [MainShell] hands
  /// this to them as MediaQuery bottom padding.
  static const double contentPadding = 60;

  static double contentInset(BuildContext context) =>
      contentPadding + bottomOffset(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final padding = MediaQuery.paddingOf(context);
    final barWidth = barWidthFor(
      screenWidth: MediaQuery.sizeOf(context).width,
      tabCount: items.length,
      safeArea: padding,
    );
    final bottom = bottomOffset(context);
    final primary = theme.colorScheme.primary;
    final text = unselectedColor(b);

    return SizedBox(
      height: barHeight + bottom + 6,
      child: Stack(
        children: [
          Positioned(
            left: 16 + padding.left,
            bottom: bottom,
            width: barWidth,
            height: barHeight,
            // ios27: blur(6px) saturate(180%) brightness(1.05); dark
            // saturate(150%) brightness(1.23) (saturation not emulated).
            child: IosGlassSurface(
              borderRadius:
                  const BorderRadius.all(Radius.circular(barRadius)),
              blur: 6,
              color: background(b),
              backdropBrightness: b == Brightness.dark ? 1.23 : 1.05,
              padding: const EdgeInsets.all(barPadding),
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
            borderRadius: BorderRadius.circular(IosTabBar.buttonRadius),
          ),
          // ion-tab-button (ios) --padding-start/end 2px; ios27
          // icon-top layout: --padding-top 7px, content from the top.
          padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(item.icon, size: 26, color: color),
              const SizedBox(height: 2),
              // Ionic shows long labels ("Meine Termine") in full: shrink
              // the 0.59rem label to the button width instead of an
              // ellipsis.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: IosTabBar.labelFontSize,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
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

/// IOS_SHELL2: the fade at the bottom of the page behind the floating tab
/// bar (Ionic iOS 26 `ion-content.content-fullscreen::part(background)::after`:
/// `calc(60px + floating-safe-area-bottom)` high, page background from 0 %
/// opacity to 80 % at half height and below). Content scrolling under the bar
/// fades out instead of ending in a separate strip.
class IosTabBarFade extends StatelessWidget {
  const IosTabBarFade({super.key, required this.height, this.color});

  final double height;

  /// Page background (`--ios26-content-box-shadow-rgb`); defaults to the
  /// scaffold background.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.withValues(alpha: 0),
                c.withValues(alpha: 0.8),
                c.withValues(alpha: 0.8),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// IOS_SHELL2: end padding for a page scroll view that sets its own
/// `padding` (scroll views without one get the MediaQuery padding
/// automatically): [base] plus the MediaQuery bottom padding, which is the
/// floating tab bar inset inside the iOS tab shell and the safe area
/// elsewhere. [fabRoom] is the extra room a floating Material FAB needs over
/// the list end; it is dropped inside the iOS tab shell, where the page FAB
/// sits in the tab bar row ([TabBarFab]).
double scrollEndPadding(
  BuildContext context, {
  double base = 0,
  double fabRoom = 0,
}) {
  final inIosShell =
      IosTabBarScope.maybeOf(context) != null && useIosLook(context);
  return base + (inIosShell ? 0 : fabRoom) + MediaQuery.paddingOf(context).bottom;
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
