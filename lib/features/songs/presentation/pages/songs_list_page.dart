import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_filter.dart';
import '../widgets/song_filter_sheet.dart';
import '../widgets/song_categories_sheet.dart';
import '../widgets/group_files_sheet.dart';
import 'song_import_page.dart';

/// Songs list page with filter and sort support
class SongsListPage extends ConsumerStatefulWidget {
  const SongsListPage({super.key});

  @override
  ConsumerState<SongsListPage> createState() => _SongsListPageState();
}

class _SongsListPageState extends ConsumerState<SongsListPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize search controller with current search query
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchController.text = ref.read(songSearchQueryProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareSongLink(WidgetRef ref, BuildContext context) {
    final tenant = ref.read(currentTenantProvider);
    final sharingId = tenant?.songSharingId;
    if (sharingId == null || sharingId.isEmpty) {
      ToastHelper.showError(context, 'Teilen ist nicht aktiviert. Aktiviere es unter Einstellungen → Allgemein.');
      return;
    }
    final link = 'https://attendix.de/songs/$sharingId';
    Clipboard.setData(ClipboardData(text: link));
    ToastHelper.showSuccess(context, 'Link kopiert');
  }

  void _handleMenuAction(String value, WidgetRef ref, BuildContext context, bool isConductor) {
    final notifier = ref.read(songViewOptionsProvider.notifier);
    switch (value) {
      case 'filter':
        showSongFilterSheet(context);
      case 'choir':
        notifier.setShowChoirBadge(!ref.read(songViewOptionsProvider).showChoirBadge);
      case 'solo':
        notifier.setShowSoloBadge(!ref.read(songViewOptionsProvider).showSoloBadge);
      case 'missing':
        notifier.setShowMissingInstruments(!ref.read(songViewOptionsProvider).showMissingInstruments);
      case 'link':
        notifier.setShowLink(!ref.read(songViewOptionsProvider).showLink);
      case 'lastSung':
        notifier.setShowLastSung(!ref.read(songViewOptionsProvider).showLastSung);
      case 'categories':
        if (isConductor) showSongCategoriesSheet(context);
      case 'share':
        _shareSongLink(ref, context);
      // PEOPLE_IMPORT: song import (Ionic: Admin/Responsible only)
      case 'import':
        _openSongImport(ref, context);
    }
  }

  Future<void> _openSongImport(WidgetRef ref, BuildContext context) async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SongImportPage(),
      ),
    );
    if (imported == true) {
      ref.invalidate(songsProvider);
      ref.invalidate(realtimeSongsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(realtimeSongsProvider);
    final filteredSongs = ref.watch(filteredSongsProvider);
    final filter = ref.watch(songFilterProvider);
    final viewOptions = ref.watch(songViewOptionsProvider);
    final searchQuery = ref.watch(songSearchQueryProvider);
    final categoriesAsync = ref.watch(songCategoriesProvider);
    final currentRole = ref.watch(currentRoleProvider);
    final groupsWithFiles = ref.watch(groupsWithFilesProvider);
    final currentSongsAsync = ref.watch(currentSongsProvider);

    final isConductor = currentRole.isConductor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lieder'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // FN-014: Use pop() instead of go() for consistent navigation
          onPressed: () => context.pop(),
        ),
        actions: [
          // Group files directory (only show if there are files)
          if (groupsWithFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () => showGroupFilesSheet(context),
              tooltip: 'Gruppenverzeichnis',
            ),
          // Overflow menu for all other options
          PopupMenuButton<String>(
            icon: Stack(
              children: [
                const Icon(Icons.more_vert),
                if (filter.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Menü',
            onSelected: (value) => _handleMenuAction(value, ref, context, isConductor),
            itemBuilder: (context) => [
              // Filter & Sort
              PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: filter.hasActiveFilters ? AppColors.primary : null,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Filter & Sortierung'),
                    if (filter.hasActiveFilters) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filter.activeFilterCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const PopupMenuDivider(),
              // View options header
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'Ansicht',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.medium,
                  ),
                ),
              ),
              CheckedPopupMenuItem(
                value: 'choir',
                checked: viewOptions.showChoirBadge,
                child: const Text('Chor-Badge'),
              ),
              CheckedPopupMenuItem(
                value: 'solo',
                checked: viewOptions.showSoloBadge,
                child: const Text('Solo-Badge'),
              ),
              CheckedPopupMenuItem(
                value: 'missing',
                checked: viewOptions.showMissingInstruments,
                child: const Text('Fehlende Instrumente'),
              ),
              CheckedPopupMenuItem(
                value: 'link',
                checked: viewOptions.showLink,
                child: const Text('Link-Icon'),
              ),
              CheckedPopupMenuItem(
                value: 'lastSung',
                checked: viewOptions.showLastSung,
                child: const Text('Zuletzt gespielt'),
              ),
              // Admin section
              if (isConductor) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 12),
                      Text('Teilen-Link kopieren'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(Icons.category, size: 20),
                      SizedBox(width: 12),
                      Text('Kategorien verwalten'),
                    ],
                  ),
                ),
              ],
              // PEOPLE_IMPORT: song import (Admin/Responsible)
              if (currentRole.isAdmin || currentRole.isResponsible)
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Werke importieren'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(songSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(songSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Category chips (horizontal scroll)
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Alle'),
                        selected: filter.category == null,
                        onSelected: (selected) {
                          if (selected) {
                            ref
                                .read(songFilterProvider.notifier)
                                .setCategory(null);
                          }
                        },
                      ),
                    ),
                    ...categories.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: filter.category == c.name,
                            onSelected: (selected) {
                              ref
                                  .read(songFilterProvider.notifier)
                                  .setCategory(selected ? c.name : null);
                            },
                          ),
                        )),
                  ],
                ),
              );
            },
          ),

          // Active filter chips
          if (filter.hasActiveFilters && filter.category == null)
            _ActiveFilterChips(filter: filter),

          // Sort indicator
          if (filter.sortOption != SongSortOption.numberAsc)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingXS,
              ),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 16, color: AppColors.medium),
                  const SizedBox(width: 4),
                  Text(
                    filter.sortOption.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.medium,
                    ),
                  ),
                ],
              ),
            ),

          // Songs list
          Expanded(
            child: songsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text('Fehler: $error'),
                    const SizedBox(height: AppDimensions.paddingM),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(realtimeSongsProvider),
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              ),
              data: (songs) {
                if (songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.music_note_outlined,
                          size: 80,
                          color: AppColors.medium,
                        ),
                        const SizedBox(height: AppDimensions.paddingL),
                        Text(
                          'Keine Lieder',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.paddingS),
                        Text(
                          'Füge das erste Lied hinzu',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.medium,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredSongs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.medium,
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Keine Ergebnisse für "$searchQuery"'
                              : 'Keine Lieder mit diesen Filtern',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        if (filter.hasActiveFilters)
                          TextButton.icon(
                            onPressed: () {
                              ref.read(songFilterProvider.notifier).reset();
                            },
                            icon: const Icon(Icons.filter_list_off),
                            label: const Text('Filter zurücksetzen'),
                          ),
                      ],
                    ),
                  );
                }

                // Get current songs data
                final currentSongs = currentSongsAsync.valueOrNull ?? [];

                return RefreshIndicator(
                  // FN-013: await provider.future to show spinner until data loads
                  onRefresh: () async {
                    ref.invalidate(realtimeSongsProvider);
                    ref.invalidate(currentSongsProvider);
                    await ref.read(realtimeSongsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    children: [
                      // Current songs section (only if there are upcoming events)
                      if (currentSongs.isNotEmpty)
                        _CollapsibleSection(
                          title: 'Aktuelle Werke',
                          count: currentSongs.fold<int>(
                            0, (sum, group) => sum + group.history.length),
                          initiallyExpanded: true,
                          isPrimary: true,
                          children: currentSongs.map((group) =>
                            _CurrentSongsGroup(
                              date: group.date,
                              songs: group.history,
                              onSongTap: (songId) => context.push('/settings/songs/$songId'),
                            ),
                          ).toList(),
                        ),

                      // All songs section
                      _CollapsibleSection(
                        title: 'Alle Lieder',
                        count: filteredSongs.length,
                        initiallyExpanded: true,
                        isPrimary: currentSongs.isEmpty,
                        children: filteredSongs.map((song) =>
                          _SongListItem(
                            song: song,
                            viewOptions: viewOptions,
                            onTap: () => context.push('/settings/songs/${song.id}'),
                          ),
                        ).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isConductor
          ? FloatingActionButton(
              onPressed: () => context.push('/settings/songs/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// Active filter chips row (removable)
class _ActiveFilterChips extends ConsumerWidget {
  final SongFilter filter;

  const _ActiveFilterChips({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (filter.withChoir)
            Chip(
              label: const Text('Chor & Orchester'),
              onDeleted: () {
                ref.read(songFilterProvider.notifier).setWithChoir(false);
              },
              visualDensity: VisualDensity.compact,
            ),
          if (filter.withSolo)
            Chip(
              label: const Text('Mit Solo'),
              onDeleted: () {
                ref.read(songFilterProvider.notifier).setWithSolo(false);
              },
              visualDensity: VisualDensity.compact,
            ),
          if (filter.difficulty != null)
            Chip(
              label: Text('Schwierigkeit: ${filter.difficulty}'),
              onDeleted: () {
                ref.read(songFilterProvider.notifier).clearDifficulty();
              },
              visualDensity: VisualDensity.compact,
            ),
          if (filter.instrumentIds.isNotEmpty)
            Chip(
              label: Text('${filter.instrumentIds.length} Instrumente'),
              onDeleted: () {
                ref.read(songFilterProvider.notifier).clearInstruments();
              },
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _SongListItem extends StatelessWidget {
  const _SongListItem({
    required this.song,
    required this.viewOptions,
    required this.onTap,
  });

  final Song song;
  final SongViewOptions viewOptions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showChoir = viewOptions.showChoirBadge && song.withChoir;
    final showSolo = viewOptions.showSoloBadge && song.withSolo;
    final showLink = viewOptions.showLink && song.link != null && song.link!.isNotEmpty;
    final showLastSung = viewOptions.showLastSung && song.lastSung != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Center(
            child: song.fullNumber.isNotEmpty
                ? Text(
                    song.fullNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.music_note,
                    color: AppColors.primary,
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                song.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (showLink)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.link, size: 16, color: AppColors.medium),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (song.conductor != null)
              Text(
                song.conductor!,
                style: const TextStyle(fontSize: 13),
              ),
            if (showChoir || showSolo)
              Row(
                children: [
                  if (showChoir)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text('Chor'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (showSolo)
                    const Chip(
                      label: Text('Solo'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
          ],
        ),
        trailing: showLastSung
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Zuletzt',
                    style: TextStyle(fontSize: 11, color: AppColors.medium),
                  ),
                  Text(
                    song.lastSung!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              )
            : const Icon(
                Icons.chevron_right,
                color: AppColors.medium,
              ),
      ),
    );
  }
}

/// Collapsible section widget (like Ionic accordion)
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.children,
    this.initiallyExpanded = true,
    this.isPrimary = true,
  });

  final String title;
  final int count;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool isPrimary;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isPrimary ? AppColors.primary : AppColors.medium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingS,
              horizontal: AppDimensions.paddingXS,
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.paddingXS),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...widget.children,
        if (_isExpanded) const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }
}

/// Current songs group widget (grouped by date)
class _CurrentSongsGroup extends StatelessWidget {
  final String date;
  final List<SongHistory> songs;
  final void Function(int songId) onSongTap;

  const _CurrentSongsGroup({
    required this.date,
    required this.songs,
    required this.onSongTap,
  });

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

      if (dateOnly == today) {
        return 'Heute';
      } else if (dateOnly == tomorrow) {
        return 'Morgen';
      } else {
        return DateFormat('EEEE, d. MMMM', 'de_DE').format(parsed);
      }
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.paddingXS,
          ),
          child: Row(
            children: [
              const Icon(Icons.event, size: 14, color: AppColors.primary),
              const SizedBox(width: AppDimensions.paddingXS),
              Text(
                _formatDate(date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        ...songs.map((history) {
          final song = history.song;
          if (song == null) return const SizedBox.shrink();

          return Card(
            margin: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
            child: ListTile(
              dense: true,
              onTap: song.id != null ? () => onSongTap(song.id!) : null,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: Center(
                  child: song.fullNumber.isNotEmpty
                      ? Text(
                          song.fullNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          color: AppColors.primary,
                          size: 18,
                        ),
                ),
              ),
              title: Text(
                song.name,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              subtitle: song.conductor != null
                  ? Text(
                      song.conductor!,
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.medium,
                size: 20,
              ),
            ),
          );
        }),
      ],
    );
  }
}
