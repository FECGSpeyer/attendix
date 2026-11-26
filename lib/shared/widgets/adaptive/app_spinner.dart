import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Spinner matching the native look on iOS (`CupertinoActivityIndicator`) and
/// Material ([CircularProgressIndicator]) elsewhere.
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

  static const double _iosDefaultRadius = 14;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS || value != null) {
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
    const defaultSize = _iosDefaultRadius * 2;
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: defaultSize,
          maxHeight: defaultSize,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: CupertinoActivityIndicator(
            radius: _iosDefaultRadius,
            color: tick,
          ),
        ),
      ),
    );
  }
}
