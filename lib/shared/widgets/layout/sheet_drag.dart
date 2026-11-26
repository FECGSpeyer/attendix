import 'package:flutter/material.dart';

/// A [DraggableScrollableSheet] with an Ionic-compatible API.
class AppDraggableSheet extends StatefulWidget {
  const AppDraggableSheet({
    super.key,
    this.breakpoints,
    this.initialBreakpoint,
    this.ionHandle = true,
    this.canDismiss = true,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 1.0,
    this.expand = true,
    this.snap = false,
    this.snapSizes,
    this.shouldCloseOnMinExtent = true,
    required this.builder,
  });

  final List<double>? breakpoints;
  final double? initialBreakpoint;
  final bool ionHandle;
  final bool canDismiss;

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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      expand: widget.expand,
      snap: widget.snap,
      snapSizes: widget.snapSizes,
      shouldCloseOnMinExtent: widget.shouldCloseOnMinExtent,
      builder: widget.builder,
    );
  }
}
