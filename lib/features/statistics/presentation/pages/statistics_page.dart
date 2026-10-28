import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart'; // UX_SETTINGS
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';

/// Statistics Page with Charts
///
/// Displays attendance statistics with various chart types:
/// - Trend line chart
/// - Status distribution pie chart
/// - Instrument/group bar chart
/// - Top 20 players chart
/// - Age distribution chart
/// - Average age per instrument chart
/// - "Diva Index" (unexcused absences) chart
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  bool _dateRangeInitialized = false;

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(statisticsDateRangeProvider);
    final attendancesAsync = ref.watch(filteredAttendancesForStatsProvider);
    final statistics = ref.watch(attendanceStatisticsProvider);

    // B6-011: Use season start as default if available
    if (!_dateRangeInitialized) {
      _dateRangeInitialized = true;
      final tenant = ref.read(currentTenantProvider);
      if (tenant?.seasonStart != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(statisticsDateRangeProvider.notifier)
              .resetToDefault(seasonStart: tenant!.seasonStart);
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statsTitle),
      ),
      // UX_SETTINGS: sections in Ionic order (stats.page.html); the period
      // ("📅 Zeitraum") is always visible so it can be changed when empty.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(filteredAttendancesForStatsProvider);
          ref.invalidate(activePlayersForStatsProvider);
          await ref.read(filteredAttendancesForStatsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context.l10n.statsPeriod),
              const SizedBox(height: AppDimensions.paddingS),
              _PeriodSection(
                dateRange: dateRange,
                onPick: (start, end) =>
                    ref.read(statisticsDateRangeProvider.notifier).setRange(start, end),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              ...attendancesAsync.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingXL),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (error, stack) => [Center(child: Text(context.l10n.attendanceFlutterErrorWith(error)))],
                data: (attendances) {
                  if (attendances.isEmpty) {
                    return [
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingXL),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.bar_chart, size: 64, color: AppColors.medium),
                              const SizedBox(height: 16),
                              Text(context.l10n.statsFlutterNoDataInPeriod),
                            ],
                          ),
                        ),
                      ),
                    ];
                  }
                  return [
                    _buildSectionTitle(context.l10n.statsOverview),
                    const SizedBox(height: AppDimensions.paddingS),
                    _SummaryCards(statistics: statistics),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _EventTypeOverview(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsTrend),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _TrendLineChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsStatusDistribution),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _StatusPieChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsTop20),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _TopPlayersChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsPerInstrument),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _InstrumentBarChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsUnexcused),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _DivaIndexChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsMembers),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _MembersOverview(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsAgeDistribution),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _AgeDistributionChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildSectionTitle(context.l10n.statsAvgAgeInstrument),
                    const SizedBox(height: AppDimensions.paddingS),
                    const _AvgAgePerInstrumentChart(),
                    const SizedBox(height: AppDimensions.paddingL),

                    // Organisation statistics (only shown if tenant has an org)
                    const _OrganisationStatsSection(),
                    const SizedBox(height: AppDimensions.paddingXL),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

}

/// Ionic "📅 Zeitraum": items "Von" / "Bis" with a date button each.
class _PeriodSection extends StatelessWidget {
  final StatisticsDateRange dateRange;
  final void Function(DateTime start, DateTime end) onPick;

  const _PeriodSection({required this.dateRange, required this.onPick});

  Future<void> _pick(BuildContext context, {required bool start}) async {
    final initial = start ? dateRange.start : dateRange.end;
    // Von ≤ Bis: "Von" ends at the current "Bis", "Bis" starts at "Von".
    final maxDate = DateTime.now().add(const Duration(days: 365 * 2));
    final upper = dateRange.end.isAfter(maxDate) ? dateRange.end : maxDate;
    final lower = DateTime(2000).isAfter(dateRange.start)
        ? dateRange.start
        : DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start ? lower : dateRange.start,
      lastDate: start ? dateRange.end : upper,
      locale: Locale(currentLanguage()),
    );
    if (picked == null) return;
    start ? onPick(picked, dateRange.end) : onPick(dateRange.start, picked);
  }

  @override
  Widget build(BuildContext context) {
    Widget item(String label, DateTime date, bool start) => ListTile(
          title: Text(label),
          trailing: ActionChip(
            label: Text(DateHelper.getShortDate(date)),
            onPressed: () => _pick(context, start: start),
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          item(context.l10n.dutyFrom, dateRange.start, true),
          const Divider(height: 1),
          item(context.l10n.dutyTo, dateRange.end, false),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AttendanceStatistics statistics;

  const _SummaryCards({required this.statistics});

  @override
  Widget build(BuildContext context) {
    final avgColor = statistics.averagePercentage >= 80
        ? AppColors.success
        : statistics.averagePercentage >= 50
            ? AppColors.warning
            : AppColors.danger;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: context.l10n.statsAvgAttendance,
                value: '${statistics.averagePercentage}%',
                color: avgColor,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: _StatCard(
                title: context.l10n.statsEventsInPeriod,
                value: '${statistics.totalAttendances}',
                color: AppColors.primary,
                icon: Icons.event,
              ),
            ),
          ],
        ),
        if (statistics.bestAttendance != null ||
            statistics.worstAttendance != null) ...[
          const SizedBox(height: AppDimensions.paddingM),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: context.l10n.statsBest,
                  value: '${statistics.bestAttendance?.percentage?.round() ?? 0}%',
                  color: AppColors.success,
                  icon: Icons.emoji_events,
                  subtitle: statistics.bestAttendance?.formattedDate,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: _StatCard(
                  title: context.l10n.statsWorst,
                  value: '${statistics.worstAttendance?.percentage?.round() ?? 0}%',
                  color: AppColors.danger,
                  icon: Icons.trending_down,
                  subtitle: statistics.worstAttendance?.formattedDate,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.medium,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.medium,
                      fontSize: 10,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ionic "👥 Mitglieder": Aktive Mitglieder / Pausierend / Ausgetreten / Gesamt.
class _MembersOverview extends ConsumerWidget {
  const _MembersOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = (ref.watch(playersProvider).valueOrNull ?? const <Person>[])
        .where((p) => p.left == null || p.left!.isEmpty)
        .toList();
    final left = ref.watch(archivedPlayersProvider).valueOrNull ?? const <Person>[];
    final active = current.where((p) => !p.paused).length;
    final paused = current.where((p) => p.paused).length;

    Widget row(String label, int count, Color color, {bool bold = false}) => ListTile(
          dense: true,
          title: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          row(context.l10n.statsActiveMembers, active, AppColors.success),
          row(context.l10n.statsPausing, paused, AppColors.warning),
          row(context.l10n.statsLeft, left.length, AppColors.medium),
          row(context.l10n.churchOverviewTotal, current.length + left.length, AppColors.primary, bold: true),
        ],
      ),
    );
  }
}

class _EventTypeOverview extends ConsumerWidget {
  const _EventTypeOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendancesAsync = ref.watch(filteredAttendancesForStatsProvider);
    final typesAsync = ref.watch(attendanceTypesProvider);

    final attendances = attendancesAsync.valueOrNull ?? [];
    final types = typesAsync.valueOrNull ?? [];

    if (attendances.isEmpty) return const _EmptyChartPlaceholder();

    // Group by typeId
    final Map<String, int> typeCounts = {};
    for (final a in attendances) {
      final typeId = a.typeId;
      if (typeId != null) {
        typeCounts[typeId] = (typeCounts[typeId] ?? 0) + 1;
      }
    }

    if (typeCounts.isEmpty) return const _EmptyChartPlaceholder();

    // Map typeId to name
    final typeNameMap = {for (final t in types) if (t.id != null) t.id!: t.name};
    final sorted = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          children: sorted.map((e) {
            final name = typeNameMap[e.key] ?? context.l10n.commonUnknown;
            final count = e.value;
            final fraction = count / attendances.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: fraction,
                      backgroundColor: AppColors.light,
                      color: AppColors.primary,
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TrendLineChart extends ConsumerWidget {
  const _TrendLineChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(trendChartDataProvider);

    if (data.values.isEmpty) {
      return const _EmptyChartPlaceholder();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (data.labels.length / 5).ceil().toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data.labels[index],
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: data.values.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value);
                  }).toList(),
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPieChart extends ConsumerWidget {
  const _StatusPieChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(attendanceStatisticsProvider);

    final total = statistics.presentCount +
        statistics.excusedCount +
        statistics.lateCount +
        statistics.absentCount;

    if (total == 0) {
      return const _EmptyChartPlaceholder();
    }

    final presentPct = (statistics.presentCount / total * 100).round();
    final excusedPct = (statistics.excusedCount / total * 100).round();
    final latePct = (statistics.lateCount / total * 100).round();
    final absentPct = (statistics.absentCount / total * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: statistics.presentCount.toDouble(),
                        color: AttendanceStatus.present.color,
                        title: '$presentPct%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: statistics.excusedCount.toDouble(),
                        color: AttendanceStatus.excused.color,
                        title: '$excusedPct%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: statistics.lateCount.toDouble(),
                        color: AttendanceStatus.late.color,
                        title: '$latePct%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: statistics.absentCount.toDouble(),
                        color: AttendanceStatus.absent.color,
                        title: '$absentPct%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(color: AttendanceStatus.present.color, label: context.l10n.commonStatusPresent),
                    _LegendItem(color: AttendanceStatus.excused.color, label: context.l10n.commonStatusExcused),
                    _LegendItem(color: AttendanceStatus.late.color, label: context.l10n.commonStatusLateShort),
                    _LegendItem(color: AttendanceStatus.absent.color, label: context.l10n.commonStatusAbsent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentBarChart extends ConsumerWidget {
  const _InstrumentBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(groupChartDataProvider);

    if (data.isEmpty) {
      return const _EmptyChartPlaceholder();
    }

    final chartHeight = (data.length * 30.0).clamp(150.0, 400.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].name}\n${rod.toY.round()}%',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 100,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          data[index].name,
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.percentage,
                      color: AppColors.primary,
                      width: 16,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ),
    );
  }
}

class _TopPlayersChart extends ConsumerWidget {
  const _TopPlayersChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(topPlayersChartDataProvider);

    if (data.isEmpty) {
      return const _EmptyChartPlaceholder();
    }

    final chartHeight = (data.length * 28.0).clamp(150.0, 560.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].name}\n${rod.toY.round()}%',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 90,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          data[index].name,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.percentage,
                      color: AppColors.success,
                      width: 14,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ),
    );
  }
}

class _AgeDistributionChart extends ConsumerWidget {
  const _AgeDistributionChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(ageDistributionProvider);

    if (data.isEmpty) {
      return _EmptyChartPlaceholder(message: context.l10n.statsFlutterNoBirthdays);
    }

    // BL-006: Use fold instead of reduce for safety
    final maxCount = data.map((e) => e.count).fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxCount.toDouble() + 2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].label} ${context.l10n.statsYears}\n${context.l10n.commonPersons(rod.toY.toInt())}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index].label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) return const SizedBox.shrink();
                      return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawHorizontalLine: true),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.count.toDouble(),
                      color: AppColors.secondary,
                      width: 24,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ),
    );
  }
}

class _AvgAgePerInstrumentChart extends ConsumerWidget {
  const _AvgAgePerInstrumentChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(avgAgePerInstrumentProvider);

    if (data.isEmpty) {
      return _EmptyChartPlaceholder(message: context.l10n.statsFlutterNoBirthdays);
    }

    // BL-006: Use fold instead of reduce for safety
    final maxAge = data.map((e) => e.percentage).fold(0.0, (a, b) => a > b ? a : b);
    final chartHeight = (data.length * 28.0).clamp(150.0, 400.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAge + 10,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].name}\nØ ${rod.toY.round()} ${context.l10n.statsYears}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 110,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          data[index].name,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.percentage,
                      color: AppColors.warning,
                      width: 14,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ),
    );
  }
}

class _DivaIndexChart extends ConsumerWidget {
  const _DivaIndexChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(divaIndexChartDataProvider);

    if (data.isEmpty) {
      return _EmptyChartPlaceholder(message: context.l10n.statsFlutterNoUnexcused);
    }

    // BL-006: Use fold instead of reduce for safety
    final maxAbsences = data.map((e) => e.percentage).fold(0.0, (a, b) => a > b ? a : b);
    final chartHeight = (data.length * 28.0).clamp(150.0, 420.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAbsences + 2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${data[groupIndex].name}\n${context.l10n.statsFlutterAbsencesCount(rod.toY.toInt())}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value != value.roundToDouble()) return const SizedBox.shrink();
                      return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 90,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          data[index].name,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.percentage,
                      color: AppColors.danger,
                      width: 14,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  final String? message;

  const _EmptyChartPlaceholder({this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 150,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart, size: 32, color: AppColors.medium),
            const SizedBox(height: 8),
            Text(
              message ?? context.l10n.statsFlutterNoData,
              style: TextStyle(color: AppColors.medium),
            ),
          ],
        ),
      ),
    );
  }
}

/// Organisation statistics section
/// Shows cross-tenant person analysis when the current tenant belongs to an organisation
class _OrganisationStatsSection extends ConsumerStatefulWidget {
  const _OrganisationStatsSection();

  @override
  ConsumerState<_OrganisationStatsSection> createState() =>
      _OrganisationStatsSectionState();
}

class _OrganisationStatsSectionState
    extends ConsumerState<_OrganisationStatsSection> {
  Set<int> _selectedTenantIds = {};
  bool _filterInitialized = false;

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(currentOrganisationProvider);

    return orgAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (org) {
        if (org == null) return const SizedBox.shrink();
        return _buildOrgSection(org);
      },
    );
  }

  Widget _buildOrgSection(Organisation organisation) {
    final tenantsAsync =
        ref.watch(organisationTenantsProvider(organisation.id!));

    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (tenants) {
        // Initialize filter with all tenants selected
        if (!_filterInitialized && tenants.isNotEmpty) {
          _selectedTenantIds =
              tenants.map((t) => t.id!).whereType<int>().toSet();
          _filterInitialized = true;
        }

        final filteredTenants = tenants
            .where((t) => t.id != null && _selectedTenantIds.contains(t.id))
            .toList();

        final personsAsync =
            ref.watch(organisationPersonsProvider(filteredTenants));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Text(
              context.l10n.statsFlutterOrganisation(organisation.name),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingS),

            // Tenant filter chips
            Wrap(
              spacing: AppDimensions.paddingS,
              runSpacing: AppDimensions.paddingXS,
              children: tenants.map((t) {
                final isSelected = _selectedTenantIds.contains(t.id);
                return FilterChip(
                  label: Text(t.shortName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTenantIds.add(t.id!);
                      } else if (_selectedTenantIds.length > 1) {
                        _selectedTenantIds.remove(t.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              _selectedTenantIds.length == tenants.length
                  ? context.l10n.statsAllCount(tenants.length)
                  : context.l10n.statsFlutterSelectedOf(_selectedTenantIds.length, tenants.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.medium,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Persons count + modal
            personsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(context.l10n.attendanceFlutterErrorWith(e)),
              data: (persons) {
                final uniquePersons =
                    _deduplicatePersons(persons, filteredTenants);

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.people, color: AppColors.primary),
                    title: Text(context.l10n.statsPersonsAllTenants),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${uniquePersons.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () =>
                        _showPersonsModal(uniquePersons, filteredTenants),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// De-duplicate persons across tenants (Ionic getOrganizationStats):
  /// key is global_person_id -> appId -> normalized name + birthday.
  List<_UniqueOrgPerson> _deduplicatePersons(
      List<Person> allPersons, List<Tenant> tenants) {
    final tenantMap = {for (final t in tenants) t.id: t};
    final byKey = <String, _UniqueOrgPerson>{};

    for (final person in allPersons) {
      final tenantName =
          tenantMap[person.tenantId]?.shortName ?? context.l10n.commonUnknown;
      final key = personIdentityKey(
        globalPersonId: person.globalPersonId,
        appId: person.appId,
        firstName: person.firstName,
        lastName: person.lastName,
        birthday: person.birthday,
      );
      final existing = byKey[key];
      if (existing != null) {
        existing.tenantNames.add(tenantName);
      } else {
        byKey[key] = _UniqueOrgPerson(
          person: person,
          tenantNames: {tenantName},
        );
      }
    }

    final all = byKey.values.toList();
    // Sort: most tenants first, then by name
    all.sort((a, b) {
      final cmp = b.tenantNames.length.compareTo(a.tenantNames.length);
      if (cmp != 0) return cmp;
      return a.person.lastName.compareTo(b.person.lastName);
    });
    return all;
  }

  void _showPersonsModal(
      List<_UniqueOrgPerson> persons, List<Tenant> tenants) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              ListTile(
                title: Text(
                  context.l10n.statsPersonsCount(persons.length),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    context.l10n.statsFlutterTenantsCount(tenants.length)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: persons.length,
                  itemBuilder: (context, index) {
                    final p = persons[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          p.person.initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(p.person.fullName),
                      subtitle: Text(p.tenantNames.join(', ')),
                      trailing: p.tenantNames.length > 1
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${p.tenantNames.length}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Represents a unique person across organisation tenants
class _UniqueOrgPerson {
  final Person person;
  final Set<String> tenantNames;

  _UniqueOrgPerson({required this.person, required this.tenantNames});
}
