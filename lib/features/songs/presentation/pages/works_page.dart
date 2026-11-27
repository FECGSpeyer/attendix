import 'package:flutter/material.dart';
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
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_filter.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';
import '../widgets/song_categories_sheet.dart';
import '../../data/import/import_controller.dart' show rdImportOwnLibraryProvider;
import '../../data/providers/shared_library.dart';
import '../../data/providers/works_filter.dart';
import '../../data/collections_logic.dart';
import '../../data/works_logic.dart';
import '../../../../shared/widgets/components/split_view.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;
import '../widgets/works/collections_ui.dart';
import '../widgets/works/current_works.dart';
import '../widgets/works/works_filter_sheet.dart';
import '../../../../shared/widgets/components/actions.dart' show rdShareLink;
import '../../../settings/presentation/pages/general_settings_page.dart' show rdEnableWorksSharing;

part 'works_page_sheets.dart';

/// Search text of the Werke list, shared by every copy of the list (the
/// split view builds a new one when the first Werk opens).
final rdWorksQueryProvider = StateProvider<String>((ref) {
  // A search does not follow into another group or account.
  ref.watch(currentTenantIdProvider);
  return '';
});

/// REDESIGN: tab "Werke" (canvas "Werke neu gedacht", board "Liste"):
/// search, "Aktuell" (canvas "Aktuelle Noten im Werke-Tab": one row of
/// cards with the Werke played right now, a tap opens the own part or, for
/// the conductor, the score), categories as chips, sort and filter, every Werk with one status
/// line. "+" adds, imports or takes over Werke; "Noten nach Stimme",
/// Sammlungen, the share link and the PDF list sit behind "•••". With
/// Sammlungen (canvas "Noten-Bereich neu gedacht") their chips come first
/// as the one row of chips and the categories move into the filter sheet
/// (shown as a removable chip above the list once chosen); the list shows
/// the chosen Sammlung and a search looks through every Sammlung the viewer
/// sees. Leads manage the categories behind "•••" and in the filter sheet.
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
    // A failed settings load fell back to the own library: read it again.
    if (ref.read(songTenantSettingsFailedProvider)) ref.invalidate(songTenantSettingsProvider);
    ref.invalidate(songsProvider);
    ref.invalidate(currentSongsProvider);
    ref.invalidate(songCategoriesProvider);
    ref.invalidate(songCollectionsProvider);
    await ref.read(songsListDataProvider(null).future).catchError((_) => null);
  }

  void _openWork(int id) => RdSplitScope.open(context, RedesignRoutes.work(id));

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
    // The Werke of another group (Werk-Synchronisierung): a note says so,
    // and "+" and the manage entries need a lead role there.
    final shared = ref.watch(rdSharedLibrarySourceProvider) != null;
    final sharedName = ref.watch(rdSharedLibraryNameProvider);
    final org = isAdmin ? ref.watch(currentOrganisationProvider).valueOrNull : null;
    final hasOrgOthers = org != null && (ref.watch(linkedTenantsProvider).valueOrNull?.isNotEmpty ?? false);
    final canManage = isAdmin && ref.watch(rdLibraryEditableProvider);
    final async = ref.watch(songsListDataProvider(null));
    // Which library the group uses could not be read: what loaded may be
    // the own, empty one instead of the shared Werke. No list and no "+"
    // (a new Werk would land in the wrong library) until it is known.
    final sourceUnknown = ref.watch(songTenantSettingsFailedProvider);
    final data = sourceUnknown ? null : async.valueOrNull;
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
            RdCircleButton(
              icon: Icons.more_horiz,
              label: l10n.redesignWorksMore,
              onPressed: () => _more(data, _shown(data), isAdmin),
            ),
            // Desktop (list next to the Werk): the one "+" sits here.
            if (canManage && inSplit) ...[
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
          sourceUnknown || (async.hasError && !async.isLoading)
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
    // What is played right now (members and leads), not during a search.
    final current = _query.trim().isEmpty ? _currentWorks(data) : const <RdCurrentWork>[];
    final categories = [...data.categories.where((c) => c.id != null)]..sort((a, b) => a.index.compareTo(b.index));
    final sort = filter.sortOption;
    final byLast = sort == SongSortOption.lastSungAsc || sort == SongSortOption.lastSungDesc;
    final listData = _scoped(data);
    // Categories (several per Werk) are the one row of chips without
    // Sammlungen; with Sammlungen a filter (only those used in the shown
    // Werke), so one row of chips never means two things.
    final sheetCategories =
        withCollections
            ? rdUsedCategories(categories, listData.songs, selected: filter.category)
            : const <SongCategory>[];
    final chosenCategory = withCollections ? categories.where((c) => c.id == filter.category).firstOrNull : null;
    final filterCount = filter.activeFilterCount + only.length + (chosenCategory != null ? 1 : 0);
    // A stored category that no longer exists would filter without a chip
    // to clear it (Ionic getSongs drops it too).
    final categoryIds = categories.map((c) => c.id!).toSet();
    if (filter.category != null && !categoryIds.contains(filter.category)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) filterNotifier.pruneCategories(categoryIds);
      });
    }
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

    // Only a Werk without any Noten gets a (calm) pill: not every Werk has
    // a part for every group, so single missing parts stay on the Werk page.
    Widget? pill(Song song) => lead && !rdHasNotes(song) ? RdPill(l10n.redesignWorksNoFilesPill) : null;

    return RdPage(
      onRefresh: _refresh,
      floatingActionButton:
          canManage && !inSplit
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
        // Not before the name is known (no text that changes a moment later).
        if (shared && !sharedName.isLoading)
          Padding(
            key: const Key('rd-works-shared-note'),
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RdOrgPill(
                  sharedName.valueOrNull == null
                      ? l10n.rdOrgBadge
                      : l10n.rdOrgBadgeGroup(sharedName.valueOrNull!),
                  compact: true,
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    sharedName.valueOrNull == null
                        ? l10n.rdWmSharedFromOther
                        : l10n.rdWmSharedFrom(sharedName.valueOrNull!),
                    // The second sentence once the roles in that group are known.
                    if (isAdmin && ref.watch(userTenantsProvider).hasValue)
                      canManage ? l10n.rdWmSharedEditable : l10n.rdWmSharedLocked,
                  ].join(' '),
                  style: RdType.meta(p, size: 13),
                ),
              ],
            ),
          ),
        if (current.isNotEmpty) ...[
          RdCurrentWorksStrip(works: current, ownGroup: ownGroup, choir: data.isChoir),
          const SizedBox(height: 18),
        ],
        if (withCollections) ...[
          RdCollectionChips(
            collections: visibleCollections,
            songs: rdVisibleWorks(data.songs, visibleCollections),
            selected: chosenCollection,
            onSelected: (id) {
              // A category of the old Sammlung may not exist in the new one.
              if (id != chosenCollection) filterNotifier.setCategory(null);
              ref.read(rdWorksCollectionProvider.notifier).state = id;
            },
          ),
          const SizedBox(height: 10),
        ],
        if (!withCollections && categories.isNotEmpty) ...[
          SingleChildScrollView(
            key: const Key('rd-works-categories'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                RdChoiceChip(
                  label: l10n.redesignWorksAll(listData.songs.length),
                  selected: filter.category == null,
                  onTap: () => filterNotifier.setCategory(null),
                ),
                const SizedBox(width: 8),
                for (final c in categories) ...[
                  RdChoiceChip(
                    key: Key('rd-works-category-${c.id}'),
                    label: c.name,
                    selected: filter.category == c.id,
                    onTap: () => filterNotifier.setCategory(filter.category == c.id ? null : c.id),
                  ),
                  const SizedBox(width: 8),
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
                  sort != SongSortOption.numberAsc || chosenCategory != null
                      ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (chosenCategory != null)
                              RdRemovableChip(
                                key: const Key('rd-works-category-chosen'),
                                label: chosenCategory.name,
                                semanticLabel: l10n.rdWmCategoryRemove(chosenCategory.name),
                                onRemove: () => filterNotifier.setCategory(null),
                              ),
                            if (sort != SongSortOption.numberAsc)
                              RdRemovableChip(
                                label: rdWorksSortLabel(l10n, sort, orchestra: data.isOrchestra),
                                semanticLabel: l10n.redesignWorksSortRemove(
                                  rdWorksSortLabel(l10n, sort, orchestra: data.isOrchestra),
                                ),
                                onRemove: () => filterNotifier.setSortOption(SongSortOption.numberAsc),
                              ),
                          ],
                        ),
                      )
                      : Text(l10n.redesignWorksEventWorks(shown.length), style: RdType.meta(p, size: 13)),
            ),
            RdFilterLink(
              label: filterCount > 0 ? '${l10n.redesignWorksFilter} · $filterCount' : l10n.redesignWorksFilter,
              onTap:
                  () => showRdWorksFilterSheet(
                    context,
                    data: listData,
                    lead: lead,
                    groupId: ownGroup?.id,
                    playerCounts: counts,
                    query: _query,
                    categories: sheetCategories,
                    // Leads find "Kategorien verwalten" here too, even
                    // before the first category is given to a Werk.
                    manageCategories: withCollections && canManage,
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
                    : (!searching && filterCount > 0
                        ? l10n.rdTextWorksNoFilterMatch
                        : (searching && filterCount == 0 && hasOrgOthers
                            ? l10n.rdOrgWorksSearchInOrgHint
                            : l10n.redesignWorksNoMatch)),
            action:
                filterCount > 0
                    ? RdOutlineButton(
                      label: l10n.redesignWorksResetFilter,
                      onPressed: () {
                        filterNotifier.reset();
                        if (chosenCategory != null) filterNotifier.setCategory(null);
                        ref.read(rdWorksOnlyProvider.notifier).state = const {};
                      },
                    )
                    : (searching && hasOrgOthers)
                    ? RdOutlineButton(
                      key: const Key('rd-works-search-in-org'),
                      icon: Icons.hub_outlined,
                      label: l10n.rdOrgWorksSearchInOrg(org.name),
                      onPressed: () => context.push(
                        '/settings/org-settings/songs?from=werke&q=${Uri.encodeQueryComponent(_query.trim())}',
                      ),
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

  /// The coming Termine with Werke, without those already over today (the
  /// times come from the loaded Termine, see [rdWithoutEndedEvents]).
  List<RdNextEvent> _nextEvents(SongsListData data) => rdWithoutEndedEvents(
    rdNextEvents(data.currentSongs, data.songs),
    now: DateTime.now(),
    attendances: ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const [],
    types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
  );

  /// "Aktuell": the Werke of the coming Termine, only from the Sammlungen
  /// the member sees (unknown: Repertoire only).
  List<RdCurrentWork> _currentWorks(SongsListData data) =>
      rdCurrentWorkCards(_nextEvents(data), visible: ref.read(rdVisibleCollectionsProvider) ?? const []);

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
