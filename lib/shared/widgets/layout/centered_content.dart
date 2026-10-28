import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Default max width of page content on wide (desktop) screens.
const double kDesktopContentMaxWidth = 900;

/// Padding for a full-width scroll view (ListView etc.) that keeps its
/// content centered and at most [maxWidth] wide on desktop, while the whole
/// page area stays scrollable (Ionic pages center their content similarly).
EdgeInsets centeredListPadding(
  BuildContext context, {
  double maxWidth = kDesktopContentMaxWidth,
  double horizontal = 0,
  double top = 0,
  double bottom = 0,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(horizontal, (width - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Centers [child] and caps its width at [maxWidth].
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = kDesktopContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
