import 'dart:async';

import 'package:flutter/material.dart';

/// Rounded chip button showing a date and/or time value.
class IonDatetimeButton extends StatelessWidget {
  const IonDatetimeButton({
    super.key,
    this.date,
    this.onDateTap,
    this.time,
    this.onTimeTap,
    this.disabled = false,
    this.betaStyle,
  }) : assert(date != null || time != null);

  final String? date;
  final FutureOr<void> Function()? onDateTap;
  final String? time;
  final FutureOr<void> Function()? onTimeTap;
  final bool disabled;
  final TextStyle? betaStyle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onTap = disabled ? null : (onDateTap ?? onTimeTap);
    return Material(
      color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEEF0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap == null ? null : () => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            [date, time].whereType<String>().join(' '),
            style: betaStyle,
          ),
        ),
      ),
    );
  }
}
