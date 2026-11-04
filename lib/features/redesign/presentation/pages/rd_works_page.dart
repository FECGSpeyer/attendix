import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
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
import '../../../songs/data/song_print_service.dart';
import '../../../songs/presentation/pages/song_import_page.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../songs/presentation/widgets/song_categories_sheet.dart';
import '../../data/providers/rd_works_filter.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/works/rd_works_filter_sheet.dart';
import 'rd_folder_page.dart' show rdEventLabel;

/// Search text of the Werke list, shared by every copy of the list (the
/// split view builds a new one when the first Werk opens).
final rdWorksQueryProvider = StateProvider<String>((ref) => '');

/// REDESIGN: tab "Werke" (canvas "Werke neu gedacht", board "Liste"):
/// search, "Als Nächstes" (members: the own Noten for the next Termin,
/// leads: where Noten are missing), categories as chips, sort and filter,
/// every Werk with one status line. "Meine Mappe" / "Mappen" opens the Noten
/// of one part, "+" adds, imports or takes over Werke; categories, the share
/// link and the PDF list sit behind "•••".
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

  /// "•••": rarely needed list actions (filter, import and the group
  /// folders have their own places now).
  Future<void> _more(SongsListData data, List<Song> shown, bool isAdmin) async {
    final l10n = context.l10n;
    final sharingId = data.songSharingId;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        if (isAdmin)
          AppActionSheetAction(
            value: 'categories',
            icon: Icons.local_library_outlined,
            label: l10n.redesignWorkEditManageCategories,
          ),
        if (sharingId != null && sharingId.isNotEmpty)
          AppActionSheetAction(value: 'share', icon: Icons.link, label: l10n.songsCopyLink),
        AppActionSheetAction(value: 'pdf', icon: Icons.description_outlined, label: l10n.songsCatalogPdf),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'categories':
        await showSongCategoriesSheet(context);
      case 'share':
        await Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId!)));
        if (mounted) ToastHelper.showSuccess(context, l10n.songsLinkCopied);
      case 'pdf':
        await _exportPdf(data, shown);
    }
  }

  /// "+": a new Werk, a work list from Excel, or Werke of another group of
  /// the organisation.
  Future<void> _add(SongsListData data) async {
    final l10n = context.l10n;
    final org = ref.read(currentOrganisationProvider).valueOrNull != null;
    final action = await showAppActionSheet<String>(
      context,
      title: l10n.redesignWorksAdd,
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
        await context.push(RedesignRoutes.newWork);
      case 'import':
        final imported = await Navigator.of(
          context,
          rootNavigator: true,
        ).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SongImportPage()));
        if (imported == true) {
          ref.invalidate(songsProvider);
          ref.invalidate(songsListDataProvider);
        }
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
  Future<void> _openMine(List<SongPrintEntry> entries, String name) async {
    final l10n = context.l10n;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final result = await ref.read(songPrintServiceProvider).printEntries(entries, 'Noten_${name}_$date.pdf');
    if (!mounted || result == null) return;
    if (result.pageCount == 0) {
      ToastHelper.showWarning(context, l10n.svcNoPrintableScores);
    } else if (result.skipped > 0) {
      ToastHelper.showWarning(context, l10n.songsFlutterFilesSkipped(result.skipped));
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

    final header = <Widget>[
      Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(l10n.redesignTabWorks, style: RdType.largeTitle(p)))),
          if (data != null) ...[
            RdPillButton(
              icon: Icons.folder_outlined,
              label: lead ? l10n.redesignWorksFolders : l10n.redesignWorksFolder,
              onPressed: () => context.push(RedesignRoutes.folder),
            ),
            const SizedBox(width: 8),
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
    final groupId = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.instrument;
    final ownGroup = data.groups.where((g) => g.id == groupId && g.maingroup != true).firstOrNull;
    final counts = lead ? ref.watch(missingGroupsPlayerCountsProvider) : null;
    final shown = _shown(data);
    final events = _query.trim().isEmpty ? rdNextEvents(data.currentSongs, data.songs) : const <RdNextEvent>[];
    final categories = [...data.categories.where((c) => c.id != null)]..sort((a, b) => a.index.compareTo(b.index));
    final sort = filter.sortOption;
    final byLast = sort == SongSortOption.lastSungAsc || sort == SongSortOption.lastSungDesc;
    final filterCount = filter.activeFilterCount + only.length;

    String status(Song song) {
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
      final part = ownGroup != null && rdPartFiles(song, ownGroup.id).isNotEmpty;
      // What is missing first, the categories last (cut on small phones).
      return [
        if (files.isEmpty)
          l10n.redesignWorksStatusNoFiles
        else if (!part && ownGroup != null && files.any(rdIsGroupPart))
          l10n.redesignWorksStatusNoPart(ownGroup.name),
        if (part) l10n.redesignWorksStatusPart,
        if (rdRecording(song) != null) l10n.redesignWorksStatusRecording,
        ...cats,
      ].join(' · ');
    }

    Widget? pill(Song song) {
      if (!lead) return null;
      final files = song.files ?? const <SongFile>[];
      if (files.isEmpty) return RdPill(l10n.redesignWorksNoFilesPill, tone: RdTone.absent);
      if (!data.isOrchestra) return null;
      final missing = rdMissingGroups(files, data.groups, counts);
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
          isAdmin
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
            ..._memberNext(context, events, ownGroup, status),
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
                    data: data,
                    lead: lead,
                    groupId: ownGroup?.id,
                    playerCounts: counts,
                    query: _query,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (shown.isEmpty)
          RdInfoCard(
            icon: Icons.music_off_outlined,
            text: data.songs.isEmpty ? l10n.redesignWorksEmpty : l10n.redesignWorksNoMatch,
            action:
                filterCount > 0
                    ? RdOutlineButton(
                      label: l10n.redesignWorksResetFilter,
                      onPressed: () {
                        filterNotifier.reset();
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
    String Function(Song) status,
  ) {
    final l10n = context.l10n;
    final p = context.rd;
    final first = events.first;
    final mine = [
      if (ownGroup != null)
        for (final song in first.songs)
          for (final f in rdPartFiles(song, ownGroup.id))
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

  /// The filtered and sorted Werke (see [rdFilteredWorks]).
  List<Song> _shown(SongsListData data) {
    final lead = ref.read(effectiveRoleProvider).isConductor;
    return rdFilteredWorks(
      data: data,
      filter: ref.read(songFilterProvider(data.tenantId)),
      only: ref.read(rdWorksOnlyProvider),
      query: _query,
      groupId: ref.read(currentSelfServicePlayerProvider).valueOrNull?.instrument,
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
