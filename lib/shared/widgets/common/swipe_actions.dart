import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/theme/app_colors.dart';

/// One option of an Ionic-like `ion-item-sliding` (icon-only by default).
class SwipeOption {
  const SwipeOption({
    required this.icon,
    required this.onPressed,
    this.color = AppColors.primary,
    this.label,
  });

  /// Danger "trash" option, the most common Ionic swipe option.
  const SwipeOption.delete({required this.onPressed, this.label})
      : icon = Icons.delete_outline,
        color = AppColors.danger;

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final String? label;
}

/// Ionic `ion-item-sliding` with options on the end side.
///
/// [fullSwipe] mirrors `<ion-item-option expandable>` + `(ionSwipe)`: a full
/// swipe runs the last option (typically delete) right away.
class SwipeActions extends StatelessWidget {
  const SwipeActions({
    super.key,
    required this.child,
    required this.options,
    this.fullSwipe = false,
    this.enabled = true,
  });

  /// Shorthand for a single delete option.
  SwipeActions.delete({
    super.key,
    required this.child,
    required VoidCallback onDelete,
    this.fullSwipe = false,
    this.enabled = true,
  }) : options = [SwipeOption.delete(onPressed: onDelete)];

  final Widget child;
  final List<SwipeOption> options;
  final bool fullSwipe;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || options.isEmpty) return child;
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: (0.2 * options.length).clamp(0.2, 0.6),
        dismissible: fullSwipe
            ? DismissiblePane(onDismissed: options.last.onPressed)
            : null,
        children: [
          for (final o in options)
            SlidableAction(
              onPressed: (_) => o.onPressed(),
              backgroundColor: o.color,
              foregroundColor: Colors.white,
              icon: o.icon,
              label: o.label,
            ),
        ],
      ),
      child: child,
    );
  }
}
