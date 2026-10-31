import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extra_field_utils.dart';
import '../../../../core/utils/field_stats.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/display/ion_badge_text.dart';
import '../../../planning/presentation/widgets/ion_items.dart' show IonSelect;

/// Ionic 4.17.17 stats.page "🧩 Zusatzfelder": distribution of the select,
/// yes/no and church fields (tenant + organisation) as a donut chart and a
/// list with count and percent per option. Field and group selectable,
/// paused people optional; with all groups additionally a 100 % bar per
/// group. Hidden when there is no such field.
class FieldStatsSection extends ConsumerStatefulWidget {
  const FieldStatsSection({super.key, required this.header});

  /// The section title ("🧩 Zusatzfelder").
  final Widget header;

  @override
  ConsumerState<FieldStatsSection> createState() => _FieldStatsSectionState();
}

class _FieldStatsSectionState extends ConsumerState<FieldStatsSection> {
  String? _fieldId;

  /// 0 = all groups.
  int _groupId = 0;
  bool _includePaused = false;

  @override
  Widget build(BuildContext context) {
    final fields = distributionFields(ref.watch(personListExtraFieldsProvider));
    if (fields.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final field = fields.firstWhere(
      (f) => f.id == _fieldId,
      orElse: () => fields.first,
    );
    final personsAsync = ref.watch(fieldStatsPersonsProvider);
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final churches = fields.any((f) => f.type == ExtraFieldType.bfecgChurch)
        ? ref.watch(churchesProvider).valueOrNull ?? const <Church>[]
        : const <Church>[];

    final stats = computeFieldStats(
      field: field,
      persons: personsAsync.valueOrNull ?? const [],
      groups: groups,
      labels: FieldStatsLabels(
        yes: l10n.commonYes,
        no: l10n.commonNo,
        noValue: l10n.statsFieldNoValue,
      ),
      groupId: _groupId,
      includePaused: _includePaused,
      churches: churches,
    );

    final rows = <Widget>[
      IonSelect<String>(
        label: l10n.statsFieldSelect,
        value: field.id,
        items: [
          for (final f in fields)
            DropdownMenuItem(value: f.id, child: Text(f.name)),
        ],
        onChanged: (v) => setState(() => _fieldId = v),
      ),
      IonSelect<int>(
        label: l10n.statsFieldGroupFilter,
        value: stats.groupId,
        items: [
          DropdownMenuItem(value: 0, child: Text(l10n.statsFieldAllGroups)),
          for (final g in stats.groups)
            DropdownMenuItem(value: g.id!, child: Text(g.name)),
        ],
        onChanged: (v) => setState(() => _groupId = v ?? 0),
      ),
      SwitchListTile.adaptive(
        title: Text(l10n.statsFieldIncludePaused),
        value: _includePaused,
        onChanged: (v) => setState(() => _includePaused = v),
      ),
      if (!personsAsync.hasValue)
        const Padding(
          padding: EdgeInsets.all(AppDimensions.paddingM),
          child: Center(child: AppSpinner()),
        )
      else if (stats.total > 0) ...[
        _FieldDonut(field: field, stats: stats),
        for (final row in stats.rows) _FieldStatsRowTile(row: row),
        ListTile(
          title: Text(
            l10n.churchOverviewTotal,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: _Badge('${stats.total}'),
        ),
        if (stats.groupBars.length > 1)
          _GroupPercentBars(field: field, stats: stats),
      ] else
        ListTile(
          title: Text(
            l10n.statsFieldNoPersons,
            style: const TextStyle(color: AppColors.medium),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header,
        const SizedBox(height: AppDimensions.paddingS),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(height: 0.5, thickness: 0.5, indent: 16),
                rows[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingL),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: ionBadgeTextStyle(color: Colors.white, height: null)),
      );
}

/// Ionic doughnut chart with the field name as title.
class _FieldDonut extends StatelessWidget {
  const _FieldDonut({required this.field, required this.stats});

  final ExtraField field;
  final FieldStats stats;

  @override
  Widget build(BuildContext context) {
    final shown = stats.shownRows;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        children: [
          Text(
            field.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                sections: [
                  for (final r in shown)
                    PieChartSectionData(
                      value: r.count.toDouble(),
                      color: r.color,
                      // Small slices stay unlabelled (the list below has
                      // the numbers).
                      title: r.perc >= 8 ? '${r.perc}%' : '',
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
        ],
      ),
    );
  }
}

/// Ionic item: legend dot, option, "N Personen" note and "perc%" badge.
class _FieldStatsRowTile extends StatelessWidget {
  const _FieldStatsRowTile({required this.row});

  final FieldStatsRow row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: row.color, shape: BoxShape.circle),
      ),
      minLeadingWidth: 12,
      title: Text(row.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.commonPersons(row.count),
            style: const TextStyle(color: AppColors.medium),
          ),
          const SizedBox(width: 8),
          _Badge('${row.perc}%'),
        ],
      ),
    );
  }
}

/// Ionic horizontal 100 % stacked bar chart "{field} nach Gruppe (in %)".
class _GroupPercentBars extends StatelessWidget {
  const _GroupPercentBars({required this.field, required this.stats});

  final ExtraField field;
  final FieldStats stats;

  @override
  Widget build(BuildContext context) {
    final shown = stats.shownRows;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.statsFieldPerGroupChart(field.name),
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          for (final bar in stats.groupBars)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      bar.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 18,
                        child: Row(
                          children: [
                            for (final r in shown)
                              if ((bar.percByLabel[r.label] ?? 0) > 0)
                                Expanded(
                                  flex: bar.percByLabel[r.label]!,
                                  child: Tooltip(
                                    message:
                                        '${r.label}: ${bar.percByLabel[r.label]}%',
                                    child: Container(color: r.color),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppDimensions.paddingS),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final r in shown)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: r.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(r.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
