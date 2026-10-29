import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../layout/ionic_ios.dart' show IonIos, IonDetailChevron; // IOS27_SWEEP
import 'adaptive_platform.dart';

/// iOS nested popovers (`side="start"`, iOS default `alignment="center"`)
/// are centred on their trigger row and moved down by Ionic's
/// `POPOVER_IOS_BODY_MARGIN` (ionic-theme-utils `calculateWindowAdjustment`).
/// Ionic does not clamp them vertically: on a phone a tall submenu runs off
/// the top of the screen, and the parent's lower rows stay readable below it.
const double kIosNestedPopoverOffset = 8;

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
    this.submenuItems,
    this.destructive = false,
  });

  /// Returned by [showAppPopoverMenu] when the entry is tapped (entries with
  /// [submenuItems] open their nested popover instead).
  final T value;
  final String label;

  /// `ion-icon slot="start"`.
  final IconData? icon;

  /// Second line (`<p>` inside the label).
  final String? subtitle;

  /// Label / icon colour (e.g. primary for an active filter). Defaults to the
  /// text colour – Ionic iOS popover icons are black.
  final Color? color;

  /// The entry opens a sub menu (Ionic `detail="true"` → chevron).
  final bool submenu;

  /// PARITY_R3: entries of a nested `ion-popover` (`side="start"`,
  /// `dismissOnSelect=false`) opened by this entry. Called again after
  /// every tap in the nested popover so checkboxes reflect the new state;
  /// the parent menu stays open.
  final List<AppPopoverSubItem> Function()? submenuItems;

  /// Red label and icon.
  final bool destructive;

  bool get _hasChevron => submenu || submenuItems != null;
}

/// PARITY_R3: one row of a nested popover (`ion-item button
/// detail="false"`): a checkbox (`ion-checkbox slot="start"`) when
/// [checked] is set, otherwise an optional icon. [onTap] runs immediately
/// and the popover stays open.
class AppPopoverSubItem {
  const AppPopoverSubItem({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.checked,
    this.icon,
    this.color,
  });

  final String label;
  final String? subtitle;
  final bool? checked;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;
}

/// IOS_DETAIL: menu behind a toolbar button (Ionic `ion-popover` with an
/// `ion-list` of button items).
///
/// - iOS: the Ionic iOS 26 popover – a frosted, rounded (24) card right
///   below [context]'s widget (the trigger button), 44 pt rows with black
///   icons.
/// - elsewhere (PARITY_R3): the Ionic md popover – white card (radius 4,
///   md shadow, 250 wide) right below the trigger, 48 px rows with grey
///   24 px icons.
///
/// Both: a chevron on sub menu entries, no pre-selected/highlighted row,
/// and entries with [AppPopoverMenuItem.submenuItems] open a nested popover
/// to the left of the entry (Ionic `side="start"`). A tap outside closes
/// everything; a tap on another entry closes the nested popover first.
///
/// [context] must be the trigger button's context (use a [Builder]).
/// [itemsBuilder] (optional) rebuilds the entries while a nested popover
/// changes state (e.g. the "Filter aktiv" subtitle). Returns the tapped
/// entry's value, or null when dismissed.
Future<T?> showAppPopoverMenu<T>({
  required BuildContext context,
  required List<AppPopoverMenuItem<T>> items,
  List<AppPopoverMenuItem<T>> Function()? itemsBuilder,
  // Ionic `popover.ios.css`: `--width: 200px` (md 250px).
  double iosWidth = 200,
}) {
  final button = context.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(context, rootNavigator: true); // IOS_SHELL2
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = Rect.fromPoints(
    button.localToGlobal(Offset.zero, ancestor: overlay),
    button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    ),
  );
  final ios = useIosLook(context);

  return navigator.push<T>(
    _PopoverRoute<T>(
      ios: ios,
      anchor: anchor,
      overlaySize: overlay.size,
      items: items,
      itemsBuilder: itemsBuilder,
      width: ios ? iosWidth : 250,
      barrierLabel: context.l10n.commonClose,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

Color? _itemColor(AppPopoverMenuItem<dynamic> item) =>
    item.destructive ? AppColors.danger : item.color;

class _PopoverRoute<T> extends PopupRoute<T> {
  _PopoverRoute({
    required this.ios,
    required this.anchor,
    required this.overlaySize,
    required this.items,
    required this.itemsBuilder,
    required this.width,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final bool ios;
  final Rect anchor;
  final Size overlaySize;
  final List<AppPopoverMenuItem<T>> items;
  final List<AppPopoverMenuItem<T>> Function()? itemsBuilder;
  final double width;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  /// AUDIT_R4: Ionic md dims the page behind a popover
  /// (`--backdrop-opacity: var(--ion-backdrop-opacity, .32)`); the ios27
  /// theme sets `--backdrop-opacity: 0`.
  @override
  Color? get barrierColor =>
      ios ? Colors.transparent : Colors.black.withValues(alpha: 0.32);

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
    return capturedThemes.wrap(
      MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: _PopoverLayer<T>(
          route: this,
          animation: animation,
          topPadding: MediaQuery.of(context).padding.top,
          bottomPadding: MediaQuery.of(context).padding.bottom,
        ),
      ),
    );
  }
}

class _PopoverLayer<T> extends StatefulWidget {
  const _PopoverLayer({
    required this.route,
    required this.animation,
    required this.topPadding,
    required this.bottomPadding,
  });

  final _PopoverRoute<T> route;
  final Animation<double> animation;

  /// Safe area top (the layer itself runs without padding).
  final double topPadding;
  final double bottomPadding;

  @override
  State<_PopoverLayer<T>> createState() => _PopoverLayerState<T>();
}

class _PopoverLayerState<T> extends State<_PopoverLayer<T>> {
  static const _margin = 8.0;

  final _stackKey = GlobalKey();
  late List<AppPopoverMenuItem<T>> _items = widget.route.items;

  /// Index of the entry whose nested popover is open.
  int? _openIndex;
  Rect? _openRowRect;

  void _refresh() {
    setState(() {
      final builder = widget.route.itemsBuilder;
      if (builder != null) _items = builder();
    });
  }

  void _onRowTap(int index, BuildContext rowContext) {
    final item = _items[index];
    if (item.submenuItems == null) {
      Navigator.of(context).pop<T>(item.value);
      return;
    }
    if (_openIndex == index) return; // Ionic: tapping the trigger keeps it
    final row = rowContext.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (row == null || stack == null) return;
    final topLeft = row.localToGlobal(Offset.zero, ancestor: stack);
    setState(() {
      _openIndex = index;
      _openRowRect = topLeft & row.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final ios = route.ios;
    final size = route.overlaySize;
    final anchor = route.anchor;
    final w = math.min(route.width, size.width - 2 * _margin);
    // iOS: right-aligned with the trigger button. md (`alignment: start`):
    // left edge at the trigger, pushed back into the viewport.
    final double left;
    if (ios) {
      final right =
          (size.width - anchor.right)
              .clamp(_margin, math.max(_margin, size.width - w - _margin))
              .toDouble();
      left = size.width - right - w;
    } else {
      left =
          anchor.left
              .clamp(_margin, math.max(_margin, size.width - w - _margin))
              .toDouble();
    }
    // PARITY_R9: ionic-theme-utils `iosPopoverEnterAnimation` (the app's
    // `popoverEnter` on iOS) treats an `ion-button` trigger as a morphing
    // "replace" surface: `calculateWindowAdjustment(…, isReplace)` puts the
    // top at `trigger.top + trigger.height - trigger.height`, i.e. the menu
    // opens over its trigger (Ionic iPhone emulation: ⋮ and menu top y 16).
    // md (`popover.md`, side bottom): directly below the trigger.
    final top = ios ? anchor.top : anchor.bottom;
    final maxHeight = math.max(
      120.0,
      size.height - top - widget.bottomPadding - _margin,
    );
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );

    final children = <Widget>[
      Positioned(
        top: top,
        left: left,
        width: w,
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: ios ? 0.85 : 0.8,
              end: 1,
            ).animate(curved),
            alignment: ios ? Alignment.topRight : Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: _PopoverCard(
                ios: ios,
                // PARITY_R8: while a nested popover is open the parent
                // stays a plain opaque card – no glass smear of the page
                // behind its labels.
                opaque: ios && _openIndex != null,
                // Ionic: a tap inside the parent (not on the trigger)
                // dismisses the nested popover.
                onBackgroundTap:
                    _openIndex == null
                        ? null
                        : () => setState(() => _openIndex = null),
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Builder(
                      builder:
                          (rowContext) => _PopoverRow(
                            ios: ios,
                            icon: _items[i].icon,
                            label: _items[i].label,
                            subtitle: _items[i].subtitle,
                            color: _itemColor(_items[i]),
                            chevron: _items[i]._hasChevron,
                            onTap: () {
                              if (_openIndex != null && _openIndex != i) {
                                setState(() => _openIndex = null);
                              }
                              _onRowTap(i, rowContext);
                            },
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];

    final openIndex = _openIndex;
    final rowRect = _openRowRect;
    if (openIndex != null && rowRect != null && openIndex < _items.length) {
      final sub = _items[openIndex].submenuItems!();
      // Nested popovers keep Ionic's default width (iOS `--width: 200px`,
      // md 250px).
      final sw = math.min(ios ? 200.0 : 250.0, size.width - 2 * _margin);
      // side="start": right edge at the trigger's left edge, top aligned;
      // pushed back into the viewport when there is no room.
      var subLeft =
          (left - sw)
              .clamp(_margin, math.max(_margin, size.width - sw - _margin))
              .toDouble();
      if (ios && left - sw < _margin) {
        // No room on the left (phone): Ionic falls back to the trigger
        // row's left edge, i.e. the nested popover lies over the parent.
        subLeft = math.max(_margin, left + w - sw);
      }
      children.add(
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _NestedPopoverLayout(
              left: subLeft,
              width: sw,
              // md (`alignment="start"`): top aligned with the row.
              rowTop: rowRect.top,
              rowCenter: ios ? rowRect.center.dy : null,
              maxHeight:
                  ios
                      ? math.max(120.0, size.height - 2 * _margin)
                      : math.max(
                        120.0,
                        size.height -
                            rowRect.top -
                            widget.bottomPadding -
                            _margin,
                      ),
            ),
            child: _PopoverCard(
              ios: ios,
              children: [
                for (final s in sub)
                  _PopoverRow(
                    ios: ios,
                    icon: s.icon,
                    checked: s.checked,
                    label: s.label,
                    subtitle: s.subtitle,
                    color: s.color,
                    onTap: () {
                      s.onTap();
                      _refresh();
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(key: _stackKey, children: children);
  }
}

/// Places a nested popover: [left]/[width] fixed; vertically centred on
/// [rowCenter] plus [kIosNestedPopoverOffset] (iOS, may leave the screen at
/// the top like Ionic) or top-aligned with [rowTop] (md).
class _NestedPopoverLayout extends SingleChildLayoutDelegate {
  _NestedPopoverLayout({
    required this.left,
    required this.width,
    required this.rowTop,
    required this.rowCenter,
    required this.maxHeight,
  });

  final double left;
  final double width;
  final double rowTop;
  final double? rowCenter;
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: maxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final center = rowCenter;
    final top =
        center == null
            ? rowTop
            : center - childSize.height / 2 + kIosNestedPopoverOffset;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_NestedPopoverLayout old) =>
      old.left != left ||
      old.width != width ||
      old.rowTop != rowTop ||
      old.rowCenter != rowCenter ||
      old.maxHeight != maxHeight;
}

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.ios,
    required this.children,
    this.onBackgroundTap,
    this.opaque = false,
  });

  final bool ios;
  final List<Widget> children;
  final VoidCallback? onBackgroundTap;

  /// PARITY_R8: iOS only – an opaque surface (item background) instead of
  /// the translucent glass, used for the parent while a nested popover is
  /// open.
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    Widget list = SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: ios ? 6 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    if (onBackgroundTap != null) {
      list = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onBackgroundTap,
        child: list,
      );
    }
    if (ios && opaque) {
      // PARITY_R8: same shape (radius 34), border and shadow as the glass
      // popover, filled with the item background (white / dark card) and
      // without backdrop blur, so the labels stay crisp.
      final brightness = Theme.of(context).brightness;
      const radius = BorderRadius.all(Radius.circular(34));
      return CustomPaint(
        painter: const IosOuterShadowPainter(
          borderRadius: radius,
          shadows: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  brightness == Brightness.dark
                      ? const Color(0xFF1C1C1D)
                      : Colors.white,
              borderRadius: radius,
              border: Border.all(
                color: IosGlass.overlayBorder(brightness),
                width: 0.5,
              ),
            ),
            child: Material(type: MaterialType.transparency, child: list),
          ),
        ),
      );
    }
    if (ios) {
      // IOS27_SWEEP: ionic-theme-ios27 popover – radius 34, rgba(glass,
      // .42) over blur(12px) brightness(1.35).
      return IosGlassSurface.popover(
        brightness: Theme.of(context).brightness,
        child: Material(type: MaterialType.transparency, child: list),
      );
    }
    // Ionic md popover: --background (item colour), radius 4, md shadow
    // (elevation ≈8).
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: list,
    );
  }
}

class _PopoverRow extends StatelessWidget {
  const _PopoverRow({
    required this.ios,
    required this.label,
    required this.onTap,
    this.icon,
    this.checked,
    this.subtitle,
    this.color,
    this.chevron = false,
  });

  final bool ios;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool? checked;
  final String? subtitle;
  final Color? color;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final fg = color ?? onSurface;
    // md: `ion-icon` in an item = rgba(text, .54), 24 px, 32 px gap.
    final iconColor =
        color ?? (ios ? onSurface : onSurface.withValues(alpha: 0.54));

    Widget? leading;
    if (checked != null) {
      leading = IgnorePointer(
        child: SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: checked,
            onChanged: (_) {},
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    } else if (icon != null) {
      // iOS: Ionic item `::slotted(ion-icon)` 1.6em of 17pt = 27.2pt.
      leading = Icon(icon, size: ios ? 27.2 : 24, color: iconColor);
    }

    return InkWell(
      // No ripple on iOS, grey press highlight; nothing highlighted
      // initially (no focus / initial value).
      splashFactory: ios ? NoSplash.splashFactory : null,
      highlightColor: ios ? IosGlass.itemActivated(theme.brightness) : null,
      canRequestFocus: false,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ios ? 44 : 48),
        // iOS (Ionic item in a 200pt popover): padding-start 16, icon
        // margin-end 16, label margin 10/8/10/0, detail chevron margin-start
        // 8 / end -6, inner-padding-end 16 – long labels wrap to two lines
        // (60pt rows) like "Status-|Filter".
        child: Padding(
          padding:
              ios
                  ? EdgeInsets.only(left: 16, right: chevron ? 10 : 16)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[
                leading,
                SizedBox(width: ios ? 16 : (checked != null ? 16 : 32)),
              ],
              Expanded(
                child: Padding(
                  padding:
                      ios
                          ? const EdgeInsets.fromLTRB(0, 10, 8, 10)
                          : EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IOS27_SWEEP: ion-item 1rem = 17pt on the iPhone
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: ios ? 17 : 16,
                          // iOS: CSS `line-height: normal` (≈1.2) – 60pt two-line rows.
                          height: ios ? 1.2 : null,
                          color: fg,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: ios ? IonIos.pFontSize : 14,
                              color:
                                  ios
                                      ? IonIos.labelP(theme.brightness)
                                      : (theme.brightness == Brightness.dark
                                          ? const Color(0xFF999999)
                                          : const Color(0xFF666666)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (chevron) ...[
                SizedBox(width: ios ? 8 : 6),
                if (ios)
                  const IonDetailChevron()
                else
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    // Ionic md detail icon: text colour at .25.
                    color: onSurface.withValues(alpha: 0.25),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
