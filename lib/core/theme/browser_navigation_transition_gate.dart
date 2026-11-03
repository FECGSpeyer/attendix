import 'package:flutter/widgets.dart';

import '../services/browser_navigation.dart';

/// SWIPE_BACK_WEB: skips a route transition the browser already showed.
///
/// After Safari's edge swipe the previous page is already on screen (the
/// browser slid its snapshot in), so the pop must not slide the old page out
/// a second time. While a transition that started right after such a step
/// runs, [builder] gets animations that already sit at their end value: the
/// popped page is gone at once and the page below is back in place without
/// the parallax. Every other navigation animates as before.
///
/// The widget tree stays the same either way (only the animation values
/// differ), so the pages keep their state.
class BrowserNavigationTransitionGate extends StatefulWidget {
  const BrowserNavigationTransitionGate({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.builder,
    this.skipCheck,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget Function(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  )
  builder;

  /// Defaults to [browserAnimatedNavigationJustHappened]; tests set it.
  final bool Function()? skipCheck;

  @override
  State<BrowserNavigationTransitionGate> createState() =>
      _BrowserNavigationTransitionGateState();
}

class _BrowserNavigationTransitionGateState
    extends State<BrowserNavigationTransitionGate> {
  late _SkippableAnimation _primary;
  late _SkippableAnimation _secondary;

  bool _shouldSkip() =>
      (widget.skipCheck ?? browserAnimatedNavigationJustHappened)();

  @override
  void initState() {
    super.initState();
    _primary = _SkippableAnimation(widget.animation, _shouldSkip);
    _secondary = _SkippableAnimation(widget.secondaryAnimation, _shouldSkip);
  }

  @override
  void didUpdateWidget(BrowserNavigationTransitionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _primary.dispose();
      _primary = _SkippableAnimation(widget.animation, _shouldSkip);
    }
    if (oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _secondary.dispose();
      _secondary = _SkippableAnimation(widget.secondaryAnimation, _shouldSkip);
    }
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_primary, _secondary);
}

/// [parent], except that a run (forward or reverse) which starts right after
/// a browser-animated history step reports its end value from the start.
class _SkippableAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _SkippableAnimation(this.parent, this._shouldSkip) {
    parent.addStatusListener(_onStatus);
    _onStatus(parent.status);
  }

  @override
  final Animation<double> parent;
  final bool Function() _shouldSkip;

  /// End value of the run being skipped, null while animating normally.
  double? _skipTo;

  void _onStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        _skipTo = _shouldSkip() ? 1.0 : null;
        if (_skipTo != null) notifyBrowserNavigationShown();
      case AnimationStatus.reverse:
        _skipTo = _shouldSkip() ? 0.0 : null;
        if (_skipTo != null) notifyBrowserNavigationShown();
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        _skipTo = null;
    }
  }

  void dispose() => parent.removeStatusListener(_onStatus);

  @override
  double get value => _skipTo ?? parent.value;
}
