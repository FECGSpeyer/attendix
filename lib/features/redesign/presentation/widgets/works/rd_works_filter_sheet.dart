import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/song_filter_providers.dart';
import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/song/song_filter.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../data/providers/rd_works_filter.dart';
import '../../../data/rd_works_logic.dart';
import '../rd_widgets.dart';

/// REDESIGN: the four sort orders of the Werke tab ("Nummer", "Titel",
/// "Zuletzt gespielt", "Am längsten nicht gespielt").
const rdWorksSorts = [
  SongSortOption.numberAsc,
  SongSortOption.nameAsc,
  SongSortOption.lastSungDesc,
  SongSortOption.lastSungAsc,
];

/// Label of a sort order ("gespielt" for orchestras). The descending number
/// and title orders of the old design (still saved) get a "↓".
String rdWorksSortLabel(AppLocalizations l10n, SongSortOption sort, {required bool orchestra}) => switch (sort) {
  SongSortOption.nameAsc => l10n.redesignWorksSortTitle,
  SongSortOption.nameDesc => '${l10n.redesignWorksSortTitle} ↓',
  SongSortOption.lastSungDesc => orchestra ? l10n.redesignWorksSortLastPlayed : l10n.redesignWorksSortLastSung,
  SongSortOption.lastSungAsc => orchestra ? l10n.redesignWorksSortLongestPlayed : l10n.redesignWorksSortLongestSung,
  SongSortOption.numberAsc => l10n.redesignWorksSortNumber,
  SongSortOption.numberDesc => '${l10n.redesignWorksSortNumber} ↓',
};

/// The sort orders of the sheet: [rdWorksSorts], plus a descending order of
/// the old design while it is still saved ([current]), right after its
/// ascending pair, so the check mark shows how the list is sorted.
List<SongSortOption> rdWorksSortOptions(SongSortOption current) => [
  for (final option in rdWorksSorts) ...[
    option,
    if ((option == SongSortOption.numberAsc && current == SongSortOption.numberDesc) ||
        (option == SongSortOption.nameAsc && current == SongSortOption.nameDesc))
      current,
  ],
];

/// "Sortieren & Filtern" (canvas "Werke neu gedacht", board "Filter"):
/// changes apply at once, the button shows how many Werke are left. Leads
/// filter on missing Noten, members on their own part.
Future<void> showRdWorksFilterSheet(
  BuildContext context, {
  required SongsListData data,
  required bool lead,
  required int? groupId,
  required Map<int, int>? playerCounts,
  required String query,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder:
        (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder:
              (sheet, controller) => _FilterSheet(
                controller: controller,
                data: data,
                lead: lead,
                groupId: groupId,
                playerCounts: playerCounts,
                query: query,
              ),
        ),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({
    required this.controller,
    required this.data,
    required this.lead,
    required this.groupId,
    required this.playerCounts,
    required this.query,
  });

  final ScrollController controller;
  final SongsListData data;
  final bool lead;
  final int? groupId;
  final Map<int, int>? playerCounts;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final filter = ref.watch(songFilterProvider(data.tenantId));
    final notifier = ref.read(songFilterProvider(data.tenantId).notifier);
    final only = ref.watch(rdWorksOnlyProvider);
    final count =
        rdFilteredWorks(
          data: data,
          filter: filter,
          only: only,
          query: query,
          groupId: groupId,
          playerCounts: playerCounts,
        ).length;

    void toggleOnly(RdWorksOnly value) {
      final next = {...only};
      if (!next.remove(value)) next.add(value);
      ref.read(rdWorksOnlyProvider.notifier).state = next;
    }

    final groups = [...data.groups.where((g) => g.maingroup != true && g.id != null)];
    final selectedGroups = [
      for (final g in groups)
        if (filter.instrumentIds.contains(g.id)) g.name,
    ];
    final booleanFields = data.additionalFields.where((f) => f.isBoolean).toList();
    final sort = filter.sortOption;

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text(l10n.redesignWorksFilterTitle, style: RdType.section(p))),
            ),
            RdTextLink(
              label: l10n.redesignWorksFilterReset,
              onTap: () {
                notifier
                  ..reset()
                  ..setSortOption(SongSortOption.numberAsc);
                ref.read(rdWorksOnlyProvider.notifier).state = const {};
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        RdGroupLabel(l10n.redesignWorksSort),
        RdGroupedList(
          children: [
            for (final option in rdWorksSortOptions(sort))
              RdListRow(
                title: rdWorksSortLabel(l10n, option, orchestra: data.isOrchestra),
                showChevron: false,
                selected: option == sort,
                trailing: option == sort ? Icon(Icons.check, color: p.primary) : null,
                onTap: () => notifier.setSortOption(option),
              ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignWorksOnly),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (lead)
              RdChoiceChip(
                label: l10n.redesignWorksOnlyMissing,
                selected: only.contains(RdWorksOnly.missing),
                onTap: () => toggleOnly(RdWorksOnly.missing),
              )
            else if (groupId != null)
              RdChoiceChip(
                label: l10n.redesignWorksOnlyMine,
                selected: only.contains(RdWorksOnly.myPart),
                onTap: () => toggleOnly(RdWorksOnly.myPart),
              ),
            RdChoiceChip(
              label: l10n.redesignWorksOnlyRecording,
              selected: only.contains(RdWorksOnly.recording),
              onTap: () => toggleOnly(RdWorksOnly.recording),
            ),
            RdChoiceChip(
              label: data.isOrchestra ? l10n.redesignWorkWithChoir : l10n.redesignWorkWithOrchestra,
              selected: filter.withChoir,
              onTap: () => notifier.setWithChoir(!filter.withChoir),
            ),
            RdChoiceChip(
              label: l10n.redesignWorksOnlySolo,
              selected: filter.withSolo,
              onTap: () => notifier.setWithSolo(!filter.withSolo),
            ),
            for (final (value, label) in [
              (1, l10n.redesignWorkEditEasy),
              (2, l10n.redesignWorkEditMedium),
              (3, l10n.redesignWorkEditHard),
            ])
              RdChoiceChip(
                label: label,
                selected: filter.difficulty == value,
                onTap: () => notifier.setDifficulty(filter.difficulty == value ? null : value),
              ),
            for (final field in booleanFields)
              RdChoiceChip(
                label: field.name,
                selected: filter.fieldFilters[field.id] == 'true',
                onTap: () => notifier.setFieldFilter(field.id, filter.fieldFilters[field.id] == 'true' ? '' : 'true'),
              ),
          ],
        ),
        if (data.isOrchestra && groups.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.redesignWorksForGroup,
                value: selectedGroups.isEmpty ? l10n.redesignWorksForGroupAll : selectedGroups.join(', '),
                onTap: () async {
                  final choice = await showAppActionSheet<int>(
                    context,
                    title: l10n.redesignWorksForGroup,
                    actions: [
                      AppActionSheetAction(value: -1, label: l10n.redesignWorksForGroupAll),
                      for (final g in groups) AppActionSheetAction(value: g.id!, label: g.name),
                    ],
                  );
                  if (choice == null) return;
                  notifier.setInstrumentIds(choice < 0 ? const [] : [choice]);
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        RdPrimaryButton(
          key: const Key('rd-works-filter-show'),
          label: l10n.redesignWorksShow(count),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
