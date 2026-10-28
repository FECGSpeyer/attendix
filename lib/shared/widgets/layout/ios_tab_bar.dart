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
/// 56pt high with 40pt corners, leaving 72pt on the right for a FAB.
/// Tabs show a 26pt icon over a 10pt label; the selected tab gets a soft
/// grey pill and the primary colour, the others use the text colour.
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

  static const double barHeight = 56;

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
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 26, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
