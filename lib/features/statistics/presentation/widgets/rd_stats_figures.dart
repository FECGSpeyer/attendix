import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/duty_utils.dart' show weekdayShortNames;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/data/providers/rd_today_providers.dart' show rdEventInfo;
import '../../data/rd_stats_logic.dart';

/// "73 %" with a no-break space, so the sign never wraps on its own.
String rdPercent(int value) => '$value\u00A0%';

/// "Do 16.10." of a Termin.
String rdStatsDay(DateTime date) =>
    '${weekdayShortNames[date.weekday - 1]} ${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(date)}';

/// Title of a Termin in the Auswertung ("Probe" or its own title).
String rdStatsEventTitle(RdStatsEvent e) => rdEventInfo(e.attendance, e.type).title;

/// One key figure ("Ø Anwesenheit 73 %"), optionally with the change
/// against the period before ([delta] in percentage points).
class RdStatsFigure extends StatelessWidget {
  const RdStatsFigure({super.key, required this.label, required this.value, this.delta});

  final String label;
  final String value;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final d = delta;
    final deltaText = d == null
        ? null
        : (d > 0 ? l10n.rdStatsDeltaUp(d) : (d < 0 ? l10n.rdStatsDeltaDown(-d) : l10n.rdStatsDeltaSame));
    final deltaLong = d == null
        ? null
        : (d > 0 ? l10n.rdStatsDeltaUpLong(d) : (d < 0 ? l10n.rdStatsDeltaDownLong(-d) : l10n.rdStatsDeltaSameLong));
    return RdCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Semantics(
        label: ['$label: $value', if (deltaLong != null) deltaLong].join(', '),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: RdType.meta(p, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (deltaText != null)
              Text(
                deltaText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: d! > 0 ? p.present : (d < 0 ? p.absent : p.text2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Column chart, one bar per Termin (oldest left); the weakest bar is
/// darker. A bar reads its day, title and percentage and opens the Termin.
class RdStatsBars extends StatelessWidget {
  const RdStatsBars({super.key, required this.events, required this.onTap});

  final List<RdStatsEvent> events;
  final ValueChanged<RdStatsEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    var lowest = 0;
    for (var i = 1; i < events.length; i++) {
      if (events[i].percent < events[lowest].percent) lowest = i;
    }
    String label(RdStatsEvent e) => l10n.rdStatsBar(rdStatsDay(e.date), rdStatsEventTitle(e), e.percent);
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < events.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: label(events[i]),
                    onTap: () => onTap(events[i]),
                    excludeSemantics: true,
                    child: Tooltip(
                      message: label(events[i]),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(events[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: FractionallySizedBox(
                            heightFactor: (events[i].percent / 100).clamp(0.02, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i == lowest ? p.softText : p.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: p.line),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rdStatsDay(events.first.date), style: RdType.meta(p, size: 11)),
            Text(rdStatsDay(events.last.date), style: RdType.meta(p, size: 11)),
          ],
        ),
      ],
    );
  }
}

/// Segments of [counts] in the order Anwesend, Verspätet, Entschuldigt,
/// Abwesend, Neutral.
List<(String, int, Color)> rdStatsSplit(BuildContext context, RdStatsCounts counts) {
  final p = context.rd;
  final l10n = context.l10n;
  return [
    (l10n.commonStatusPresent, counts.present, p.present),
    (l10n.commonStatusLateShort, counts.late, p.late),
    (l10n.commonStatusExcused, counts.excused, p.excused),
    (l10n.commonStatusAbsent, counts.absent, p.absent),
    (l10n.commonStatusNeutral, counts.open, p.text2),
  ];
}

/// Thin bar with the share of each status of [counts].
class RdStatsSplitBar extends StatelessWidget {
  const RdStatsSplitBar({super.key, required this.counts});

  final RdStatsCounts counts;

  @override
  Widget build(BuildContext context) {
    final split = rdStatsSplit(context, counts);
    return RdStatusBar(
      segments: [for (final (_, n, color) in split) RdBarSegment(n, color)],
      total: counts.total,
      semanticLabel: [
        for (final (label, n, _) in split)
          if (n > 0) '$label ${rdPercent(_share(n, counts.total))}',
      ].join(', '),
    );
  }
}

int _share(int n, int total) => total == 0 ? 0 : (n * 100 / total).round();

/// "Statusverteilung": how all counted entries of the period split up.
class RdStatsSplitCard extends StatelessWidget {
  const RdStatsSplitCard({super.key, required this.counts});

  final RdStatsCounts counts;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rdStatsSplit, style: RdType.section(p)),
          const SizedBox(height: 10),
          RdStatsSplitBar(counts: counts),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (label, n, color) in rdStatsSplit(context, counts))
                  if (n > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$label ${rdPercent(_share(n, counts.total))}', style: RdType.meta(p, size: 13)),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
