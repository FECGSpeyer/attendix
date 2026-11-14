import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../adaptive/adaptive.dart';
import '../layout/ion_modal_handle.dart';
import '../layout/ionic_ios.dart';
import '../layout/sheet_drag.dart';
import 'ion_modal.dart';

export '../adaptive/app_toolbar.dart' show IonCloseButton, ToolbarButtonGroup;
export '../layout/ionic_ios.dart' show IonSheetHeader;

/// Builds the content of an [IonBreakpointSheet]. Give [scrollController] to
/// the sheet's scroll view: a drag on the list then moves the sheet between
/// its breakpoints first and scrolls the list at the highest one, like the
/// `ion-content` of an Ionic sheet modal.
typedef IonSheetBuilder = Widget Function(
    BuildContext context, ScrollController scrollController);

/// The ONE way to present a classic-design sheet: an Ionic **sheet modal**
/// (`<ion-modal [breakpoints] [initialBreakpoint]>` /
/// `modalController.create({ breakpoints, initialBreakpoint })`).
///
/// * [breakpoints] and [initialBreakpoint] are the Ionic values 1:1. A `0`
///   in the list means the sheet can be dragged shut; `1` is the full sheet
///   (`--height: calc(100% - (safe-area-top + 10px))`).
/// * The Ionic modal handle is drawn over the top of the content
///   ([handle], Ionic default `true`), not in a zone of its own like
///   Material's `showDragHandle`.
/// * The sheet follows the finger wherever it is touched (toolbar, handle,
///   empty space, the list while it is at its top) and settles on the
///   nearest breakpoint.
/// * A tap on the backdrop closes it ([backdropDismiss]).
/// * On screens from 768 × 600 the sheet is 600 px wide, centred and
///   anchored to the bottom (Ionic `--width: 600px`; see [IonModalTheme]);
///   md there gets the 2 px radius.
/// * [avoidKeyboard]: the sheet sits on top of the on-screen keyboard (the
///   builder then sees no bottom view inset).
///
/// The content is usually an [IonSheetScaffold].
///
/// The Beta design has its own sheet look: callers that are reachable from
/// the Beta keep their previous presentation behind
/// `context.rdSkin != null`.
Future<T?> showIonSheet<T>(
  BuildContext context, {
  required IonSheetBuilder builder,
  List<double> breakpoints = const [0, 1],
  double initialBreakpoint = 1,
  bool handle = true,
  bool backdropDismiss = true,
  bool canDismiss = true,
  bool useRootNavigator = true,
  bool avoidKeyboard = true,
  Color? backgroundColor,
  RouteSettings? routeSettings,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    isDismissible: backdropDismiss && canDismiss,
    enableDrag: canDismiss,
    clipBehavior: Clip.antiAlias,
    backgroundColor: backgroundColor,
    routeSettings: routeSettings,
    builder: (_) => IonBreakpointSheet(
      breakpoints: breakpoints,
      initialBreakpoint: initialBreakpoint,
      handle: handle,
      canDismiss: canDismiss,
      avoidKeyboard: avoidKeyboard,
      builder: builder,
    ),
  );
}

/// The body of [showIonSheet]: sizes its child to the Ionic [breakpoints]
/// and draws the modal handle. Use it directly only where a sheet widget is
/// presented by its own `showModalBottomSheet(isScrollControlled: true)`
/// call (e.g. to change [canDismiss] while the sheet is open).
class IonBreakpointSheet extends StatelessWidget {
  const IonBreakpointSheet({
    super.key,
    this.breakpoints = const [0, 1],
    this.initialBreakpoint = 1,
    this.handle = true,
    this.canDismiss = true,
    this.avoidKeyboard = true,
    required this.builder,
  });

  /// Ionic `breakpoints`, e.g. `[0, 0.5, 1]`.
  final List<double> breakpoints;

  /// Ionic `initialBreakpoint`.
  final double initialBreakpoint;

  /// Ionic `handle`: the grabber over the top of the sheet.
  final bool handle;

  /// Ionic `canDismiss`: false keeps the sheet at its lowest breakpoint
  /// (e.g. while it saves).
  final bool canDismiss;

  /// Lifts the sheet above the on-screen keyboard.
  final bool avoidKeyboard;

  final IonSheetBuilder builder;

  /// Ionic `.modal-sheet`: `--height: calc(100% - (safe-area-top + 10px))`.
  static const double topGap = 10;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    Widget sheet = LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        // Breakpoints are fractions of the full sheet, which ends 10pt
        // below the safe area (already removed by `useSafeArea`).
        final gap = topGap + media.padding.top;
        final full = available > gap * 2 ? (available - gap) / available : 1.0;
        final stops = <double>{
          for (final b in breakpoints)
            if (b > 0) (b.clamp(0.0, 1.0)) * full,
        }.toList()
          ..sort();
        if (stops.isEmpty) stops.add(full);
        final closes = canDismiss && breakpoints.any((b) => b <= 0);
        final initial =
            (initialBreakpoint * full).clamp(stops.first, stops.last);
        // The content keeps the layout of the lowest breakpoint while the
        // sheet is dragged shut (Ionic moves the sheet, it does not
        // squeeze it).
        final floor = stops.first * available;
        return AppDraggableSheet(
          expand: false,
          initialChildSize: initial,
          minChildSize: closes ? 0 : stops.first,
          maxChildSize: stops.last,
          snap: true,
          snapSizes: stops,
          shouldCloseOnMinExtent: closes,
          builder: (context, controller) {
            Widget child = builder(context, controller);
            if (handle) child = IonModalHandleOverlay(child: child);
            return LayoutBuilder(
              builder: (context, c) {
                final height = math.max(c.maxHeight, floor);
                return ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: height,
                    maxHeight: height,
                    child: child,
                  ),
                );
              },
            );
          },
        );
      },
    );
    if (avoidKeyboard) {
      sheet = Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: sheet,
        ),
      );
    }
    return sheet;
  }
}

/// Content frame of a classic sheet or card modal, the Ionic
/// `ion-header > ion-toolbar` + `ion-content` (+ `ion-footer`):
///
/// * [title] in the toolbar – centred 64pt toolbar on iOS, start-aligned
///   56px toolbar with the header shadow in md ([IonSheetHeader]);
///   `null` = no header at all (Ionic modal without `ion-header`),
/// * [start] / [end]: the `ion-buttons slot="start|end"`. Pass plain
///   [IconButton]s / [TextButton]s (iOS groups them into one glass capsule
///   per slot) or an [IonCloseButton]; [showClose] appends the close ✕ to
///   the end slot,
/// * [bottom]: further toolbar rows under the title (searchbar, segment,
///   breadcrumbs, progress line),
/// * [body] fills the rest, [footer] stays at the bottom edge.
///
/// Works inside [showIonSheet], [showIonCardModal] and any other sheet.
class IonSheetScaffold extends StatelessWidget {
  const IonSheetScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.start = const [],
    this.end = const [],
    this.showClose = false,
    this.onClose,
    this.bottom,
    required this.body,
    this.footer,
    this.backgroundColor,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> start;
  final List<Widget> end;

  /// Adds an [IonCloseButton] to the end slot (Ionic
  /// `<ion-buttons slot="end"><ion-button><ion-icon name="close">`).
  final bool showClose;

  /// Replaces the default "pop this route" of the close button.
  final VoidCallback? onClose;

  final Widget? bottom;
  final Widget body;
  final Widget? footer;

  /// `ion-content color="light"` and the like; null keeps the sheet colour.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final header = title == null
        ? null
        : IonSheetHeader(
            title: title!,
            subtitle: subtitle,
            start: start,
            end: [
              ...end,
              if (showClose) IonCloseButton(onPressed: onClose),
            ],
          );
    final content = Column(
      children: [
        Expanded(child: body),
        if (footer != null) footer!,
      ],
    );
    return Material(
      type: backgroundColor == null
          ? MaterialType.transparency
          : MaterialType.canvas,
      color: backgroundColor,
      child: Column(
        // Laid out top-down, painted bottom-up: the md header shadow lies
        // over the content.
        verticalDirection: VerticalDirection.up,
        children: [
          Expanded(child: content),
          if (bottom != null) bottom!,
          if (header != null) header,
        ],
      ),
    );
  }
}

/// Presents [builder] like an Ionic **card modal**
/// (`modalController.create({ component, presentingElement })`):
/// * iOS phone: the card over the shrunk presenting page
///   ([showIosCardModal], swipe down to close),
/// * md phone: full screen (md has no card style),
/// * tablet / desktop ([isIonModalCard]): a centred card with a maximum
///   width ([showIonModal]).
///
/// The content is an [IonSheetScaffold] or a page [Scaffold] with its own
/// app bar. For whole pages that should also close on navigation use
/// [showPageModal].
Future<T?> showIonCardModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool backdropDismiss = true,
  Color? iosBackgroundColor,
  double width = 600,
  double? height,
}) {
  final size = MediaQuery.sizeOf(context);
  if (isIonModalCard(size)) {
    return showIonModal<T>(
      context,
      builder: (ctx) => Material(
        type: MaterialType.transparency,
        child: builder(ctx),
      ),
      width: width,
      height: height,
      barrierDismissible: backdropDismiss,
    );
  }
  if (useIosLook(context)) {
    return showIosCardModal<T>(
      context,
      builder: builder,
      backgroundColor: iosBackgroundColor,
      barrierDismissible: backdropDismiss,
    );
  }
  return Navigator.of(context, rootNavigator: true).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        // The status bar strip takes the toolbar colour; the content starts
        // below it (an `ion-header` pads its first toolbar the same way).
        return ColoredBox(
          color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Material(
              color: theme.scaffoldBackgroundColor,
              child: builder(ctx),
            ),
          ),
        );
      },
    ),
  );
}
