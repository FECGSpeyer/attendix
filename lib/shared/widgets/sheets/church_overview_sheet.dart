import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/church/church.dart';
import '../../../l10n/l10n.dart';

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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => ChurchOverviewView(
        data: data,
        subtitle: subtitle ?? context.l10n.commonPeople,
        scrollController: scrollController,
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
  });

  final ChurchOverviewData data;
  final String subtitle;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.churchOverviewTitle, style: theme.textTheme.titleLarge),
        ),
        header(l10n.churchOverviewTotal),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(subtitle),
          trailing: badge(data.total),
        ),
        ListTile(
          leading: const Icon(Icons.business_outlined),
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
