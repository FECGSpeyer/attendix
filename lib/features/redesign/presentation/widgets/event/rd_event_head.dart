import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/rd_dates.dart';
import '../../../data/rd_event_phase.dart';
import '../rd_widgets.dart';

/// REDESIGN (concept "Termin-Bereich neu", Schritt 2): the same head on
/// every Termin page, for the Leitung and for members: type and phase
/// pills, title, "So 29. Nov · 17:00–19:00 · Gedächtniskirche".
class RdEventHead extends StatelessWidget {
  const RdEventHead({
    super.key,
    required this.title,
    required this.phase,
    this.span,
    this.typeName,
    this.typeHighlight = false,
    this.timeRange = '',
    this.place = '',
    this.durationDays,
    this.now,
  });

  final String title;
  final RdEventPhase phase;
  final ({DateTime start, DateTime end, bool hasTime})? span;
  final String? typeName;

  /// Vortrag-like types (Termin-Art "hervorheben") get the blue pill.
  final bool typeHighlight;
  final String timeRange;
  final String place;
  final int? durationDays;

  /// For tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final pill = rdPhasePill(context.l10n, phase, span: span, now: now);
    final type = (typeName ?? '').trim();
    final showType = type.isNotEmpty && type != title;
    final meta = rdEventMeta(span?.start, durationDays: durationDays, timeRange: timeRange, place: place);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showType || pill != null) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (showType) RdPill(type, tone: typeHighlight ? RdTone.excused : RdTone.primary),
              if (pill != null) RdPill(pill.label, key: const Key('rd-event-phase'), tone: pill.tone),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Semantics(header: true, child: Text(title, style: RdType.title(p))),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meta, style: RdType.meta(p, size: 15)),
        ],
      ],
    );
  }
}

/// "So 29. Nov · 17:00–19:00 · Gedächtniskirche Speyer"; several days as
/// "Fr 27. Nov – So 29. Nov".
String rdEventMeta(DateTime? start, {int? durationDays, String timeRange = '', String place = ''}) {
  final locale = currentIntlLocale();
  String day(DateTime d) => '${DateFormat.E(locale).format(d).replaceAll('.', '')} ${DateFormat.MMMd(locale).format(d)}';
  final days = durationDays ?? 1;
  final date = start == null
      ? ''
      : days > 1
          ? '${day(start)} – ${day(rdAddDays(start, days - 1))}'
          : day(start);
  return [date, timeRange, place].where((s) => s.isNotEmpty).join(' · ');
}

/// Pill of the phase: "Morgen", "Heute 19:30", "Läuft · seit 19:30",
/// "Gestern", "Archiviert"; null on other days (the date says it).
({String label, RdTone? tone})? rdPhasePill(
  AppLocalizations l10n,
  RdEventPhase phase, {
  ({DateTime start, DateTime end, bool hasTime})? span,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final time = span == null || !span.hasTime ? null : DateFormat('HH:mm').format(span.start);
  switch (phase) {
    case RdEventPhase.archived:
      return (label: l10n.redesignEventPhaseArchived, tone: null);
    case RdEventPhase.running:
      return (
        label: time == null ? l10n.redesignEventPhaseRunningShort : l10n.redesignEventPhaseRunning(time),
        tone: RdTone.present,
      );
    case RdEventPhase.today:
      return (label: time == null ? l10n.redesignTodayDayToday : l10n.redesignEventPhaseToday(time), tone: RdTone.late);
    case RdEventPhase.before:
      if (span == null || rdDaysBetween(current, span.start) != 1) return null;
      return (label: l10n.redesignTodayDayTomorrow, tone: RdTone.late);
    case RdEventPhase.after:
      if (span == null) return null;
      final lastDay = span.end.subtract(const Duration(minutes: 1));
      if (rdDaysBetween(lastDay, current) != 1) return null;
      return (label: l10n.redesignEventPhaseYesterday, tone: null);
  }
}
