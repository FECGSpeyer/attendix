import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// IOS_R4: Ionic iOS **card modal** (`modalController.create({ component,
/// presentingElement })`) on a phone:
///
/// * the presenting page moves down to `max(30, safe-area-top)`, scales to
///   0.915 (top centre), gets 10pt top corners and `contrast(.85)` on a black
///   body;
/// * the card starts 10pt below that (`--height: calc(100% - max(30px,
///   safe-area-top) - 10px)`), with rounded top corners (ionic-theme-ios27:
///   32pt), slides up with `cubic-bezier(.32,.72,0,1)` over 500ms and a 0.2
///   backdrop (theme `--backdrop-opacity`);
/// * swiping the card down (outside inner scroll views) or tapping the strip
///   above it closes it.
///
/// The presenting page is drawn from a snapshot of the route below (taken
/// when the modal opens), so any page can present a card. If no snapshot
/// can be taken the real page stays visible behind the card instead.
///
/// Use it on iOS only (callers keep their Material presentation elsewhere).
Future<T?> showIosCardModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? backgroundColor,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final snapshot = _PresentingSnapshot.take(context, navigator);
  return navigator.push<T>(_IosCardModalRoute<T>(
    builder: builder,
    snapshot: snapshot,
    backgroundColor: backgroundColor,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    capturedThemes:
        InheritedTheme.capture(from: context, to: navigator.context),
  ));
}

/// Card corner radius (ionic-theme-ios27 `.modal-card { --border-radius }`).
const double kIosCardModalRadius = 32;

/// Header toolbar height inside the card (ionic-theme-ios27 `.modal-card`).
const double kIosCardModalToolbarHeight = 64;

/// Ionic `SwipeToCloseDefaults.MIN_PRESENTING_SCALE`.
const double kIosCardModalPresentingScale = 0.915;

/// Top of the presenting page / card for [safeTop] (Ionic
/// `max(30px, var(--ion-safe-area-top))`).
double iosCardModalPresentingTop(double safeTop) =>
    safeTop > 30 ? safeTop : 30;

class _PresentingSnapshot {
  _PresentingSnapshot(this.image, this.rect);

  final ui.Image image;
  final Rect rect;

  /// Snapshot of the outermost repaint boundary between [context] and the
  /// root navigator's overlay, i.e. the whole route that presents the card
  /// (incl. the tab bar of the shell route).
  static _PresentingSnapshot? take(
      BuildContext context, NavigatorState navigator) {
    try {
      final overlay = navigator.overlay?.context.findRenderObject();
      RenderObject? node = context.findRenderObject();
      RenderRepaintBoundary? outer;
      while (node != null && node != overlay) {
        if (node is RenderRepaintBoundary && node.hasSize) outer = node;
        node = node.parent;
      }
      if (outer == null || node == null) return null;
      final origin = outer.localToGlobal(
        Offset.zero,
        ancestor: overlay,
      );
      final image = outer.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
      return _PresentingSnapshot(image, origin & outer.size);
    } catch (_) {
      return null;
    }
  }
}

class _IosCardModalRoute<T> extends PopupRoute<T> {
  _IosCardModalRoute({
    required this.builder,
    required this.snapshot,
    required this.backgroundColor,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final WidgetBuilder builder;
  final _PresentingSnapshot? snapshot;
  final Color? backgroundColor;
  final CapturedThemes capturedThemes;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  // The strip above the card closes the modal (Ionic backdropDismiss).
  @override
  bool get barrierDismissible => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  void _dragUpdate(DragUpdateDetails details, double cardHeight) {
    final c = controller;
    if (c == null || cardHeight <= 0) return;
    c.value -= (details.primaryDelta ?? 0) / cardHeight;
  }

  void _dragEnd(DragEndDetails details) {
    final c = controller;
    if (c == null) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity > 700 || c.value < 0.6) {
      navigator?.pop();
    } else {
      c.forward();
    }
  }

  @override
  void dispose() {
    snapshot?.image.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return capturedThemes.wrap(_IosCardModalFrame(route: this));
  }
}

class _IosCardModalFrame extends StatelessWidget {
  const _IosCardModalFrame({required this.route});

  final _IosCardModalRoute<dynamic> route;

  static const Curve _curve = Cubic(0.32, 0.72, 0, 1);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final presentingTop = iosCardModalPresentingTop(media.padding.top);
    final cardTop = presentingTop + 10;
    final cardHeight = size.height - cardTop;
    final animation = route.animation!;
    final curved = CurvedAnimation(
      parent: animation,
      curve: _curve,
      reverseCurve: _curve.flipped,
    );
    final snapshot = route.snapshot;
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Presenting page on the black body.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final t = curved.value.clamp(0.0, 1.0);
              if (snapshot == null) {
                return ColoredBox(
                    color: Colors.black.withValues(alpha: 0.4 * t));
              }
              final scale = 1 - (1 - kIosCardModalPresentingScale) * t;
              final contrast = 1 - 0.15 * t;
              final offset = (1 - contrast) / 2 * 255;
              return ColoredBox(
                color: Colors.black,
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: snapshot.rect,
                      child: Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.translationValues(
                            0, presentingTop * t, 0)
                          ..scale(scale, scale, 1),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(10 * t)),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(<double>[
                              contrast, 0, 0, 0, offset, //
                              0, contrast, 0, 0, offset, //
                              0, 0, contrast, 0, offset, //
                              0, 0, 0, 1, 0,
                            ]),
                            child: RawImage(
                              image: snapshot.image,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ionic-theme `--backdrop-opacity: 0.2`
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.2 * t),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Tap on the strip above the card closes it.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: cardTop,
          child: Semantics(
            label: route.barrierLabel,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        // The card.
        Positioned(
          left: 0,
          right: 0,
          top: cardTop,
          height: cardHeight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: GestureDetector(
              onVerticalDragUpdate: (d) => route._dragUpdate(d, cardHeight),
              onVerticalDragEnd: route._dragEnd,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(kIosCardModalRadius),
                ),
                child: Material(
                  color: route.backgroundColor ?? theme.colorScheme.surface,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    // ionic-theme-ios27 `.modal-card` header toolbar:
                    // padding 0, --min-height 64px.
                    child: Theme(
                      data: theme.copyWith(
                        appBarTheme: theme.appBarTheme
                            .copyWith(toolbarHeight: kIosCardModalToolbarHeight),
                      ),
                      child: Builder(builder: route.builder),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
