import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'ion_md_datetime.dart';

/// QUE-27: how the Ionic page presents the `ion-datetime` of a date field.
/// Only the md look (Android, desktop, web) tells them apart; the iOS look
/// always closes its calendar card on the tapped day.
enum IonDatetimeOverlay {
  /// `ion-datetime-button` + `ion-modal [keepContentsMounted]`: a 320px
  /// calendar that stays open; the picked day is taken over when the
  /// backdrop is tapped (Ionic writes the value on every tap).
  button,

  /// `ion-modal.dateModal` (290 × 382, radius 8) whose `(ionChange)`
  /// dismisses the modal: closes as soon as a day is picked.
  dateModal,

  /// `[showDefaultButtons]="true"`: the calendar of [button] with the
  /// "Abbrechen" / "OK" footer; only the confirm button returns a date.
  /// Also used where Ionic has a native `<input type="date">`.
  buttons,
}

/// IOS_LOOK: [showDatePicker] replacement matching `ion-datetime`
/// (`presentation="date"`, `[firstDayOfWeek]="1"`) in an `ion-modal`:
///
/// - iOS: a centred rounded card with the iOS calendar grid; tapping a day
///   returns it, tapping outside cancels (null),
/// - md: the Ionic md `ion-datetime` ([IonMdCalendar], with [preferWheel]
///   the day / month / year wheels) in an md `ion-modal`, presented as
///   [overlay] says; null when nothing was picked. [helpText] is only
///   shown with [showTitle] (Ionic `<span slot="title">`, the primary
///   header of the md `ion-datetime`),
/// - Beta in md: the Material [showDatePicker] with the same parameters.
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
  IonDatetimeOverlay overlay = IonDatetimeOverlay.button,
  bool preferWheel = false,
  bool showAdjacentDays = false,
  bool showTitle = false,
}) {
  if (!useIosLook(context) && context.rdSkin == null) {
    var initial = initialDate ?? DateTime.now();
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    return showIonMdModal<DateTime>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (ctx) {
        Widget card = _MdDateCard(
          initial: initial,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: currentDate,
          selectableDayPredicate: selectableDayPredicate,
          overlay: overlay,
          preferWheel: preferWheel,
          showAdjacentDays: showAdjacentDays,
          cancelText: cancelText,
          confirmText: confirmText,
          title: showTitle ? helpText : null,
        );
        if (locale != null) {
          card = Localizations.override(
              context: ctx, locale: locale, child: card);
        }
        if (builder != null) card = builder(ctx, card);
        return card;
      },
    );
  }
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
/// `presentation="time"` (wheel columns for hour and minute, 24h) in a
/// centred card: the iOS wheel on iOS, the Ionic md wheels
/// ([IonMdTimeWheel]) in an md `ion-modal` elsewhere. Tapping outside
/// closes it and returns the chosen time, or null if it was not changed.
/// Beta in md: the Material [showTimePicker].
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  TransitionBuilder? builder,
  String? helpText,
  String? cancelText,
  String? confirmText,
  bool useRootNavigator = true,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  int minuteInterval = 1,
}) {
  // ion-datetime `minuteValues="0,5,…"`: only multiples of [minuteInterval].
  TimeOfDay snap(TimeOfDay t) => minuteInterval <= 1
      ? t
      : TimeOfDay(hour: t.hour, minute: t.minute - t.minute % minuteInterval);
  if (!useIosLook(context) && context.rdSkin == null) {
    return showIonMdModal<TimeOfDay>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (ctx) {
        Widget card = _MdTimeCard(
          initial: snap(initialTime),
          minuteInterval: minuteInterval < 1 ? 1 : minuteInterval,
        );
        if (builder != null) card = builder(ctx, card);
        return card;
      },
    );
  }
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
    ).then((t) => t == null ? null : snap(t));
  }
  return showDialog<TimeOfDay>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: false,
    barrierColor: const Color(0x33000000),
    builder: (ctx) => _IosTimePicker(
      initial: snap(initialTime),
      title: helpText,
      minuteInterval: minuteInterval < 1 ? 1 : minuteInterval,
    ),
  );
}

/// QUE-27: the md `ion-modal` around an Ionic md date `ion-datetime`.
class _MdDateCard extends StatefulWidget {
  const _MdDateCard({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.overlay,
    required this.preferWheel,
    required this.showAdjacentDays,
    this.currentDate,
    this.selectableDayPredicate,
    this.cancelText,
    this.confirmText,
    this.title,
  });

  /// Ionic `slot="title"`.
  final String? title;
  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final SelectableDayPredicate? selectableDayPredicate;
  final IonDatetimeOverlay overlay;
  final bool preferWheel;
  final bool showAdjacentDays;
  final String? cancelText;
  final String? confirmText;

  @override
  State<_MdDateCard> createState() => _MdDateCardState();
}

class _MdDateCardState extends State<_MdDateCard> {
  /// The last value Ionic would have written (`ionChange`), if any.
  DateTime? _picked;

  bool get _buttons => widget.overlay == IonDatetimeOverlay.buttons;
  bool get _dateModal => widget.overlay == IonDatetimeOverlay.dateModal;

  void _onChanged(DateTime value, {required bool byDay}) {
    _picked = value;
    // `.dateModal`: the page dismisses the modal when the day changed.
    if (_dateModal && byDay) Navigator.of(context).pop(value);
  }

  void _dismiss() => Navigator.of(context).pop(_buttons ? null : _picked);

  void _done() => Navigator.of(context).pop(_picked ?? widget.initial);

  /// md `.datetime-header` with only the title slot: primary, padding 20,
  /// `.datetime-title { font-size: .75rem; text-transform: uppercase }`.
  Widget _header(BuildContext context) {
    return Container(
      height: _headerHeight,
      color: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        widget.title!.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  static const double _headerHeight = 54;

  @override
  Widget build(BuildContext context) {
    final cancel = widget.cancelText ?? context.l10n.commonCancel;
    final done = widget.confirmText ?? context.l10n.commonOk;
    final titled = widget.title != null && widget.title!.isNotEmpty;
    if (widget.preferWheel) {
      // `ion-modal.dateModal { --width: 100%; --max-width: 400px;
      // --height: auto }`; without it `datetime-prefer-wheel` is 350px.
      return IonMdModalCard(
        onDismiss: _dismiss,
        width: _dateModal ? 400 : 350,
        radius: _dateModal ? 8 : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titled) _header(context),
            IonMdDateWheel(
              initialDate: widget.initial,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onChanged: _onChanged,
            ),
            if (_buttons)
              IonMdDatetimeButtons(
                cancelText: cancel,
                doneText: done,
                onCancel: _dismiss,
                onDone: _done,
              ),
          ],
        ),
      );
    }
    final calendar = IonMdCalendar(
      initialDate: widget.initial,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      currentDate: widget.currentDate,
      selectableDayPredicate: widget.selectableDayPredicate,
      showAdjacentDays: widget.showAdjacentDays,
      onChanged: _onChanged,
      showDefaultButtons: _buttons,
      cancelText: cancel,
      doneText: done,
      onCancel: _dismiss,
      onDone: (value) => Navigator.of(context).pop(value),
    );
    // `.dateModal { --width: 290px; --height: 382px; --border-radius: 8px }`
    final height = _dateModal
        ? 382.0
        : IonMdDatetime.gridHeight +
            (_buttons ? IonMdDatetime.footerHeight : 0);
    return IonMdModalCard(
      onDismiss: _dismiss,
      width: _dateModal ? 290 : IonMdDatetime.overlayWidth,
      height: titled && !_dateModal ? height + _headerHeight : height,
      radius: _dateModal ? 8 : null,
      child: titled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_header(context), Expanded(child: calendar)],
            )
          : calendar,
    );
  }
}

/// QUE-27: the md `ion-modal` around the Ionic md time wheels.
class _MdTimeCard extends StatefulWidget {
  const _MdTimeCard({required this.initial, required this.minuteInterval});

  final TimeOfDay initial;
  final int minuteInterval;

  @override
  State<_MdTimeCard> createState() => _MdTimeCardState();
}

class _MdTimeCardState extends State<_MdTimeCard> {
  late TimeOfDay _value = widget.initial;

  void _dismiss() {
    final changed = _value.hour != widget.initial.hour ||
        _value.minute != widget.initial.minute;
    Navigator.of(context).pop(changed ? _value : null);
  }

  @override
  Widget build(BuildContext context) {
    return IonMdModalCard(
      onDismiss: _dismiss,
      child: IonMdTimeWheel(
        initialTime: widget.initial,
        minuteInterval: widget.minuteInterval,
        onChanged: (t) => _value = t,
      ),
    );
  }
}

class _IosTimePicker extends StatefulWidget {
  const _IosTimePicker(
      {required this.initial, this.title, this.minuteInterval = 1});

  final TimeOfDay initial;
  final String? title;
  final int minuteInterval;

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
              minuteInterval: widget.minuteInterval,
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
