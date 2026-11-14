import 'package:flutter/material.dart';

/// A [DraggableScrollableSheet] whose fixed header moves the sheet too.
///
/// Ionic sheet modals (`breakpoints`) follow the finger wherever the sheet
/// is touched, also on the toolbar: up to the next breakpoint, down to the
/// previous one or closed. A plain [DraggableScrollableSheet] only follows
/// drags that start in its scrollable, so a header placed above the list
/// stayed dead. Headers wrapped in [SheetDragArea] (the shared sheet headers
/// are) drive this sheet; the constructor matches
/// [DraggableScrollableSheet], so it is a drop-in replacement.
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

  void _dragEnd(DragEndDetails details) {
    if (!_controller.isAttached) return;
    final size = _controller.size;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final stops = _stops;
    if (stops.isEmpty) return;
    double? target;
    if (velocity > 700) {
      // Flick down: the next stop below, or closed.
      target = stops.lastWhere((s) => s < size - 0.02, orElse: () => -1);
    } else if (velocity < -700) {
      target = stops.firstWhere((s) => s > size + 0.02, orElse: () => stops.last);
    } else if (size < (widget.minChildSize + stops.first) / 2) {
      target = -1;
    } else {
      target = stops.reduce((a, b) => (a - size).abs() <= (b - size).abs() ? a : b);
    }
    if (target < 0) {
      if (widget.shouldCloseOnMinExtent) {
        Navigator.of(context).maybePop();
      } else {
        target = stops.first;
      }
    }
    if (target >= 0 && (target - size).abs() > 0.001) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetDragScope(
      state: this,
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: widget.initialChildSize,
        minChildSize: widget.minChildSize,
        maxChildSize: widget.maxChildSize,
        expand: widget.expand,
        snap: widget.snap,
        snapSizes: widget.snapSizes,
        shouldCloseOnMinExtent: widget.shouldCloseOnMinExtent,
        builder: widget.builder,
      ),
    );
  }
}

class _SheetDragScope extends InheritedWidget {
  const _SheetDragScope({required this.state, required super.child});

  final _AppDraggableSheetState state;

  @override
  bool updateShouldNotify(_SheetDragScope oldWidget) => state != oldWidget.state;
}

/// The part of a sheet outside its list that moves the sheet when dragged
/// (header, grabber). Outside an [AppDraggableSheet] it is just [child].
class SheetDragArea extends StatelessWidget {
  const SheetDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state =
        context.dependOnInheritedWidgetOfExactType<_SheetDragScope>()?.state;
    if (state == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: state._dragUpdate,
      onVerticalDragEnd: state._dragEnd,
      child: child,
    );
  }
}
