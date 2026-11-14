import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../data/models/church/church.dart';
import '../../../features/planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../features/redesign/presentation/widgets/rd_widgets.dart';
import '../../../l10n/l10n.dart';
import '../layout/ionic_ios.dart' as ios27
    show IonInsetList, IonItem, IonListHeader;
import '../../../features/people/presentation/widgets/ion/ion_widgets.dart'
    show IonBadge, ionLightColor;

/// One church with its number of persons.
class ChurchCount {
  const ChurchCount({required this.name, required this.count});

  final String name;
  final int count;
}

/// Result of [computeChurchOverview].
class ChurchOverviewData {
  const ChurchOverviewData({
    required this.total,
    required this.withoutChurch,
    required this.churchCounts,
  });

  final int total;
  final int withoutChurch;
  final List<ChurchCount> churchCounts;
}

/// Counts persons per Gemeinde (Ionic ChurchOverviewComponent).
///
/// [churchIds] holds the value of the `bfecg_church` extra field per person
/// (null/empty = "Ohne Gemeinde"). Sorted by count desc, then name.
ChurchOverviewData computeChurchOverview(
  Iterable<String?> churchIds,
  List<Church> churches,
) {
  final countMap = <String, int>{};
  var total = 0;
  var without = 0;
  for (final id in churchIds) {
    total++;
    if (id == null || id.isEmpty) {
      without++;
      continue;
    }
    countMap[id] = (countMap[id] ?? 0) + 1;
  }
  final counts = countMap.entries
      .map((e) => ChurchCount(
            name: churches.where((c) => c.id == e.key).firstOrNull?.name ?? l10nWithoutContext.churchOverviewUnknownChurch,
            count: e.value,
          ))
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
  return ChurchOverviewData(total: total, withoutChurch: without, churchCounts: counts);
}

/// Reads the church id of a person from its `additional_fields`.
String? churchIdOf(Map<String, dynamic>? additionalFields, String fieldId) {
  final value = additionalFields?[fieldId];
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

/// "Gemeinde-Übersicht" bottom sheet. Usable from the Termin (present
/// persons, subtitle "Anwesende") and from the people list (subtitle "Personen").
Future<void> showChurchOverviewSheet(
  BuildContext context, {
  required Iterable<String?> churchIds,
  required List<Church> churches,
  String? subtitle,
}) {
  final data = computeChurchOverview(churchIds, churches);
  if (context.rdSkin != null) {
    final label = subtitle ?? context.l10n.commonPeople;
    return showRdPlanSheet<void>(
      context,
      title: context.l10n.churchOverviewTitle,
      builder: (ctx, _) => [RdChurchOverviewView(data: data, subtitle: label)],
    );
  }
  // Ionic ChurchOverviewComponent: breakpoints [0, 0.5, 0.75, 1], initial
  // 0.5; toolbar with the title and the close button at the end.
  final label = subtitle ?? context.l10n.commonPeople;
  return showIonSheet<void>(
    context,
    breakpoints: const [0, 0.5, 0.75, 1],
    initialBreakpoint: 0.5,
    builder: (ctx, scrollController) => IonSheetScaffold(
      title: ctx.l10n.churchOverviewTitle,
      showClose: true,
      // PEO-09: Ionic `ion-content color="light"`.
      backgroundColor: ionLightColor(ctx),
      body: ChurchOverviewView(
        data: data,
        subtitle: label,
        scrollController: scrollController,
        showTitle: false,
      ),
    ),
  );
}

/// Content of the church overview sheet.
class ChurchOverviewView extends StatelessWidget {
  const ChurchOverviewView({
    super.key,
    required this.data,
    required this.subtitle,
    this.scrollController,
    this.showTitle = true,
  });

  final ChurchOverviewData data;
  final String subtitle;
  final ScrollController? scrollController;

  /// false when the sheet toolbar already shows the title.
  final bool showTitle;

  /// PEO-09: Ionic `ion-list inset` with list headers, start icons and
  /// `ion-badge` (primary / medium) on the light background.
  Widget _buildIonic(BuildContext context) {
    final l10n = context.l10n;
    Widget badge(int value, {Color color = AppColors.primary}) =>
        IonBadge(text: '$value', color: color);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        ios27.IonListHeader(l10n.churchOverviewTotal),
        ios27.IonInsetList(children: [
          ios27.IonItem(
            leading: Icon(AppIcons.peopleOutline),
            title: Text(subtitle),
            trailing: badge(data.total),
          ),
          ios27.IonItem(
            leading: Icon(AppIcons.businessOutlined),
            title: Text(l10n.churchOverviewChurches),
            trailing: badge(data.churchCounts.length),
          ),
        ]),
        if (data.churchCounts.isNotEmpty) ...[
          ios27.IonListHeader(l10n.churchOverviewChurches),
          ios27.IonInsetList(children: [
            for (final c in data.churchCounts)
              ios27.IonItem(title: Text(c.name), trailing: badge(c.count)),
          ]),
        ],
        if (data.withoutChurch > 0) ...[
          ios27.IonListHeader(l10n.churchOverviewUnassigned),
          ios27.IonInsetList(children: [
            ios27.IonItem(
              title: Text(l10n.churchOverviewNoChurch),
              trailing: badge(data.withoutChurch, color: AppColors.medium),
            ),
          ]),
        ],
        if (data.total == 0)
          ios27.IonInsetList(children: [
            ios27.IonItem(
              title: Center(
                child: Text(l10n.churchOverviewNoPeople,
                    style: const TextStyle(color: AppColors.medium)),
              ),
            ),
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showTitle && context.rdSkin == null) return _buildIonic(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: AppColors.medium)),
        );
    Widget badge(int value, {Color color = AppColors.primary}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text('$value',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.churchOverviewTitle, style: theme.textTheme.titleLarge),
          ),
        header(l10n.churchOverviewTotal),
        ListTile(
          leading: Icon(AppIcons.peopleOutline),
          title: Text(subtitle),
          trailing: badge(data.total),
        ),
        ListTile(
          leading: Icon(AppIcons.businessOutlined),
          title: Text(l10n.churchOverviewChurches),
          trailing: badge(data.churchCounts.length),
        ),
        if (data.churchCounts.isNotEmpty) ...[
          header(l10n.churchOverviewChurches),
          for (final c in data.churchCounts)
            ListTile(title: Text(c.name), trailing: badge(c.count)),
        ],
        if (data.withoutChurch > 0) ...[
          header(l10n.churchOverviewUnassigned),
          ListTile(
            title: Text(l10n.churchOverviewNoChurch),
            trailing: badge(data.withoutChurch, color: AppColors.medium),
          ),
        ],
        if (data.total == 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(l10n.churchOverviewNoPeople,
                  style: const TextStyle(color: AppColors.medium)),
            ),
          ),
      ],
    );
  }
}

/// Beta (redesign) content of the church overview sheet: the total on top,
/// then one row per Gemeinde with its count.
class RdChurchOverviewView extends StatelessWidget {
  const RdChurchOverviewView({super.key, required this.data, required this.subtitle});

  final ChurchOverviewData data;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            RdListRow(
              title: subtitle,
              leading: const RdRowIcon(Icons.people_outline),
              value: '${data.total}',
              showChevron: false,
            ),
            RdListRow(
              title: l10n.churchOverviewChurches,
              leading: const RdRowIcon(Icons.business_outlined),
              value: '${data.churchCounts.length}',
              showChevron: false,
            ),
          ],
        ),
        if (data.churchCounts.isNotEmpty || data.withoutChurch > 0) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.churchOverviewChurches),
          RdGroupedList(
            children: [
              for (final c in data.churchCounts)
                RdListRow(title: c.name, value: '${c.count}', showChevron: false),
              if (data.withoutChurch > 0)
                RdListRow(
                  title: l10n.churchOverviewNoChurch,
                  titleColor: p.text2,
                  value: '${data.withoutChurch}',
                  showChevron: false,
                ),
            ],
          ),
        ],
        if (data.total == 0)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(l10n.churchOverviewNoPeople, style: TextStyle(color: p.text2))),
          ),
      ],
    );
  }
}
