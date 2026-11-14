import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/song/song_filter.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart';

/// Filter, sort and view options of the songs list (Ionic filter popover)
class SongFilterSheet extends ConsumerWidget {
  const SongFilterSheet({super.key, required this.data});

  final SongsListData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(songFilterProvider(data.tenantId));
    final view = ref.watch(songViewOptionsProvider(data.tenantId));
    final notifier = ref.read(songFilterProvider(data.tenantId).notifier);
    final viewNotifier = ref.read(songViewOptionsProvider(data.tenantId).notifier);
    final orchestra = data.isOrchestra;
    final l10n = context.l10n;
    final lastLabel = orchestra ? l10n.songsLastPlayed : l10n.songsLastSung;

    final sortOptions = SongSortOption.values
        .where((o) => !o.isLastSung || !data.isPublic)
        .toList();

    final viewEntries = <(String, String)>[
      ('link', l10n.songsLink),
      ('difficulty', l10n.songsDifficulty),
      ('withChoir', l10n.songsChoirOrchestra),
      ('withSolo', l10n.songsSolo),
      ('missingInstruments', l10n.songsMissingInstruments),
      if (!data.isPublic) ('lastSung', lastLabel),
      for (final f in data.additionalFields) (f.id, f.name),
    ];

    return AppDraggableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.songsFlutterFilterAndView,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (filter.hasActiveFilters)
                  TextButton(
                    onPressed: notifier.reset,
                    child: IonButtonLabel(l10n.dateDialogReset),
                  ),
                IconButton(
                  icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            _Header(icon: AppIcons.sort, title: l10n.attendanceSorting),
            DropdownButtonFormField<SongSortOption>(
              value: sortOptions.contains(filter.sortOption)
                  ? filter.sortOption
                  : SongSortOption.numberAsc,
              isDense: true,
              items: [
                for (final o in sortOptions)
                  DropdownMenuItem(value: o, child: Text(o.labelFor(orchestra: orchestra))),
              ],
              onChanged: (v) {
                if (v != null) notifier.setSortOption(v);
              },
            ),
            _Header(icon: AppIcons.speed, title: l10n.songsDifficulty),
            DropdownButtonFormField<int?>(
              value: filter.difficulty,
              isDense: true,
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.commonAll)),
                DropdownMenuItem(value: 1, child: Text(l10n.songsEasy)),
                DropdownMenuItem(value: 2, child: Text(l10n.songsMedium)),
                DropdownMenuItem(value: 3, child: Text(l10n.songsHard)),
              ],
              onChanged: notifier.setDifficulty,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(AppIcons.people),
              title: Text(l10n.songsChoirOrchestra),
              value: filter.withChoir,
              onChanged: notifier.setWithChoir,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(AppIcons.person),
              title: Text(l10n.songsSolo),
              value: filter.withSolo,
              onChanged: notifier.setWithSolo,
            ),
            if (data.categories.isNotEmpty) ...[
              _Header(icon: AppIcons.sellOutlined, title: l10n.songsCategories),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in data.categories)
                    FilterChip(
                      label: Text(c.name),
                      selected: filter.categoryIds.contains(c.id),
                      onSelected: (selected) {
                        final ids = [...filter.categoryIds];
                        selected ? ids.add(c.id!) : ids.remove(c.id);
                        notifier.setCategoryIds(ids);
                      },
                    ),
                ],
              ),
            ],
            if (data.instruments.isNotEmpty) ...[
              _Header(icon: AppIcons.musicNote, title: l10n.settingsGroups),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final g in data.instruments)
                    FilterChip(
                      label: Text(g.name),
                      selected: filter.instrumentIds.contains(g.id),
                      onSelected: (selected) {
                        final ids = [...filter.instrumentIds];
                        selected ? ids.add(g.id!) : ids.remove(g.id);
                        notifier.setInstrumentIds(ids);
                      },
                    ),
                ],
              ),
            ],
            for (final field in data.additionalFields)
              if (field.isSelect || field.isBoolean) ...[
                _Header(icon: AppIcons.filterAltOutlined, title: field.name),
                DropdownButtonFormField<String>(
                  value: filter.fieldFilters[field.id] ?? '',
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.commonAll)),
                    if (field.isBoolean) ...[
                      DropdownMenuItem(value: 'true', child: Text(l10n.commonYes)),
                      DropdownMenuItem(value: 'false', child: Text(l10n.commonNo)),
                    ] else
                      for (final opt in field.options)
                        DropdownMenuItem(value: opt, child: Text(opt)),
                  ],
                  onChanged: (v) => notifier.setFieldFilter(field.id, v ?? ''),
                ),
              ],
            _Header(icon: AppIcons.visibility, title: l10n.attendanceView),
            for (final entry in viewEntries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(entry.$2),
                value: view.has(entry.$1),
                onChanged: (_) => viewNotifier.toggle(entry.$1),
              ),
            const SizedBox(height: AppDimensions.paddingL),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingM, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.medium),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.medium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the filter sheet
Future<void> showSongFilterSheet(BuildContext context, SongsListData data) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SongFilterSheet(data: data),
  );
}

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
        () => showAppFilterPopover(
          context: triggerContext,
          rows: () => _rows(triggerContext, ref),
        ),
      ),
    );
  }

  List<AppFilterRow> _rows(BuildContext context, WidgetRef ref) {
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
