import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../utils/song_utils.dart';
import '../widgets/file_drop/file_drop_target.dart' show isFileDropSupported;
import '../../data/providers/rd_shared_library.dart';
import '../../data/rd_collections_logic.dart';
import '../../../../core/redesign/rd_words.dart';
import '../../data/rd_work_files_controller.dart';
import '../../data/rd_work_files_logic.dart';
import '../../data/rd_works_logic.dart';
import '../../../attendance/presentation/widgets/event/rd_record_widgets.dart' show RdUndoBar;
import '../../../../shared/widgets/redesign/rd_split_view.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;
import '../widgets/work/rd_work_file_actions.dart';
import '../widgets/work/rd_work_files.dart';
import '../widgets/work/rd_sibelius_actions.dart' show RdSibeliusPluginHintRow;
import '../../../../core/providers/debug_providers.dart' show effectiveRoleProvider;
import '../widgets/works/rd_collections_ui.dart';

part 'rd_work_page_actions.dart';
part 'rd_work_page_cards.dart';

/// REDESIGN: a work, one page for everybody (canvas "Werke neu gedacht",
/// boards 4 and 12). On top the part to open ("Deine Stimme", for the
/// conductor the score) and the recording with 0,8× to practise along.
/// Below "Noten & Dateien": a tap opens a file right away, "•••" next to it
/// shares, downloads, prints or sends it; people who may edit the Werk also
/// add files here (on the phone too), change the part, rename and delete
/// (with "Rückgängig"), and see which parts are still missing. "Über das
/// Werk" holds the quiet details, rare actions sit in the "•••" at the top.
/// On wide screens editors get the file workspace ([RdWorkFiles]) instead
/// of the list. "Bearbeiten" (fields) still opens the existing page.
class RdWorkPage extends ConsumerWidget {
  const RdWorkPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The real width of this page (window minus side bar and split list).
    return LayoutBuilder(builder: (context, constraints) => _content(context, ref, constraints.maxWidth));
  }

  Widget _content(BuildContext context, WidgetRef ref, double width) {
    final p = context.rd;
    final l10n = context.l10n;
    final params = (songId: songId, sharingId: null);
    final async = ref.watch(songDetailDataProvider(params));
    final data = async.valueOrNull;

    final back =
        RdSplitScope.of(context)?.isDetail ?? false
            ? const SizedBox(height: 44)
            : RdBackLink(
              label: l10n.redesignTabWorks,
              onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.works),
            );

    if (data == null) {
      return RdPage(
        children: [
          Row(children: [Expanded(child: back)]),
          const SizedBox(height: 8),
          async.isLoading
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignWorkNotFound,
                icon: Icons.music_off_outlined,
                // Retry only helps after an error, not when it is gone.
                action: async.hasError
                    ? RdOutlineButton(
                      label: l10n.redesignCommonRetry,
                      onPressed: () => ref.invalidate(songDetailDataProvider(params)),
                    )
                    : null,
              ),
        ],
      );
    }

    final canEdit = _canEdit(ref, data);
    final filesState = canEdit ? ref.watch(rdWorkFilesProvider(songId)) : null;
    final groups = ref.watch(groupsProvider).valueOrNull ?? data.partGroups;

    // Last played / planned come from the list (enriched with the history).
    final listed = ref.watch(songsProvider).valueOrNull?.where((s) => s.id == songId).firstOrNull;
    final files = _visibleFiles(ref, data, groups);
    final song = data.song.copyWith(
      files: files,
      lastSung: listed?.lastSung,
      nextPlanned: listed?.nextPlanned,
      conductor: listed?.conductor,
      collectionId: listed?.collectionId ?? data.song.collectionId,
    );
    // Sammlungen (null while the database has none, or on the public page).
    final collections = data.isPublic ? null : ref.watch(songCollectionsProvider).valueOrNull;
    final collection = rdCollectionById(collections ?? const [], song.collectionId);
    // A Werk of a Sammlung hidden from the viewer (e.g. "Nur Leitung"),
    // opened from a link or the overview: not shown, like in the list.
    // While the visibility is unknown (Sammlungen loading or failed) a
    // member does not see it either.
    if (!data.isPublic && song.collectionId != null && !ref.watch(effectiveRoleProvider).isConductor) {
      final visible = ref.watch(rdVisibleCollectionsProvider);
      if (visible == null || !visible.any((c) => c.id == song.collectionId)) {
        final loading = visible == null && ref.watch(songCollectionsProvider).isLoading;
        return RdPage(
          children: [
            Row(children: [Expanded(child: back)]),
            const SizedBox(height: 8),
            loading
                ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
                : RdInfoCard(text: l10n.redesignWorkNotFound, icon: Icons.music_off_outlined),
          ],
        );
      }
    }
    final groupId = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.instrument;
    final ownGroup = groups.where((g) => g.id == groupId).firstOrNull;
    final lead = rdWorkLead(song, groupId, isMainGroup: ownGroup?.maingroup ?? false, choir: data.isChoir);
    final part = rdMemberPartFiles(song, groupId, choir: data.isChoir);
    final recording = rdRecording(song);
    final score = rdScore(song);
    // Choirs: the practice recording of the voice ("Sopran.mp3").
    final practice = lead == RdWorkLead.part ? part.where(rdIsAudioFile).firstOrNull : null;
    final workspace = canEdit && width >= rdWorkFilesMinWidth;
    final missing =
        canEdit && data.isOrchestra
            ? rdWorkMissingGroups(song, groups, ref.watch(missingGroupsPlayerCountsProvider))
            : const <Group>[];
    final copyTargets =
        data.isPublic
            ? const <Tenant>[]
            : rdCopyTargets(
              ref.watch(linkedTenantsProvider).valueOrNull ?? const [],
              ref.watch(userTenantsProvider).valueOrNull ?? const [],
              ref.watch(currentTenantIdProvider),
            );
    final meta = [
      if (collection != null) collection.name,
      if (song.fullNumber.isNotEmpty) l10n.redesignWorkNumber(song.fullNumber),
      ...rdCategoryNames(song, data.categories),
    ].join(' · ');
    final banner = rdCollectionBanner(l10n, collection, groups);
    final songs = ref.watch(songsProvider).valueOrNull;
    final intoRepertoire =
        collection != null && songs != null ? rdMoveNumbering(song, null, collections!, songs) : null;

    void more(BuildContext button, SongFile file) => rdShowWorkFileActions(button, ref, data, file, groups);
    // Cards above the file list: no "Stimme ändern" (only in Noten & Dateien).
    void cardMore(BuildContext button, SongFile file) =>
        rdShowWorkFileActions(button, ref, data, file, groups, withPart: false);
    // The recordings as rows under the card on top; the player itself is the
    // bar at the bottom of the app (one player only).
    final recordingRows = [
      if (practice != null && practice.url != part.first.url)
        _RecordingRow(
          song: song,
          file: practice,
          title: l10n.redesignWorkPractice(ownGroup?.name ?? SongUtils.fileLabel(practice, groups)),
          onMore: (button) => cardMore(button, practice),
        ),
      if (recording != null)
        _RecordingRow(song: song, file: recording, onMore: (button) => cardMore(button, recording)),
    ];
    Future<void> pick() => _pickFiles(context, ref, data);

    final header = Row(
      children: [
        Expanded(child: back),
        if (canEdit)
          RdTextLink(label: l10n.redesignWorkEdit, onTap: () => context.push(RedesignRoutes.workEdit(songId))),
        if (rdCanShareWorkLink(data)) ...[
          const SizedBox(width: 4),
          Builder(
            builder:
                (button) => RdCircleButton(
                  key: const Key('rd-work-share-link'),
                  icon: Icons.ios_share,
                  label: l10n.redesignWorkShareLink,
                  onPressed: () => rdShareWorkLink(button, data),
                ),
          ),
        ],
        if (rdWorkMenuHasActions(data, files, copyTargets)) ...[
          const SizedBox(width: 4),
          Builder(
            builder:
                (button) => RdCircleButton(
                  icon: Icons.more_horiz,
                  label: l10n.redesignWorkMore,
                  onPressed:
                      () => rdShowWorkMenu(
                        button,
                        ref,
                        data: data,
                        files: files,
                        groups: groups,
                        copyTargets: copyTargets,
                      ),
                ),
          ),
        ],
      ],
    );

    final page = RdPage(
      maxWidth: workspace ? 1000 : 720,
      onRefresh: () async {
        ref.invalidate(songDetailDataProvider(params));
        ref.invalidate(songByIdProvider(songId));
      },
      children: [
        header,
        const SizedBox(height: 4),
        if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text2)),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(song.name, style: RdType.title(p).copyWith(fontSize: 28))),
        if ((song.composer ?? '').isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 2), child: Text(song.composer!, style: RdType.meta(p, size: 15))),
        if (banner != null) ...[
          const SizedBox(height: 14),
          RdInfoCard(
            key: const Key('rd-work-collection-banner'),
            text: banner,
            icon: rdCollectionIcon(collection),
            action:
                !canEdit
                    ? null
                    : collection?.visibleTo == SongCollectionVisibility.leads
                    ? RdOutlineButton(
                      key: const Key('rd-work-into-repertoire'),
                      label: l10n.collectionsIntoRepertoire(
                        intoRepertoire == null ? song.fullNumber : '${intoRepertoire.prefix}${intoRepertoire.number}',
                      ),
                      onPressed: () => rdMoveWorkToCollection(context, ref, song, to: -1),
                    )
                    : RdOutlineButton(
                      label: l10n.collectionsMove,
                      onPressed: () => rdMoveWorkToCollection(context, ref, song),
                    ),
          ),
        ],
        const SizedBox(height: 14),
        ...switch (lead) {
          RdWorkLead.part => [
            _PartCard(
              eyebrow: l10n.redesignWorkYourPart,
              // A choir without an own file gets "Chor (alle)".
              title:
                  part.first.instrumentId == groupId
                      ? ownGroup?.name ?? SongUtils.fileLabel(part.first, groups)
                      : SongUtils.fileLabel(part.first, groups, isChoir: data.isChoir),
              detail: [
                rdFileKind(part.first),
                if (part.length > 1) l10n.redesignWorkFileCount(part.length),
              ].join(' · '),
              onOpen: () => rdOpenWorkFile(context, ref, song, part.first),
              recordings: recordingRows,
            ),
            const SizedBox(height: 12),
          ],
          RdWorkLead.score => [
            _PartCard(
              eyebrow: l10n.redesignWorkForConductors,
              title: l10n.redesignWorkScore,
              detail: rdFileKind(score!),
              onOpen: () => rdOpenWorkFile(context, ref, song, score),
              recordings: recordingRows,
            ),
            const SizedBox(height: 12),
          ],
          RdWorkLead.allParts => [
            _PartCard(
              eyebrow: l10n.redesignWorkAllParts,
              title: l10n.redesignWorkFileCount(files.where(rdIsGroupPart).length),
              detail: song.name,
              onOpen: () => _showParts(context, ref, song, groups, groupId),
              recordings: recordingRows,
            ),
            const SizedBox(height: 12),
          ],
          RdWorkLead.noPart => [
            RdInfoCard(text: l10n.redesignWorkNoPart, icon: Icons.description_outlined),
            const SizedBox(height: 12),
            if (recordingRows.isNotEmpty) ...[_RecordingsCard(rows: recordingRows), const SizedBox(height: 12)],
          ],
          RdWorkLead.none => [
            if (recordingRows.isNotEmpty) ...[_RecordingsCard(rows: recordingRows), const SizedBox(height: 12)],
          ],
        },
        const SizedBox(height: 12),
        if (workspace) ...[
          if (missing.isNotEmpty) ...[
            RdGroupedList(children: [_MissingRow(missing: missing, onUpload: pick)]),
            const SizedBox(height: 16),
          ],
          RdSibeliusPluginHintRow(files: files),
          RdWorkFiles(data: data, groups: groups),
        ] else
          ..._fileSection(context, ref, data, song, files, groups, recording, groupId, missing, filesState, more, pick),
        const SizedBox(height: 24),
        RdSectionHeader(l10n.redesignWorkAbout),
        RdGroupedList(
          children: [
            // Where the Werk lives; leads move it from here.
            if (collections != null && collections.isNotEmpty)
              RdListRow(
                key: const Key('rd-work-collection-row'),
                title: l10n.collectionsRow,
                value: collection?.name ?? l10n.collectionsRepertoire,
                showChevron: canEdit,
                onTap: canEdit ? () => rdMoveWorkToCollection(context, ref, song) : null,
              ),
            ..._aboutRows(context, ref, data, song, files, groups),
          ],
        ),
      ],
    );
    if (!canEdit) return page;

    final controller = ref.read(rdWorkFilesProvider(songId).notifier);
    final notice = filesState?.notice;
    return RdWorkDropArea(
      data: data,
      child: Stack(
        children: [
          page,
          if (notice != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: RdUndoBar(
                      text: notice,
                      onUndo:
                          controller.canUndoDelete
                              ? () => controller.undoDelete(notice: l10n.redesignFilesRestored)
                              : null,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Noten & Dateien" on the phone: every file for editors (with "fehlt"
  /// and the upload queue), for members their part, the score and the other
  /// files, the parts of the other groups behind "Alle Stimmen".
  List<Widget> _fileSection(
    BuildContext context,
    WidgetRef ref,
    SongDetailData data,
    Song song,
    List<SongFile> files,
    List<Group> groups,
    SongFile? recording,
    int? groupId,
    List<Group> missing,
    RdWorkFilesState? filesState,
    void Function(BuildContext button, SongFile file) more,
    Future<void> Function() pick,
  ) {
    final l10n = context.l10n;
    final canEdit = filesState != null;
    final member = canEdit ? null : rdMemberFiles(files, groupId, recording);
    final rows = canEdit ? files : member!.shown;
    return [
      RdSectionHeader(
        files.isEmpty ? l10n.redesignWorkFiles : '${l10n.redesignWorkFiles} · ${files.length}',
        // Without files the card below is the one way to add them.
        action: canEdit && files.isNotEmpty ? _AddLink(label: l10n.redesignWorkAdd, onTap: pick) : null,
      ),
      if (filesState != null && filesState.uploads.isNotEmpty) ...[
        RdUploadQueue(
          state: filesState,
          groups: groups,
          onRetry: (id) => ref.read(rdWorkFilesProvider(songId).notifier).retry(id),
          onDismiss: () => ref.read(rdWorkFilesProvider(songId).notifier).dismissFinished(),
        ),
        const SizedBox(height: 12),
      ],
      if (files.isEmpty)
        canEdit
            ? _AddFilesCard(onPick: pick)
            : RdInfoCard(text: l10n.redesignWorkNoFilesYet, icon: Icons.folder_open_outlined)
      else
        RdGroupedList(
          children: [
            if (missing.isNotEmpty) _MissingRow(missing: missing, onUpload: pick),
            for (final f in rows)
              _FileRow(
                file: f,
                label: SongUtils.fileLabel(f, groups),
                detail: _fileDetail(context, f, rows, groups, canEdit: canEdit, groupId: groupId),
                onOpen: () => rdOpenWorkFile(context, ref, song, f),
                onMore: (button) => more(button, f),
              ),
            if (member != null && member.others.isNotEmpty)
              RdListRow(
                leading: RdRowIcon(
                  Icons.library_music_outlined,
                  color: context.rd.softText,
                  background: context.rd.soft,
                ),
                title: l10n.redesignWorkAllParts,
                subtitle: {for (final f in member.others) SongUtils.fileLabel(f, groups)}.join(', '),
                value: '${member.others.length}',
                onTap: () => _showParts(context, ref, song, groups, groupId),
              ),
          ],
        ),
    ];
  }

  /// Leads edit the Werk; Werke of another group only as lead there (the
  /// Werke tab says whose they are).
  bool _canEdit(WidgetRef ref, SongDetailData data) =>
      !data.readOnly && !data.isPublic && ref.watch(rdLibraryEditableProvider);

  /// The files of the Werk in list order; files deleted a moment ago are
  /// gone at once (until "Rückgängig").
  List<SongFile> _visibleFiles(WidgetRef ref, SongDetailData data, List<Group> groups) {
    final canEdit = _canEdit(ref, data);
    final hidden = canEdit ? ref.watch(rdWorkFilesProvider(songId)).hidden : const <String>{};
    return SongUtils.sortedFiles([
      for (final f in data.song.files ?? const <SongFile>[])
        if (!hidden.contains(f.url)) f,
    ], groups);
  }

  /// Second line of a file row: the file name for editors; for members the
  /// kind ("PDF · deine Stimme"), or the file name when another file of
  /// [list] has the same label (two Klarinette PDFs stay apart).
  String _fileDetail(
    BuildContext context,
    SongFile file,
    List<SongFile> list,
    List<Group> groups, {
    required bool canEdit,
    int? groupId,
  }) {
    if (canEdit) return file.fileName;
    final label = SongUtils.fileLabel(file, groups);
    final twin = list.where((o) => SongUtils.fileLabel(o, groups) == label).length > 1;
    return [
      twin ? file.fileName : rdFileKind(file),
      if (groupId != null && file.instrumentId == groupId) context.l10n.redesignWorkPartOwn,
    ].join(' · ');
  }
}
