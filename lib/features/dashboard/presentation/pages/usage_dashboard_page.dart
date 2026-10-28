import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/dashboard/dashboard_models.dart';

const _palette = [
  Color(0xFF2DD36F), Color(0xFF3880FF), Color(0xFFFFC409), Color(0xFFEB445A),
  Color(0xFF5260FF), Color(0xFFFF9F0A), Color(0xFF36A2EB), Color(0xFF9966FF),
  Color(0xFF4BC0C0), Color(0xFFFF9F40), Color(0xFFC9CBCF), Color(0xFFAAFF80),
];

const _deviceColors = {
  'ios': Color(0xFFA2AAAD),
  'android': Color(0xFF3DDC84),
  'web': Color(0xFF3880FF),
  'unknown': Color(0xFFC9CBCF),
};

/// Fills the per-day series with zeros for every day of the range
/// (Ionic `buildCharts`). Returns (label "dd.MM.", count) oldest first.
List<(String, int)> fillUsagePerDay(List<UsageCount> perDay, int days, {DateTime? now}) {
  final today = now ?? DateTime.now();
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final counts = {for (final r in perDay) r.label.length >= 10 ? r.label.substring(0, 10) : r.label: r.count};
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
        return (
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.',
          counts[key(d)] ?? 0,
        );
      }(),
  ];
}

/// Super-developer usage analytics (Ionic `dashboard/`).
class UsageDashboardPage extends ConsumerWidget {
  const UsageDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(usageDashboardRangeProvider);
    final async = ref.watch(usageDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Dashboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 Tage')),
                ButtonSegment(value: 30, label: Text('30 Tage')),
                ButtonSegment(value: 90, label: Text('90 Tage')),
              ],
              selected: {range},
              onSelectionChanged: (s) =>
                  ref.read(usageDashboardRangeProvider.notifier).state = s.first,
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _empty(),
        data: (data) {
          if (data.kpis.totalEvents <= 0) return _empty();
          return _content(context, data, range);
        },
      ),
    );
  }

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: AppColors.medium),
              SizedBox(height: 12),
              Text(
                'Keine Events im gewählten Zeitraum.',
                style: TextStyle(color: AppColors.medium),
              ),
            ],
          ),
        ),
      );

  Widget _content(BuildContext context, UsageDashboardData data, int range) {
    final topNames = data.byName.take(10).toList();
    final topTenants = data.byTenant.take(10).toList();
    final perDay = fillUsagePerDay(data.perDay, range);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 768 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.9,
          children: [
            _Kpi('Events gesamt', '${data.kpis.totalEvents}'),
            _Kpi('Aktive Instanzen', '${data.kpis.distinctTenants}'),
            _Kpi('Aktiv (7T)', '${data.kpis.activeTenants7d}'),
            _Kpi('Top Event', topNames.isNotEmpty ? topNames.first.label : '—', small: true),
          ],
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Events pro Tag',
          height: 280,
          child: LineChart(
            LineChartData(
              minY: 0,
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: math.max(1, (perDay.length / 6).ceil()).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= perDay.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(perDay[i].$1, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < perDay.length; i++)
                      FlSpot(i.toDouble(), perDay[i].$2.toDouble()),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: _palette[1],
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: _palette[1].withAlpha((0.2 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
        ),
        _ChartCard(
          title: 'Top Events',
          height: 36.0 * math.max(topNames.length, 1) + 16,
          child: _HorizontalBars(rows: topNames),
        ),
        _ChartCard(
          title: 'Top Instanzen',
          height: 280,
          child: BarChart(
            BarChartData(
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= topTenants.length) return const SizedBox.shrink();
                      return Text('#${topTenants[i].label}', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < topTenants.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: topTenants[i].count.toDouble(),
                      color: _palette[i % _palette.length],
                      width: 18,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ]),
              ],
            ),
          ),
        ),
        _ChartCard(
          title: 'Event-Verteilung',
          height: 320,
          child: _Doughnut(
            rows: topNames,
            colorFor: (i, _) => _palette[i % _palette.length],
          ),
        ),
        _ChartCard(
          title: 'Geräte',
          height: 280,
          child: _Doughnut(
            rows: data.byDevice,
            colorFor: (_, label) => _deviceColors[label] ?? const Color(0xFF999999),
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.small = false});

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.medium)),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: small ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: small ? 14 : 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.height, required this.child});

  final String title;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(height: height, child: child),
            ],
          ),
        ),
      );
}

/// Horizontal bar list (Ionic bar chart with `indexAxis: 'y'`).
class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({required this.rows});

  final List<UsageCount> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) => math.max(m, r.count));
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          SizedBox(
            height: 36,
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    rows[i].label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 20,
                        width: c.maxWidth * rows[i].count / max,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${rows[i].count}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Doughnut extends StatelessWidget {
  const _Doughnut({required this.rows, required this.colorFor});

  final List<UsageCount> rows;
  final Color Function(int index, String label) colorFor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 50,
              sectionsSpace: 1,
              sections: [
                for (var i = 0; i < rows.length; i++)
                  PieChartSectionData(
                    value: rows[i].count.toDouble(),
                    color: colorFor(i, rows[i].label),
                    title: '',
                    radius: 40,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, color: colorFor(i, rows[i].label)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${rows[i].label} (${rows[i].count})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
