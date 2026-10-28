import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';

/// One entry of [showAppPopoverMenu] (an `ion-item button` inside the
/// `ion-list lines="none"` of an `ion-popover`).
class AppPopoverMenuItem<T> {
  const AppPopoverMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.color,
    this.submenu = false,
    this.destructive = false,
  });

  /// Returned by [showAppPopoverMenu] when the entry is tapped.
  final T value;
  final String label;

  /// `ion-icon slot="start"`.
  final IconData? icon;

  /// Second line (`<p>` inside the label).
  final String? subtitle;

  /// Label / icon colour (e.g. primary for an active filter). Defaults to the
  /// text colour – Ionic iOS popover icons are black.
  final Color? color;

  /// The entry opens a sub menu (Ionic `detail="true"` → chevron on iOS).
  final bool submenu;

  /// Red label and icon.
  final bool destructive;
}

/// IOS_DETAIL: menu behind a toolbar button (Ionic `ion-popover` with an
/// `ion-list` of button items).
///
/// - iOS: the Ionic iOS 26 popover – a frosted, rounded (24) card right
///   below [context]'s widget (the trigger button), 44 pt rows with black
///   icons, a chevron on [AppPopoverMenuItem.submenu] entries and no
///   pre-selected row.
/// - elsewhere: the Material popup menu ([showMenu]) at the button, like
///   [PopupMenuButton].
///
/// [context] must be the trigger button's context (use a [Builder]).
/// Returns the tapped entry's value, or null when dismissed.
Future<T?> showAppPopoverMenu<T>({
  required BuildContext context,
  required List<AppPopoverMenuItem<T>> items,
  double iosWidth = 250,
}) {
  final button = context.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = Rect.fromPoints(
    button.localToGlobal(Offset.zero, ancestor: overlay),
    button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
  );

  if (!useIosLook(context)) {
    // IOS_THEME2: Ionic md popover opens below its trigger (nothing under
    // the pointer gets highlighted) and shows a chevron on sub menus.
    final below = Rect.fromLTWH(anchor.left, anchor.bottom, anchor.width, 0);
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(below, Offset.zero & overlay.size),
      items: [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            child: ListTile(
              leading: item.icon == null
                  ? null
                  : Icon(item.icon, color: _itemColor(item)),
              title: Text(item.label, style: TextStyle(color: _itemColor(item))),
              subtitle: item.subtitle == null ? null : Text(item.subtitle!),
              trailing: item.submenu
                  ? const Icon(Icons.chevron_right, color: AppColors.medium)
                  : null,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  return navigator.push<T>(
    _IosPopoverRoute<T>(
      anchor: anchor,
      overlaySize: overlay.size,
      items: items,
      width: iosWidth,
      barrierLabel: context.l10n.commonClose,
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

Color? _itemColor(AppPopoverMenuItem<dynamic> item) =>
    item.destructive ? AppColors.danger : item.color;

class _IosPopoverRoute<T> extends PopupRoute<T> {
  _IosPopoverRoute({
    required this.anchor,
    required this.overlaySize,
    required this.items,
    required this.width,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final Rect anchor;
  final Size overlaySize;
  final List<AppPopoverMenuItem<T>> items;
  final double width;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    const margin = 8.0;
    final w = math.min(width, overlaySize.width - 2 * margin);
    // Right-aligned with the trigger button, kept on screen.
    final right = (overlaySize.width - anchor.right)
        .clamp(margin, math.max(margin, overlaySize.width - w - margin))
        .toDouble();
    final top = anchor.bottom + 6;
    final maxHeight = math.max(
      120.0,
      overlaySize.height - top - media.padding.bottom - margin,
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );

    return capturedThemes.wrap(
      MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Stack(
          children: [
            Positioned(
              top: top,
              right: right,
              width: w,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
                  alignment: Alignment.topRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: _IosPopoverCard<T>(items: items),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IosPopoverCard<T> extends StatelessWidget {
  const _IosPopoverCard({required this.items});

  final List<AppPopoverMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    return IosGlassSurface(
      // IOS_THEME2: ionic-theme-ios26 popover radius 24.
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      opacity: 0.9,
      blur: 20,
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items) _IosPopoverRow<T>(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosPopoverRow<T> extends StatelessWidget {
  const _IosPopoverRow({required this.item});

  final AppPopoverMenuItem<T> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = _itemColor(item) ?? theme.colorScheme.onSurface;
    return InkWell(
      // iOS: grey press highlight, no ripple, nothing highlighted initially.
      splashFactory: NoSplash.splashFactory,
      highlightColor: IosGlass.overlayButton(theme.brightness),
      onTap: () => Navigator.of(context).pop<T>(item.value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 22, color: fg),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(fontSize: 16, color: fg),
                    ),
                    if (item.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.subtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.medium,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.submenu) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.medium.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
