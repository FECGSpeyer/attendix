import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// IOS_LOOK: drop-in replacement for an indeterminate
/// [CircularProgressIndicator] that renders like `ion-spinner`:
/// - iOS: the "lines" activity indicator (Ionic iOS default spinner,
///   28px), sized to the box it is put in (e.g. `SizedBox(20, 20)` in a
///   button),
/// - elsewhere: the Material [CircularProgressIndicator] (Ionic md
///   "circular" spinner), with the same parameters.
class AppSpinner extends StatelessWidget {
  const AppSpinner({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.strokeWidth = 4.0,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final Animation<Color?>? valueColor;
  final double strokeWidth;
  final String? semanticsLabel;
  final String? semanticsValue;

  /// Default `ion-spinner` size in iOS mode (28px → radius 14).
  static const double _iosDefaultRadius = 14;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context) || value != null) {
      return CircularProgressIndicator(
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        valueColor: valueColor,
        strokeWidth: strokeWidth,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      );
    }
    final tick = valueColor?.value ?? color;
    return LayoutBuilder(builder: (context, constraints) {
      var radius = _iosDefaultRadius;
      final side = [constraints.maxWidth, constraints.maxHeight]
          .reduce((a, b) => a < b ? a : b);
      if (side.isFinite && side < radius * 2) radius = side / 2;
      return Semantics(
        label: semanticsLabel,
        value: semanticsValue,
        child: CupertinoActivityIndicator(radius: radius, color: tick),
      );
    });
  }
}
