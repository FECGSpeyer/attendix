import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/optional_tabs_providers.dart'; // SETTINGS2
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/models/song/song_filter.dart';
import '../../../../shared/widgets/loading/skeleton_list_tile.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';
import '../widgets/add_song_sheet.dart';
import '../widgets/current_songs_sheet.dart';
import '../widgets/group_files_sheet.dart';
import '../widgets/song_categories_sheet.dart';
import '../widgets/song_filter_sheet.dart';
import 'song_import_page.dart';
import '../../../../core/providers/branding_providers.dart'; // MISC2

/// Songs list (Ionic `songs.page`).
///
/// Used for the logged-in tenant (`/settings/songs`) and - with
/// [songSharingId] - for the public share link `/<song_sharing_id>`
/// (read only, no login required).
class SongsListPage extends ConsumerStatefulWidget {
  const SongsListPage({super.key, this.songSharingId});

  final String? songSharingId;

  @override
  ConsumerState<SongsListPage> createState() => _SongsListPageState();
}

class _SongsListPageState extends ConsumerState<SongsListPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';
  bool _pruned = false;

  bool get _isPublic => widget.songSharingId != null;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Ionic searchbar debounce: 250 ms
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _search = value);
    });
  }

  Future<void> _refresh() async {
    if (_isPublic) {
      ref.invalidate(songsListDataProvider(widget.songSharingId));
    } else {
      ref.invalidate(songsProvider);
      ref.invalidate(currentSongsProvider);
      ref.invalidate(songCategoriesProvider);
    }
    await ref.read(songsListDataProvider(widget.songSharingId).future);
  }

  Future<void> _openSongImport() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SongImportPage(),
      ),
    );
    if (imported == true) {
      ref.invalidate(songsProvider);
      ref.invalidate(songsListDataProvider);
    }
  }

  void _openSong(int songId) {
    if (_isPublic) {
      context.push('/${widget.songSharingId}/$songId');
    } else {
      context.push('/settings/songs/$songId');
    }
  }

  /// SETTINGS2: Ionic `toggleSongsTab`.
  Future<void> _toggleSongsTab() async {
    final current = ref.read(optionalTabsNotifierProvider).songs;
    try {
      await ref.read(optionalTabsNotifierProvider.notifier).setShowSongsTab(!current);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
    }
  }

  void _copyShareLink(String sharingId) {
    Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId)));
    ToastHelper.showSuccess(context, 'Der Link wurde in die Zwischenablage kopiert');
  }

  Future<void> _exportPdf(SongsListData data, List<Song> filtered, SongViewOptions view) async {
    final tenant = data.publicTenant ?? ref.read(currentTenantProvider);
    try {
      final branding = data.isPublic ? null : await resolvePdfBranding(ref); // MISC2
      await ref.read(songPrintServiceProvider).exportSongsCatalogPdf(
            branding: branding,
            songs: filtered,
            tenantShortName: tenant?.shortName ?? '',
            viewOpts: view.opts,
            showLastSung: !data.isPublic,
            isOrchestra: data.isOrchestra,
            additionalFields: data.additionalFields,
          );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Erstellen der PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPublic) ref.watch(songsRealtimeProvider);
    final dataAsync = ref.watch(songsListDataProvider(widget.songSharingId));
    final role = ref.watch(currentRoleProvider);
    final isAdmin = !_isPublic && (role.isAdmin || role.isResponsible);
    final data = dataAsync.valueOrNull;

    if (dataAsync.hasError && data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Werke')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text('Fehler: ${dataAsync.error}'),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (dataAsync.hasValue && data == null) {
      // Invalid public sharing link (or no tenant selected)
      return Scaffold(
        appBar: AppBar(title: const Text('Werke')),
        body: const Center(child: Text('Ungültiger Freigabe-Link.')),
      );
    }

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isPublic ? '' : 'Werke')),
        body: ListView(
          children: List.generate(10, (_) => const SkeletonListTile(showAvatar: false)),
        ),
      );
    }

    final filter = ref.watch(songFilterProvider(data.tenantId));
    final view = ref.watch(songViewOptionsProvider(data.tenantId));
    final filterNotifier = ref.read(songFilterProvider(data.tenantId).notifier);

    if (!_pruned) {
      _pruned = true;
      final ids = data.categories.map((c) => c.id).whereType<String>().toSet();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) filterNotifier.pruneCategories(ids);
      });
    }

    final filtered = applySongFilter(
      data.songs,
      filter,
      search: _search,
      additionalFields: data.additionalFields,
    );
    final groupsWithFiles = buildGroupsWithFiles(data.songs, data.groups);
    final sharingId = data.songSharingId;
    final hasSongSharing = sharingId != null && sharingId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(data.isPublic
            ? data.publicTenant!.longName
            : 'Werke (${data.songs.length})'),
        automaticallyImplyLeading: !data.isPublic,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menü',
            onSelected: (value) {
              switch (value) {
                case 'categories':
                  showSongCategoriesSheet(context);
                case 'share':
                  _copyShareLink(sharingId!);
                case 'pdf':
                  _exportPdf(data, filtered, view);
                // PEOPLE_IMPORT: song import (Ionic: Admin/Responsible only)
                case 'import':
                  _openSongImport();
                // SETTINGS2: "Als Tab anzeigen" / "Tab ausblenden"
                case 'tab':
                  _toggleSongsTab();
              }
            },
            itemBuilder: (context) => [
              if (isAdmin)
                const PopupMenuItem(
                  value: 'categories',
                  child: ListTile(
                    leading: Icon(Icons.local_library_outlined),
                    title: Text('Werk-Kategorien'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (hasSongSharing)
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.link),
                    title: Text('Link kopieren'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // SETTINGS2: Ionic toggleSongsTab (not on the public page)
              if (!data.isPublic)
                PopupMenuItem(
                  value: 'tab',
                  child: ListTile(
                    leading: Icon(ref.watch(optionalTabsNotifierProvider).songs
                        ? Icons.bookmark
                        : Icons.bookmark_outline),
                    title: Text(ref.watch(optionalTabsNotifierProvider).songs
                        ? 'Tab ausblenden'
                        : 'Als Tab anzeigen'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // UX_SETTINGS: Ionic order (import before PDF)
              if (isAdmin)
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.cloud_upload_outlined),
                    title: Text('Werke importieren'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Werkverzeichnis als PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final id = await showAddSongSheet(context, data);
                if (id != null && mounted) _openSong(id);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            if (data.categories.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategorySegment(
                  categories: data.categories,
                  selected: filter.category,
                  onSelected: filterNotifier.setCategory,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM,
                  AppDimensions.paddingS,
                  AppDimensions.paddingS,
                  AppDimensions.paddingS,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Werk suchen...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchDebounce?.cancel();
                                    setState(() => _search = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Filter & Ansicht',
                      icon: Badge(
                        isLabelVisible: filter.hasActiveFilters,
                        smallSize: 8,
                        child: const Icon(Icons.tune),
                      ),
                      onPressed: () => showSongFilterSheet(context, data),
                    ),
                  ],
                ),
              ),
            ),
            if (dataAsync.isLoading && dataAsync.hasValue)
              const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
            SliverToBoxAdapter(
              child: _QuickLinks(
                showCurrent: data.currentSongs.isNotEmpty &&
                    filter.category == null &&
                    filter.categoryIds.isEmpty,
                showGroups: groupsWithFiles.isNotEmpty,
                onCurrent: () => showCurrentSongsSheet(
                  context,
                  data: data,
                  canPrint: isAdmin,
                  onOpenSong: _openSong,
                ),
                onGroups: () => showGroupFilesSheet(
                  context,
                  songs: data.songs,
                  groups: groupsWithFiles,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM,
                  AppDimensions.paddingM,
                  AppDimensions.paddingM,
                  AppDimensions.paddingXS,
                ),
                child: Text(
                  'Werke (${filtered.length})',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.medium,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXL),
                  child: Column(
                    children: [
                      const Icon(Icons.music_off_outlined, size: 56, color: AppColors.medium),
                      const SizedBox(height: AppDimensions.paddingS),
                      Text(
                        data.songs.isEmpty
                            ? 'Keine Werke vorhanden'
                            : 'Keine Werke gefunden',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (filter.hasActiveFilters)
                        TextButton.icon(
                          onPressed: filterNotifier.reset,
                          icon: const Icon(Icons.filter_list_off),
                          label: const Text('Filter zurücksetzen'),
                        ),
                    ],
                  ),
                ),
              )
            else
              // Ionic `ion-list [inset]="true"`: rounded card around the songs
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                sliver: DecoratedSliver(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
                  ),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                    itemBuilder: (context, index) {
                      final song = filtered[index];
                      return _SongListItem(
                        key: ValueKey(song.id),
                        song: song,
                        data: data,
                        view: view,
                        onTap: song.id == null ? null : () => _openSong(song.id!),
                      );
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }
}

/// Ionic `ion-segment [scrollable]="true" mode="md"`: horizontally
/// scrollable segment buttons ("Alle" + categories) with an underline.
class _CategorySegment extends StatelessWidget {
  const _CategorySegment({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<SongCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = <(String?, String)>[
      (null, 'Alle'),
      for (final c in categories)
        if (c.id != null) (c.id, c.name),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
        children: [
          for (final e in entries)
            _SegmentButton(
              label: e.$2,
              selected: selected == e.$1,
              onTap: () => onSelected(e.$1),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.medium;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// "Aktuelle Werke anzeigen" / "Gruppenverzeichnis" entries
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({
    required this.showCurrent,
    required this.showGroups,
    required this.onCurrent,
    required this.onGroups,
  });

  final bool showCurrent;
  final bool showGroups;
  final VoidCallback onCurrent;
  final VoidCallback onGroups;

  @override
  Widget build(BuildContext context) {
    if (!showCurrent && !showGroups) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: Column(
        children: [
          if (showCurrent)
            ListTile(
              title: const Text('Aktuelle Werke anzeigen',
                  style: TextStyle(color: AppColors.primary)),
              onTap: onCurrent,
            ),
          if (showCurrent && showGroups) const Divider(height: 1),
          if (showGroups)
            ListTile(
              title: const Text('Gruppenverzeichnis',
                  style: TextStyle(color: AppColors.primary)),
              onTap: onGroups,
            ),
        ],
      ),
    );
  }
}

class _SongListItem extends StatelessWidget {
  const _SongListItem({
    super.key,
    required this.song,
    required this.data,
    required this.view,
    required this.onTap,
  });

  final Song song;
  final SongsListData data;
  final SongViewOptions view;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final lines = <Widget>[];
    final orchestra = data.isOrchestra;

    if (orchestra &&
        (song.instrumentIds?.isNotEmpty ?? false) &&
        view.showMissingInstruments) {
      final text = SongUtils.missingInstrumentsText(
        song.instrumentIds!,
        data.groups,
        data.groupCategories,
      );
      if (text.isNotEmpty) {
        lines.add(Text(text, style: subtitleStyle?.copyWith(color: AppColors.danger)));
      }
    }

    if (!data.isPublic && view.showLastSung) {
      if (song.lastSung != null) {
        final date = SongUtils.formatDate(song.lastSung);
        lines.add(Text(
          '${orchestra ? 'Zuletzt gespielt' : 'Zuletzt gesungen'} am $date | ${song.conductor ?? ''}',
          style: subtitleStyle,
        ));
      }
      if (song.nextPlanned != null) {
        final prefix = song.lastSung == null
            ? (orchestra ? 'Noch nicht gespielt · ' : 'Noch nicht gesungen · ')
            : '';
        lines.add(Text(
          '${prefix}Geplant am ${SongUtils.formatDate(song.nextPlanned)}',
          style: subtitleStyle,
        ));
      }
    }

    final badges = <Widget>[];
    for (final field in data.additionalFields) {
      final value = song.additionalFields?[field.id];
      if (!view.has(field.id) || !isDisplayableSongFieldValue(value)) continue;
      if (field.showUnderneath) {
        lines.add(Text(
          field.isBoolean ? field.name : '${field.name}: $value',
          style: subtitleStyle,
        ));
      }
    }

    if (song.withSolo && view.showSoloBadge) {
      badges.add(const SongBadge(color: AppColors.success, label: 'Solo'));
    }
    if (song.withChoir && view.showChoirBadge) {
      badges.add(SongBadge(
        color: AppColors.tertiary,
        label: orchestra ? 'Chor' : 'Orchester',
      ));
    }
    if ((song.link?.isNotEmpty ?? false) && view.showLink) {
      badges.add(const SongBadge(color: AppColors.primary, icon: Icons.link));
    }
    if (view.showDifficulty) {
      badges.add(SongBadge(
        color: SongUtils.difficultyColor(song.difficulty),
        label: SongUtils.difficultyLabel(song.difficulty),
      ));
    }
    for (final field in data.additionalFields) {
      final value = song.additionalFields?[field.id];
      if (!view.has(field.id) ||
          field.showUnderneath ||
          !isDisplayableSongFieldValue(value)) {
        continue;
      }
      badges.add(SongBadge(
        color: AppColors.dark,
        label: field.isBoolean ? field.name : value.toString(),
      ));
    }

    return ListTile(
      onTap: onTap,
      title: Text(
        '${song.prefix ?? ''}${song.number ?? ''} ${song.name}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: lines.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
      trailing: badges.isEmpty
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.45,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 4,
                children: badges,
              ),
            ),
    );
  }
}
