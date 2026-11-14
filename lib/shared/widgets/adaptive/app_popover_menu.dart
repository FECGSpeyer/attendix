import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import '../layout/ionic_ios.dart' show IonIos, IonDetailChevron;
import 'adaptive_platform.dart';

/// iOS nested popovers (`side="start"`, iOS default `alignment="center"`)
/// are centred on their trigger row and moved down by Ionic's
/// `POPOVER_IOS_BODY_MARGIN` (ionic-theme-utils `calculateWindowAdjustment`).
/// Ionic does not clamp them vertically; here a submenu that would run off
/// the screen is pushed back into the safe area (F-TERM-16).
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
    this.header = false,
    this.iconColor,
    this.note,
    this.selected = false,
    this.lines,
    this.end,
  })  : info = false,
        divider = true;

  /// Section header (Ionic `ion-item-divider` + `<small><b>` label): a
  /// divider line and a small bold, non-tappable label. [value] is never
  /// returned. [divider] false: only the label (a second section right
  /// below another one, Ionic: label item without `ion-item-divider`).
  const AppPopoverMenuItem.header(this.label, this.value, {this.divider = true})
    : icon = null,
      subtitle = null,
      color = null,
      submenu = false,
      submenuItems = null,
      destructive = false,
      header = true,
      iconColor = null,
      note = null,
      selected = false,
      lines = false,
      end = null,
      info = false;

  /// Only the divider line of a section (Ionic `ion-item-divider` without
  /// a label row). [value] is never returned.
  const AppPopoverMenuItem.divider(this.value)
    : label = '',
      icon = null,
      subtitle = null,
      color = null,
      submenu = false,
      submenuItems = null,
      destructive = false,
      header = true,
      divider = true,
      iconColor = null,
      note = null,
      selected = false,
      lines = false,
      end = null,
      info = false;

  /// Non-tappable text row (Ionic `ion-item` without `button`, label with
  /// `<h3>` [label] and `<p>` [subtitle]), e.g. the current sorting.
  /// [value] is never returned.
  const AppPopoverMenuItem.info(
    this.label,
    this.value, {
    this.subtitle,
    this.lines = false,
  })  : icon = null,
        color = null,
        submenu = false,
        submenuItems = null,
        destructive = false,
        header = false,
        iconColor = null,
        note = null,
        selected = false,
        end = null,
        info = true,
        divider = true;

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

  /// See [AppPopoverMenuItem.header].
  final bool header;

  /// See [AppPopoverMenuItem.header].
  final bool divider;

  /// See [AppPopoverMenuItem.info].
  final bool info;

  /// Colour of the start icon only (Ionic `<ion-icon slot="start"
  /// [color]>` next to an uncoloured label), e.g. the dot of a Termin type.
  final Color? iconColor;

  /// Grey text after the label on the same line (Ionic `<ion-note>` inside
  /// the `ion-label`), e.g. "10 Min.".
  final String? note;

  /// The active entry of a filter: primary label and a primary checkmark
  /// at the end (Ionic `ion-label color="primary"` +
  /// `ion-icon slot="end" name="checkmark" color="primary"`).
  final bool selected;

  /// Item line below this entry. null: as the menu ([showAppPopoverMenu]
  /// `lines`); false: Ionic `lines="none"`; true: a line although the menu
  /// has none.
  final bool? lines;

  /// Small button at the end of the row with its own result (Ionic
  /// `ion-button slot="end" fill="clear"` with `stopPropagation`), e.g.
  /// "delete this template".
  final AppPopoverMenuEndAction<T>? end;

  bool get _hasChevron => submenu || submenuItems != null;
}

/// See [AppPopoverMenuItem.end].
class AppPopoverMenuEndAction<T> {
  const AppPopoverMenuEndAction({
    required this.value,
    required this.icon,
    required this.tooltip,
    this.color,
  });

  /// Returned by [showAppPopoverMenu] when the button is tapped.
  final T value;
  final IconData icon;
  final String tooltip;

  /// Icon colour (Ionic `color="medium"` → [AppColors.medium] by default).
  final Color? color;
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
/// Entries follow the Ionic template: `lines` (item lines, per entry
/// [AppPopoverMenuItem.lines]), start icon, [AppPopoverMenuItem.note],
/// [AppPopoverMenuItem.selected] (checkmark at the end), danger colour,
/// section headers and info rows. `iosArrow` is for triggers that are not
/// toolbar buttons.
///
/// [context] must be the trigger button's context (use a [Builder]).
/// [itemsBuilder] (optional) rebuilds the entries while a nested popover
/// changes state (e.g. the "Filter aktiv" subtitle). Returns the tapped
/// entry's value, or null when dismissed.
/// BETA_SELECT: the Ionic iOS glass popover only outside the Beta design;
/// the Beta design gets its own menu card (see [_PopoverCard]) with the md
/// placement below the trigger.
bool _iosPopover(BuildContext context) =>
    useIosLook(context) && context.rdSkin == null;

Future<T?> showAppPopoverMenu<T>({
  required BuildContext context,
  required List<AppPopoverMenuItem<T>> items,
  List<AppPopoverMenuItem<T>> Function()? itemsBuilder,
  // Ionic `popover.ios.css`: `--width: 200px` (md 250px).
  double iosWidth = 200,
  // Item lines of the entries: false = `ion-list lines="none"`; true = the
  // Ionic default of an `ion-list` / of bare `ion-item`s (an inset line
  // below every entry that does not say `lines: false`).
  bool lines = false,
  // iOS: the trigger is not an `ion-button` (e.g. an `ion-item`): the
  // popover opens below the trigger, centred, with the arrow tip pointing
  // at it (Ionic iOS default) instead of covering the trigger.
  bool iosArrow = false,
  // Ionic `--max-height` (e.g. 70 % of the screen); the menu scrolls.
  double? maxHeight,
  // md look: a page-set Ionic `--width` (default md 250px).
  double? mdWidth,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = _anchorOf(context, overlay);
  final ios = _iosPopover(context);

  return navigator.push<T>(
    _PopoverRoute<T>(
      ios: ios,
      beta: context.rdSkin != null,
      lines: lines,
      arrow: ios && iosArrow,
      maxHeight: maxHeight,
      anchor: anchor,
      // Opened from the keyboard (the focused trigger): the first entry
      // gets the focus, like the former action sheet. A mouse/touch open
      // keeps nothing highlighted; Tab still reaches the first entry.
      autofocusFirst: _openedByKeyboard(context),
      overlaySize: overlay.size,
      items: items,
      itemsBuilder: itemsBuilder,
      width: ios ? iosWidth : (mdWidth ?? 250),
      barrierLabel: context.l10n.commonClose,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

/// Whether [context]'s widget (or a widget inside it) has the keyboard focus
/// while focus highlights are shown, i.e. it was activated from the keyboard
/// (buttons don't take the focus on a mouse click or tap).
bool _openedByKeyboard(BuildContext context) {
  if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) {
    return false;
  }
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  if (focused == context) return true;
  var inside = false;
  focused.visitAncestorElements((element) {
    if (element == context) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

/// Ionic `ion-popover` with free content (`<ion-content class="ion-padding">`)
/// behind an info button, e.g. a help text: [showAppPopover] at the button
/// with [child] inside 16 px padding. A tap outside closes it.
///
/// [context] must be the trigger button's context (use a [Builder]).
Future<void> showAppContentPopover({
  required BuildContext context,
  required Widget child,
  double iosWidth = 200,
}) {
  return showAppPopover<void>(
    context: context,
    width: _iosPopover(context) ? iosWidth : 250,
    builder: (_) => Padding(padding: const EdgeInsets.all(16), child: child),
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
  final ios = _iosPopover(context);
  return navigator.push<T>(
    _ContentPopoverRoute<T>(
      ios: ios,
      beta: context.rdSkin != null,
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
    required this.beta,
    required this.anchor,
    required this.coverAnchor,
    required this.width,
    required this.maxHeight,
    required this.builder,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final bool ios;

  /// The Beta design: no dimmed page behind its menu card.
  final bool beta;
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
      ios || beta ? Colors.transparent : Colors.black.withValues(alpha: 0.32);

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
    return capturedThemes.wrap(_EscapeDismiss(child:
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
    ));
  }
}

/// F-PERS-05: Escape closes a popover even when the keyboard focus is not
/// inside it. On the web the focus can stay on the trigger of the page
/// below (e.g. its accessibility element took the browser focus on the
/// click), so the popover's own Escape action (an ancestor of the focus
/// only inside the popover) never saw the key until something in it was
/// clicked. With the focus inside the popover the usual action handles
/// Escape (a nested popover closes alone), so nothing runs twice.
class _EscapeDismiss extends StatefulWidget {
  const _EscapeDismiss({required this.child});

  final Widget child;

  @override
  State<_EscapeDismiss> createState() => _EscapeDismissState();
}

class _EscapeDismissState extends State<_EscapeDismiss> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !mounted) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent || !route.isActive) return false;
    final focus = FocusManager.instance.primaryFocus;
    // The route's own focus scope (its page lies right inside it).
    final scope = FocusScope.of(context, createDependency: false);
    if (focus != null &&
        (focus == scope || focus.ancestors.contains(scope))) {
      return false;
    }
    Navigator.of(context).maybePop();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    final card = !widget.arrow
        ? widget.child
        : LayoutBuilder(
            builder: (context, constraints) {
              // The card is centred on the anchor and pushed back into the
              // viewport ([_AnchoredPopoverLayout]); the arrow stays on the
              // anchor's centre (Ionic does not move it), but on the
              // straight part of the card's edge.
              final viewport = MediaQuery.sizeOf(context).width;
              final w = constraints.maxWidth;
              const m = _AnchoredPopoverLayout._margin;
              final left = (widget.anchor.center.dx - w / 2)
                  .clamp(m, math.max(m, viewport - w - m))
                  .toDouble();
              const aw = _IosPopoverArrow.width;
              const r = 34.0;
              final arrowLeft = (widget.anchor.center.dx - left - aw / 2)
                  .clamp(math.min(r, (w - aw) / 2),
                      math.max((w - aw) / 2, w - aw - r))
                  .toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  widget.child,
                  Positioned(
                    left: arrowLeft,
                    top: _above ? null : -kIosPopoverArrowGap,
                    bottom: _above ? -kIosPopoverArrowGap : null,
                    child: _IosPopoverArrow(down: _above),
                  ),
                ],
              );
            },
          );
    return CustomSingleChildLayout(
      delegate: _AnchoredPopoverLayout(
        ios: widget.ios,
        anchor: widget.anchor,
        coverAnchor: widget.coverAnchor,
        width: widget.width,
        maxHeight: widget.maxHeight,
        topPadding: widget.topPadding,
        bottomPadding: widget.bottomPadding,
        gap: widget.arrow ? kIosPopoverArrowGap : 0,
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
          child: card,
        ),
      ),
    );
  }
}

/// Distance between an iOS popover with an arrow and its trigger: Ionic
/// puts the content at `trigger.bottom + arrowHeight - 1` (ios27 arrow:
/// 34 × 14).
const double kIosPopoverArrowGap = 13;

/// ionic-theme-ios27 `ion-popover::part(arrow)`: a 34 × 14 glass tip with a
/// rounded point and concave shoulders that joins the popover's edge
/// (`clip-path: path('M 0 14 L 0 13 C 3 13 4.5 12 6.5 10 L 14.5 1.5 C 16
/// -0.5 18 -0.5 19.5 1.5 L 27.5 10 C 29.5 12 31 13 34 13 L 34 14 Z')`).
/// [down]: the popover sits above its trigger, the tip points down.
class _IosPopoverArrow extends StatelessWidget {
  const _IosPopoverArrow({required this.down});

  static const double width = 34;
  static const double height = 14;

  final bool down;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    // The colour of [IosGlassSurface.popover] (PERF_GLASS: frosted, opaque).
    final glass = IosGlass.background(b, b == Brightness.dark ? 0.08 : 0.42);
    final fill = IosGlass.liveBlur(context)
        ? glass
        : IosGlass.frosted(
            glass,
            page: IosGlass.pageColor(context),
            backdropBrightness: b == Brightness.dark ? 0.9 : 1.35,
          );
    return IgnorePointer(
      child: RotatedBox(
        quarterTurns: down ? 2 : 0,
        child: CustomPaint(
          size: const Size(width, height),
          painter: _IosPopoverArrowPainter(
            fill: fill,
            border: IosGlass.overlayBorder(b),
          ),
        ),
      ),
    );
  }
}

class _IosPopoverArrowPainter extends CustomPainter {
  const _IosPopoverArrowPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    Path outline() => Path()
      ..moveTo(0, 13)
      ..cubicTo(3, 13, 4.5, 12, 6.5, 10)
      ..lineTo(14.5, 1.5)
      ..cubicTo(16, -0.5, 18, -0.5, 19.5, 1.5)
      ..lineTo(27.5, 10)
      ..cubicTo(29.5, 12, 31, 13, 34, 13);
    // The base overlaps the card's 0.5pt border so tip and card read as
    // one surface.
    final shape = outline()
      ..lineTo(34, 14)
      ..lineTo(0, 14)
      ..close();
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      outline(),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_IosPopoverArrowPainter old) =>
      old.fill != fill || old.border != border;
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

/// Text styles of an `ion-label` inside a popover list (h3 heading and `p`
/// lines), shared by content popovers.
class AppPopoverText {
  const AppPopoverText._();

  static TextStyle heading(BuildContext context) => TextStyle(
        fontSize: _iosPopover(context) ? 17 : 16,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle paragraph(BuildContext context) {
    final ios = _iosPopover(context);
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

  /// AUDIT_R4: Ionic md dims the page behind a popover
  /// (`--backdrop-opacity: var(--ion-backdrop-opacity, .32)`); the ios27
  /// theme sets `--backdrop-opacity: 0`.
  @override
  Color? get barrierColor =>
      ios || beta ? Colors.transparent : Colors.black.withValues(alpha: 0.32);

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
    // BETA_SELECT: the Beta menu card (as its row menus and selects).
    final rd = context.rdSkin;
    if (rd != null) {
      return Material(
        color: rd.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: rd.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: list,
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

class _PopoverHeader extends StatelessWidget {
  const _PopoverHeader({
    required this.ios,
    required this.label,
    this.divider = true,
  });

  final bool ios;
  final String label;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider)
        Divider(height: 1, color: Theme.of(context).dividerColor),
        if (label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
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
    this.focusNode,
    this.autofocus = false,
    this.iconColor,
    this.note,
    this.selected = false,
    this.line = false,
    this.end,
  });

  final bool ios;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool? checked;
  final String? subtitle;
  final Color? color;
  final bool chevron;
  final FocusNode? focusNode;
  final bool autofocus;

  /// See [AppPopoverMenuItem.iconColor], [AppPopoverMenuItem.note],
  /// [AppPopoverMenuItem.selected], [AppPopoverMenuItem.lines] and
  /// [AppPopoverMenuItem.end].
  final Color? iconColor;
  final String? note;
  final bool selected;
  final bool line;
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final fg = color ?? (selected ? AppColors.primary : onSurface);
    // md: `ion-icon` in an item = rgba(text, .54), 24 px, 32 px gap.
    final iconColor = this.iconColor ??
        color ??
        (ios ? onSurface : onSurface.withValues(alpha: 0.54));

    Widget? leading;
    if (checked != null) {
      // Purely decorative: IgnorePointer alone leaves it Tab-focusable, where
      // Enter / Space would hit the no-op onChanged. ExcludeFocus keeps the
      // focus on the row itself, which toggles (semantics stay for the state).
      leading = ExcludeFocus(
        child: IgnorePointer(
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
        ),
      );
    } else if (icon != null) {
      // iOS: Ionic item `::slotted(ion-icon)` 1.6em of 17pt = 27.2pt.
      leading = Icon(icon, size: ios ? 27.2 : 24, color: iconColor);
    }

    final row = InkWell(
      // No ripple on iOS, grey press highlight; nothing highlighted
      // initially (no initial value). Focusable for the keyboard (Tab /
      // arrow keys, Enter / Space); the focus highlight only shows in
      // keyboard mode, a mouse click or tap doesn't take the focus.
      splashFactory: ios ? NoSplash.splashFactory : null,
      highlightColor: ios ? IosGlass.itemActivated(theme.brightness) : null,
      focusNode: focusNode,
      autofocus: autofocus,
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
                      _PopoverLabel(
                        ios: ios,
                        label: label,
                        note: note,
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
              // `ion-icon slot="end" name="checkmark" color="primary"`.
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: ios ? 2 : 16),
                  child: Icon(
                    AppIcons.check,
                    size: ios ? 27.2 : 24,
                    color: AppColors.primary,
                  ),
                ),
              if (end != null) end!,
              if (chevron) ...[
                SizedBox(width: ios ? 8 : 6),
                if (ios)
                  const IonDetailChevron()
                else
                  Icon(
                    AppIcons.chevronRight,
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
    if (!line) return row;
    return _PopoverLine(
      ios: ios,
      // The Ionic default line is the inner border: it starts at the label
      // (after the start icon and its margin) and runs to the edge.
      inset: 16 +
          (leading == null
              ? 0
              : (checked != null ? 24 : (ios ? 27.2 : 24)) +
                  (ios ? 16 : (checked != null ? 16 : 32))),
      child: row,
    );
  }
}

/// Label of a popover row with the optional grey [note] behind it. iOS
/// (200pt popover): a single word wider than the row (e.g.
/// "Werkkategorien" next to an icon) is set slightly smaller instead of
/// being broken inside the word – CSS never breaks inside a word either.
class _PopoverLabel extends StatelessWidget {
  const _PopoverLabel({
    required this.ios,
    required this.label,
    required this.style,
    this.note,
  });

  final bool ios;
  final String label;
  final String? note;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    Widget text(TextStyle style) => Text.rich(
          TextSpan(
            text: label,
            children: [
              // `ion-note` inside the label: step-350 at the label's size
              // (iOS) / step-600 14px (md).
              if (note != null)
                TextSpan(
                  text: ' $note',
                  style: TextStyle(
                    fontSize: ios ? null : 14,
                    color: ios
                        ? IonIos.labelP(brightness)
                        : (brightness == Brightness.dark
                            ? const Color(0xFF999999)
                            : const Color(0xFF666666)),
                  ),
                ),
            ],
          ),
          style: style,
        );
    if (!ios) return text(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        if (!max.isFinite || max <= 0) return text(style);
        final scaler = MediaQuery.textScalerOf(context);
        final base = DefaultTextStyle.of(context).style.merge(style);
        var widest = 0.0;
        for (final word in label.split(RegExp(r'[\s\-/]+'))) {
          if (word.length < 8) continue;
          final painter = TextPainter(
            text: TextSpan(text: word, style: base),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          widest = math.max(widest, painter.width);
          painter.dispose();
        }
        if (widest <= max) return text(style);
        final size = style.fontSize ?? 17;
        return text(
          style.copyWith(
            fontSize: math.max(size * 0.8, size * max / widest - 0.1),
          ),
        );
      },
    );
  }
}

/// Item line below [child]: Ionic `--inner-border-width` 0.55px (iOS) /
/// 1px (md) in the item border colour, from [inset] to the end edge.
class _PopoverLine extends StatelessWidget {
  const _PopoverLine({
    required this.ios,
    required this.inset,
    required this.child,
  });

  final bool ios;
  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = ios ? 0.5 : 1.0;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          start: inset,
          end: 0,
          bottom: 0,
          height: w,
          child: IgnorePointer(
            child: ColoredBox(color: Theme.of(context).dividerColor),
          ),
        ),
      ],
    );
  }
}

/// [AppPopoverMenuItem.info]: `ion-item` (no button) with an `ion-label`
/// holding `<h3>` and `<p>` (both .875rem; the `p` grey).
class _PopoverInfoRow extends StatelessWidget {
  const _PopoverInfoRow({
    required this.ios,
    required this.label,
    required this.subtitle,
    required this.line,
  });

  final bool ios;
  final String label;
  final String? subtitle;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = AppPopoverText.paragraph(context);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: ios ? 44 : 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: p.fontSize,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(subtitle!, style: p),
              ),
          ],
        ),
      ),
    );
    if (!line) return row;
    return _PopoverLine(ios: ios, inset: 16, child: row);
  }
}

/// [AppPopoverMenuItem.end]: `ion-button slot="end" fill="clear"
/// size="small"` with an icon – a tap does not select the row.
class _PopoverEndButton extends StatelessWidget {
  const _PopoverEndButton({
    required this.ios,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final bool ios;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
      color: color ?? AppColors.medium,
      icon: Icon(icon, size: 20),
      onPressed: onTap,
    );
  }
}
