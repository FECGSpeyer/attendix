import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../songs/data/song_print_service.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../data/rd_collections_logic.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/work/rd_work_file_actions.dart' show rdOpenWorkFile;
import '../widgets/works/rd_collections_ui.dart';

/// REDESIGN: "Meine Noten" (canvas "Werke neu gedacht", board "Mappe"):
/// the Noten of one part, for the coming Termine or all Werke, opened one
/// by one or as one PDF (also to print). Members see their own part and may
/// pick another; leads pick any group, the conductors' scores included.
/// Replaces the group folders ("Dateien") of the Werke tab. With Sammlungen
/// (canvas "Noten-Bereich neu gedacht") "Alle" is grouped by Sammlung,
/// Repertoire first, and leaves out the Sammlungen the viewer does not see.
class RdFolderPage extends ConsumerStatefulWidget {
  const RdFolderPage({super.key});

  @override
  ConsumerState<RdFolderPage> createState() => _RdFolderPageState();
}

class _RdFolderPageState extends ConsumerState<RdFolderPage> {
  /// Picked part (null: the own one, for leads the first).
  int? _picked;
  bool _all = false;
  bool _printing = false;

  /// Files of [groupId] in [song]; choirs fall back to "Chor (alle)". The
  /// virtual groups (Dirigenten −1, Chor (alle) −2) list their files.
  List<SongFile> _files(Song song, int groupId, bool choir) =>
      groupId < 0
          ? [
            for (final e in filesForGroup([song], groupId)) e.file,
          ]
          : rdMemberPartFiles(song, groupId, choir: choir);

  Future<void> _pick(List<Group> groups) async {
    final l10n = context.l10n;
    final choice = await showAppActionSheet<int>(
      context,
      title: l10n.redesignFolderPick,
      actions: [for (final g in groups) AppActionSheetAction(value: g.id!, label: g.name)],
    );
    if (choice != null && mounted) setState(() => _picked = choice);
  }

  Future<void> _openAll(List<({Song song, SongFile file})> entries, String name) async {
    final l10n = context.l10n;
    final printable = [
      for (final e in entries)
        if (SongUtils.isPdf(e.file) || SongUtils.isImage(e.file)) SongPrintEntry(song: e.song, file: e.file),
    ];
    if (printable.isEmpty) {
      ToastHelper.showWarning(context, l10n.svcNoPrintableScores);
      return;
    }
    setState(() => _printing = true);
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final result = await ref.read(songPrintServiceProvider).printEntries(printable, 'Mappe_${name}_$date.pdf');
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

  void _back() => context.canPop() ? context.pop() : context.go(RedesignRoutes.works);

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final lead = ref.watch(effectiveRoleProvider).isConductor;
    final async = ref.watch(songsListDataProvider(null));
    final data = async.valueOrNull;
    final title = lead ? l10n.redesignFolderTitleLeads : l10n.redesignFolderTitle;

    final head = <Widget>[
      Row(children: [RdBackLink(label: l10n.redesignTabWorks, onTap: _back)]),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(title, style: RdType.largeTitle(p))),
      const SizedBox(height: 8),
    ];
    if (data == null) {
      return RdPage(
        children: [
          ...head,
          RdInfoCard(
            text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignTodayLoading,
            loading: !async.hasError,
          ),
        ],
      );
    }

    final choir = data.isChoir;
    final groups = buildGroupsWithFiles(
      data.songs,
      data.groups,
      conductorsLabel: l10n.songsConductors,
      isChoir: choir,
      choirAllLabel: l10n.songsChoirAll,
    );
    final own = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.instrument;
    final ownGroup = data.groups.where((g) => g.id == own && g.maingroup != true).firstOrNull;
    final groupId = _picked ?? (lead ? (groups.any((g) => g.id == own) ? own : groups.firstOrNull?.id) : ownGroup?.id);
    final group = [...groups, ...data.groups].where((g) => g.id == groupId).firstOrNull;

    if (groupId == null || group == null) {
      return RdPage(
        children: [
          ...head,
          RdInfoCard(
            text: groups.isEmpty ? l10n.redesignWorksNoMatch : l10n.redesignFolderNoGroup,
            icon: Icons.folder_open_outlined,
            action:
                groups.isEmpty ? null : RdOutlineButton(label: l10n.redesignFolderPick, onPressed: () => _pick(groups)),
          ),
        ],
      );
    }

    final events = rdWithoutEndedEvents(
      rdNextEvents(data.currentSongs, data.songs),
      now: DateTime.now(),
      attendances: ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const [],
      types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
    );
    final nextSongs = {for (final e in events) ...e.songs};
    final collections = ref.watch(rdVisibleCollectionsProvider);
    final byCollection = collections != null && collections.isNotEmpty;
    // Repertoire (null) first, then the Sammlungen in their order.
    final collectionOrder = <int?, int>{null: -1, for (final (i, c) in collections?.indexed ?? const <(int, SongCollection)>[]) c.id: i};
    final allEntries = [
      for (final song in collections == null ? data.songs : rdVisibleWorks(data.songs, collections))
        for (final f in _files(song, groupId, choir)) (song: song, file: f),
    ]..sort((a, b) {
      if (byCollection) {
        final o = (collectionOrder[a.song.collectionId] ?? 0).compareTo(collectionOrder[b.song.collectionId] ?? 0);
        if (o != 0) return o;
      }
      final c = (a.song.prefix ?? '').compareTo(b.song.prefix ?? '');
      return c != 0 ? c : (a.song.number ?? 0).compareTo(b.song.number ?? 0);
    });
    final allSongs = {for (final e in allEntries) e.song};
    final nextEntries = [
      for (final song in nextSongs)
        for (final f in _files(song, groupId, choir)) (song: song, file: f),
    ];
    final shown = _all ? allEntries : nextEntries;

    Widget row(Song song, SongFile? file) => _FolderRow(
      song: song,
      subtitle:
          file == null
              ? l10n.redesignFolderNoPart(group.name)
              : '${SongUtils.fileLabel(file, data.groups)} · ${rdFileKind(file)}',
      missing: file == null,
      onTap:
          file != null
              ? () => rdOpenWorkFile(context, ref, song, file)
              : song.id == null
              ? null
              : () => context.push(RedesignRoutes.work(song.id!)),
    );

    return RdPage(
      children: [
        ...head,
        if (lead)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final g in groups) ...[
                  RdChoiceChip(label: g.name, selected: g.id == groupId, onTap: () => setState(() => _picked = g.id)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(child: Text(group.name, style: RdType.meta(p, size: 15))),
              if (groups.isNotEmpty) RdTextLink(label: l10n.redesignFolderOther, onTap: () => _pick(groups)),
            ],
          ),
        const SizedBox(height: 14),
        RdSegmented<bool>(
          values: const [false, true],
          selected: _all,
          labelOf: (all) => all ? l10n.redesignFolderAll(allSongs.length) : l10n.redesignFolderNext(nextSongs.length),
          onChanged: (all) => setState(() => _all = all),
        ),
        const SizedBox(height: 16),
        if (_all && allEntries.isEmpty)
          RdInfoCard(text: l10n.redesignFolderEmpty(group.name), icon: Icons.folder_open_outlined)
        else if (_all && byCollection) ...[
          // Grouped by Sammlung (a spread, so the "else" below stays here).
          for (final id in [null, for (final c in collections) c.id])
            if (allEntries.where((e) => e.song.collectionId == id).toList() case final entries
                when entries.isNotEmpty) ...[
              RdGroupLabel(rdCollectionName(l10n, collections, id)),
              RdGroupedList(children: [for (final e in entries) row(e.song, e.file)]),
              const SizedBox(height: 16),
            ],
        ] else if (_all)
          RdGroupedList(children: [for (final e in allEntries) row(e.song, e.file)])
        else if (events.isEmpty)
          RdInfoCard(text: l10n.redesignFolderNothingNext, icon: Icons.event_outlined)
        else
          for (final event in events) ...[
            RdGroupLabel(rdEventLabel(event)),
            RdGroupedList(
              children: [
                for (final song in event.songs)
                  if (_files(song, groupId, choir) case final files when files.isNotEmpty)
                    for (final f in files) row(song, f)
                  else
                    row(song, null),
              ],
            ),
            const SizedBox(height: 16),
          ],
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdPrimaryButton(
            key: const Key('rd-folder-open-all'),
            icon: Icons.picture_as_pdf_outlined,
            label: l10n.redesignFolderOpen,
            loading: _printing,
            onPressed: () => _openAll(shown, group.name),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.redesignFolderOpenHint, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
          ),
        ],
      ],
    );
  }
}

/// "Do., 5. Nov. · Probe".
String rdEventLabel(RdNextEvent event) => [
  if (event.date != null) DateFormat.MMMEd(currentIntlLocale()).format(event.date!),
  if (event.type.isNotEmpty) event.type,
].join(' · ');

/// Number, title and the part's file (or "fehlt").
class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.song, required this.subtitle, required this.missing, required this.onTap});

  final Song song;
  final String subtitle;
  final bool missing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdListRow(
      leading: SizedBox(
        width: 40,
        child: Text(
          song.fullNumber,
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
      title: song.name,
      subtitle: subtitle,
      trailing: missing ? RdPill(context.l10n.redesignFolderMissing, tone: RdTone.late) : null,
      showChevron: onTap != null && !missing,
      onTap: onTap,
    );
  }
}
