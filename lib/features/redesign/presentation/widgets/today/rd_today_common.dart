import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../l10n/l10n.dart';
import '../rd_widgets.dart';
import '../../../data/rd_dates.dart';

/// REDESIGN: shared pieces of the "Heute" cards.

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Heute", "Morgen" or "Do., 30. Okt.".
String rdRelativeDay(AppLocalizations l10n, DateTime start, {DateTime? now}) {
  final diff = rdDaysBetween(now ?? DateTime.now(), start);
  if (diff <= 0) return l10n.redesignTodayDayToday;
  if (diff == 1) return l10n.redesignTodayDayTomorrow;
  return DateFormat.MMMEd(currentIntlLocale()).format(start);
}

/// "in 3 Std." / "in 25 Min." for a start later today; "läuft" once it
/// started; null for other days or without a start time.
String? rdCountdown(
  AppLocalizations l10n,
  DateTime? start, {
  bool hasTime = true,
  DateTime? now,
}) {
  if (start == null || !hasTime) return null;
  final current = now ?? DateTime.now();
  if (_day(start) != _day(current)) return null;
  final diff = start.difference(current);
  if (diff.isNegative) return l10n.redesignTodayRunning;
  if (diff.inMinutes < 60) return l10n.redesignTodayInMinutes(diff.inMinutes.clamp(1, 59));
  return l10n.redesignTodayInHours((diff.inMinutes / 60).round());
}

/// Own answer as a pill ("Zugesagt", "Entschuldigt", "Offen").
RdPill rdOwnStatusPill(AppLocalizations l10n, AttendanceStatus status) {
  return switch (status) {
    AttendanceStatus.present =>
      RdPill(l10n.redesignStatusYes, tone: RdTone.present, icon: Icons.check),
    AttendanceStatus.late => RdPill(l10n.redesignStatusLate, tone: RdTone.late),
    AttendanceStatus.lateExcused =>
      RdPill(l10n.redesignStatusLater, tone: RdTone.late, icon: Icons.schedule),
    AttendanceStatus.excused => RdPill(l10n.redesignStatusExcused, tone: RdTone.excused),
    AttendanceStatus.absent => RdPill(l10n.redesignStatusAbsent, tone: RdTone.absent),
    AttendanceStatus.neutral => RdPill(l10n.redesignStatusOpen),
  };
}

/// Row of a Termin list ("Diese Woche", "Als Nächstes") with a date tile.
class RdEventRow extends StatelessWidget {
  const RdEventRow({
    super.key,
    required this.date,
    required this.title,
    this.meta = '',
    this.trailing,
    this.onTap,
    this.highlight = false,
  });

  final String? date;
  final String title;
  final String meta;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final day = EventListUtils.parse(date);
    final locale = currentIntlLocale();
    return RdListRow(
      leading: RdDateTile(
        weekday: day == null ? '' : DateFormat.E(locale).format(day).replaceAll('.', ''),
        day: day == null ? '–' : '${day.day}',
        highlight: highlight,
      ),
      title: title,
      subtitle: meta,
      trailing: trailing,
      onTap: onTap,
      showChevron: trailing == null,
    );
  }
}

/// Card for loading, empty and error states.
class RdInfoCard extends StatelessWidget {
  const RdInfoCard({
    super.key,
    required this.text,
    this.icon,
    this.loading = false,
    this.action,
  });

  final String text;
  final IconData? icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (icon != null)
                Icon(icon, color: p.text2),
              if (loading || icon != null) const SizedBox(width: 12),
              Expanded(child: Text(text, style: RdType.body(p).copyWith(color: p.text2))),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// Small text button in the section header ("Alle").
class RdLinkButton extends StatelessWidget {
  const RdLinkButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: p.link,
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

/// Date box of a Termin card; multi-day Termine show the range.
class RdEventDateBox extends StatelessWidget {
  const RdEventDateBox({super.key, required this.date, this.durationDays, this.highlight = false});

  final String? date;
  final int? durationDays;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final start = EventListUtils.parse(date);
    final locale = currentIntlLocale();
    String wd(DateTime d) => DateFormat.E(locale).format(d).replaceAll('.', '').toUpperCase();
    var top = start == null ? '' : wd(start);
    var bottom = start == null ? '–' : '${start.day}';
    final days = durationDays ?? 1;
    if (start != null && days > 1) {
      final end = rdAddDays(start, days - 1);
      top = '${wd(start)}–${wd(end)}';
      bottom = '${start.day}–${end.day}';
    }
    final fg = highlight ? p.softText : p.text;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? p.soft : p.track,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            top,
            maxLines: 1,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? fg : p.text2),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bottom,
              style: TextStyle(fontSize: days > 1 ? 16 : 20, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
