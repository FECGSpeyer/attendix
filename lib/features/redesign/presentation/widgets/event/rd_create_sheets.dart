import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/services/holiday_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/color_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker;
import '../../../data/rd_create_logic.dart';
import '../rd_widgets.dart';

/// REDESIGN: sheets of "Termin anlegen" (Art, Abmeldeschluss, weitere
/// Daten).

Future<T?> _showRdSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.rd.bg,
    builder: (_) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: child,
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Semantics(header: true, child: Text(text, style: RdType.cardTitle(context.rd))),
      );
}

Widget _check(BuildContext context, bool selected) =>
    selected ? Icon(Icons.check, size: 22, color: context.rd.primary) : const SizedBox(width: 22);

/// Picks the Art of the new Termin.
Future<AttendanceType?> showRdTypePicker(
  BuildContext context, {
  required List<AttendanceType> types,
  AttendanceType? selected,
}) {
  return _showRdSheet<AttendanceType>(
    context,
    Builder(builder: (context) {
      final l10n = context.l10n;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          _SheetTitle(l10n.redesignCreateChooseType),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RdGroupedList(children: [
              for (final t in types)
                RdListRow(
                  leading: Icon(Icons.circle, size: 14, color: ColorUtils.parseNamedColor(t.color)),
                  title: t.name,
                  selected: t.id == selected?.id,
                  showChevron: false,
                  trailing: _check(context, t.id == selected?.id),
                  onTap: () => Navigator.of(context).pop(t),
                ),
            ]),
          ),
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
    };

/// Picks the Abmeldeschluss (relative to each Termin).
Future<RdDeadline?> showRdDeadlinePicker(BuildContext context, RdDeadline selected) {
  return _showRdSheet<RdDeadline>(
    context,
    Builder(builder: (context) {
      final l10n = context.l10n;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        children: [
          _SheetTitle(l10n.redesignCreateDeadline),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RdGroupedList(children: [
              for (final d in RdDeadline.values)
                RdListRow(
                  title: rdDeadlineLabel(l10n, d),
                  selected: d == selected,
                  showChevron: false,
                  trailing: _check(context, d == selected),
                  onTap: () => Navigator.of(context).pop(d),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(l10n.redesignCreateDeadlineHint, style: RdType.meta(context.rd, size: 13)),
          ),
        ],
      );
    }),
  );
}

/// Result of the "Weitere Daten" sheet. [custom] is set when the days are
/// picked one by one in the calendar instead.
typedef RdRepeatChoice = ({RdRepeat repeat, DateTime until, bool skipHolidays, bool custom});

/// "Weitere Daten": once, every week or every two weeks until a day, with
/// a preview of the dates (holidays marked, optionally left out).
Future<RdRepeatChoice?> showRdRepeatSheet(
  BuildContext context, {
  required DateTime start,
  required RdRepeat repeat,
  required DateTime until,
  required bool skipHolidays,
  required HolidayData holidays,
}) {
  return _showRdSheet<RdRepeatChoice>(
    context,
    _RepeatSheet(
      start: start,
      repeat: repeat == RdRepeat.custom ? RdRepeat.once : repeat,
      until: until,
      skipHolidays: skipHolidays,
      holidays: holidays,
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
  });

  final DateTime start;
  final RdRepeat repeat;
  final DateTime until;
  final bool skipHolidays;
  final HolidayData holidays;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late RdRepeat _repeat = widget.repeat;
  late DateTime _until = widget.until;
  late bool _skip = widget.skipHolidays;

  bool get _hasHolidays =>
      widget.holidays.publicHolidays.isNotEmpty || widget.holidays.schoolHolidays.isNotEmpty;

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

  void _done({bool custom = false}) => Navigator.of(context).pop((
        repeat: _repeat,
        until: _until,
        skipHolidays: _skip,
        custom: custom,
      ));

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final repeating = _repeat != RdRepeat.once;
    final all = repeating
        ? rdRepeatDates(widget.start, _until, everyWeeks: _repeat == RdRepeat.biweekly ? 2 : 1)
        : [rdDay(widget.start)];
    final kept = _skip ? all.where((d) => rdHolidayOn(widget.holidays, d) == null).toList() : all;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _SheetTitle(l10n.redesignCreateMoreDates),
        RdSegmented<RdRepeat>(
          values: const [RdRepeat.once, RdRepeat.weekly, RdRepeat.biweekly],
          selected: _repeat,
          labelOf: (r) => switch (r) {
            RdRepeat.weekly => l10n.redesignCreateRepeatWeeklyOption,
            RdRepeat.biweekly => l10n.redesignCreateRepeatBiweeklyOption,
            _ => l10n.redesignCreateRepeatOnce,
          },
          onChanged: (r) => setState(() => _repeat = r),
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
              ),
          ]),
          const SizedBox(height: 14),
          Text(l10n.redesignCreateRepeatCount(kept.length), style: RdType.section(p)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in all) _DateChip(day: d, holiday: rdHolidayOn(widget.holidays, d), skipped: !kept.contains(d)),
            ],
          ),
          if (all.length >= rdMaxCreateDates) ...[
            const SizedBox(height: 8),
            Text(l10n.redesignCreateRepeatMax(rdMaxCreateDates), style: RdType.meta(p, size: 13)),
          ],
          const SizedBox(height: 14),
        ],
        RdGroupedList(children: [
          RdListRow(
            leading: const RdRowIcon(Icons.calendar_month_outlined),
            title: l10n.redesignCreateRepeatPick,
            onTap: () => _done(custom: true),
          ),
        ]),
        const SizedBox(height: 16),
        RdPrimaryButton(
          label: l10n.redesignCommonDone,
          onPressed: kept.isEmpty ? null : _done,
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.day, required this.holiday, required this.skipped});

  final DateTime day;
  final String? holiday;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final label = DateFormat.MMMEd(currentIntlLocale()).format(day);
    final isHoliday = holiday != null;
    return Semantics(
      label: [label, if (isHoliday) holiday!].join(', '),
      excludeSemantics: true,
      child: Tooltip(
        message: holiday ?? '',
        triggerMode: isHoliday ? TooltipTriggerMode.tap : TooltipTriggerMode.manual,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isHoliday ? p.lateSoft : p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: isHoliday ? p.late : p.line),
          ),
          child: Text(
            isHoliday && !skipped ? '$label · ${l10n.redesignCreateRepeatHoliday}' : label,
            style: TextStyle(
              fontSize: 13,
              color: skipped ? p.text2 : p.text,
              decoration: skipped ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}
