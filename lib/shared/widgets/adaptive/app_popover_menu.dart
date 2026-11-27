import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';


part 'app_popover_models.dart';
part 'app_popover_layout.dart';
part 'app_popover_layer.dart';
part 'app_popover_widgets.dart';

/// iOS nested popovers (`side="start"`, iOS default `alignment="center"`)
/// are centred on their trigger row and moved down by Ionic's
/// `POPOVER_IOS_BODY_MARGIN` (ionic-theme-utils `calculateWindowAdjustment`).
/// Ionic does not clamp them vertically; here a submenu that would run off
/// the screen is pushed back into the safe area (F-TERM-16).
const double kIosNestedPopoverOffset = 8;


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
Future<T?> showAppPopoverMenu<T>({
  required BuildContext context,
  required List<AppPopoverMenuItem<T>> items,
  List<AppPopoverMenuItem<T>> Function()? itemsBuilder,
  double iosWidth = 200,
  bool lines = false,
  bool iosArrow = false,
  double? maxHeight,
  double? mdWidth,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final anchor = _anchorOf(context, overlay);

  return navigator.push<T>(
    _PopoverRoute<T>(
      ios: false,
      lines: lines,
      arrow: false,
      maxHeight: maxHeight,
      anchor: anchor,
      autofocusFirst: _openedByKeyboard(context),
      overlaySize: overlay.size,
      items: items,
      itemsBuilder: itemsBuilder,
      width: mdWidth ?? 250,
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
    width: 250,
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

/// Popover with free content (a help text, a glossary card) instead of a menu.
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Rect? anchor,
  double? width,
  double? maxHeight,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  return navigator.push<T>(
    _ContentPopoverRoute<T>(
      ios: false,
      anchor: anchor == null
          ? _anchorOf(context, overlay)
          : Rect.fromPoints(
              overlay.globalToLocal(anchor.topLeft),
              overlay.globalToLocal(anchor.bottomRight),
            ),
      coverAnchor: false,
      width: width ?? 250,
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


/// Text styles of an `ion-label` inside a popover list (h3 heading and `p`
/// lines), shared by content popovers.
class AppPopoverText {
  const AppPopoverText._();

  static TextStyle heading(BuildContext context) => TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle paragraph(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: brightness == Brightness.dark
          ? const Color(0xFF999999)
          : const Color(0xFF666666),
    );
  }
}

Color? _itemColor(AppPopoverMenuItem<dynamic> item) =>
    item.destructive ? AppColors.danger : item.color;

