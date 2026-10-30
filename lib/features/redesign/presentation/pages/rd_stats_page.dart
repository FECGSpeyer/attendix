import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../export/presentation/pages/export_page.dart' show showExportModal;
import '../../data/rd_stats_logic.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: Verwaltung › Auswertung (canvas "Statistik"): range chips,
/// three key figures, attendance per Termin, per Register and the people
/// below 50 %. Uses the providers of the old statistics page.
class RdStatsPage extends ConsumerStatefulWidget {
  const RdStatsPage({super.key});

  @override
  ConsumerState<RdStatsPage> createState() => _RdStatsPageState();
}

class _RdStatsPageState extends ConsumerState<RdStatsPage> {
  RdStatsRange _range = RdStatsRange.season;

  @override
  void initState() {
    super.initState();
    // The range provider is shared with the old statistics page; start
    // from the season like Ionic.
    WidgetsBinding.instance.addPostFrameCallback((_) => _setRange(_range));
  }

  void _setRange(RdStatsRange range) {
    if (!mounted) return;
    setState(() => _range = range);
    final now = DateTime.now();
    final start = rdStatsRangeStart(range, now,
        seasonStart: ref.read(currentTenantProvider)?.seasonStart);
    ref.read(statisticsDateRangeProvider.notifier).setRange(start, now);
  }

  Future<void> _refresh() async {
    ref.invalidate(filteredAttendancesForStatsProvider);
    ref.invalidate(activePlayersForStatsProvider);
    await ref.read(filteredAttendancesForStatsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final attendancesAsync = ref.watch(filteredAttendancesForStatsProvider);
    final stats = ref.watch(attendanceStatisticsProvider);
    final trend = ref.watch(trendChartDataProvider);
    final groups = ref.watch(groupChartDataProvider);
    final players = ref.watch(activePlayersForStatsProvider).valueOrNull ?? const [];
    final low = rdLowAttendance(
      ref.watch(allPersonAttendancesForStatsProvider).valueOrNull ?? const [],
      players,
    );

    return RdPage(
      onRefresh: _refresh,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: RdBackLink(
                  label: l10n.redesignAdminTitle,
                  onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
                ),
              ),
            ),
            RdTextLink(label: l10n.settingsExport, onTap: () => showExportModal(context)),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.redesignStatsTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in RdStatsRange.values)
              RdChoiceChip(
                label: switch (r) {
                  RdStatsRange.season => l10n.redesignStatsRangeSeason,
                  RdStatsRange.threeMonths => l10n.redesignStatsRange3m,
                  RdStatsRange.twelveMonths => l10n.redesignStatsRange12m,
                },
                selected: r == _range,
                onTap: () => _setRange(r),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (attendancesAsync.isLoading && !attendancesAsync.hasValue)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: p.primary)),
          )
        else if (attendancesAsync.hasError)
          RdCard(child: Text(l10n.redesignStatsLoadFailed, style: RdType.body(p)))
        else if (stats.totalAttendances == 0)
          RdCard(child: Text(l10n.redesignStatsEmpty, style: RdType.body(p)))
        else ...[
          Row(
            children: [
              Expanded(child: _Figure(label: l10n.redesignStatsAvg, value: '${stats.averagePercentage} %')),
              const SizedBox(width: 8),
              Expanded(child: _Figure(label: l10n.redesignStatsEvents, value: '${stats.totalAttendances}')),
              const SizedBox(width: 8),
              Expanded(child: _Figure(label: l10n.redesignStatsMembers, value: '${players.length}')),
            ],
          ),
          const SizedBox(height: 12),
          if (trend.values.isNotEmpty)
            RdCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.redesignStatsPerEvent, style: RdType.section(p)),
                  Text(l10n.redesignStatsPerEventHint(trend.values.length), style: RdType.meta(p, size: 13)),
                  const SizedBox(height: 14),
                  _Bars(labels: trend.labels, values: trend.values),
                ],
              ),
            ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            RdCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.redesignStatsPerGroup, style: RdType.section(p)),
                  const SizedBox(height: 10),
                  for (final g in groups) _GroupRow(name: g.name, percent: g.percentage),
                ],
              ),
            ),
          ],
          if (low.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LowCard(low: low),
          ],
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Semantics(
        label: '$label: $value',
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
          ],
        ),
      ),
    );
  }
}

/// Column chart, one bar per Termin; the lowest bar is darker. Each bar
/// reads its date and percentage to screen readers.
class _Bars extends StatelessWidget {
  const _Bars({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    var lowest = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] < values[lowest]) lowest = i;
    }
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Semantics(
                    label: l10n.redesignStatsBar(labels[i], values[i].round()),
                    excludeSemantics: true,
                    child: Tooltip(
                      message: l10n.redesignStatsBar(labels[i], values[i].round()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: FractionallySizedBox(
                          heightFactor: (values[i] / 100).clamp(0.02, 1.0),
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
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: p.line),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labels.first, style: RdType.meta(p, size: 11)),
            Text(labels.last, style: RdType.meta(p, size: 11)),
          ],
        ),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.name, required this.percent});

  final String name;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final value = percent.round();
    return Semantics(
      label: '$name: $value %',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(name, style: RdType.body(p), maxLines: 1, overflow: TextOverflow.ellipsis),
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
              width: 44,
              child: Text('$value %', textAlign: TextAlign.end, style: RdType.body(p)),
            ),
          ],
        ),
      ),
    );
  }
}

/// People below 50 %; each name opens the person.
class _LowCard extends StatelessWidget {
  const _LowCard({required this.low});

  final List<RdLowAttendance> low;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdCard(
      color: p.absentSoft,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: p.absent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.redesignStatsLow(low.length),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                  ),
                ),
              ],
            ),
          ),
          for (final entry in low)
            InkWell(
              onTap: entry.person.id == null
                  ? null
                  : () => context.push(RedesignRoutes.person(entry.person.id!)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.person.firstName} ${entry.person.lastName}'.trim(),
                          style: RdType.body(p),
                        ),
                      ),
                      Text('${entry.percent} %', style: RdType.meta(p, size: 14)),
                      Icon(Icons.chevron_right, size: 20, color: p.text2),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
