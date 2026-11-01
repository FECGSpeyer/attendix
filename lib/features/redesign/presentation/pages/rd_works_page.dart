import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../songs/data/song_print_service.dart';
import '../../../songs/presentation/pages/song_import_page.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../songs/presentation/widgets/add_song_sheet.dart';
import '../../../songs/presentation/widgets/group_files_sheet.dart';
import '../../../songs/presentation/widgets/song_categories_sheet.dart';
import '../../../songs/presentation/widgets/song_filter_sheet.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import 'rd_import_page.dart';

/// REDESIGN: tab "Werke" (canvas "WerkeListe"): search, "Gerade geprobt",
/// categories as chips, the works with PDF / Audio badges. Filter, view,
/// categories, import, PDF catalogue and the share link sit behind "Mehr";
/// the group folders behind "Dateien".
/// Search text of the Werke list, shared by every copy of the list (the
/// split view builds a new one when the first Werk opens).
final rdWorksQueryProvider = StateProvider<String>((ref) => '');

class RdWorksPage extends ConsumerStatefulWidget {
  const RdWorksPage({super.key});

  @override
  ConsumerState<RdWorksPage> createState() => _RdWorksPageState();
}

class _RdWorksPageState extends ConsumerState<RdWorksPage> {
  late final _search = TextEditingController(text: ref.read(rdWorksQueryProvider));

  String get _query => ref.read(rdWorksQueryProvider);

  void _setQuery(String value) => ref.read(rdWorksQueryProvider.notifier).state = value;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(songsProvider);
    ref.invalidate(currentSongsProvider);
    ref.invalidate(songCategoriesProvider);
    await ref.read(songsListDataProvider(null).future).catchError((_) => null);
  }

  void _openWork(int id) => RdSplitScope.open(context, RedesignRoutes.work(id));

  Future<void> _more(SongsListData data, List<Song> shown, bool isAdmin) async {
    final l10n = context.l10n;
    final sharingId = data.songSharingId;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(value: 'filter', icon: Icons.tune, label: l10n.songsFlutterFilterAndView),
        if (isAdmin)
          AppActionSheetAction(
            value: 'categories',
            icon: Icons.local_library_outlined,
            label: l10n.songsSongCategories,
          ),
        if (sharingId != null && sharingId.isNotEmpty)
          AppActionSheetAction(value: 'share', icon: Icons.link, label: l10n.songsCopyLink),
        if (isAdmin)
          AppActionSheetAction(value: 'import', icon: Icons.cloud_upload_outlined, label: l10n.songsImportSongs),
        if (isAdmin && _canImportFiles)
          AppActionSheetAction(value: 'importFiles', icon: Icons.folder_zip_outlined, label: l10n.redesignImportTitle),
        AppActionSheetAction(value: 'pdf', icon: Icons.description_outlined, label: l10n.songsCatalogPdf),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'filter':
        await showSongFilterSheet(context, data);
      case 'categories':
        await showSongCategoriesSheet(context);
      case 'share':
        await Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId!)));
        if (mounted) ToastHelper.showSuccess(context, l10n.songsLinkCopied);
      case 'import':
        final imported = await Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SongImportPage()),
        );
        if (imported == true) {
          ref.invalidate(songsProvider);
          ref.invalidate(songsListDataProvider);
        }
      case 'importFiles':
        await _importFiles();
      case 'pdf':
        await _exportPdf(data, shown);
    }
  }

  /// "Noten importieren" is for the own library only (a synced instance
  /// shows the Werke of another one).
  bool get _canImportFiles {
    final source = ref.read(songTenantSettingsProvider).valueOrNull?.songSourceTenantId;
    return source == null || source == ref.read(currentTenantIdProvider);
  }

  Future<void> _importFiles() async {
    final imported = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const RdImportPage()),
    );
    if (imported == true) {
      ref.invalidate(songsProvider);
      ref.invalidate(songsListDataProvider);
    }
  }

  /// "+": a new Werk, or several from a ZIP ("Noten importieren").
  Future<void> _add(SongsListData data) async {
    final l10n = context.l10n;
    final action = _canImportFiles
        ? await showAppActionSheet<String>(
            context,
            actions: [
              AppActionSheetAction(value: 'add', icon: Icons.add, label: l10n.redesignWorksAdd),
              AppActionSheetAction(
                value: 'importFiles',
                icon: Icons.folder_zip_outlined,
                label: l10n.redesignImportTitle,
                subtitle: l10n.redesignImportMenuHint,
              ),
            ],
          )
        : 'add';
    if (!mounted || action == null) return;
    if (action == 'importFiles') {
      await _importFiles();
      return;
    }
    final id = await showAddSongSheet(context, data);
    if (id != null && mounted) _openWork(id);
  }

  Future<void> _exportPdf(SongsListData data, List<Song> shown) async {
    final tenant = ref.read(currentTenantProvider);
    final view = ref.read(songViewOptionsProvider(data.tenantId));
    try {
      final branding = await resolvePdfBranding(ref);
      await ref.read(songPrintServiceProvider).exportSongsCatalogPdf(
            branding: branding,
            songs: shown,
            tenantShortName: tenant?.shortName ?? '',
            viewOpts: view.opts,
            showLastSung: true,
            isOrchestra: data.isOrchestra,
            additionalFields: data.additionalFields,
          );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.songsFlutterPdfCreateFailed(friendlyErrorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    ref.watch(songsRealtimeProvider);
    // Every copy of the list shows the shared search text (e.g. back from
    // the split view after searching there).
    ref.listen(rdWorksQueryProvider, (_, next) {
      if (_search.text != next) _search.text = next;
    });
    ref.watch(rdWorksQueryProvider);
    final role = ref.watch(effectiveRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final async = ref.watch(songsListDataProvider(null));
    final data = async.valueOrNull;

    final header = <Widget>[
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l10n.redesignTabWorks, style: RdType.largeTitle(p)),
            ),
          ),
          if (data != null) ...[
            if (buildGroupsWithFiles(data.songs, data.groups, conductorsLabel: l10n.songsConductors).isNotEmpty) ...[
              RdPillButton(
                icon: Icons.folder_outlined,
                label: l10n.redesignWorksFiles,
                semanticLabel: l10n.redesignWorksFilesLabel,
                onPressed: () => showGroupFilesSheet(
                  context,
                  songs: data.songs,
                  groups: buildGroupsWithFiles(data.songs, data.groups, conductorsLabel: l10n.songsConductors),
                ),
              ),
              const SizedBox(width: 8),
            ],
            RdCircleButton(
              icon: Icons.more_horiz,
              label: l10n.redesignWorksMore,
              onPressed: () => _more(data, _shown(data), isAdmin),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: _setQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: l10n.redesignWorksSearch,
          prefixIcon: Icon(Icons.search, color: p.text2),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: p.text2),
                  tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  onPressed: () {
                    _search.clear();
                    _setQuery('');
                  },
                ),
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (data == null) {
      return RdPage(
        onRefresh: _refresh,
        children: [
          ...header,
          async.hasError && !async.isLoading
              ? RdInfoCard(
                  text: l10n.redesignTodayLoadFailed,
                  icon: Icons.cloud_off_outlined,
                  action: RdOutlineButton(label: l10n.redesignCommonRetry, onPressed: _refresh),
                )
              : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
        ],
      );
    }

    final filter = ref.watch(songFilterProvider(data.tenantId));
    final filterNotifier = ref.read(songFilterProvider(data.tenantId).notifier);
    final shown = _shown(data);
    final current = _query.trim().isEmpty && filter.category == null ? rdCurrentWorks(data.currentSongs, data.songs) : const <Song>[];
    final categories = [...data.categories.where((c) => c.id != null)]..sort((a, b) => a.index.compareTo(b.index));

    return RdPage(
      onRefresh: _refresh,
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              tooltip: l10n.redesignWorksAdd,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => _add(data),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      children: [
        ...header,
        if (current.isNotEmpty) ...[
          RdSectionHeader(l10n.redesignWorksCurrent),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: current.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _CurrentCard(
                song: current[i],
                onTap: current[i].id == null ? null : () => _openWork(current[i].id!),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (categories.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                RdChoiceChip(
                  label: l10n.redesignWorksAll(data.songs.length),
                  selected: filter.category == null,
                  onTap: () => filterNotifier.setCategory(null),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: 8),
                  RdChoiceChip(
                    label: c.name,
                    selected: filter.category == c.id,
                    onTap: () => filterNotifier.setCategory(filter.category == c.id ? null : c.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (filter.hasActiveFilters)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                RdPill(l10n.redesignWorksFilterActive, tone: RdTone.primary, icon: Icons.tune),
                const Spacer(),
                RdTextLink(label: l10n.redesignWorksResetFilter, onTap: filterNotifier.reset),
              ],
            ),
          ),
        if (shown.isEmpty)
          RdInfoCard(
            icon: Icons.music_off_outlined,
            text: data.songs.isEmpty ? l10n.redesignWorksEmpty : l10n.redesignWorksNoMatch,
          )
        else
          RdGroupedList(children: [
            for (final song in shown)
              _WorkRow(
                key: ValueKey('rd-work-${song.id}'),
                song: song,
                selected: song.id != null && RdSplitScope.of(context)?.selectedId == song.id,
                onTap: song.id == null ? null : () => _openWork(song.id!),
              ),
          ]),
      ],
    );
  }

  /// Persisted filter and sort of the old list, plus the search over
  /// title, composer and number.
  List<Song> _shown(SongsListData data) {
    final filter = ref.read(songFilterProvider(data.tenantId));
    return applySongFilter(data.songs, filter, additionalFields: data.additionalFields)
        .where((s) => rdWorkMatches(s, _query))
        .toList();
  }
}

/// Card of "Gerade geprobt".
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.song, required this.onTap});

  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return SizedBox(
      width: 230,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.music_note_outlined, size: 22, color: p.softText),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                      ),
                      if ((song.composer ?? '').isNotEmpty)
                        Text(
                          song.composer!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RdType.meta(p, size: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Number, title, composer, PDF / Audio.
class _WorkRow extends StatelessWidget {
  const _WorkRow({super.key, required this.song, required this.onTap, this.selected = false});

  final Song song;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final number = song.fullNumber;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? p.soft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.text2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                        ),
                        if ((song.composer ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              song.composer!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RdType.meta(p, size: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (rdHasPdf(song)) ...[const SizedBox(width: 6), RdPill(l10n.redesignWorksPdf)],
                  if (rdHasAudio(song)) ...[
                    const SizedBox(width: 6),
                    RdPill(l10n.redesignWorksAudio, tone: RdTone.primary),
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 20, color: p.text2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
