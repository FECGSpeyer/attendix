import 'package:flutter/material.dart';

import '../../../core/theme/design_theme.dart';
import '../../../data/models/church/church.dart';
import '../../../features/planning/presentation/widgets/plan_widgets.dart';
import '../components/components.dart';
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
  final label = subtitle ?? context.l10n.commonPeople;
  return showRdPlanSheet<void>(
    context,
    title: context.l10n.churchOverviewTitle,
    builder: (ctx, _) => [RdChurchOverviewView(data: data, subtitle: label)],
  );
}

/// Content of the church overview sheet: the total on top,
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
