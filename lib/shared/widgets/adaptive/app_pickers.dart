import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// IOS_LOOK: [showDatePicker] replacement matching `ion-datetime`
/// (`presentation="date"`, `[firstDayOfWeek]="1"`) in an `ion-modal`:
///
/// - iOS: a centred rounded card with the iOS calendar grid; tapping a day
///   returns it, tapping outside cancels (null),
/// - elsewhere: the Material [showDatePicker] with the same parameters.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  Locale? locale,
  String? helpText,
  String? cancelText,
  String? confirmText,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
  bool useRootNavigator = true,
  TransitionBuilder? builder,
}) {
  if (!useIosLook(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      locale: locale,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      initialEntryMode: initialEntryMode,
      selectableDayPredicate: selectableDayPredicate,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }
  var initial = initialDate ?? DateTime.now();
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;
  return showDialog<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: const Color(0x33000000),
    builder: (ctx) {
      Widget picker = CalendarDatePicker(
        initialDate: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        currentDate: currentDate,
        selectableDayPredicate: selectableDayPredicate,
        onDateChanged: (d) => Navigator.of(ctx).pop(d),
      );
      if (locale != null) {
        picker = Localizations.override(
            context: ctx, locale: locale, child: picker);
      }
      Widget card = _IosPickerCard(
        title: helpText,
        width: 340,
        child: picker,
      );
      if (builder != null) card = builder(ctx, card);
      return card;
    },
  );
}

/// IOS_LOOK: [showTimePicker] replacement matching `ion-datetime`
/// `presentation="time"` (iOS: wheel columns for hour and minute, 24h) in a
/// centred card. Tapping outside closes it and returns the chosen time, or
/// null if it was not changed. Elsewhere the Material [showTimePicker].
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  TransitionBuilder? builder,
  String? helpText,
  String? cancelText,
  String? confirmText,
  bool useRootNavigator = true,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
}) {
  if (!useIosLook(context)) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: builder,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
      useRootNavigator: useRootNavigator,
      initialEntryMode: initialEntryMode,
    );
  }
  return showDialog<TimeOfDay>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: false,
    barrierColor: const Color(0x33000000),
    builder: (ctx) => _IosTimePicker(initial: initialTime, title: helpText),
  );
}

class _IosTimePicker extends StatefulWidget {
  const _IosTimePicker({required this.initial, this.title});

  final TimeOfDay initial;
  final String? title;

  @override
  State<_IosTimePicker> createState() => _IosTimePickerState();
}

class _IosTimePickerState extends State<_IosTimePicker> {
  late TimeOfDay _value = widget.initial;

  void _close() {
    final changed = _value.hour != widget.initial.hour ||
        _value.minute != widget.initial.minute;
    Navigator.of(context).pop(changed ? _value : null);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        _IosPickerCard(
          title: widget.title,
          width: 300,
          child: SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(now.year, now.month, now.day,
                  widget.initial.hour, widget.initial.minute),
              onDateTimeChanged: (d) =>
                  _value = TimeOfDay(hour: d.hour, minute: d.minute),
            ),
          ),
        ),
      ],
    );
  }
}

/// ion-modal around an ion-datetime (iOS 26 theme: `--border-radius: 24px`).
class _IosPickerCard extends StatelessWidget {
  const _IosPickerCard({required this.child, required this.width, this.title});

  final Widget child;
  final double width;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = (MediaQuery.sizeOf(context).width - 32).clamp(240.0, width);
    return Center(
      child: SizedBox(
        width: w,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          shadowColor: Colors.black26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
