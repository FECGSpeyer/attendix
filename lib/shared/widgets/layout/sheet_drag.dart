import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';

/// A [DraggableScrollableSheet] that also follows drags outside its list.
///
/// Ionic sheet modals (`breakpoints`) follow the finger wherever the sheet
/// is touched, also on the toolbar: up to the next breakpoint, down to the
/// previous one or closed. A plain [DraggableScrollableSheet] only follows
/// drags that start in its scrollable, so a header placed above the list
/// stayed dead. Here every vertical drag that no scrollable inside takes
/// (header, grabber, empty space) moves the sheet. The constructor matches
/// [DraggableScrollableSheet], so it is a drop-in replacement.
///
/// The Beta design keeps the plain sheet behaviour.
class AppDraggableSheet extends StatefulWidget {
  const AppDraggableSheet({
    super.key,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 1.0,
    this.expand = true,
    this.snap = false,
    this.snapSizes,
    this.shouldCloseOnMinExtent = true,
    required this.builder,
  });

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;
  final bool snap;
  final List<double>? snapSizes;
  final bool shouldCloseOnMinExtent;
  final ScrollableWidgetBuilder builder;

  @override
  State<AppDraggableSheet> createState() => _AppDraggableSheetState();
}

class _AppDraggableSheetState extends State<AppDraggableSheet> {
  final _controller = DraggableScrollableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The sizes the sheet rests at, ascending (Ionic breakpoints without 0).
  List<double> get _stops {
    final stops = <double>{
      widget.initialChildSize,
      widget.maxChildSize,
      ...?widget.snapSizes,
    }.where((s) => s >= widget.minChildSize && s <= widget.maxChildSize).toList()
      ..sort();
    return stops;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_controller.isAttached) return;
    final pixels = _controller.pixels - details.delta.dy;
    _controller.jumpTo(_controller
        .pixelsToSize(pixels)
        .clamp(widget.minChildSize, widget.maxChildSize));
  }

  Future<void> _dragEnd(DragEndDetails details) async {
    if (!_controller.isAttached) return;
    final size = _controller.size;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final stops = _stops;
    if (stops.isEmpty) return;
    double target;
    if (velocity > 700) {
      // Flick down: the next stop below, or closed.
      target = stops.lastWhere((s) => s < size - 0.02, orElse: () => -1);
    } else if (velocity < -700) {
      target = stops.firstWhere((s) => s > size + 0.02, orElse: () => stops.last);
    } else if (size <= widget.minChildSize + 0.001 ||
        size < (widget.minChildSize + stops.first) / 2) {
      target = -1;
    } else {
      target = stops.reduce((a, b) => (a - size).abs() <= (b - size).abs() ? a : b);
    }
    if (target < 0) {
      // Closed – unless the sheet may not close right now (busy, PopScope):
      // then it returns to its first stop.
      final closed = widget.shouldCloseOnMinExtent &&
          await Navigator.of(context).maybePop();
      if (closed || !mounted || !_controller.isAttached) return;
      target = stops.first;
    }
    if ((target - _controller.size).abs() > 0.001) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final classic = context.rdSkin == null;
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      expand: widget.expand,
      snap: widget.snap,
      snapSizes: widget.snapSizes,
      shouldCloseOnMinExtent: widget.shouldCloseOnMinExtent,
      builder: (context, scrollController) {
        final child = widget.builder(context, scrollController);
        if (!classic) return child;
        // A scrollable inside wins the gesture for drags that start on it
        // (it is deeper in the tree), so this only gets the rest.
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: _dragUpdate,
          onVerticalDragEnd: _dragEnd,
          child: child,
        );
      },
    );
  }
}
