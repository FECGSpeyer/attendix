import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../data/models/song/song_filter.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Ionic songs `ion-popover trigger="filter-trigger-songs"`: one row per
/// option, only an icon at the start (no headings) and the current value at
/// the end – Sortierung (filter), Schwierigkeit (speedometer), Chor &
/// Orchester / Solo toggles, Kategorien (pricetag), Instrumente (musical
/// notes, orchestras only), Ansicht (eye) and a select per Zusatzfeld
/// (funnel) at the end. [builder] draws the trigger button.
///
/// The selects open in nested popovers and the filter popover stays open
/// while they are used ([showAppFilterPopover]).
class SongFilterMenu extends ConsumerWidget {
  const SongFilterMenu({super.key, required this.data, required this.builder});

  final SongsListData data;
  final Widget Function(BuildContext context, VoidCallback toggle) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The selects open nested popovers; the filter popover stays open while
    // they are used (Ionic), so its rows are built from the current filter
    // each time.
    return Builder(
      builder: (triggerContext) => builder(
        triggerContext,
        () {
          // The popover can outlive this widget: read through the
          // container, not through the widget's ref.
          final container = ProviderScope.containerOf(triggerContext);
          showAppFilterPopover(
            context: triggerContext,
            rows: () => triggerContext.mounted
                ? _rows(triggerContext, container)
                : const [],
          );
        },
      ),
    );
  }

  List<AppFilterRow> _rows(BuildContext context, ProviderContainer ref) {
    final filter = ref.read(songFilterProvider(data.tenantId));
    final notifier = ref.read(songFilterProvider(data.tenantId).notifier);
    final viewNotifier = ref.read(songViewOptionsProvider(data.tenantId).notifier);
    final orchestra = data.isOrchestra;
    final l10n = context.l10n;
    final lastLabel = orchestra ? l10n.songsLastPlayed : l10n.songsLastSung;

    List<T> toggled<T>(List<T> list, T id, bool on) =>
        on ? [...list.where((e) => e != id), id] : list.where((e) => e != id).toList();

    final sortOptions = SongSortOption.values.where((o) => !o.isLastSung || !data.isPublic).toList();
    final viewEntries = <(String, String)>[
      ('link', l10n.songsLink),
      ('difficulty', l10n.songsDifficulty),
      ('withChoir', l10n.songsChoirOrchestra),
      ('withSolo', l10n.songsSolo),
      ('missingInstruments', l10n.songsMissingInstruments),
      if (!data.isPublic) ('lastSung', lastLabel),
      for (final f in data.additionalFields) (f.id, f.name),
    ];
    // Ionic fills the instrument options only for orchestras.
    final instruments = orchestra ? data.instruments : const [];

    return [
      AppFilterSelect<SongSortOption>(
        icon: AppIcons.filterList,
        value: sortOptions.contains(filter.sortOption) ? filter.sortOption : SongSortOption.numberAsc,
        options: [for (final o in sortOptions) (o, o.labelFor(orchestra: orchestra))],
        onSelected: notifier.setSortOption,
      ),
      AppFilterSelect<int?>(
        icon: AppIcons.speed,
        value: filter.difficulty,
        options: [
          (null, l10n.commonAll),
          (1, l10n.songsEasy),
          (2, l10n.songsMedium),
          (3, l10n.songsHard),
        ],
        onSelected: notifier.setDifficulty,
      ),
      AppFilterToggle(
        icon: AppIcons.people,
        label: l10n.songsChoirOrchestra,
        value: filter.withChoir,
        onChanged: notifier.setWithChoir,
      ),
      AppFilterToggle(
        icon: AppIcons.person,
        label: l10n.songsSolo,
        value: filter.withSolo,
        onChanged: notifier.setWithSolo,
      ),
      if (data.categories.isNotEmpty)
        AppFilterMultiSelect<String>(
          icon: AppIcons.sellOutlined,
          values: () => ref.read(songFilterProvider(data.tenantId)).categoryIds,
          options: [
            for (final c in data.categories)
              if (c.id != null) (c.id!, c.name),
          ],
          onChanged: (id, on) => notifier.setCategoryIds(
              toggled(ref.read(songFilterProvider(data.tenantId)).categoryIds, id, on)),
        ),
      if (instruments.isNotEmpty)
        AppFilterMultiSelect<int>(
          icon: AppIcons.musicNote,
          values: () => ref.read(songFilterProvider(data.tenantId)).instrumentIds,
          options: [
            for (final g in instruments)
              if (g.id != null) (g.id!, g.name),
          ],
          onChanged: (id, on) => notifier.setInstrumentIds(
              toggled(ref.read(songFilterProvider(data.tenantId)).instrumentIds, id, on)),
        ),
      AppFilterMultiSelect<String>(
        icon: AppIcons.visibility,
        values: () {
          final v = ref.read(songViewOptionsProvider(data.tenantId));
          return [for (final e in viewEntries) if (v.has(e.$1)) e.$1];
        },
        options: viewEntries,
        onChanged: (id, _) => viewNotifier.toggle(id),
      ),
      for (final field in data.additionalFields)
        if (field.isSelect || field.isBoolean)
          AppFilterSelect<String>(
            icon: AppIcons.filterAltOutlined,
            value: filter.fieldFilters[field.id] ?? '',
            placeholder: filter.fieldFilters.containsKey(field.id) ? null : field.name,
            options: [
              ('', l10n.commonAll),
              if (field.isBoolean) ...[
                ('true', l10n.commonYes),
                ('false', l10n.commonNo),
              ] else
                for (final opt in field.options) (opt, opt),
            ],
            onSelected: (v) => notifier.setFieldFilter(field.id, v),
          ),
    ];
  }
}
