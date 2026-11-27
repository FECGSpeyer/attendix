part of 'rd_work_page.dart';

/// Metadata rows, file picker, link launcher, history sheet, and all-parts sheet
/// for [RdWorkPage].
extension _RdWorkPageActions on RdWorkPage {
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
          value: l10n.rdWordsGroupCount(ref.watch(rdGroupKindProvider), fileGroups.length),
          showChevron: false,
        ),
      if ((song.difficulty ?? 0) >= 1 && (song.difficulty ?? 0) <= 3)
        RdListRow(
          title: l10n.redesignWorkDifficulty,
          value: switch (song.difficulty) {
            1 => l10n.redesignWorkEditEasy,
            2 => l10n.redesignWorkEditMedium,
            _ => l10n.redesignWorkEditHard,
          },
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

  /// "Verlauf": every Termin the Werk was played in, newest first.
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
                  final canEdit = data != null && _canEdit(sheetRef, data);
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
