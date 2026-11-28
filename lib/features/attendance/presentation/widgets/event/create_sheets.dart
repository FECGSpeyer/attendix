import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/services/holiday_service.dart';
import '../../../../../core/theme/design_theme.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker, showAppTimePicker;
import '../../../data/create_logic.dart';
import '../multi_date_calendar.dart';
import '../../../../../shared/widgets/components/components.dart';

/// REDESIGN: sheets of "Termin anlegen" (Art, Abmeldeschluss, weitere
/// Daten).

/// Picks the Art of the new Termin. With [onManage] (leads) a last row
/// "Terminarten verwalten" closes the sheet and calls it.
Future<AttendanceType?> showRdTypePicker(
  BuildContext context, {
  required List<AttendanceType> types,
  AttendanceType? selected,
  VoidCallback? onManage,
}) {
  return showRdSheet<AttendanceType>(
    context,
    Builder(builder: (context) {
      final l10n = context.l10n;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          RdSheetTitle(l10n.redesignCreateChooseType),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RdGroupedList(children: [
              for (final t in types)
                RdListRow(
                  leading: Icon(Icons.circle, size: 14, color: ColorUtils.parseNamedColor(t.color)),
                  title: t.name,
                  selected: t.id == selected?.id,
                  showChevron: false,
                  trailing: RdSheetCheck(t.id == selected?.id),
                  onTap: () => Navigator.of(context).pop(t),
                ),
            ]),
          ),
          if (onManage != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RdGroupedList(children: [
                RdListRow(
                  leading: const RdRowIcon(Icons.category_outlined),
                  title: l10n.rdAdminManageTypes,
                  titleColor: context.rd.primary,
                  showChevron: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    onManage();
                  },
                ),
              ]),
            ),
          ],
        ],
      );
    }),
  );
}

String rdDeadlineLabel(AppLocalizations l10n, RdDeadline d) => switch (d) {
      RdDeadline.none => l10n.redesignCreateDeadlineNone,
      RdDeadline.hours24 => l10n.redesignCreateDeadline24h,
      RdDeadline.days2 => l10n.redesignCreateDeadline2d,
      RdDeadline.week => l10n.redesignCreateDeadlineWeek,
      RdDeadline.custom => l10n.redesignCreateDeadlineCustomLabel,
    };

/// "25 Std." / "2 Tage 3 Std." for a lead time in minutes.
String rdDeadlineOffset(AppLocalizations l10n, int minutes) {
  final days = minutes ~/ (24 * 60);
  final hours = (minutes % (24 * 60)) ~/ 60;
  final rest = minutes % 60;
  // Under two days reads better in hours ("25 Std.").
  final useDays = days >= 2;
  return [
    if (useDays) l10n.redesignCreateDeadlineCustomDays(days),
    if (useDays ? hours > 0 : minutes >= 60) l10n.redesignCreateDeadlineCustomHours(useDays ? hours : minutes ~/ 60),
    if (rest > 0) l10n.redesignCreateDeadlineCustomMinutes(rest),
  ].join(' ');
}

/// The chosen "Antwort bis" as shown in the form: a picked date reads as
/// that date for one Termin, as the lead time for several.
String rdDeadlineValue(
  AppLocalizations l10n,
  RdDeadline d, {
  int? customMinutes,
  required DateTime firstStart,
  required bool series,
}) {
  if (d != RdDeadline.custom || customMinutes == null) return rdDeadlineLabel(l10n, d);
  if (series) return l10n.redesignCreateDeadlineCustomEach(rdDeadlineOffset(l10n, customMinutes));
  final at = DateTime(
    firstStart.year,
    firstStart.month,
    firstStart.day,
    firstStart.hour,
    firstStart.minute - customMinutes,
  );
  final locale = currentIntlLocale();
  return '${DateFormat.MMMEd(locale).format(at)}, ${DateFormat.Hm(locale).format(at)}';
}

/// Result of the "Antwort bis" sheet.
typedef RdDeadlineChoice = ({RdDeadline option, int? customMinutes});

/// Picks the Abmeldeschluss (relative to each Termin). "Eigenes Datum …"
/// asks for a day and time before [firstStart], the start of the first
/// Termin; its distance applies to each Termin.
Future<RdDeadlineChoice?> showRdDeadlinePicker(
  BuildContext context,
  RdDeadline selected, {
  int? customMinutes,
  required DateTime firstStart,
  bool series = false,
}) {
  return showRdSheet<RdDeadlineChoice>(
    context,
    Builder(builder: (context) {
      final l10n = context.l10n;
      final custom = selected == RdDeadline.custom && customMinutes != null;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          RdSheetTitle(l10n.redesignCreateDeadline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RdGroupedList(children: [
              for (final d in RdDeadline.values.where((d) => d != RdDeadline.custom))
                RdListRow(
                  title: rdDeadlineLabel(l10n, d),
                  selected: d == selected,
                  showChevron: false,
                  trailing: RdSheetCheck(d == selected),
                  onTap: () => Navigator.of(context).pop((option: d, customMinutes: null)),
                ),
              if (custom)
                RdListRow(
                  title: rdDeadlineValue(l10n, selected,
                      customMinutes: customMinutes, firstStart: firstStart, series: false),
                  subtitle: l10n.redesignCreateDeadlineCustomLabel,
                  selected: true,
                  showChevron: false,
                  trailing: const RdSheetCheck(true),
                  onTap: () => _pickCustomDeadline(context, firstStart, customMinutes),
                )
              else
                RdListRow(
                  leading: const RdRowIcon(Icons.calendar_month_outlined),
                  title: l10n.redesignCreateDeadlineCustom,
                  titleColor: context.rd.primary,
                  showChevron: false,
                  onTap: () => _pickCustomDeadline(context, firstStart, null),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              [
                l10n.redesignCreateDeadlineHint,
                if (series) l10n.redesignCreateDeadlineCustomEachHint,
              ].join(' '),
              style: RdType.meta(context.rd, size: 13),
            ),
          ),
        ],
      );
    }),
  );
}

/// Day, then time of a custom "Antwort bis"; closes the sheet with it.
/// Cancelling either picker keeps the sheet open.
Future<void> _pickCustomDeadline(BuildContext context, DateTime firstStart, int? current) async {
  final l10n = context.l10n;
  final now = DateTime.now();
  final today = rdDay(now);
  final lastDay = rdDay(firstStart);
  if (lastDay.isBefore(today)) return;
  var initial = current != null
      ? DateTime(firstStart.year, firstStart.month, firstStart.day, firstStart.hour, firstStart.minute - current)
      : DateTime(firstStart.year, firstStart.month, firstStart.day - 1, firstStart.hour, firstStart.minute);
  if (rdDay(initial).isBefore(today)) initial = DateTime(today.year, today.month, today.day, initial.hour, initial.minute);
  final day = await showAppDatePicker(
    context: context,
    initialDate: rdDay(initial),
    firstDate: today,
    lastDate: lastDay,
    helpText: l10n.redesignCreateDeadline,
  );
  if (day == null || !context.mounted) return;
  final time = await showAppTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    helpText: l10n.redesignCreateDeadline,
  );
  if (time == null || !context.mounted) return;
  // Wall-clock distance, like rdDeadlineFor counts it back.
  final minutes = DateTime.utc(firstStart.year, firstStart.month, firstStart.day, firstStart.hour, firstStart.minute)
      .difference(DateTime.utc(day.year, day.month, day.day, time.hour, time.minute))
      .inMinutes;
  if (minutes <= 0) {
    ToastHelper.showError(context, l10n.redesignCreateDeadlineCustomTooLate);
    return;
  }
  Navigator.of(context).pop((option: RdDeadline.custom, customMinutes: minutes));
}

/// Result of the "Weitere Daten" sheet: the rhythm and the single days
/// taken out of it ([removed]) or added on top ([added]).
/// [showHolidays]: "Ferien und Feiertage einblenden" was tapped; the choice
/// still applies, then the caller opens the setting.
typedef RdRepeatChoice = ({
  RdRepeat repeat,
  DateTime until,
  bool skipHolidays,
  Set<DateTime> removed,
  Set<DateTime> added,
  bool showHolidays,
});

/// "Weitere Daten": once, every week or every two weeks until a day, with
/// the dates as chips. Tapping a chip leaves that day out (again brings it
/// back); "Tage im Kalender wählen" edits the same selection in a calendar
/// on top of this sheet.
Future<RdRepeatChoice?> showRdRepeatSheet(
  BuildContext context, {
  required DateTime start,
  required RdRepeat repeat,
  required DateTime until,
  required bool skipHolidays,
  required HolidayData holidays,
  Set<DateTime> removed = const {},
  Set<DateTime> added = const {},
  bool offerHolidays = false,
}) {
  return showRdSheet<RdRepeatChoice>(
    context,
    _RepeatSheet(
      start: start,
      repeat: repeat,
      until: until,
      skipHolidays: skipHolidays,
      holidays: holidays,
      removed: removed,
      added: added,
      offerHolidays: offerHolidays,
    ),
  );
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({
    required this.start,
    required this.repeat,
    required this.until,
    required this.skipHolidays,
    required this.holidays,
    required this.removed,
    required this.added,
    this.offerHolidays = false,
  });

  final DateTime start;
  final RdRepeat repeat;
  final DateTime until;
  final bool skipHolidays;
  final Set<DateTime> removed;
  final Set<DateTime> added;

  /// Leads in groups without Ferien und Feiertage: a row to switch them on
  /// (Verwaltung › Ferien und Feiertage), so series can leave them out.
  final bool offerHolidays;
  final HolidayData holidays;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RdRepeat _repeat = widget.repeat;
  late DateTime _until = widget.until;
  late bool _skip = widget.skipHolidays;
  late Set<DateTime> _removed = {...widget.removed};
  late Set<DateTime> _added = {...widget.added};

  bool get _hasHolidays =>
      widget.holidays.publicHolidays.isNotEmpty || widget.holidays.schoolHolidays.isNotEmpty;

  List<DateTime> get _rhythm =>
      rdRhythmDates(widget.start, _repeat, _until, skipHolidays: _skip, holidays: widget.holidays);

  List<DateTime> get _chosen => rdChosenDates(_rhythm, _removed, _added);

  /// Every day shown as a chip: the whole series (holidays too) and the
  /// added days, chosen or left out.
  List<DateTime> get _chipDays {
    final series = _repeat == RdRepeat.once
        ? [rdDay(widget.start)]
        : rdRhythmDates(widget.start, _repeat, _until);
    return {...series, ..._chosen}.toList()..sort();
  }

  void _choose(Iterable<DateTime> chosen) {
    final changes = rdDateChanges(_rhythm, chosen);
    setState(() {
      _removed = changes.removed;
      _added = changes.added;
    });
  }

  void _toggle(DateTime day) {
    final chosen = _chosen.toSet();
    chosen.contains(day) ? chosen.remove(day) : chosen.add(day);
    _choose(chosen);
  }

  Future<void> _pickUntil() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _until,
      firstDate: widget.start,
      lastDate: DateTime(widget.start.year + 2, widget.start.month, widget.start.day),
      helpText: context.l10n.redesignCreateRepeatUntil,
    );
    if (picked != null && mounted) setState(() => _until = rdDay(picked));
  }

  /// The calendar opens over this sheet with the same days; closing it
  /// without "Übernehmen" comes back here unchanged.
  Future<void> _pickInCalendar() async {
    final chosen = _chosen;
    final l10n = context.l10n;
    final result = await MultiDateCalendarDialog.show(
      context,
      initialDates: chosen,
      initialFocusedDay: chosen.isEmpty ? widget.start : chosen.first,
      title: l10n.redesignCreateRepeatPickTitle,
      countLabel: (n) => l10n.redesignCreateRepeatCount(n),
      skippedDates: _chipDays,
      skippedLabel: l10n.redesignCreateRepeatSkippedLegend,
    );
    if (result == null || result.isEmpty || !mounted) return;
    _choose(result);
  }

  void _done({bool showHolidays = false}) => Navigator.of(context).pop((
        repeat: _repeat,
        until: _until,
        skipHolidays: _skip,
        removed: _removed,
        added: _added,
        showHolidays: showHolidays,
      ));

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final repeating = _repeat != RdRepeat.once;
    final chosen = _chosen;
    final chosenSet = chosen.toSet();
    final chips = _chipDays;
    final start = rdDay(widget.start);
    final seriesSet = (repeating ? rdRhythmDates(widget.start, _repeat, _until) : [start]).toSet();
    final skipped = chips.where((d) => !chosenSet.contains(d)).length;
    final added = chosen.where((d) => !seriesSet.contains(d)).length;
    final extra = [
      if (skipped > 0) l10n.redesignCreateRepeatSkipped(skipped),
      if (added > 0) l10n.redesignCreateRepeatAdded(added),
    ].join(', ');

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetTitle(l10n.redesignCreateMoreDates),
        RdSegmented<RdRepeat>(
          values: const [RdRepeat.once, RdRepeat.weekly, RdRepeat.biweekly],
          selected: _repeat,
          labelOf: (r) => switch (r) {
            RdRepeat.weekly => l10n.redesignCreateRepeatWeeklyOption,
            RdRepeat.biweekly => l10n.redesignCreateRepeatBiweeklyOption,
            RdRepeat.once => l10n.redesignCreateRepeatOnce,
          },
          // A new rhythm starts without the days left out of the old one.
          onChanged: (r) => setState(() {
            _repeat = r;
            _removed = {};
          }),
        ),
        const SizedBox(height: 14),
        if (repeating) ...[
          RdGroupedList(children: [
            RdListRow(
              title: l10n.redesignCreateRepeatUntil,
              value: DateFormat.yMMMEd(locale).format(_until),
              onTap: _pickUntil,
            ),
            if (_hasHolidays)
              RdListRow(
                title: l10n.redesignCreateRepeatSkipHolidays,
                showChevron: false,
                trailing: Switch.adaptive(
                  value: _skip,
                  activeTrackColor: p.primary,
                  onChanged: (v) => setState(() => _skip = v),
                ),
                onTap: () => setState(() => _skip = !_skip),
              )
            else if (widget.offerHolidays)
              // Keeps the series chosen so far.
              RdListRow(
                title: l10n.rdAdminShowHolidays,
                titleColor: p.primary,
                showChevron: false,
                onTap: () => _done(showHolidays: true),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        if (repeating || chips.length > 1) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(l10n.redesignCreateRepeatCount(chosen.length), style: RdType.section(p)),
              if (extra.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(extra, style: RdType.meta(p, size: 13)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in chips)
                _DateChip(
                  day: d,
                  holiday: rdHolidayOn(widget.holidays, d),
                  skipped: !chosenSet.contains(d),
                  added: !seriesSet.contains(d),
                  // Einmalig: the day itself is the Datum of the form.
                  onTap: !repeating && d == start ? null : () => _toggle(d),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (chosen.length >= rdMaxCreateDates)
            Text(l10n.redesignCreateRepeatMax(rdMaxCreateDates), style: RdType.meta(p, size: 13))
          else
            Text(l10n.redesignCreateRepeatTapHint, style: RdType.meta(p, size: 13)),
          const SizedBox(height: 14),
        ],
        RdGroupedList(children: [
          RdListRow(
            leading: const RdRowIcon(Icons.calendar_month_outlined),
            title: l10n.redesignCreateRepeatPick,
            onTap: _pickInCalendar,
          ),
        ]),
        const SizedBox(height: 16),
        RdPrimaryButton(
          label: l10n.redesignCommonDone,
          onPressed: chosen.isEmpty ? null : _done,
        ),
      ],
    );
  }
}

/// One day of "Weitere Daten". Tapping leaves it out or brings it back;
/// [added] marks a day picked on top of the rhythm.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.holiday,
    required this.skipped,
    required this.added,
    this.onTap,
  });

  final DateTime day;
  final String? holiday;
  final bool skipped;
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final label = DateFormat.MMMEd(currentIntlLocale()).format(day);
    final isHoliday = holiday != null;
    final fg = skipped ? p.text2 : (added ? p.softText : p.text);
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: EdgeInsets.fromLTRB(10, 5, onTap == null ? 10 : 6, 5),
      decoration: BoxDecoration(
        color: skipped
            ? Colors.transparent
            : isHoliday
                ? p.lateSoft
                : added
                    ? p.soft
                    : p.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isHoliday ? p.late : (added && !skipped ? p.primary : p.line)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isHoliday && !skipped ? '$label · ${l10n.redesignCreateRepeatHoliday}' : label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                decoration: skipped ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 3),
            Icon(skipped ? Icons.undo : Icons.close, size: 15, color: skipped ? p.text2 : fg),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: [
        label,
        if (isHoliday) holiday!,
        if (onTap != null) skipped ? l10n.redesignCreateRepeatChipRestore : l10n.redesignCreateRepeatChipSkip,
      ].join(', '),
      excludeSemantics: true,
      child: Tooltip(
        message: holiday ?? '',
        triggerMode: isHoliday ? TooltipTriggerMode.longPress : TooltipTriggerMode.manual,
        child: onTap == null
            ? chip
            : InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: chip),
      ),
    );
  }
}
