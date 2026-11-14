import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_colors.dart';
import '../layout/ionic_md.dart';
import 'ion_button_label.dart';

/// QUE-27: the Ionic **md** `ion-datetime` (@ionic/core 9 `datetime.md.css`,
/// `picker.md.css`, `picker-column.css`, `picker-column-option.md.css`) and
/// the md `ion-modal` it is shown in. Used by the md path of
/// `showAppDatePicker` / `showAppTimePicker` (app_pickers.dart); the iOS
/// look and the Beta keep their own pickers.
class IonMdDatetime {
  IonMdDatetime._();

  /// `--background: var(--ion-color-step-100, #fff)` (md dark #2a2a2a).
  static Color background(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2A2A2A) : Colors.white;

  /// `--ion-color-step-500` (gray, md dark #898989): days of week and
  /// adjacent days.
  static Color step500(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF898989) : const Color(0xFF808080);

  /// `--ion-color-step-300` (#edeef0, md dark #595959): `ion-datetime-button`
  /// and the time button of a date-time calendar.
  static Color step300(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF595959) : const Color(0xFFEDEEF0);

  /// `ion-datetime-button` overlay: `ion-datetime.datetime-grid` 320px wide.
  static const double overlayWidth = 320;

  /// `.calendar-month-year-toggle { min-height: 48px }`.
  static const double headerHeight = 48;

  /// `.calendar-days-of-week { line-height: 36px }`.
  static const double weekdaysHeight = 36;

  /// `.calendar-day { width: 42px; height: 42px }`.
  static const double day = 42;

  /// `ion-picker { height: 200px }`, options 34px, 22px text.
  static const double wheelHeight = 200;
  static const double wheelItem = 34;
  static const double wheelFontSize = 22;

  /// Natural height of the grid: header, days of week and six rows of days
  /// inside `padding: 4px 10px`.
  static const double gridHeight = headerHeight + weekdaysHeight + 8 + 6 * day;

  /// `.datetime-buttons { padding: 10px }` around 32px `ion-button`s.
  static const double footerHeight = 52;
}

/// Shows [builder] in an Ionic md `ion-modal` that is as large as its
/// content (`ion-datetime-button-overlay`: `--width / --height:
/// fit-content`): `--backdrop-opacity: .32`, the md enter animation (40px
/// up, fading in, 280ms `cubic-bezier(.36,.66,.04,1)`). The card decides
/// what a tap on the backdrop returns ([IonMdModalCard.onDismiss]).
Future<T?> showIonMdModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    // The card handles the backdrop tap itself (it returns the value).
    barrierDismissible: false,
    barrierColor: IonMd.backdrop,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.36, 0.66, 0.04, 1),
        reverseCurve: const Cubic(0.47, 0, 0.745, 0.715),
      );
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          builder: (_, c) => Transform.translate(
            offset: Offset(0, 40 * (1 - curved.value)),
            child: c,
          ),
          child: child,
        ),
      );
    },
  );
}

/// The wrapper of an md `ion-modal` around an `ion-datetime`: centred, the
/// md modal corners (`--border-radius: 0`, from 768 × 600 on 2px with
/// `0 28px 48px rgba(0,0,0,.4)`) unless the page sets its own [radius]
/// (`ion-modal.dateModal { --border-radius: 8px }`). A tap on the backdrop,
/// the system back gesture and Escape call [onDismiss].
class IonMdModalCard extends StatelessWidget {
  const IonMdModalCard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.width,
    this.height,
    this.radius,
  });

  final Widget child;
  final VoidCallback onDismiss;

  /// null = as wide as [child] (`--width: fit-content`).
  final double? width;
  final double? height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final size = MediaQuery.sizeOf(context);
    final large = size.width >= 768 && size.height >= 600;
    final r = BorderRadius.circular(radius ?? (large ? 2 : 0));
    final w = width?.clamp(0.0, size.width);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDismiss();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): onDismiss,
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: r,
                        boxShadow: large
                            ? const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 48,
                                  offset: Offset(0, 28),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: IonMdDatetime.background(b),
                        borderRadius: r,
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(width: w, height: height, child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String _monthName(BuildContext context, int month) {
  final locale = Localizations.localeOf(context).toString();
  try {
    return DateFormat.MMMM(locale).format(DateTime(2024, month));
  } catch (_) {
    // Date symbols of the locale not loaded (tests): "November 2024" without
    // the year.
    return MaterialLocalizations.of(context)
        .formatMonthYear(DateTime(2024, month))
        .replaceAll(RegExp(r'\s*2024\s*'), '')
        .trim();
  }
}

/// Ionic md `ion-datetime presentation="date"` as a calendar grid
/// (`[firstDayOfWeek]="1"`): the month / year toggle with the caret (opens
/// the month + year wheels), the previous / next chevrons, the narrow days
/// of week, six rows of 42px days (today outlined, the value filled in the
/// primary colour, days outside [firstDate]..[lastDate] at 40 %), and with
/// [showDefaultButtons] the `ion-buttons` footer.
class IonMdCalendar extends StatefulWidget {
  const IonMdCalendar({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.currentDate,
    this.selectableDayPredicate,
    this.showAdjacentDays = false,
    this.showDefaultButtons = false,
    this.cancelText,
    this.doneText,
    this.onCancel,
    this.onDone,
  });

  /// The value shown as selected.
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? currentDate;
  final SelectableDayPredicate? selectableDayPredicate;

  /// `show-adjacent-days`: the days of the neighbouring months fill the
  /// first and last row (grey).
  final bool showAdjacentDays;

  /// Ionic `ionChange`: a day was tapped ([byDay]) or the month / year
  /// wheels moved the value.
  final void Function(DateTime value, {required bool byDay}) onChanged;

  /// `[showDefaultButtons]="true"`: "Abbrechen" / "Fertig".
  final bool showDefaultButtons;
  final String? cancelText;
  final String? doneText;
  final VoidCallback? onCancel;
  final ValueChanged<DateTime>? onDone;

  @override
  State<IonMdCalendar> createState() => _IonMdCalendarState();
}

class _IonMdCalendarState extends State<IonMdCalendar> {
  late final DateTime _first = _day(widget.firstDate);
  late final DateTime _last = _day(widget.lastDate);
  late DateTime _value = _clamp(_day(widget.initialDate));
  late int _page = _pageOf(_value);
  late final PageController _pages = PageController(initialPage: _page);
  bool _monthYear = false;

  DateTime _clamp(DateTime d) =>
      d.isBefore(_first) ? _first : (d.isAfter(_last) ? _last : d);

  int _pageOf(DateTime d) =>
      (d.year - _first.year) * 12 + d.month - _first.month;

  int get _pageCount => _pageOf(_last) + 1;

  DateTime _monthOf(int page) =>
      DateTime(_first.year, _first.month + page);

  bool _enabled(DateTime d) =>
      !d.isBefore(_first) &&
      !d.isAfter(_last) &&
      (widget.selectableDayPredicate?.call(d) ?? true);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = _page + delta;
    if (target < 0 || target >= _pageCount) return;
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _pickDay(DateTime d) {
    setState(() => _value = d);
    final page = _pageOf(d);
    if (page != _page && _pages.hasClients) _go(page - _page);
    widget.onChanged(d, byDay: true);
  }

  /// Month / year wheels: the value keeps its day (Ionic `setActiveParts`).
  void _pickMonthYear(int year, int month) {
    final day = _value.day.clamp(1, _daysInMonth(year, month));
    final next = _clamp(DateTime(year, month, day));
    if (next == _value) {
      // Rebuild so a wheel left outside min / max snaps back.
      setState(() {});
      return;
    }
    setState(() {
      _value = next;
      _page = _pageOf(next);
    });
    widget.onChanged(next, byDay: false);
  }

  void _toggleMonthYear() {
    setState(() => _monthYear = !_monthYear);
    if (!_monthYear) {
      // The grid was rebuilt: show the month of the wheels.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_page);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    final l = MaterialLocalizations.of(context);
    final grey = IonMd.step650(b);
    final month = _monthOf(_page);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .calendar-action-buttons
        SizedBox(
          height: IonMdDatetime.headerHeight,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                  onTap: _toggleMonthYear,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l.formatMonthYear(month),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.2,
                              color: _monthYear ? AppColors.primary : grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _monthYear
                              ? Ionicons.caretUpSharp
                              : Ionicons.caretDownSharp,
                          size: 16,
                          color: _monthYear ? AppColors.primary : grey,
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
              if (!_monthYear) ...[
                _NavButton(
                  icon: Ionicons.chevronBack,
                  label: l.previousMonthTooltip,
                  color: grey,
                  onTap: _page > 0 ? () => _go(-1) : null,
                ),
                _NavButton(
                  icon: Ionicons.chevronForward,
                  label: l.nextMonthTooltip,
                  color: grey,
                  onTap: _page < _pageCount - 1 ? () => _go(1) : null,
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
        ),
        if (_monthYear)
          Expanded(
            child: Center(
              child: _MonthYearWheels(
                value: _value,
                first: _first,
                last: _last,
                onChanged: _pickMonthYear,
              ),
            ),
          )
        else ...[
          // .calendar-days-of-week
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: IonMdDatetime.weekdaysHeight,
              child: Row(
                children: [
                  // Monday first; narrowWeekdays starts with Sunday.
                  for (var i = 1; i <= 7; i++)
                    Expanded(
                      child: Center(
                        child: ExcludeSemantics(
                          child: Text(
                            l.narrowWeekdays[i % 7],
                            style: TextStyle(
                              fontSize: 14,
                              color: IonMdDatetime.step500(b),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // .calendar-body
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _pageCount,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (_, p) => _MonthGrid(
                month: _monthOf(p),
                value: _value,
                today: _day(widget.currentDate ?? DateTime.now()),
                enabled: _enabled,
                showAdjacentDays: widget.showAdjacentDays,
                onPick: _pickDay,
              ),
            ),
          ),
        ],
        if (widget.showDefaultButtons)
          // .datetime-buttons (hidden while the month / year wheels show)
          Visibility(
            visible: !_monthYear,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: IonMdDatetimeButtons(
              cancelText: widget.cancelText,
              doneText: widget.doneText,
              onCancel: widget.onCancel,
              onDone: () => widget.onDone?.call(_value),
            ),
          ),
      ],
    );
  }
}

/// `.datetime-buttons`: the `ion-buttons` footer of `showDefaultButtons`
/// (10px padding, end-aligned md toolbar buttons in the primary colour).
class IonMdDatetimeButtons extends StatelessWidget {
  const IonMdDatetimeButtons({
    super.key,
    this.cancelText,
    this.doneText,
    this.onCancel,
    this.onDone,
  });

  final String? cancelText;
  final String? doneText;
  final VoidCallback? onCancel;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    Widget button(String text, VoidCallback? onTap) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
              textStyle: const TextStyle(
                fontSize: IonMd.buttonFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: IonMd.buttonLetterSpacing,
              ),
            ),
            child: Text(ionUppercase(text)),
          ),
        );
    return SizedBox(
      height: IonMdDatetime.footerHeight,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            button(cancelText ?? l.cancelButtonLabel, onCancel),
            button(doneText ?? l.okButtonLabel, onDone),
          ],
        ),
      ),
    );
  }
}

/// `ion-buttons > ion-button` icon-only in md: 48 × 48, round.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 24,
            color: onTap == null ? color.withValues(alpha: 0.5) : color,
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.value,
    required this.today,
    required this.enabled,
    required this.showAdjacentDays,
    required this.onPick,
  });

  final DateTime month;
  final DateTime value;
  final DateTime today;
  final bool Function(DateTime) enabled;
  final bool showAdjacentDays;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    // Monday first: blanks before the 1st.
    final lead = (DateTime(month.year, month.month, 1).weekday - 1) % 7;
    final days = _daysInMonth(month.year, month.month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          for (var row = 0; row < 6; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(child: _cell(context, row * 7 + col - lead + 1, days)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, int dayNumber, int days) {
    final adjacent = dayNumber < 1 || dayNumber > days;
    if (adjacent && !showAdjacentDays) return const SizedBox.shrink();
    // DateTime normalises day 0 / 32 into the neighbouring month.
    final date = DateTime(month.year, month.month, dayNumber);
    final b = Theme.of(context).brightness;
    final active = date == value;
    final isToday = date == today;
    final ok = enabled(date);
    final color = active
        ? Colors.white
        : adjacent
            ? IonMdDatetime.step500(b)
            : isToday
                ? AppColors.primary
                : IonMd.text(b);
    final circle = Container(
      width: IonMdDatetime.day,
      height: IonMdDatetime.day,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.primary : null,
        border: active || (isToday && !adjacent)
            ? Border.all(color: AppColors.primary)
            : null,
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(fontSize: 14, color: color),
      ),
    );
    return Semantics(
      button: true,
      selected: active,
      enabled: ok,
      label: MaterialLocalizations.of(context).formatFullDate(date),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ok ? () => onPick(date) : null,
        // 42px circles in narrower columns overlap like in Ionic.
        child: OverflowBox(
          minWidth: IonMdDatetime.day,
          maxWidth: IonMdDatetime.day,
          minHeight: IonMdDatetime.day,
          maxHeight: IonMdDatetime.day,
          child: Opacity(opacity: ok ? 1 : 0.4, child: circle),
        ),
      ),
    );
  }
}

/// The month + year wheels behind the month / year toggle
/// (`renderWheelView('month-year')`).
class _MonthYearWheels extends StatelessWidget {
  const _MonthYearWheels({
    required this.value,
    required this.first,
    required this.last,
    required this.onChanged,
  });

  final DateTime value;
  final DateTime first;
  final DateTime last;
  final void Function(int year, int month) onChanged;

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = first.year; y <= last.year; y++) y];
    return IonMdPicker(
      columns: [
        IonMdPickerColumnData(
          items: [for (var m = 1; m <= 12; m++) _monthName(context, m)],
          index: value.month - 1,
          onChanged: (i) => onChanged(value.year, i + 1),
        ),
        IonMdPickerColumnData(
          items: [for (final y in years) '$y'],
          index: value.year - first.year,
          onChanged: (i) => onChanged(years[i], value.month),
        ),
      ],
    );
  }
}

/// One column of an [IonMdPicker].
class IonMdPickerColumnData {
  const IonMdPickerColumnData({
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<String> items;
  final int index;

  /// Ionic `ionChange` of the column: called when the wheel has settled on
  /// another option.
  final ValueChanged<int> onChanged;
}

/// Ionic md `ion-picker` with its `ion-picker-column`s: 200px high, 34px
/// options in 22px text, the centred option in the primary colour, no
/// highlight bar, the page colour fading in from the top and the bottom.
/// The first column is start-aligned, the last end-aligned, others centred;
/// every column is as wide as its longest option plus 16px on each side.
class IonMdPicker extends StatelessWidget {
  const IonMdPicker({super.key, required this.columns});

  final List<IonMdPickerColumnData> columns;

  /// Width of a column showing [items].
  static double columnWidth(BuildContext context, List<String> items) {
    final style = DefaultTextStyle.of(context)
        .style
        .copyWith(fontSize: IonMdDatetime.wheelFontSize);
    var widest = 26.0; // .picker-opts { min-width: 26px }
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    );
    // The longest labels are enough (month names, numbers).
    final sorted = [...items]..sort((a, b) => b.length.compareTo(a.length));
    for (final item in sorted.take(4)) {
      painter.text = TextSpan(text: item, style: style);
      painter.layout();
      if (painter.width > widest) widest = painter.width;
    }
    painter.dispose();
    return widest.ceilToDouble() + 32;
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    // `--fade-background-rgb` is not set in md: `--ion-background-color`.
    final fade = IonMd.background(b);
    final n = columns.length;
    return SizedBox(
      height: IonMdDatetime.wheelHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Scaled down instead of overflowing on very narrow cards or
          // with a large text size.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < n; i++)
                  _IonMdPickerColumn(
                    data: columns[i],
                    width: columnWidth(context, columns[i].items),
                    align: n == 1
                        ? Alignment.center
                        : i == 0
                            ? Alignment.centerLeft
                            : i == n - 1
                                ? Alignment.centerRight
                                : Alignment.center,
                  ),
              ],
            ),
          ),
          // .picker-before / .picker-after
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 83,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fade, fade.withValues(alpha: 0)],
                    stops: const [0.2, 0.9],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 116,
            left: 0,
            right: 0,
            height: 84,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [fade, fade.withValues(alpha: 0)],
                    stops: const [0.3, 0.9],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IonMdPickerColumn extends StatefulWidget {
  const _IonMdPickerColumn({
    required this.data,
    required this.width,
    required this.align,
  });

  final IonMdPickerColumnData data;
  final double width;
  final Alignment align;

  @override
  State<_IonMdPickerColumn> createState() => _IonMdPickerColumnState();
}

class _IonMdPickerColumnState extends State<_IonMdPickerColumn> {
  late int _current = widget.data.index;
  late int _reported = widget.data.index;
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.data.index);

  @override
  void didUpdateWidget(_IonMdPickerColumn old) {
    super.didUpdateWidget(old);
    final index = widget.data.index.clamp(0, widget.data.items.length - 1);
    if (index != _reported) {
      // The value was changed from outside (clamped to min / max).
      _reported = index;
      _current = index;
      // Not while building: the jump notifies the wheel's listeners.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _controller.hasClients &&
            _controller.selectedItem != _reported) {
          _controller.jumpToItem(_reported);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScrollEnd(ScrollEndNotification n) {
    if (_current != _reported) {
      _reported = _current;
      widget.data.onChanged(_current);
    }
    return false;
  }

  /// Ionic: a click on an option scrolls it into the centre.
  void _onTapUp(TapUpDetails d) {
    final delta =
        ((d.localPosition.dy - IonMdDatetime.wheelHeight / 2) / IonMdDatetime.wheelItem)
            .round();
    if (delta == 0 || !_controller.hasClients) return;
    final target =
        (_controller.selectedItem + delta).clamp(0, widget.data.items.length - 1);
    _controller.animateToItem(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final items = widget.data.items;
    return SizedBox(
      width: widget.width,
      height: IonMdDatetime.wheelHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEnd,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: IonMdDatetime.wheelItem,
              // Ionic's columns are flat lists, no drum.
              diameterRatio: 100,
              perspective: 0.0001,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => setState(() => _current = i),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: widget.align,
                    child: Text(
                      items[i],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: IonMdDatetime.wheelFontSize,
                        height: 1,
                        color: i == _current ? AppColors.primary : IonMd.text(b),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Ionic md `ion-datetime presentation="time"`: the hour and minute wheels
/// (24h, two digits), minutes limited to multiples of [minuteInterval]
/// (`minuteValues="0,5,…"`).
class IonMdTimeWheel extends StatefulWidget {
  const IonMdTimeWheel({
    super.key,
    required this.initialTime,
    required this.onChanged,
    this.minuteInterval = 1,
  });

  final TimeOfDay initialTime;
  final int minuteInterval;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  State<IonMdTimeWheel> createState() => _IonMdTimeWheelState();
}

class _IonMdTimeWheelState extends State<IonMdTimeWheel> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;

  @override
  Widget build(BuildContext context) {
    final step = widget.minuteInterval < 1 ? 1 : widget.minuteInterval;
    final minutes = [for (var m = 0; m < 60; m += step) m];
    return IonMdPicker(
      columns: [
        IonMdPickerColumnData(
          items: [for (var h = 0; h < 24; h++) _two(h)],
          index: _hour,
          onChanged: (i) {
            setState(() => _hour = i);
            widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
          },
        ),
        IonMdPickerColumnData(
          items: [for (final m in minutes) _two(m)],
          index: (_minute ~/ step).clamp(0, minutes.length - 1),
          onChanged: (i) {
            setState(() => _minute = minutes[i]);
            widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
          },
        ),
      ],
    );
  }
}

/// Ionic md `ion-datetime presentation="date" [preferWheel]="true"`: day,
/// month and year wheels (day first, as in the German locale). The value
/// stays inside [firstDate]..[lastDate].
class IonMdDateWheel extends StatefulWidget {
  const IonMdDateWheel({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Ionic `ionChange`; [byDay] when the day wheel was moved.
  final void Function(DateTime value, {required bool byDay}) onChanged;

  @override
  State<IonMdDateWheel> createState() => _IonMdDateWheelState();
}

class _IonMdDateWheelState extends State<IonMdDateWheel> {
  late final DateTime _first = _day(widget.firstDate);
  late final DateTime _last = _day(widget.lastDate);
  late DateTime _value = _clamp(_day(widget.initialDate));

  DateTime _clamp(DateTime d) =>
      d.isBefore(_first) ? _first : (d.isAfter(_last) ? _last : d);

  void _set(int year, int month, int day, {required bool byDay}) {
    final next = _clamp(
        DateTime(year, month, day.clamp(1, _daysInMonth(year, month))));
    if (next == _value) {
      // Rebuild so a wheel left outside min / max snaps back.
      setState(() {});
      return;
    }
    final dayChanged = next.day != _value.day;
    setState(() => _value = next);
    widget.onChanged(next, byDay: byDay || dayChanged);
  }

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = _first.year; y <= _last.year; y++) y];
    final days = _daysInMonth(_value.year, _value.month);
    return IonMdPicker(
      columns: [
        IonMdPickerColumnData(
          items: [for (var d = 1; d <= days; d++) '$d'],
          index: _value.day - 1,
          onChanged: (i) => _set(_value.year, _value.month, i + 1, byDay: true),
        ),
        IonMdPickerColumnData(
          items: [for (var m = 1; m <= 12; m++) _monthName(context, m)],
          index: _value.month - 1,
          onChanged: (i) => _set(_value.year, i + 1, _value.day, byDay: false),
        ),
        IonMdPickerColumnData(
          items: [for (final y in years) '$y'],
          index: _value.year - _first.year,
          onChanged: (i) => _set(years[i], _value.month, _value.day, byDay: false),
        ),
      ],
    );
  }
}
