import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/logic/words.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/duty_utils.dart' show weekdayShortNames;
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../people/presentation/pages/members_page.dart' show rdPercentColor;
import '../../data/stats_logic.dart';
import 'stats_figures.dart';
import 'stats_sheets.dart' show showRdStatsEventSheet;

/// One Register or Terminart: name (with an optional [meta] line), bar
/// and percentage (the percentage keeps one line, also "100 %"). [onTap]
/// narrows the Auswertung to it.
class RdStatsGroupRow extends StatelessWidget {
  const RdStatsGroupRow({super.key, required this.name, required this.percent, this.meta, this.onTap, this.valueText});

  final String name;
  final int percent;
  final String? meta;
  final VoidCallback? onTap;

  /// Shown instead of the percentage (bar length stays [percent]).
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: onTap == null ? 0 : 36),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: RdType.body(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (meta != null) Text(meta!, style: RdType.meta(p, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: p.primary,
                  backgroundColor: p.track,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  valueText ?? rdPercent(percent),
                  maxLines: 1,
                  softWrap: false,
                  style: RdType.body(p).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 20, color: p.text2),
          ],
        ),
      ),
    );
    return Semantics(
      label: [name, if (meta != null) meta!, valueText ?? rdPercent(percent)].join(', '),
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: onTap == null
          ? row
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row),
    );
  }
}

/// Label of an order of the Termine level.
String rdStatsSortLabel(AppLocalizations l10n, RdStatsEventSort sort) => switch (sort) {
      RdStatsEventSort.newest => l10n.rdStatsSortNewest,
      RdStatsEventSort.oldest => l10n.rdStatsSortOldest,
      RdStatsEventSort.weakest => l10n.rdStatsSortWeakest,
      RdStatsEventSort.best => l10n.rdStatsSortBest,
    };

/// Label of an order of the Personen level.
String rdStatsPersonSortLabel(AppLocalizations l10n, RdStatsPersonSort sort) => switch (sort) {
      RdStatsPersonSort.fewest => l10n.rdStatsPersonSortFewest,
      RdStatsPersonSort.most => l10n.rdStatsPersonSortMost,
      RdStatsPersonSort.absent => l10n.rdStatsPersonSortAbsent,
      RdStatsPersonSort.late => l10n.rdStatsPersonSortLate,
      RdStatsPersonSort.name => l10n.rdStatsPersonSortName,
    };

/// "Fällt auf": the people below 50 %, the Register that lost most
/// against the period before (else the weakest one), the weakest and the
/// best Termin. Each row leads on: the people, the Register as filter, the
/// Termin sheet. Nothing to show: nothing at all.
class RdStatsNotable extends StatelessWidget {
  const RdStatsNotable({
    super.key,
    required this.result,
    required this.previous,
    required this.groups,
    required this.onGroup,
    required this.onLow,
  });

  final RdStatsResult result;
  final RdStatsResult? previous;
  final List<Group> groups;

  /// Narrows the Auswertung to one Register.
  final ValueChanged<Group> onGroup;

  /// Shows the people below 50 % (Personen level, weakest first).
  final VoidCallback onLow;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final low = result.low();
    final drop = rdStatsBiggestDrop(result, previous);
    final weakGroup = drop == null && result.groups.length > 1 ? result.groups.last : null;
    final byPercent = rdSortStatsEvents(result.events, RdStatsEventSort.weakest);
    final weakest = byPercent.length > 1 ? byPercent.first : null;
    final best = byPercent.length > 1 && byPercent.last.percent > byPercent.first.percent ? byPercent.last : null;
    Widget pct(int v) => Text(
          rdPercent(v),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: rdPercentColor(p, v)),
        );
    final rows = <Widget>[
      if (low.isNotEmpty)
        RdListRow(
          key: const Key('rd-stats-notable-low'),
          leading: RdRowIcon(Icons.person_outline, color: p.absent, background: p.absentSoft),
          title: l10n.redesignStatsLow(low.length),
          subtitle: [for (final e in low.take(3)) rdPersonName(e.person)].join(', ') + (low.length > 3 ? ' …' : ''),
          onTap: onLow,
        ),
      if (drop != null)
        RdListRow(
          leading: RdRowIcon(Icons.trending_down, color: p.absent, background: p.absentSoft),
          title: l10n.rdStatsNotableDrop(drop.$1.group.name),
          subtitle: l10n.rdStatsNotableDropDetail(rdPercent(drop.$1.percent), rdPercent(drop.$1.percent + drop.$2)),
          onTap: () => onGroup(drop.$1.group),
        ),
      if (weakGroup != null)
        RdListRow(
          leading: const RdRowIcon(Icons.groups_outlined),
          title: l10n.rdStatsNotableWeakGroup(rdGroupKindOf(context), weakGroup.group.name),
          trailing: pct(weakGroup.percent),
          onTap: () => onGroup(weakGroup.group),
        ),
      if (weakest != null)
        RdListRow(
          leading: const RdRowIcon(Icons.south),
          title: l10n.rdStatsNotableWeakest,
          subtitle: '${rdStatsDay(weakest.date)} · ${rdStatsEventTitle(weakest)}',
          trailing: pct(weakest.percent),
          onTap: () => showRdStatsEventSheet(context, weakest, groups),
        ),
      if (best != null)
        RdListRow(
          leading: const RdRowIcon(Icons.north),
          title: l10n.rdStatsNotableBest,
          subtitle: '${rdStatsDay(best.date)} · ${rdStatsEventTitle(best)}',
          trailing: pct(best.percent),
          onTap: () => showRdStatsEventSheet(context, best, groups),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.rdStatsNotable),
        RdGroupedList(children: rows),
      ],
    );
  }
}

/// One Termin of the Termine level: day, title, who was missing, split
/// bar and percentage. [withDate] adds the date (lists not grouped by
/// month).
class RdStatsEventRow extends StatelessWidget {
  const RdStatsEventRow({super.key, required this.event, required this.onTap, this.withDate = false});

  final RdStatsEvent event;
  final VoidCallback onTap;
  final bool withDate;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final c = event.counts;
    final missing = [
      if (c.absent > 0) l10n.rdStatsCountAbsent(c.absent),
      if (c.excused > 0) l10n.rdStatsCountExcused(c.excused),
      if (c.late > 0) l10n.rdStatsCountLate(c.late),
      if (c.open > 0) l10n.rdStatsCountOpen(c.open),
    ];
    final d = event.date;
    return RdListRow(
      leading: RdDateTile(weekday: weekdayShortNames[d.weekday - 1], day: '${d.day}'),
      title: rdStatsEventTitle(event),
      subtitle: [
        if (withDate) DateFormat(dateFmt(DateFmtKind.short)).format(d),
        if (c.total > 0) missing.isEmpty ? l10n.rdStatsAllThere : missing.join(', '),
      ].join(' · '),
      footer: c.total > 0 ? RdStatsSplitBar(counts: c) : null,
      // Fixed width: the split bars of all rows end at the same place.
      trailing: SizedBox(
        width: 56,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            rdPercent(event.percent),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: rdPercentColor(p, event.percent),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
