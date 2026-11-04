import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../layout/ionic_ios.dart' show IonIos, IonDetailChevron;
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
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = _anchorOf(context, overlay);
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

/// Global rect of [context]'s widget inside [overlay].
Rect _anchorOf(BuildContext context, RenderBox overlay) {
  final box = context.findRenderObject()! as RenderBox;
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero, ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
  );
}

/// Ionic `ion-popover` with free content (a help text, a glossary card)
/// instead of a menu – same surface, backdrop and animation as
/// [showAppPopoverMenu]. There is no button: a tap outside closes it.
///
/// Placement follows Ionic:
/// - anchored on [context]'s widget (the trigger button), or on [anchor]
///   (global coordinates, e.g. the point of a tapped text link – Ionic
///   `popoverController.create({event})`);
/// - md: below the anchor, left edge at the anchor;
/// - iOS: a button trigger ([anchor] null) is covered by the popover,
///   right-aligned with it (ios27 "replace", like [showAppPopoverMenu]);
///   any other anchor gets the popover below it, centred;
/// - pushed back into the viewport, and above the anchor when there is no
///   room below.
///
/// [width] is Ionic `--width` (default iOS 200 / md 250), [maxHeight] is
/// Ionic `--max-height`.
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Rect? anchor,
  double? width,
  double? maxHeight,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final ios = useIosLook(context);
  return navigator.push<T>(
    _ContentPopoverRoute<T>(
      ios: ios,
      anchor: anchor == null
          ? _anchorOf(context, overlay)
          : Rect.fromPoints(
              overlay.globalToLocal(anchor.topLeft),
              overlay.globalToLocal(anchor.bottomRight),
            ),
      coverAnchor: ios && anchor == null,
      width: width ?? (ios ? 200 : 250),
      maxHeight: maxHeight,
      builder: builder,
      barrierLabel: context.l10n.commonClose,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

class _ContentPopoverRoute<T> extends PopupRoute<T> {
  _ContentPopoverRoute({
    required this.ios,
    required this.anchor,
    required this.coverAnchor,
    required this.width,
    required this.maxHeight,
    required this.builder,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final bool ios;
  final Rect anchor;
  final bool coverAnchor;
  final double width;
  final double? maxHeight;
  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  // Same backdrop as [_PopoverRoute].
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
    final padding = MediaQuery.of(context).padding;
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
        child: _AnchoredPopover(
          ios: ios,
          anchor: anchor,
          coverAnchor: coverAnchor,
          width: width,
          maxHeight: maxHeight,
          topPadding: padding.top,
          bottomPadding: padding.bottom,
          animation: curved,
          originX: 0,
          child: _PopoverCard(
            ios: ios,
            children: [Builder(builder: builder)],
          ),
        ),
      ),
    );
  }
}

/// Where an [_AnchoredPopover] was put on its first layout. Like Ionic, a
/// popover is positioned once when it opens: when its content grows later
/// (e.g. a "Filter aktiv" subtitle) it keeps its top edge and scrolls
/// inside instead of jumping (a nested popover stays at its row).
class _PopoverPlacement {
  Size? viewport;
  double? top;
}

/// Popover surface at [anchor] with the Ionic enter animation (fade +
/// scale). The scale origin follows the placement: the top edge, or the
/// bottom edge when the popover opened above its anchor (Ionic
/// `originY = 'bottom'`); [originX] is the horizontal origin (-1 left,
/// 0 centre, 1 right).
class _AnchoredPopover extends StatefulWidget {
  const _AnchoredPopover({
    required this.ios,
    required this.anchor,
    required this.coverAnchor,
    required this.width,
    required this.maxHeight,
    required this.topPadding,
    required this.bottomPadding,
    required this.animation,
    required this.originX,
    required this.child,
  });

  final bool ios;
  final Rect anchor;
  final bool coverAnchor;
  final double width;
  final double? maxHeight;
  final double topPadding;
  final double bottomPadding;
  final Animation<double> animation;
  final double originX;
  final Widget child;

  @override
  State<_AnchoredPopover> createState() => _AnchoredPopoverState();
}

class _AnchoredPopoverState extends State<_AnchoredPopover> {
  final _placement = _PopoverPlacement();
  bool _above = false;

  /// Called from layout: the scale origin is updated after the frame.
  void _onPlaced(bool above) {
    if (above == _above) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && above != _above) setState(() => _above = above);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _AnchoredPopoverLayout(
        ios: widget.ios,
        anchor: widget.anchor,
        coverAnchor: widget.coverAnchor,
        width: widget.width,
        maxHeight: widget.maxHeight,
        topPadding: widget.topPadding,
        bottomPadding: widget.bottomPadding,
        placement: _placement,
        onPlaced: _onPlaced,
      ),
      child: FadeTransition(
        opacity: widget.animation,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: widget.ios ? 0.85 : 0.8,
            end: 1,
          ).animate(widget.animation),
          alignment: Alignment(widget.originX, _above ? 1 : -1),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Places a popover card at its anchor (see [showAppPopover]) and keeps it
/// fully inside the safe viewport: below (or, [coverAnchor], over) the
/// anchor, above it when there is no room below, otherwise pinned to the
/// bottom edge. The height is capped at the visible area (scrolls inside).
/// The top edge is decided on the first layout and kept ([placement]).
/// Shared by [showAppPopover] and the [showAppPopoverMenu] parent menu.
class _AnchoredPopoverLayout extends SingleChildLayoutDelegate {
  _AnchoredPopoverLayout({
    required this.ios,
    required this.anchor,
    required this.coverAnchor,
    required this.width,
    required this.maxHeight,
    required this.topPadding,
    required this.bottomPadding,
    required this.placement,
    required this.onPlaced,
  });

  static const _margin = 8.0;

  final bool ios;
  final Rect anchor;
  final bool coverAnchor;
  final double width;
  final double? maxHeight;
  final double topPadding;
  final double bottomPadding;
  final _PopoverPlacement placement;
  final ValueChanged<bool> onPlaced;

  /// The top edge kept from the first layout in this viewport.
  double? _fixedTop(Size viewport) =>
      placement.viewport == viewport ? placement.top : null;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final w = math.min(width, size.width - 2 * _margin);
    final fixedTop = _fixedTop(size);
    final room = fixedTop != null
        // Placed already: grow down to the bottom edge, then scroll.
        ? math.max(0.0, size.height - bottomPadding - _margin - fixedTop)
        : math.max(
            120.0,
            size.height - topPadding - bottomPadding - 2 * _margin,
          );
    return BoxConstraints(
      minWidth: w,
      maxWidth: w,
      maxHeight: maxHeight == null ? room : math.min(maxHeight!, room),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final w = childSize.width;
    final double preferredLeft;
    if (!ios) {
      preferredLeft = anchor.left;
    } else if (coverAnchor) {
      preferredLeft = anchor.right - w;
    } else {
      preferredLeft = anchor.center.dx - w / 2;
    }
    final left = preferredLeft
        .clamp(_margin, math.max(_margin, size.width - w - _margin))
        .toDouble();

    final fixedTop = _fixedTop(size);
    if (fixedTop != null) return Offset(left, fixedTop);

    // A trigger in the toolbar may sit inside the top safe-area margin: a
    // popover covering it keeps the trigger's top (Ionic "replace").
    final minTop = math.min(topPadding + _margin, math.max(0.0, anchor.top));
    final maxBottom = size.height - bottomPadding - _margin;
    var top = coverAnchor ? anchor.top : anchor.bottom;
    var isAbove = false;
    if (top + childSize.height > maxBottom) {
      // No room below: above the anchor (covering: bottom at its bottom).
      final above =
          (coverAnchor ? anchor.bottom : anchor.top) - childSize.height;
      isAbove = above >= minTop;
      top = isAbove ? above : maxBottom - childSize.height;
    }
    top = math.max(minTop, top);
    placement
      ..viewport = size
      ..top = top;
    onPlaced(isAbove);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_AnchoredPopoverLayout old) =>
      old.anchor != anchor ||
      old.ios != ios ||
      old.coverAnchor != coverAnchor ||
      old.width != width ||
      old.maxHeight != maxHeight ||
      old.topPadding != topPadding ||
      old.bottomPadding != bottomPadding;
}

/// Text styles of an `ion-label` inside a popover list (h3 heading and `p`
/// lines), shared by content popovers.
class AppPopoverText {
  const AppPopoverText._();

  static TextStyle heading(BuildContext context) => TextStyle(
        fontSize: useIosLook(context) ? 17 : 16,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle paragraph(BuildContext context) {
    final ios = useIosLook(context);
    final brightness = Theme.of(context).brightness;
    return TextStyle(
      fontSize: ios ? IonIos.pFontSize : 14,
      height: ios ? null : 20 / 14,
      color: ios
          ? IonIos.labelP(brightness)
          : (brightness == Brightness.dark
              ? const Color(0xFF999999)
              : const Color(0xFF666666)),
    );
  }
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
    // left edge at the trigger, pushed back into the viewport. Same as
    // [_AnchoredPopoverLayout] places it; kept here for the nested popover.
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
    // Sol review: like Ionic, the menu flips above the trigger when it does
    // not fit below and always stays inside the visible area (lower entries
    // stay reachable) – see [_AnchoredPopoverLayout].
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );

    final children = <Widget>[
      Positioned.fill(
        child: _AnchoredPopover(
          ios: ios,
          anchor: anchor,
          coverAnchor: ios,
          width: w,
          maxHeight: null,
          topPadding: widget.topPadding,
          bottomPadding: widget.bottomPadding,
          animation: curved,
          originX: ios ? 1 : -1,
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
        // ios27 popovers don't dim the page ([barrierColor])
        scrim: Colors.transparent,
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
