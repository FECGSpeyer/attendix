import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import 'adaptive_platform.dart';

/// QUE-28: Ionic `ion-datetime-button` – the grey rounded pill(s) at the end
/// of an item that show the value of an `ion-datetime` and open it.
///
/// `presentation="date"` shows the [date] pill, `"time"` the [time] pill,
/// `"date-time"` both next to each other (the date pill opens the calendar,
/// the time pill the wheels). The caller formats the text and opens the
/// picker (`showAppDatePicker` / `showAppTimePicker`) in [onDateTap] /
/// [onTimeTap]; while the returned future runs, the pill's text is in the
/// primary colour like Ionic's `date-active` / `time-active`.
///
/// Ionic 9 `datetime-button.{ios,md}.css`: radius 8, 2px side margin,
/// `--ion-color-step-300` background (#edeef0; dark iOS #4d4d4d, md
/// #595959), text colour, 1rem; padding 6 × 12 (md) / 7 × 13 (iOS); iOS
/// greys the text while pressed, md shows a ripple. [disabled] (Ionic
/// `[disabled]`) dims the pills to 40 %. A pill without a tap handler stays
/// at full opacity (Ionic: a button in front of a disabled `ion-datetime`).
///
/// The Beta keeps the chip it had before (see [betaStyle]).
class IonDatetimeButton extends StatefulWidget {
  const IonDatetimeButton({
    super.key,
    this.date,
    this.onDateTap,
    this.time,
    this.onTimeTap,
    this.disabled = false,
    this.betaStyle,
  }) : assert(date != null || time != null);

  /// Text of the date pill, e.g. "14. Nov. 2026"; null = no date pill.
  final String? date;
  final FutureOr<void> Function()? onDateTap;

  /// Text of the time pill, e.g. "19:30"; null = no time pill.
  final String? time;
  final FutureOr<void> Function()? onTimeTap;

  final bool disabled;

  /// Text style of the chip in the Beta design (it differed per page).
  final TextStyle? betaStyle;

  /// `--ion-color-step-300` of the current look.
  static Color background(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) return const Color(0xFFEDEEF0);
    return useIosLook(context)
        ? const Color(0xFF4D4D4D)
        : const Color(0xFF595959);
  }

  @override
  State<IonDatetimeButton> createState() => _IonDatetimeButtonState();
}

class _IonDatetimeButtonState extends State<IonDatetimeButton> {
  bool _dateActive = false;
  bool _timeActive = false;

  Future<void> _run(FutureOr<void> Function() onTap, bool date) async {
    final result = onTap();
    if (result is! Future<void>) return;
    setState(() => date ? _dateActive = true : _timeActive = true);
    try {
      await result;
    } finally {
      if (mounted) {
        setState(() => date ? _dateActive = false : _timeActive = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _betaChip(context);
    final date = widget.date;
    final time = widget.time;
    final dateTap = widget.onDateTap;
    final timeTap = widget.onTimeTap;
    final off = widget.disabled;
    final pills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (date != null)
          _Pill(
            text: date,
            active: _dateActive,
            onTap: off || dateTap == null ? null : () => _run(dateTap, true),
          ),
        if (time != null)
          _Pill(
            text: time,
            active: _timeActive,
            onTap: off || timeTap == null ? null : () => _run(timeTap, false),
          ),
      ],
    );
    return off ? Opacity(opacity: 0.4, child: pills) : pills;
  }

  /// The chip of the pages before QUE-28, kept for the Beta design.
  Widget _betaChip(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onTap = widget.disabled ? null : (widget.onDateTap ?? widget.onTimeTap);
    return Material(
      color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEEF0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap == null ? null : () => onTap(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            [widget.date, widget.time].whereType<String>().join(' '),
            style: widget.betaStyle,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatefulWidget {
  const _Pill({required this.text, required this.active, required this.onTap});

  final String text;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(8);
    final color = widget.active
        ? AppColors.primary
        : ios && _pressed
            // `button.ion-activated`: step-600 (#666666, dark #999999)
            ? (dark ? const Color(0xFF999999) : const Color(0xFF666666))
            : theme.colorScheme.onSurface;
    final label = Padding(
      padding: ios
          ? const EdgeInsets.symmetric(horizontal: 13, vertical: 7)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 150),
        style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
          fontSize: ios ? 17 : 16,
          height: 1.25,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: color,
        ),
        child: Text(widget.text, maxLines: 1, softWrap: false),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        child: Material(
          color: IonDatetimeButton.background(context),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: widget.onTap == null
              // no recogniser: a tap falls through to the row behind
              ? label
              : ios
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  child: label,
                )
              : InkWell(onTap: widget.onTap, child: label),
        ),
      ),
    );
  }
}
