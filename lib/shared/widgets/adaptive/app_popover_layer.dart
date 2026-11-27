part of 'app_popover_menu.dart';

// Menu popup route, keyboard focus tracking, and nested submenu overlay layer.

class _PopoverRoute<T> extends PopupRoute<T> {
  _PopoverRoute({
    required this.ios,
    required this.beta,
    required this.lines,
    required this.arrow,
    required this.maxHeight,
    required this.anchor,
    required this.autofocusFirst,
    required this.overlaySize,
    required this.items,
    required this.itemsBuilder,
    required this.width,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final bool ios;

  /// The Beta design: no dimmed page behind its menu card.
  final bool beta;

  /// Default item lines of the entries (see [showAppPopoverMenu]).
  final bool lines;

  /// iOS: below the trigger with an arrow instead of covering it.
  final bool arrow;
  final double? maxHeight;
  final Rect anchor;
  final bool autofocusFirst;
  final Size overlaySize;
  final List<AppPopoverMenuItem<T>> items;
  final List<AppPopoverMenuItem<T>> Function()? itemsBuilder;
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
    return capturedThemes.wrap(_EscapeDismiss(child:
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
    ));
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

  /// Focus node of the nested popover's first entry: it gets the focus when
  /// the nested popover is opened from the keyboard (`autofocus` doesn't
  /// apply, the parent entry already has the focus in this scope).
  final _nestedFirstFocus = FocusNode(debugLabel: 'nested popover row 0');

  /// Focus nodes of the parent entries (keyboard: Tab / arrow keys,
  /// Enter / Space; Escape in a nested popover returns to its entry).
  final List<FocusNode> _rowFocus = [];

  FocusNode _rowFocusNode(int index) {
    while (_rowFocus.length <= index) {
      _rowFocus.add(FocusNode(debugLabel: 'popover row ${_rowFocus.length}'));
    }
    return _rowFocus[index];
  }

  @override
  void dispose() {
    for (final node in _rowFocus) {
      node.dispose();
    }
    _nestedFirstFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      final builder = widget.route.itemsBuilder;
      if (builder != null) _items = builder();
    });
  }

  /// Escape inside a nested popover closes only that one and puts the focus
  /// back on its entry.
  void _closeNested() {
    final index = _openIndex;
    setState(() => _openIndex = null);
    if (index != null && index < _rowFocus.length) {
      _rowFocus[index].requestFocus();
    }
  }

  /// Whether entry [index] gets its item line: as the entry / the menu
  /// says, but not above a section divider (one line is enough) and, on
  /// iOS, not below the last entry (in Ionic that line lies on the
  /// popover's edge – the list has no padding there).
  bool _hasLine(int index) {
    if (!(_items[index].lines ?? widget.route.lines)) return false;
    final last = index == _items.length - 1;
    if (last) return !widget.route.ios;
    final next = _items[index + 1];
    return !(next.header && next.divider);
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
    final keyboard = _openedByKeyboard(rowContext);
    setState(() {
      _openIndex = index;
      _openRowRect = topLeft & row.size;
    });
    if (keyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _openIndex == index) _nestedFirstFocus.requestFocus();
      });
    }
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
          coverAnchor: ios && !route.arrow,
          arrow: route.arrow,
          width: w,
          maxHeight: route.maxHeight,
          topPadding: widget.topPadding,
          bottomPadding: widget.bottomPadding,
          animation: curved,
          originX: route.arrow ? 0 : (ios ? 1 : -1),
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
                if (_items[i].header)
                  _PopoverHeader(
                    ios: ios,
                    label: _items[i].label,
                    divider: _items[i].divider,
                  )
                else if (_items[i].info)
                  _PopoverInfoRow(
                    ios: ios,
                    label: _items[i].label,
                    subtitle: _items[i].subtitle,
                    line: _hasLine(i),
                  )
                else
                Builder(
                  builder:
                      (rowContext) => _PopoverRow(
                        ios: ios,
                        icon: _items[i].icon,
                        label: _items[i].label,
                        subtitle: _items[i].subtitle,
                        color: _itemColor(_items[i]),
                        iconColor: _items[i].iconColor,
                        note: _items[i].note,
                        selected: _items[i].selected,
                        line: _hasLine(i),
                        end: _items[i].end == null
                            ? null
                            : _PopoverEndButton(
                                ios: ios,
                                icon: _items[i].end!.icon,
                                tooltip: _items[i].end!.tooltip,
                                color: _items[i].end!.color,
                                onTap: () => Navigator.of(context)
                                    .pop<T>(_items[i].end!.value),
                              ),
                        chevron: _items[i]._hasChevron,
                        focusNode: _rowFocusNode(i),
                        autofocus: i == 0 && route.autofocusFirst,
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
              // F-TERM-16: the nested popover stays inside the safe area
              // (a tall one on a phone used to run off the top, its first
              // entries were unreachable).
              minTop: widget.topPadding + _margin,
              maxBottom: size.height - widget.bottomPadding - _margin,
              maxHeight:
                  ios
                      ? math.max(
                        120.0,
                        size.height -
                            widget.topPadding -
                            widget.bottomPadding -
                            2 * _margin,
                      )
                      : math.max(
                        120.0,
                        size.height -
                            rowRect.top -
                            widget.bottomPadding -
                            _margin,
                      ),
            ),
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    _closeNested();
                    return null;
                  },
                ),
              },
              child: _PopoverCard(
                ios: ios,
                children: [
                  for (var j = 0; j < sub.length; j++)
                    _PopoverRow(
                      ios: ios,
                      icon: sub[j].icon,
                      checked: sub[j].checked,
                      label: sub[j].label,
                      subtitle: sub[j].subtitle,
                      color: sub[j].color,
                      focusNode: j == 0 ? _nestedFirstFocus : null,
                      onTap: () {
                        sub[j].onTap();
                        _refresh();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(key: _stackKey, children: children);
  }
}

