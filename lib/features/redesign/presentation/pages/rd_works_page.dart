import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart' show canAccessFilesProvider;
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_filter.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../history/presentation/pages/history_page.dart' show showHistoryModal;
import '../../../songs/data/song_print_service.dart';
import '../../../songs/presentation/pages/song_import_page.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../songs/presentation/widgets/song_categories_sheet.dart';
import '../../data/import/rd_import_controller.dart' show rdImportOwnLibraryProvider;
import '../../data/providers/rd_works_filter.dart';
import '../../data/rd_collections_logic.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/works/rd_collections_ui.dart';
import '../widgets/works/rd_works_filter_sheet.dart';
import 'rd_folder_page.dart' show rdEventLabel;

/// Search text of the Werke list, shared by every copy of the list (the
/// split view builds a new one when the first Werk opens).
final rdWorksQueryProvider = StateProvider<String>((ref) {
  // A search does not follow into another group or account.
  ref.watch(currentTenantIdProvider);
  return '';
});

/// REDESIGN: tab "Werke" (canvas "Werke neu gedacht", board "Liste"):
/// search, "Als Nächstes" (members: the own Noten for the next Termin,
/// leads: where Noten are missing), categories as chips, sort and filter,
/// every Werk with one status line. "Meine Noten" / "Nach Stimme" opens the
/// Noten of one part, "+" adds, imports or takes over Werke; categories, the
/// share link and the PDF list sit behind "•••". With Sammlungen (canvas
/// "Noten-Bereich neu gedacht") their chips replace the category chips (the
/// categories move into the filter sheet), the list shows the chosen
/// Sammlung and a search looks through every Sammlung the viewer sees.
class RdWorksPage extends ConsumerStatefulWidget {
  const RdWorksPage({super.key});

  @override
  ConsumerState<RdWorksPage> createState() => _RdWorksPageState();
}

class _RdWorksPageState extends ConsumerState<RdWorksPage> {
  late final _search = TextEditingController(text: ref.read(rdWorksQueryProvider));

  /// "Meine Noten öffnen" is building its PDF.
  bool _printing = false;

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

  /// "•••": rarely needed list actions (filter, import and the group
  /// folders have their own places now).
  Future<void> _more(SongsListData data, List<Song> shown, bool isAdmin) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    final sharingId = data.songSharingId;
    // Sammlungen once the database has them (null before the migration).
    final collections = ref.read(songCollectionsProvider).valueOrNull != null;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        if (isAdmin && collections)
          AppActionSheetAction(
            value: 'collections',
            icon: Icons.folder_copy_outlined,
            label: l10n.collectionsManage,
          ),
        if (isAdmin)
          AppActionSheetAction(
            value: 'categories',
            icon: Icons.local_library_outlined,
            label: l10n.redesignWorkEditManageCategories,
          ),
        // From the old Verwaltung (canvas "Werke-Tab: •••"): Werkhistorie
        // for leads and helpers, the Dateiablage for everyone with access.
        if (isAdmin || role.isHelperRole)
          AppActionSheetAction(value: 'history', icon: Icons.history, label: l10n.rdAdminWorkHistory),
        if (ref.read(canAccessFilesProvider))
          AppActionSheetAction(value: 'files', icon: Icons.folder_outlined, label: l10n.settingsFileStorage),
        if (sharingId != null && sharingId.isNotEmpty)
          AppActionSheetAction(value: 'share', icon: Icons.link, label: l10n.songsCopyLink),
        AppActionSheetAction(value: 'pdf', icon: Icons.description_outlined, label: l10n.songsCatalogPdf),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'collections':
        await context.push(RedesignRoutes.collections);
      case 'categories':
        await showSongCategoriesSheet(context);
      case 'history':
        await showHistoryModal(context);
      case 'files':
        await context.push('/settings/files');
      case 'share':
        await Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId!)));
        if (mounted) ToastHelper.showSuccess(context, l10n.songsLinkCopied);
      case 'pdf':
        await _exportPdf(data, shown);
    }
  }

  /// "+": a new Werk, a work list from Excel, or Werke of another group of
  /// the organisation.
  Future<void> _add(SongsListData data, {BuildContext? anchor}) async {
    final l10n = context.l10n;
    // "Aus der Organisation" needs the organisation: wait for it to load.
    var org = false;
    try {
      org = await ref.read(currentOrganisationProvider.future).timeout(const Duration(seconds: 5)) != null;
    } catch (_) {}
    final ownLibrary = await ref.read(rdImportOwnLibraryProvider.future).catchError((_) => false);
    if (!mounted) return;
    if (!mounted || (anchor != null && !anchor.mounted)) return;
    final action = await showAppActionSheet<String>(
      context,
      title: l10n.redesignWorksAdd,
      anchor: anchor,
      actions: [
        AppActionSheetAction(
          value: 'new',
          icon: Icons.add,
          label: l10n.redesignWorksAddNew,
          subtitle: l10n.redesignWorksAddNewHint,
        ),
        AppActionSheetAction(
          value: 'import',
          icon: Icons.table_chart_outlined,
          label: l10n.redesignWorksAddImport,
          subtitle: l10n.redesignWorksAddImportHint,
        ),
        if (ownLibrary)
          AppActionSheetAction(
            value: 'files',
            icon: Icons.folder_zip_outlined,
            label: l10n.redesignImportTitle,
            subtitle: l10n.redesignImportMenuHint,
          ),
        if (org)
          AppActionSheetAction(
            value: 'org',
            icon: Icons.travel_explore,
            label: l10n.redesignWorksAddOrg,
            subtitle: l10n.redesignWorksAddOrgHint,
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'new':
        // In the Sammlung the list shows.
        final collection = rdShownCollectionId(
          ref.read(rdWorksCollectionProvider),
          ref.read(rdVisibleCollectionsProvider),
        );
        await context.push(
          collection == null ? RedesignRoutes.newWork : '${RedesignRoutes.newWork}?sammlung=$collection',
        );
      case 'import':
        final imported = await Navigator.of(
          context,
          rootNavigator: true,
        ).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SongImportPage()));
        if (imported == true && mounted) {
          ref.invalidate(songsProvider);
          ref.invalidate(songsListDataProvider);
        }
      case 'files':
        // "Noten importieren": its controller refreshes the Werke.
        await context.push(RedesignRoutes.worksImport);
      case 'org':
        await context.push('/settings/org-settings/songs');
    }
  }

  Future<void> _exportPdf(SongsListData data, List<Song> shown) async {
    final tenant = ref.read(currentTenantProvider);
    final view = ref.read(songViewOptionsProvider(data.tenantId));
    try {
      final branding = await resolvePdfBranding(ref);
      await ref
          .read(songPrintServiceProvider)
          .exportSongsCatalogPdf(
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

  /// "Meine Noten öffnen": the own parts of the next Termin as one PDF.
  /// Locked while the PDF is built (no second PDF on a double tap).
  Future<void> _openMine(List<SongPrintEntry> entries, String name) async {
    if (_printing) return;
    final l10n = context.l10n;
    setState(() => _printing = true);
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final result = await ref.read(songPrintServiceProvider).printEntries(entries, 'Noten_${name}_$date.pdf');
      if (!mounted || result == null) return;
      if (result.pageCount == 0) {
        ToastHelper.showWarning(context, l10n.svcNoPrintableScores);
      } else if (result.skipped > 0) {
        ToastHelper.showWarning(context, l10n.songsFlutterFilesSkipped(result.skipped));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
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
    final lead = role.isConductor;
    final async = ref.watch(songsListDataProvider(null));
    final data = async.valueOrNull;
    // Sammlungen: null before the database has them (then as before).
    final visibleCollections = ref.watch(rdVisibleCollectionsProvider);
    final chosenCollection = rdShownCollectionId(ref.watch(rdWorksCollectionProvider), visibleCollections);
    final withCollections = visibleCollections != null && visibleCollections.isNotEmpty;
    final inSplit = RdSplitScope.of(context) != null;

    final header = <Widget>[
      Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(l10n.redesignTabWorks, style: RdType.largeTitle(p)))),
          if (data != null) ...[
            RdPillButton(
              icon: Icons.queue_music_outlined,
              label: lead ? l10n.redesignWorksFolders : l10n.redesignWorksFolder,
              onPressed: () => context.push(RedesignRoutes.folder),
            ),
            const SizedBox(width: 8),
            RdCircleButton(
              icon: Icons.more_horiz,
              label: l10n.redesignWorksMore,
              onPressed: () => _more(data, _shown(data), isAdmin),
            ),
            // Desktop (list next to the Werk): the one "+" sits here.
            if (isAdmin && inSplit) ...[
              const SizedBox(width: 8),
              Builder(
                builder: (button) => RdCircleButton(
                  key: const Key('rd-works-add'),
                  icon: Icons.add,
                  label: l10n.redesignWorksAdd,
                  primary: true,
                  onPressed: () => _add(data, anchor: button),
                ),
              ),
            ],
          ],
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _search,
        onChanged: _setQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: withCollections ? l10n.collectionsSearchAll : l10n.redesignWorksSearch,
          prefixIcon: Icon(Icons.search, color: p.text2),
          suffixIcon:
              _query.isEmpty
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(p.buttonRadius), borderSide: BorderSide.none),
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
    final only = ref.watch(rdWorksOnlyProvider);
    ref.watch(currentSelfServicePlayerProvider);
    final ownGroup = _ownGroup(data);
    final counts = lead ? ref.watch(missingGroupsPlayerCountsProvider) : null;
    final shown = _shown(data);
    final events = _query.trim().isEmpty ? _nextEvents(data) : const <RdNextEvent>[];
    final categories = [...data.categories.where((c) => c.id != null)]..sort((a, b) => a.index.compareTo(b.index));
    final sort = filter.sortOption;
    final byLast = sort == SongSortOption.lastSungAsc || sort == SongSortOption.lastSungDesc;
    // With Sammlungen the category sits in the filter sheet and counts there.
    final filterCount =
        filter.activeFilterCount + only.length + (withCollections && filter.category != null ? 1 : 0);
    final listData = _scoped(data);
    final searching = _query.trim().isNotEmpty;

    String baseStatus(Song song) {
      final cats = rdCategoryNames(song, data.categories);
      if (lead) {
        final last = DateTime.tryParse(song.lastSung ?? '');
        return [
          if (byLast)
            last == null
                ? (data.isOrchestra ? l10n.redesignWorksNeverPlayed : l10n.redesignWorksNeverSung)
                : l10n.redesignWorksLastOn(SongUtils.formatDate(song.lastSung)),
          ...cats,
        ].join(' · ');
      }
      final files = song.files ?? const <SongFile>[];
      final part = ownGroup != null && rdMemberPartFiles(song, ownGroup.id, choir: data.isChoir).isNotEmpty;
      // What is missing first, the categories last (cut on small phones).
      return [
        if (!rdHasNotes(song))
          l10n.redesignWorksStatusNoFiles
        else if (!part && ownGroup != null && files.any(rdIsGroupPart))
          l10n.redesignWorksStatusNoPart(ownGroup.name),
        if (part) l10n.redesignWorksStatusPart,
        if (rdRecording(song) != null) l10n.redesignWorksStatusRecording,
        ...cats,
      ].join(' · ');
    }

    String status(Song song) {
      // A search finds Werke of other Sammlungen: their name comes first.
      final elsewhere =
          withCollections && searching && song.collectionId != chosenCollection
              ? rdCollectionName(l10n, visibleCollections, song.collectionId)
              : null;
      return [if (elsewhere != null) elsewhere, baseStatus(song)].where((t) => t.isNotEmpty).join(' · ');
    }

    Widget? pill(Song song) {
      if (!lead) return null;
      if (!rdHasNotes(song)) return RdPill(l10n.redesignWorksNoFilesPill, tone: RdTone.late);
      if (!data.isOrchestra) return null;
      final missing = rdWorkMissingGroups(song, data.groups, counts);
      if (missing.isEmpty) return null;
      return RdPill(
        missing.length == 1
            ? l10n.redesignWorkMissingPillOne(missing.single.name)
            : l10n.redesignWorkMissingPillMany(missing.length),
        tone: RdTone.late,
      );
    }

    return RdPage(
      onRefresh: _refresh,
      floatingActionButton:
          isAdmin && !inSplit
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
        if (events.isNotEmpty) ...[
          RdSectionHeader(
            l10n.redesignWorksNext,
            action: RdTextLink(label: l10n.redesignWorksAllEvents, onTap: () => context.go(RedesignRoutes.events)),
          ),
          if (lead)
            RdGroupedList(
              children: [
                for (final e in events.take(3))
                  _LeadEventRow(
                    event: e,
                    missing: e.songs.any((s) => rdWorkLacksNotes(s, data.groups, counts, orchestra: data.isOrchestra)),
                    onTap:
                        e.attendanceId == null || !role.canAddAttendance
                            ? null
                            : () => context.push(RedesignRoutes.event(e.attendanceId!)),
                  ),
              ],
            )
          else
            ..._memberNext(context, events, ownGroup, data.isChoir, status),
          const SizedBox(height: 18),
        ],
        if (withCollections) ...[
          RdCollectionChips(
            collections: visibleCollections,
            songs: rdVisibleWorks(data.songs, visibleCollections),
            selected: chosenCollection,
            onSelected: (id) => ref.read(rdWorksCollectionProvider.notifier).state = id,
          ),
          const SizedBox(height: 10),
        ] else if (categories.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                RdChoiceChip(
                  label: l10n.redesignWorksAll(listData.songs.length),
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
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child:
                  sort != SongSortOption.numberAsc
                      ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _SortChip(
                          label: rdWorksSortLabel(l10n, sort, orchestra: data.isOrchestra),
                          onRemove: () => filterNotifier.setSortOption(SongSortOption.numberAsc),
                        ),
                      )
                      : Text(l10n.redesignWorksEventWorks(shown.length), style: RdType.meta(p, size: 13)),
            ),
            _FilterLink(
              label: filterCount > 0 ? '${l10n.redesignWorksFilter} · $filterCount' : l10n.redesignWorksFilter,
              onTap:
                  () => showRdWorksFilterSheet(
                    context,
                    data: listData,
                    lead: lead,
                    groupId: ownGroup?.id,
                    playerCounts: counts,
                    query: _query,
                    withCategories: withCollections,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (shown.isEmpty)
          RdInfoCard(
            icon: Icons.music_off_outlined,
            text:
                data.songs.isEmpty
                    ? l10n.redesignWorksEmpty
                    : listData.songs.isEmpty && !searching
                    ? l10n.collectionsEmptyIn(rdCollectionName(l10n, visibleCollections, chosenCollection))
                    : l10n.redesignWorksNoMatch,
            action:
                filterCount > 0
                    ? RdOutlineButton(
                      label: l10n.redesignWorksResetFilter,
                      onPressed: () {
                        filterNotifier.reset();
                        if (withCollections) filterNotifier.setCategory(null);
                        ref.read(rdWorksOnlyProvider.notifier).state = const {};
                      },
                    )
                    : null,
          )
        else
          RdGroupedList(
            children: [
              for (final song in shown)
                _WorkRow(
                  key: ValueKey('rd-work-${song.id}'),
                  song: song,
                  subtitle: status(song),
                  pill: pill(song),
                  selected: song.id != null && RdSplitScope.of(context)?.selectedId == song.id,
                  onTap: song.id == null ? null : () => _openWork(song.id!),
                ),
            ],
          ),
      ],
    );
  }

  /// Members: the next Termin with its Werke and "Meine Noten öffnen", the
  /// one after it as a single line.
  List<Widget> _memberNext(
    BuildContext context,
    List<RdNextEvent> events,
    Group? ownGroup,
    bool choir,
    String Function(Song) status,
  ) {
    final l10n = context.l10n;
    final p = context.rd;
    final first = events.first;
    final mine = [
      if (ownGroup != null)
        for (final song in first.songs)
          for (final f in rdMemberPartFiles(song, ownGroup.id, choir: choir))
            if (SongUtils.isPdf(f) || SongUtils.isImage(f)) SongPrintEntry(song: song, file: f),
    ];
    return [
      RdGroupedList(
        children: [
          RdListRow(
            leading: RdRowIcon(Icons.event_outlined, color: p.softText, background: p.soft),
            title: rdEventLabel(first),
            subtitle: l10n.redesignWorksEventWorks(first.songs.length),
            showChevron: false,
          ),
          for (final song in first.songs)
            _WorkRow(song: song, subtitle: status(song), onTap: song.id == null ? null : () => _openWork(song.id!)),
          if (mine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RdPrimaryButton(
                    key: const Key('rd-works-open-mine'),
                    icon: Icons.picture_as_pdf_outlined,
                    label: l10n.redesignWorksOpenMine,
                    loading: _printing,
                    onPressed: () => _openMine(mine, ownGroup!.name),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.redesignWorksOpenMineHint(mine.length),
                      textAlign: TextAlign.center,
                      style: RdType.meta(p, size: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      for (final e in events.skip(1).take(1)) ...[
        const SizedBox(height: 10),
        RdGroupedList(
          children: [
            RdListRow(
              leading: RdRowIcon(Icons.event_outlined, color: p.text2, background: p.track),
              title: rdEventLabel(e),
              subtitle: '${l10n.redesignWorksEventWorks(e.songs.length)} · ${e.songs.map((s) => s.name).join(', ')}',
              onTap: e.songs.length == 1 && e.songs.single.id != null ? () => _openWork(e.songs.single.id!) : null,
              showChevron: e.songs.length == 1,
            ),
          ],
        ),
      ],
    ];
  }

  /// The coming Termine with Werke, without those already over today (the
  /// times come from the loaded Termine, see [rdWithoutEndedEvents]).
  List<RdNextEvent> _nextEvents(SongsListData data) => rdWithoutEndedEvents(
    rdNextEvents(data.currentSongs, data.songs),
    now: DateTime.now(),
    attendances: ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const [],
    types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
  );

  /// The own group of a member (never the main group of the conductor), the
  /// same for the list, the status lines and the filter sheet.
  Group? _ownGroup(SongsListData data) {
    final groupId = ref.read(currentSelfServicePlayerProvider).valueOrNull?.instrument;
    return data.groups.where((g) => g.id == groupId && g.maingroup != true).firstOrNull;
  }

  /// The Werke the list works on: those of the chosen Sammlung, during a
  /// search those of every Sammlung the viewer sees; without Sammlungen in
  /// the database all of them.
  SongsListData _scoped(SongsListData data) {
    final visible = ref.read(rdVisibleCollectionsProvider);
    if (visible == null) {
      // Visibility unknown (loading/failed): members only see the Werke
      // outside every Sammlung, leads all.
      return ref.read(effectiveRoleProvider).isConductor ? data : data.withSongs(rdVisibleWorks(data.songs, const []));
    }
    final songs = rdVisibleWorks(data.songs, visible);
    if (visible.isEmpty || _query.trim().isNotEmpty) return data.withSongs(songs);
    final chosen = rdShownCollectionId(ref.read(rdWorksCollectionProvider), visible);
    return data.withSongs(rdWorksIn(songs, chosen));
  }

  /// The filtered and sorted Werke (see [rdFilteredWorks]).
  List<Song> _shown(SongsListData data) {
    final lead = ref.read(effectiveRoleProvider).isConductor;
    return rdFilteredWorks(
      data: _scoped(data),
      filter: ref.read(songFilterProvider(data.tenantId)),
      only: ref.read(rdWorksOnlyProvider),
      query: _query,
      groupId: _ownGroup(data)?.id,
      playerCounts: lead ? ref.read(missingGroupsPlayerCountsProvider) : null,
    );
  }
}

/// Leads: a coming Termin with its Werke and, below, "Noten fehlen" when a
/// Werk still lacks Noten (a pill next to the title would squeeze it).
class _LeadEventRow extends StatelessWidget {
  const _LeadEventRow({required this.event, required this.missing, required this.onTap});

  final RdNextEvent event;
  final bool missing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                RdRowIcon(Icons.event_outlined, color: p.softText, background: p.soft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rdEventLabel(event),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          event.songs.map((s) => s.name).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RdType.meta(p, size: 13),
                        ),
                      ),
                      if (missing)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: RdPill(context.l10n.redesignWorksMissingNotes, tone: RdTone.late),
                        ),
                    ],
                  ),
                ),
                if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.chevron_right, size: 20, color: p.text2)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen sort order above the list, removable.
class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      label: context.l10n.redesignWorksSortRemove(label),
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onRemove,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.softText),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.close, size: 16, color: p.softText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Filter" (with the number of active filters) above the list.
class _FilterLink extends StatelessWidget {
  const _FilterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 18, color: p.link),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 15, color: p.link)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Number, title, one status line and a pill (leads: missing Noten).
class _WorkRow extends StatelessWidget {
  const _WorkRow({
    super.key,
    required this.song,
    required this.subtitle,
    required this.onTap,
    this.pill,
    this.selected = false,
  });

  final Song song;
  final String subtitle;
  final Widget? pill;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final number = song.fullNumber;
    final second = subtitle.isNotEmpty ? subtitle : (song.composer ?? '');
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
                        if (second.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              second,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RdType.meta(p, size: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (pill != null) ...[const SizedBox(width: 6), pill!],
                  if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.chevron_right, size: 20, color: p.text2)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
