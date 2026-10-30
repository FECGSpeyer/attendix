import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show IonIos, IonSheetHeader, ionItemBackground;
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import '../../../../shared/widgets/display/ion_badge_text.dart';

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
/// PARITY_R5: Ionic settings `openStats()` presents the StatsPage with
/// `modalController.create({ component, presentingElement })`: on iOS a
/// card modal ([showIosCardModal]), in md mode a regular `ion-modal`
/// ([showIonModal]: full screen on phones, centred card on desktop).
Future<void> showStatisticsModal(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (useIosLook(context)) {
    return showIosCardModal<void>(
      context,
      backgroundColor: dark ? null : AppColors.light,
      builder: (_) => const StatisticsPage(asModal: true),
    );
  }
  return showIonModal<void>(
    context,
    builder: (_) => const StatisticsPage(asModal: true),
  );
}

/// Sections of the statistics page below "Zeitraum", in Ionic
/// stats.page.html order.
enum StatsSection {
  overview,
  trend,
  statusDistribution,
  top20,
  perInstrument,
  unexcused,

  /// Flutter empty / loading / error state for the Termin-dependent part.
  noData,
  members,
  ageDistribution,
  avgAgeInstrument,
  organisation,
}

/// ASTRA_TEACH_STATS: Ionic shows the attendance overview (with 0 Termine
/// and 0 %), members, demography and organisation regardless of the period;
/// only the attendance charts depend on Termine. Without Termine those
/// charts are replaced by the empty state, the rest keeps Ionic's order.
/// While the Termine are still loading (or failed), the overview is replaced
/// by the spinner / error as well, so no misleading "0" flashes.
List<StatsSection> statsSectionsFor({
  required bool hasAttendances,
  bool loaded = true,
}) =>
    [
      if (loaded) StatsSection.overview,
      if (hasAttendances) ...const [
        StatsSection.trend,
        StatsSection.statusDistribution,
        StatsSection.top20,
        StatsSection.perInstrument,
        StatsSection.unexcused,
      ] else
        StatsSection.noData,
      StatsSection.members,
      StatsSection.ageDistribution,
      StatsSection.avgAgeInstrument,
      StatsSection.organisation,
    ];

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key, this.asModal = false});

  /// Presented by [showStatisticsModal]: the ✕ closes the modal.
  final bool asModal;

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
      // P10_ATTENDANCE: always reset (Ionic falls back to 2023-01-01).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(statisticsDateRangeProvider.notifier)
            .resetToDefault(seasonStart: tenant?.seasonStart);
      });
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    // UX_ATT: Ionic opens the Statistik as a modal: light toolbar and page,
    // title + close (X) at the end, no back button.
    return Scaffold(
      backgroundColor: dark ? null : AppColors.light,
      appBar: AppBar(
        title: Text(context.l10n.statsTitle),
        automaticallyImplyLeading: false,
        backgroundColor: dark ? null : AppColors.light,
        // IOS_PAGES3: iOS → ✕ in a Liquid Glass circle (ion-buttons end)
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.commonClose,
              onPressed: () => widget.asModal
                  ? Navigator.of(context).pop()
                  : (context.canPop() ? context.pop() : context.go('/settings')),
            ),
          ]),
        ],
      ),
      // UX_SETTINGS: sections in Ionic order (stats.page.html); the period
      // ("📅 Zeitraum") is always visible so it can be changed when empty.
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(filteredAttendancesForStatsProvider);
          ref.invalidate(activePlayersForStatsProvider);
          await ref.read(filteredAttendancesForStatsProvider.future);
        },
        // IOS_PAGES3: every section is an Ionic `ion-list inset` >
        // `ion-item-group` (stats.page.scss: white / black groups): iOS
        // radius 28, md (md-ion-list-inset) radius 16, no shadow.
        child: Theme(
          data: Theme.of(context).copyWith(
            cardTheme: Theme.of(context).cardTheme.copyWith(
                  color: ionItemBackground(context),
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        useIosLook(context) ? IonIos.groupRadius : 16),
                  ),
                ),
          ),
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
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
              // ASTRA_TEACH_STATS: only the Termin-dependent sections are
              // replaced by the loading / error / empty state; members, age
              // charts and the organisation are always shown (Ionic
              // stats.page.html renders them independently of the period).
              for (final section in statsSectionsFor(
                hasAttendances:
                    attendancesAsync.valueOrNull?.isNotEmpty ?? false,
                loaded: attendancesAsync.hasValue,
              ))
                ..._buildSection(context, section, attendancesAsync, statistics),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => _StatsSectionTitle(title);

  List<Widget> _titled(String title, Widget child) => [
        _buildSectionTitle(title),
        const SizedBox(height: AppDimensions.paddingS),
        child,
        const SizedBox(height: AppDimensions.paddingL),
      ];

  List<Widget> _buildSection(
    BuildContext context,
    StatsSection section,
    AsyncValue<List<Attendance>> attendancesAsync,
    AttendanceStatistics statistics,
  ) {
    final l10n = context.l10n;
    switch (section) {
      case StatsSection.overview:
        return _titled(l10n.statsOverview, _OverviewList(statistics: statistics));
      case StatsSection.trend:
        return _titled(l10n.statsTrend, const _TrendLineChart());
      case StatsSection.statusDistribution:
        return _titled(l10n.statsStatusDistribution, const _StatusPieChart());
      case StatsSection.top20:
        return _titled(l10n.statsTop20, const _TopPlayersChart());
      case StatsSection.perInstrument:
        return _titled(l10n.statsPerInstrument, const _InstrumentBarChart());
      case StatsSection.unexcused:
        return _titled(l10n.statsUnexcused, const _DivaIndexChart());
      case StatsSection.noData:
        return [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXL),
            child: Center(
              child: attendancesAsync.when(
                loading: () => const AppSpinner(),
                error: (error, stack) => Text(l10n.attendanceFlutterErrorWith(
                    friendlyErrorMessage(error))),
                data: (_) => Column(
                  children: [
                    const Icon(Icons.bar_chart,
                        size: 64, color: AppColors.medium),
                    const SizedBox(height: 16),
                    Text(l10n.statsFlutterNoDataInPeriod),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
        ];
      case StatsSection.members:
        return _titled(l10n.statsMembers, const _MembersOverview());
      case StatsSection.ageDistribution:
        return _titled(l10n.statsAgeDistribution, const _AgeDistributionChart());
      case StatsSection.avgAgeInstrument:
        return _titled(
            l10n.statsAvgAgeInstrument, const _AvgAgePerInstrumentChart());
      case StatsSection.organisation:
        // Organisation statistics (only shown if tenant has an org)
        return const [
          _OrganisationStatsSection(),
          SizedBox(height: AppDimensions.paddingXL),
        ];
    }
  }

}

/// Ionic `ion-list-header` with plain text (no ion-label): iOS 22pt,
/// md 14pt; stats.page.scss sets font-weight 600 (IOS_PAGES3).
class _StatsSectionTitle extends StatelessWidget {
  const _StatsSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: ios ? 22 : 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// IOS_PAGES3: rows of an Ionic item group separated by inset hairlines.
List<Widget> _withInsetDividers(List<Widget> rows) => [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 16),
        rows[i],
      ],
    ];

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
    final picked = await showAppDatePicker(
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
    // UX_ATT: `ion-datetime-button`: grey rounded value button
    Widget item(String label, DateTime date, bool start) => ListTile(
          title: Text(label),
          trailing: _IonDatetimeButton(
            label: DateHelper.getShortDate(date),
            onTap: () => _pick(context, start: start),
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          item(context.l10n.dutyFrom, dateRange.start, true),
          const Divider(height: 0.5, thickness: 0.5, indent: 16),
          item(context.l10n.dutyTo, dateRange.end, false),
        ],
      ),
    );
  }
}

/// UX_ATT: Ionic `ion-badge` (iOS: radius 10, 3/8 padding, 13 px bold).
class _IonBadge extends StatelessWidget {
  const _IonBadge(this.text, {this.color = AppColors.primary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        // PARITY_R8: real bold (700) also on the web
        style: ionBadgeTextStyle(
          color: color == AppColors.warning ? Colors.black : Colors.white,
          height: null,
        ),
      ),
    );
  }
}

/// UX_ATT: Ionic `ion-datetime-button`.
class _IonDatetimeButton extends StatelessWidget {
  const _IonDatetimeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEEF0),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: const TextStyle(fontSize: 17)),
        ),
      ),
    );
  }
}

/// UX_ATT: Ionic "Übersicht" list: Termine im Zeitraum, one row per Termintyp
/// (type order, only types with Terminen), Ø Anwesenheit (≥70 success,
/// ≥50 warning, else danger), Beste / Schlechteste with date and %.
class _OverviewList extends ConsumerWidget {
  final AttendanceStatistics statistics;

  const _OverviewList({required this.statistics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendances = ref.watch(filteredAttendancesForStatsProvider).valueOrNull ?? const <Attendance>[];
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final avg = statistics.averagePercentage;
    final avgColor = avg >= 70
        ? AppColors.success
        : avg >= 50
            ? AppColors.warning
            : AppColors.danger;

    final rows = <Widget>[
      ListTile(
        title: Text(context.l10n.statsEventsInPeriod),
        trailing: _IonBadge('${attendances.length}'),
      ),
      for (final type in types)
        if (attendances.where((a) => a.typeId == type.id).isNotEmpty)
          ListTile(
            title: Text(type.name),
            trailing: _IonBadge('${attendances.where((a) => a.typeId == type.id).length}'),
          ),
      ListTile(
        title: Text(context.l10n.statsAvgAttendance),
        trailing: _IonBadge('$avg%', color: avgColor),
      ),
      if (statistics.bestAttendance != null)
        ListTile(
          title: Text(context.l10n.statsBest,
              style: const TextStyle(fontSize: 14, color: AppColors.medium)),
          subtitle: Text(statistics.bestAttendance!.formattedDate,
              style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onSurface)),
          trailing: _IonBadge('${statistics.bestAttendance!.percentage?.round() ?? 0}%',
              color: AppColors.success),
        ),
      if (statistics.worstAttendance != null)
        ListTile(
          title: Text(context.l10n.statsWorst,
              style: const TextStyle(fontSize: 14, color: AppColors.medium)),
          subtitle: Text(statistics.worstAttendance!.formattedDate,
              style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onSurface)),
          trailing: _IonBadge('${statistics.worstAttendance!.percentage?.round() ?? 0}%',
              color: AppColors.danger),
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 16),
            rows[i],
          ],
        ],
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
          title: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          trailing: _IonBadge('$count', color: color),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: _withInsetDividers([
          row(context.l10n.statsActiveMembers, active, AppColors.success),
          row(context.l10n.statsPausing, paused, AppColors.warning),
          row(context.l10n.statsLeft, left.length, AppColors.medium),
          row(context.l10n.churchOverviewTotal, current.length + left.length, AppColors.primary, bold: true),
        ]),
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
  /// Ionic `selectedInstances`: empty = all instances.
  Set<int> _selectedTenantIds = {};

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

  /// Ionic `ion-select multiple interface="modal"` "Instanzen filtern".
  Future<void> _pickTenants(List<Tenant> tenants) async {
    final selection = {..._selectedTenantIds};
    final result = await showAppDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(ctx.l10n.statsFilterTenants),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in tenants)
                  if (t.id != null)
                    CheckboxListTile(
                      title: Text(t.longName),
                      value: selection.contains(t.id),
                      onChanged: (v) => setLocal(() {
                        v == true ? selection.add(t.id!) : selection.remove(t.id);
                      }),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selection),
              child: Text(ctx.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selectedTenantIds = result);
  }

  Widget _buildOrgSection(Organisation organisation) {
    final tenantsAsync =
        ref.watch(organisationTenantsProvider(organisation.id!));

    return tenantsAsync.when(
      loading: () => const Center(child: AppSpinner()),
      error: (_, __) => const SizedBox.shrink(),
      data: (tenants) {
        final l10n = context.l10n;
        // IOS_PAGES3: load all persons once (stable family key = the
        // provider's tenant list) and filter locally like Ionic
        // `filterInstances()`.
        final personsAsync = ref.watch(organisationPersonsProvider(tenants));
        final selected = _selectedTenantIds;
        final persons = (personsAsync.valueOrNull ?? const <Person>[])
            .where((p) => selected.isEmpty || selected.contains(p.tenantId))
            .toList();
        final uniquePersons = _deduplicatePersons(persons, tenants);
        final selectedNames = [
          for (final t in tenants)
            if (selected.contains(t.id)) t.longName,
        ].join(', ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // UX_ATT: Ionic list header "🏢 {name}"
            _StatsSectionTitle('🏢 ${organisation.name}'),
            const SizedBox(height: AppDimensions.paddingS),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: _withInsetDividers([
                  ListTile(
                    title: Text(l10n.statsFilterTenants),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selectedNames.isNotEmpty)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                            ),
                            child: Text(
                              selectedNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(width: 4),
                        const IonSelectIcon(),
                      ],
                    ),
                    onTap: () => _pickTenants(tenants),
                  ),
                  ListTile(
                    title: Text(l10n.statsTenants),
                    trailing: _IonBadge(selected.isEmpty
                        ? l10n.statsAllCount(tenants.length)
                        : '${selected.length}'),
                    onTap: () => DialogHelper.showAlert(
                      context,
                      title: l10n.statsOrgTenants,
                      message: tenants.map((t) => t.longName).join(', '),
                    ),
                  ),
                  ListTile(
                    title: Text(l10n.statsPersonsAllTenants),
                    trailing: personsAsync.isLoading && !personsAsync.hasValue
                        ? const SizedBox(width: 18, height: 18, child: AppSpinner(strokeWidth: 2))
                        : _IonBadge('${uniquePersons.length}'),
                    onTap: () => _showPersonsModal(uniquePersons),
                  ),
                ]),
              ),
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
      // Ionic persons modal: one `<p>` per instance with its long name.
      final tenantName =
          tenantMap[person.tenantId]?.longName ?? context.l10n.commonUnknown;
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

  /// Ionic persons modal (sheet, breakpoint 1): toolbar "Personen (n)",
  /// inset list with the name, one line per instance and a badge with the
  /// number of instances.
  void _showPersonsModal(List<_UniqueOrgPerson> persons) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 1,
        child: Column(
          children: [
            IonSheetHeader(title: context.l10n.statsPersonsCount(persons.length)),
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    if (persons.isNotEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        color: ionItemBackground(context),
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              useIosLook(context) ? IonIos.listRadius : 16),
                        ),
                        child: Column(
                          children: _withInsetDividers([
                            for (final p in persons)
                              ListTile(
                                title: Text(p.person.fullName),
                                subtitle: Text(p.tenantNames.join('\n')),
                                trailing: _IonBadge('${p.tenantNames.length}'),
                              ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
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
