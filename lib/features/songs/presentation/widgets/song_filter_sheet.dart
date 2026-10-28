import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/song/song_filter.dart';

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
    final lastLabel = orchestra ? 'Zuletzt gespielt' : 'Zuletzt gesungen';

    final sortOptions = SongSortOption.values
        .where((o) => !o.isLastSung || !data.isPublic)
        .toList();

    final viewEntries = <(String, String)>[
      ('link', 'Link'),
      ('difficulty', 'Schwierigkeitsgrad'),
      ('withChoir', 'Chor & Orchester'),
      ('withSolo', 'Solo'),
      ('missingInstruments', 'Fehlende Instrumente'),
      if (!data.isPublic) ('lastSung', lastLabel),
      for (final f in data.additionalFields) (f.id, f.name),
    ];

    return DraggableScrollableSheet(
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
                    'Filter & Ansicht',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (filter.hasActiveFilters)
                  TextButton(
                    onPressed: notifier.reset,
                    child: const Text('Zurücksetzen'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const _Header(icon: Icons.sort, title: 'Sortierung'),
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
            const _Header(icon: Icons.speed, title: 'Schwierigkeitsgrad'),
            DropdownButtonFormField<int?>(
              value: filter.difficulty,
              isDense: true,
              items: const [
                DropdownMenuItem(value: null, child: Text('Alle')),
                DropdownMenuItem(value: 1, child: Text('1 - Leicht')),
                DropdownMenuItem(value: 2, child: Text('2 - Mittel')),
                DropdownMenuItem(value: 3, child: Text('3 - Schwer')),
              ],
              onChanged: notifier.setDifficulty,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.people),
              title: const Text('Chor & Orchester'),
              value: filter.withChoir,
              onChanged: notifier.setWithChoir,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.person),
              title: const Text('Solo'),
              value: filter.withSolo,
              onChanged: notifier.setWithSolo,
            ),
            if (data.categories.isNotEmpty) ...[
              const _Header(icon: Icons.sell_outlined, title: 'Kategorien'),
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
              const _Header(icon: Icons.music_note, title: 'Gruppen'),
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
                _Header(icon: Icons.filter_alt_outlined, title: field.name),
                DropdownButtonFormField<String>(
                  value: filter.fieldFilters[field.id] ?? '',
                  isDense: true,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Alle')),
                    if (field.isBoolean) ...const [
                      DropdownMenuItem(value: 'true', child: Text('Ja')),
                      DropdownMenuItem(value: 'false', child: Text('Nein')),
                    ] else
                      for (final opt in field.options)
                        DropdownMenuItem(value: opt, child: Text(opt)),
                  ],
                  onChanged: (v) => notifier.setFieldFilter(field.id, v ?? ''),
                ),
              ],
            const _Header(icon: Icons.visibility, title: 'Ansicht'),
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
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SongFilterSheet(data: data),
  );
}
