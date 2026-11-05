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
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_additional_field.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../songs/presentation/widgets/file_drop/file_drop_target.dart' show isFileDropSupported;
import '../../data/rd_work_files_controller.dart';
import '../../data/rd_work_files_logic.dart';
import '../../data/rd_works_logic.dart';
import '../widgets/event/rd_record_widgets.dart' show RdUndoBar;
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/work/rd_work_file_actions.dart';
import '../widgets/work/rd_work_files.dart';

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
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(songDetailDataProvider(params)),
                ),
              ),
        ],
      );
    }

    final canEdit = !data.readOnly && !data.isPublic;
    final filesState = canEdit ? ref.watch(rdWorkFilesProvider(songId)) : null;
    final groups = ref.watch(groupsProvider).valueOrNull ?? data.instruments;

    // Last played / planned come from the list (enriched with the history).
    final listed = ref.watch(songsProvider).valueOrNull?.where((s) => s.id == songId).firstOrNull;
    final files = _visibleFiles(ref, data, groups);
    final song = data.song.copyWith(
      files: files,
      lastSung: listed?.lastSung,
      nextPlanned: listed?.nextPlanned,
      conductor: listed?.conductor,
    );
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
      if (song.fullNumber.isNotEmpty) l10n.redesignWorkNumber(song.fullNumber),
      ...rdCategoryNames(song, data.categories),
    ].join(' · ');
    final difficulty = (song.difficulty ?? 0) >= 1 && (song.difficulty ?? 0) <= 3;

    void more(BuildContext button, SongFile file) => rdShowWorkFileActions(button, ref, data, file, groups);
    Future<void> pick() => _pickFiles(context, ref, data);

    final header = Row(
      children: [
        Expanded(child: back),
        if (canEdit)
          RdTextLink(label: l10n.redesignWorkEdit, onTap: () => context.push(RedesignRoutes.workEdit(songId))),
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
        if (difficulty || missing.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (difficulty) RdPill(SongUtils.difficultyLabel(song.difficulty)),
              if (missing.isNotEmpty)
                RdPill(
                  missing.length == 1
                      ? l10n.redesignWorkMissingPillOne(missing.single.name)
                      : l10n.redesignWorkMissingPillMany(missing.length),
                  tone: RdTone.late,
                ),
            ],
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
              moreLabel: l10n.redesignWorkFileMore(SongUtils.fileLabel(part.first, groups, isChoir: data.isChoir)),
              onOpen: () => rdOpenWorkFile(context, ref, song, part.first),
              onMore: (button) => more(button, part.first),
            ),
            const SizedBox(height: 12),
          ],
          RdWorkLead.score => [
            _PartCard(
              eyebrow: l10n.redesignWorkForConductors,
              title: l10n.redesignWorkScore,
              detail: rdFileKind(score!),
              moreLabel: l10n.redesignWorkFileMore(l10n.redesignWorkScore),
              onOpen: () => rdOpenWorkFile(context, ref, song, score),
              onMore: (button) => more(button, score),
            ),
            const SizedBox(height: 12),
          ],
          RdWorkLead.allParts => [
            _PartCard(
              eyebrow: l10n.redesignWorkAllParts,
              title: l10n.redesignWorkFileCount(files.where(rdIsGroupPart).length),
              detail: song.name,
              onOpen: () => _showParts(context, ref, song, groups, groupId),
            ),
            const SizedBox(height: 12),
          ],
          RdWorkLead.noPart => [
            RdInfoCard(text: l10n.redesignWorkNoPart, icon: Icons.description_outlined),
            const SizedBox(height: 12),
          ],
          RdWorkLead.none => const <Widget>[],
        },
        if (practice != null && practice.url != part.first.url) ...[
          _RecordingCard(
            song: song,
            file: practice,
            title: l10n.redesignWorkPractice(ownGroup?.name ?? SongUtils.fileLabel(practice, groups)),
            onMore: (button) => more(button, practice),
          ),
          const SizedBox(height: 12),
        ],
        if (recording != null) ...[
          _RecordingCard(song: song, file: recording, onMore: (button) => more(button, recording)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        if (workspace) ...[
          if (missing.isNotEmpty) ...[
            RdGroupedList(children: [_MissingRow(missing: missing, onUpload: pick)]),
            const SizedBox(height: 16),
          ],
          RdWorkFiles(data: data, groups: groups),
        ] else
          ..._fileSection(context, ref, data, song, files, groups, recording, groupId, missing, filesState, more, pick),
        const SizedBox(height: 24),
        RdSectionHeader(l10n.redesignWorkAbout),
        RdGroupedList(children: _aboutRows(context, ref, data, song, files, groups)),
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
        action: canEdit ? _AddLink(label: l10n.redesignWorkAdd, onTap: pick) : null,
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

  /// The files of the Werk in list order; files deleted a moment ago are
  /// gone at once (until "Rückgängig").
  List<SongFile> _visibleFiles(WidgetRef ref, SongDetailData data, List<Group> groups) {
    final canEdit = !data.readOnly && !data.isPublic;
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

  /// "Über das Werk": the quiet details. Termine only as "Als Nächstes" and
  /// "Zuletzt gespielt"; the Besetzung is what the Noten say.
  List<Widget> _aboutRows(
    BuildContext context,
    WidgetRef ref,
    SongDetailData data,
    Song song,
    List<SongFile> files,
    List<Group> groups,
  ) {
    final l10n = context.l10n;
    // A practice recording is no Noten: same groups as "X fehlt".
    final fileGroups = data.isOrchestra ? rdFileGroups([...files.where(rdIsNotes)], groups) : const <Group>[];
    final beamer = !data.isPublic && PlanBeamer.active(ref.watch(currentOrganisationProvider).valueOrNull, true);
    return [
      if (song.nextPlanned != null)
        RdListRow(title: l10n.redesignWorkNext, value: SongUtils.formatDate(song.nextPlanned), showChevron: false),
      RdListRow(
        title: data.isOrchestra ? l10n.redesignWorkLastPlayed : l10n.redesignWorkLastSung,
        value:
            song.lastSung == null
                ? l10n.redesignWorkNever
                : [
                  SongUtils.formatDate(song.lastSung),
                  if ((song.conductor ?? '').isNotEmpty) song.conductor!,
                ].join(' · '),
        showChevron: data.history.isNotEmpty,
        // The whole history (loaded for the leads, like the old page).
        onTap: data.history.isEmpty ? null : () => _showHistory(context, data),
      ),
      if (fileGroups.isNotEmpty)
        RdListRow(
          title: l10n.redesignWorkInstrumentation,
          subtitle: l10n.redesignWorkInstrumentationHint(fileGroups.map((g) => g.name).join(', ')),
          value: l10n.redesignWorkInstrumentationValue(fileGroups.length),
          showChevron: false,
        ),
      if ((song.difficulty ?? 0) >= 1 && (song.difficulty ?? 0) <= 3)
        RdListRow(
          title: l10n.redesignWorkDifficulty,
          value: SongUtils.difficultyLabel(song.difficulty),
          showChevron: false,
        ),
      if (song.withChoir)
        RdListRow(
          title: data.isOrchestra ? l10n.redesignWorkWithChoir : l10n.redesignWorkWithOrchestra,
          showChevron: false,
        ),
      if (song.withSolo) RdListRow(title: l10n.redesignWorkWithSolo, showChevron: false),
      for (final field in data.additionalFields)
        if (isDisplayableSongFieldValue(song.additionalFields?[field.id]))
          RdListRow(
            title: field.name,
            value: field.isBoolean ? l10n.commonYes : song.additionalFields![field.id].toString(),
            showChevron: false,
          ),
      if ((song.link ?? '').isNotEmpty)
        RdListRow(
          title: l10n.redesignWorkLink,
          value: Uri.tryParse(song.link!)?.host ?? song.link!,
          onTap: () => _openLink(context, song.link!),
        ),
      if (beamer)
        RdListRow(
          title: l10n.songsBeamerFile,
          subtitle: song.beamerFile != null ? l10n.planningBeamerChangeInApp : l10n.planningBeamerLinkInApp,
          value: song.beamerFile?.name ?? l10n.planningBeamerNoFile,
          showChevron: false,
        ),
      if (!data.readOnly && song.copiedFrom != null)
        RdListRow(
          title: l10n.redesignWorkCopiedFrom,
          subtitle: SongUtils.formatDate(song.copiedFrom!.copiedAt),
          value: song.copiedFrom!.tenantName,
          showChevron: false,
        ),
    ];
  }

  Future<void> _pickFiles(BuildContext context, WidgetRef ref, SongDetailData data) async {
    final picked = await ref.read(songFileServiceProvider).pickMultipleFiles();
    if (picked == null || picked.isEmpty || !context.mounted) return;
    await rdAddWorkFiles(context, ref, data, picked);
  }

  Future<void> _openLink(BuildContext context, String link) async {
    final uri = Uri.tryParse(link);
    var ok = false;
    try {
      if (uri != null) ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) ToastHelper.showError(context, context.l10n.songsFlutterOpenFileFailed);
  }

  /// "Verlauf": every Termin the Werk was played in (old song page
  /// "Historie"), newest first.
  Future<void> _showHistory(BuildContext context, SongDetailData data) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.rd.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        final p = sheet.rd;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder:
              (sheet, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Text(sheet.l10n.redesignWorkHistory, style: RdType.section(p)),
                  Text(
                    '${data.song.name} · ${sheet.l10n.redesignWorkHistoryCount(data.history.length)}',
                    style: RdType.meta(p, size: 14),
                  ),
                  const SizedBox(height: 12),
                  RdGroupedList(
                    children: [
                      for (final entry in data.history)
                        RdListRow(
                          title: [
                            SongUtils.formatDate(entry.attendanceDate ?? entry.date),
                            if ((entry.typeTitle ?? '').isNotEmpty) entry.typeTitle!,
                          ].join(' · '),
                          subtitle: (entry.conductorName ?? '').isNotEmpty ? entry.conductorName : null,
                          showChevron: false,
                        ),
                    ],
                  ),
                ],
              ),
        );
      },
    );
  }

  /// "Alle Stimmen": the parts of every group; a tap opens one, "•••" has
  /// the rest. The list follows renames and part changes; deleting closes
  /// the sheet, so "Rückgängig" on the page can be reached.
  Future<void> _showParts(BuildContext context, WidgetRef ref, Song song, List<Group> groups, int? groupId) {
    final params = (songId: songId, sharingId: null);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.rd.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        final p = sheet.rd;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder:
              (sheet, controller) => Consumer(
                builder: (sheet, sheetRef, _) {
                  final data = sheetRef.watch(songDetailDataProvider(params)).valueOrNull;
                  final files =
                      data == null
                          ? const <SongFile>[]
                          : _visibleFiles(sheetRef, data, groups).where(rdIsGroupPart).toList();
                  final canEdit = data != null && !data.readOnly && !data.isPublic;
                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      Text(sheet.l10n.redesignWorkAllParts, style: RdType.section(p)),
                      Text(song.name, style: RdType.meta(p, size: 14)),
                      const SizedBox(height: 12),
                      RdGroupedList(
                        children: [
                          for (final f in files)
                            _FileRow(
                              file: f,
                              label: SongUtils.fileLabel(f, groups),
                              detail: _fileDetail(sheet, f, files, groups, canEdit: canEdit, groupId: groupId),
                              onOpen: () {
                                Navigator.of(sheet).pop();
                                rdOpenWorkFile(context, ref, song, f);
                              },
                              onMore:
                                  (button) => rdShowWorkFileActions(
                                    button,
                                    ref,
                                    data!,
                                    f,
                                    groups,
                                    beforeDelete: () => Navigator.of(sheet).pop(),
                                  ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
        );
      },
    );
  }
}

/// One file: a tap opens it, "•••" holds the rest.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.label,
    required this.detail,
    required this.onOpen,
    required this.onMore,
  });

  final SongFile file;
  final String label;
  final String detail;
  final VoidCallback onOpen;
  final void Function(BuildContext button) onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final audio = rdIsAudioFile(file);
    return RdListRow(
      leading: RdRowIcon(
        audio
            ? Icons.graphic_eq
            : (SongUtils.isPdf(file) ? Icons.description_outlined : Icons.insert_drive_file_outlined),
        color: audio ? p.text2 : p.softText,
        background: audio ? p.track : p.soft,
      ),
      title: label,
      subtitle: detail,
      showChevron: false,
      onTap: onOpen,
      trailing: Builder(
        builder:
            (button) => IconButton(
              tooltip: context.l10n.redesignWorkFileMore(label),
              icon: Icon(Icons.more_horiz, color: p.link),
              onPressed: () => onMore(button),
            ),
      ),
    );
  }
}

/// "Horn fehlt noch": somebody plays in these groups, but there are no
/// Noten for them yet.
class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.missing, required this.onUpload});

  final List<Group> missing;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final one = missing.length == 1;
    return ColoredBox(
      color: p.toneSoft(RdTone.late).withValues(alpha: 0.5),
      child: RdListRow(
        leading: RdRowIcon(
          Icons.warning_amber_rounded,
          color: p.toneColor(RdTone.late),
          background: p.toneSoft(RdTone.late),
        ),
        title: one ? l10n.redesignWorkMissingOne(missing.single.name) : l10n.redesignWorkMissingMany(missing.length),
        subtitle: one ? l10n.redesignWorkMissingOneHint(missing.single.name) : missing.map((g) => g.name).join(', '),
        showChevron: false,
        trailing: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: p.link,
            minimumSize: const Size(0, 40),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          onPressed: onUpload,
          child: Text(l10n.redesignWorkUpload),
        ),
      ),
    );
  }
}

/// "+ Hinzufügen" on the right of "Noten & Dateien".
class _AddLink extends StatelessWidget {
  const _AddLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: p.link,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 20),
      label: Text(label),
    );
  }
}

/// Werk without files, for editors: the next step right there.
class _AddFilesCard extends StatelessWidget {
  const _AddFilesCard({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdCard(
      onTap: onPick,
      border: Border.all(color: p.offBorder, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          RdRowIcon(Icons.upload_outlined, color: p.softText, background: p.soft),
          const SizedBox(height: 10),
          Text(l10n.redesignWorkAddTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text)),
          const SizedBox(height: 4),
          Text(l10n.redesignWorkAddHint, textAlign: TextAlign.center, style: RdType.meta(p, size: 14)),
          const SizedBox(height: 12),
          RdPrimaryButton(
            label: l10n.redesignWorkAddPick,
            icon: Icons.folder_open_outlined,
            height: 44,
            onPressed: onPick,
          ),
          if (isFileDropSupported) ...[
            const SizedBox(height: 8),
            Text(l10n.redesignWorkAddDrop, textAlign: TextAlign.center, style: RdType.meta(p, size: 13)),
          ],
        ],
      ),
    );
  }
}

/// The top card with "Öffnen": "Deine Stimme" (the person's part), or for
/// conductors the score or all parts. The whole card opens it too; "•••"
/// has sharing and the rest.
class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.onOpen,
    this.onMore,
    this.moreLabel,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final VoidCallback onOpen;

  /// "•••" of the file; gets the button as anchor for the sheets.
  final void Function(BuildContext button)? onMore;
  final String? moreLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final actions = [
      if (onMore != null)
        Builder(
          builder:
              (button) => IconButton(
                tooltip: moreLabel,
                icon: Icon(Icons.more_horiz, color: p.link),
                onPressed: () => onMore!(button),
              ),
        ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        onPressed: onOpen,
        child: Text(l10n.redesignWorkOpen),
      ),
    ];
    final info = Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 52,
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.offBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (var i = 0; i < 5; i++) Container(height: 2, color: p.text2.withValues(alpha: 0.5))],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RdEyebrow(eyebrow),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
              ),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: RdType.meta(p, size: 13)),
            ],
          ),
        ),
      ],
    );
    return RdCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Small phones and large text: the buttons move below the text,
          // next to it they would squeeze the title into one letter a line.
          final compact = constraints.maxWidth < MediaQuery.textScalerOf(context).scale(300);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            );
          }
          return Row(children: [Expanded(child: info), const SizedBox(width: 8), ...actions]);
        },
      ),
    );
  }
}

/// The recording inline: play / pause, progress (tap to seek), 0,8×, and
/// "•••" for sharing and the rest.
class _RecordingCard extends ConsumerStatefulWidget {
  const _RecordingCard({required this.song, required this.file, this.title, this.onMore});

  final Song song;
  final SongFile file;

  /// Instead of "Aufnahme vom …" (practice recording of a voice).
  final String? title;
  final void Function(BuildContext button)? onMore;

  @override
  ConsumerState<_RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends ConsumerState<_RecordingCard> {
  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final audio = ref.watch(audioPlayerServiceProvider);
    final service = ref.read(audioPlayerServiceProvider.notifier);
    final mine = audio.currentUrl == widget.file.url;
    final playing = mine && audio.isPlaying;
    final position = mine ? audio.currentTime : Duration.zero;
    final duration = mine ? audio.duration : Duration.zero;
    final progress =
        duration.inMilliseconds <= 0 ? 0.0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final created = DateTime.tryParse(widget.file.createdAt ?? '');
    final title =
        widget.title ??
        (created == null
            ? l10n.redesignWorkRecording
            : l10n.redesignWorkRecordingFrom(DateFormat.Md(currentIntlLocale()).format(created.toLocal())));
    // One speed for every card: they all drive the same player.
    final slow = ref.watch(audioPlaybackSpeedProvider) < 1;

    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text))),
              if (widget.onMore != null)
                SizedBox(
                  height: 32,
                  child: Builder(
                    builder:
                        (button) => IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: l10n.redesignWorkFileMore(title),
                          icon: Icon(Icons.more_horiz, color: p.link),
                          onPressed: () => widget.onMore!(button),
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Semantics(
                button: true,
                label: playing ? l10n.redesignWorkPause : l10n.redesignWorkPlay,
                excludeSemantics: true,
                child: Material(
                  color: p.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (mine) {
                        service.togglePlayPause();
                      } else {
                        service.playFromUrl(widget.file.url, widget.file.fileName, widget.song.name);
                      }
                    },
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(playing ? Icons.pause : Icons.play_arrow, color: p.onPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder:
                          (context, c) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown:
                                !mine || duration == Duration.zero
                                    ? null
                                    : (d) => service.seek(duration * (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
                            child: SizedBox(
                              height: 20,
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: SizedBox(
                                    height: 4,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(child: ColoredBox(color: p.track)),
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          bottom: 0,
                                          width: c.maxWidth * progress,
                                          child: ColoredBox(color: p.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AudioPlayerService.formatTime(position), style: _time(p)),
                        Text(mine ? AudioPlayerService.formatTime(duration) : '–:––', style: _time(p)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: slow ? l10n.redesignWorkNormalSpeed : l10n.redesignWorkSlower,
                excludeSemantics: true,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: slow ? p.primary : p.offBorder),
                    backgroundColor: slow ? p.soft : p.surface,
                    foregroundColor: slow ? p.softText : p.text,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => service.setSpeed(slow ? 1.0 : 0.8),
                  child: Text('${NumberFormat.decimalPattern(currentIntlLocale()).format(slow ? 0.8 : 1)}×'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _time(RdPalette p) =>
      TextStyle(fontSize: 12, color: p.text2, fontFeatures: const [FontFeature.tabularFigures()]);
}
