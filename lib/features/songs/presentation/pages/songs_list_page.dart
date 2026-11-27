import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/models/song/song_filter.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/common/error_state_view.dart';
import '../../../../shared/widgets/loading/skeleton_list_tile.dart';
import '../../../redesign/presentation/widgets/event/rd_current_songs_sheet.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart' show rdInputDecoration;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';
import '../widgets/group_files_sheet.dart';
import '../widgets/song_filter_sheet.dart';

/// Public read-only song catalog for the share link `/<song_sharing_id>`
/// (no login required).
class SongsListPage extends ConsumerStatefulWidget {
  const SongsListPage({super.key, required this.songSharingId});

  final String songSharingId;

  @override
  ConsumerState<SongsListPage> createState() => _SongsListPageState();
}

class _SongsListPageState extends ConsumerState<SongsListPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';

  /// Instance and category ids the stored filter was last checked against.
  String? _prunedFor;
  bool _invalidLinkToastShown = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Searchbar debounce: 250 ms.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _search = value);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(songsListDataProvider(widget.songSharingId));
    await ref.read(songsListDataProvider(widget.songSharingId).future);
  }

  void _openSong(int songId) => context.push('/${widget.songSharingId}/$songId');

  void _copyShareLink(String sharingId) {
    Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId)));
    ToastHelper.showSuccess(context, context.l10n.songsLinkCopied);
  }

  Future<void> _exportPdf(SongsListData data, List<Song> filtered, SongViewOptions view) async {
    final tenant = data.publicTenant ?? ref.read(currentTenantProvider);
    try {
      await ref.read(songPrintServiceProvider).exportSongsCatalogPdf(
            branding: null,
            songs: filtered,
            tenantShortName: tenant?.shortName ?? '',
            viewOpts: view.opts,
            showLastSung: false,
            isOrchestra: data.isOrchestra,
            additionalFields: data.additionalFields,
          );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.songsFlutterPdfCreateFailed(friendlyErrorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invalidPublicId = !SongUtils.isValidSharingId(widget.songSharingId);
    final AsyncValue<SongsListData?> dataAsync = invalidPublicId
        ? const AsyncValue.data(null)
        : ref.watch(songsListDataProvider(widget.songSharingId));
    final data = dataAsync.valueOrNull;

    if (dataAsync.hasError && !dataAsync.isLoading && data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsSongs)),
        body: ErrorStateView(error: dataAsync.error, onRetry: _refresh),
      );
    }

    if (dataAsync.hasValue && !dataAsync.isLoading && data == null) {
      if (!_invalidLinkToastShown) {
        _invalidLinkToastShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ToastHelper.showInfo(context, context.l10n.songsInvalidShareLink);
          }
        });
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settingsSongs),
          leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
          ),
        ),
        body: ErrorStateView(
          icon: Icons.link_off,
          message: context.l10n.songsInvalidShareLink,
        ),
      );
    }

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('')),
        body: ListView(
          children: List.generate(10, (_) => const SkeletonListTile(showAvatar: false)),
        ),
      );
    }

    final filter = ref.watch(songFilterProvider(data.tenantId));
    final view = ref.watch(songViewOptionsProvider(data.tenantId));
    final filterNotifier = ref.read(songFilterProvider(data.tenantId).notifier);

    final ids = data.categories.map((c) => c.id).whereType<String>().toSet();
    final idsKey = '${data.tenantId}|${(ids.toList()..sort()).join(',')}';
    if (_prunedFor != idsKey) {
      _prunedFor = idsKey;
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
    final groupsWithFiles = buildGroupsWithFiles(
      data.songs,
      data.groups,
      conductorsLabel: context.l10n.songsConductors,
      isChoir: data.tenantType == 'choir',
      choirAllLabel: context.l10n.songsChoirAll,
    );
    final showCurrentLink =
        data.currentSongs.isNotEmpty && filter.category == null && filter.categoryIds.isEmpty;
    final showQuickLinks = showCurrentLink || groupsWithFiles.isNotEmpty;
    final sharingId = data.songSharingId;
    final hasSongSharing = sharingId != null && sharingId.isNotEmpty;
    final title = data.publicTenant?.longName ?? context.l10n.settingsSongs;
    final p = context.rd;

    void onMenuSelected(String value) {
      switch (value) {
        case 'share':
          if (sharingId != null) _copyShareLink(sharingId);
        case 'pdf':
          _exportPdf(data, filtered, view);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: context.l10n.songsFlutterMenu,
            onSelected: onMenuSelected,
            itemBuilder: (context) => [
              if (hasSongSharing)
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(context.l10n.songsCopyLink),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.l10n.songsCatalogPdf),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingM,
            AppDimensions.paddingS,
            AppDimensions.paddingM,
            AppDimensions.paddingL,
          ),
          children: [
            if (data.categories.isNotEmpty) ...[
              RdChipScroller(
                children: [
                  RdChoiceChip(
                    label: context.l10n.commonAll,
                    selected: filter.category == null,
                    onTap: () => filterNotifier.setCategory(null),
                  ),
                  for (final c in data.categories)
                    if (c.id != null)
                      RdChoiceChip(
                        label: c.name,
                        selected: filter.category == c.id,
                        onTap: () => filterNotifier.setCategory(c.id),
                      ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: rdInputDecoration(p, context.l10n.attListSearchSong).copyWith(
                      prefixIcon: Icon(Icons.search, color: p.text2),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.l10n.commonClose,
                              icon: Icon(Icons.close, color: p.text2),
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SongFilterMenu(
                  data: data,
                  builder: (context, toggleMenu) => IconButton(
                    tooltip: context.l10n.songsFlutterFilterAndView,
                    icon: Badge(
                      isLabelVisible: filter.hasActiveFilters,
                      smallSize: 8,
                      child: const Icon(Icons.tune),
                    ),
                    onPressed: toggleMenu,
                  ),
                ),
              ],
            ),
            if (showQuickLinks) ...[
              const SizedBox(height: 16),
              RdGroupedList(
                children: [
                  if (showCurrentLink)
                    RdListRow(
                      title: context.l10n.songsShowCurrent,
                      titleColor: p.primary,
                      onTap: () => showCurrentSongsSheet(context, data.currentSongs),
                    ),
                  if (groupsWithFiles.isNotEmpty)
                    RdListRow(
                      title: context.l10n.songsGroupDirectory,
                      titleColor: p.primary,
                      onTap: () => showGroupFilesSheet(
                        context,
                        songs: data.songs,
                        groups: groupsWithFiles,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            RdGroupLabel(context.l10n.songsSongsCount(filtered.length)),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingXL),
                child: Column(
                  children: [
                    Icon(Icons.music_off_outlined, size: 56, color: AppColors.mediumOf(context)),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      data.songs.isEmpty ? context.l10n.songsFlutterNoSongs : context.l10n.attListNoSongsFound,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (filter.hasActiveFilters)
                      TextButton.icon(
                        onPressed: filterNotifier.reset,
                        icon: const Icon(Icons.filter_list_off),
                        label: Text(context.l10n.peopleResetFilter),
                      ),
                  ],
                ),
              )
            else
              RdGroupedList(
                children: [
                  for (final song in filtered)
                    _PublicSongRow(
                      key: ValueKey(song.id),
                      song: song,
                      data: data,
                      view: view,
                      onTap: song.id == null ? null : () => _openSong(song.id!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PublicSongRow extends StatelessWidget {
  const _PublicSongRow({
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
    final p = context.rd;
    final subtitleStyle = RdType.meta(p, size: 13);
    final lines = <Widget>[];
    final orchestra = data.isOrchestra;

    if (orchestra && (song.instrumentIds?.isNotEmpty ?? false) && view.showMissingInstruments) {
      final text = SongUtils.missingInstrumentsText(
        song.instrumentIds!,
        data.groups,
        data.groupCategories,
      );
      if (text.isNotEmpty) {
        lines.add(Text(text, style: subtitleStyle.copyWith(color: AppColors.danger)));
      }
    }

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

    final badges = <Widget>[];
    if (song.withSolo && view.showSoloBadge) {
      badges.add(SongBadge(color: AppColors.success, label: context.l10n.songsSolo));
    }
    if (song.withChoir && view.showChoirBadge) {
      badges.add(SongBadge(
        color: AppColors.tertiary,
        label: orchestra ? context.l10n.songsChoir : context.l10n.songsOrchestra,
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
      if (!view.has(field.id) || field.showUnderneath || !isDisplayableSongFieldValue(value)) {
        continue;
      }
      badges.add(SongBadge(
        color: AppColors.dark,
        label: field.isBoolean ? field.name : value.toString(),
      ));
    }

    return RdListRow(
      title: '${song.prefix ?? ''}${song.number ?? ''} ${song.name}'.trim(),
      onTap: onTap,
      trailing: badges.isEmpty
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
              child: Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 4,
                children: badges,
              ),
            ),
      footer: lines.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: lines,
            ),
    );
  }
}
