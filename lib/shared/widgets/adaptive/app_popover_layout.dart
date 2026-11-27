part of 'app_popover_menu.dart';

// Viewport-aware positioning delegates for anchored and nested popovers.

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
    this.arrow = false,
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

  /// iOS: the popover keeps [kIosPopoverArrowGap] to the anchor and shows
  /// the arrow tip ([_IosPopoverArrow]) pointing at the anchor's centre.
  final bool arrow;

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
        gap: 0,
        placement: _placement,
        onPlaced: _onPlaced,
      ),
      child: FadeTransition(
        opacity: widget.animation,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
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
    this.gap = 0,
  });

  static const _margin = 8.0;

  /// Space kept between the anchor and the popover (the iOS arrow).
  final double gap;

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
    var top = coverAnchor ? anchor.top : anchor.bottom + gap;
    var isAbove = false;
    if (top + childSize.height > maxBottom) {
      // No room below: above the anchor (covering: bottom at its bottom).
      final above = (coverAnchor ? anchor.bottom : anchor.top - gap) -
          childSize.height;
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
      old.bottomPadding != bottomPadding ||
      old.gap != gap;
}


/// Places a nested popover: [left]/[width] fixed; vertically centred on
/// [rowCenter] plus [kIosNestedPopoverOffset] (iOS) or top-aligned with
/// [rowTop] (md). Pushed back between [minTop] and [maxBottom] when it would
/// leave the visible area, so every entry stays reachable (F-TERM-16).
class _NestedPopoverLayout extends SingleChildLayoutDelegate {
  _NestedPopoverLayout({
    required this.left,
    required this.width,
    required this.rowTop,
    required this.rowCenter,
    required this.maxHeight,
    required this.minTop,
    required this.maxBottom,
  });

  final double left;
  final double width;
  final double rowTop;
  final double? rowCenter;
  final double maxHeight;
  final double minTop;
  final double maxBottom;

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
    final lowest = math.max(minTop, maxBottom - childSize.height);
    return Offset(left, top.clamp(minTop, lowest).toDouble());
  }

  @override
  bool shouldRelayout(_NestedPopoverLayout old) =>
      old.minTop != minTop ||
      old.maxBottom != maxBottom ||
      old.left != left ||
      old.width != width ||
      old.rowTop != rowTop ||
      old.rowCenter != rowCenter ||
      old.maxHeight != maxHeight;
}

