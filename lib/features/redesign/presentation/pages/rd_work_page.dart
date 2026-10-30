import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../songs/presentation/widgets/group_pdf_print.dart';
import '../../../songs/presentation/widgets/song_file_opener.dart';
import '../../data/rd_works_logic.dart';
import '../rd_actions.dart';
import '../../data/rd_work_files_controller.dart';
import '../widgets/event/rd_record_widgets.dart' show RdUndoBar;
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/work/rd_work_files.dart';

/// REDESIGN: a work (canvas "WerkDetail"): your part to open, the
/// recording with 0,8× to practise along, all parts, score, link, last
/// played. Every part can be shared (the file itself through the share
/// sheet), and editors print the group PDFs right here. "Bearbeiten"
/// (fields, history) opens the existing page. On wide
/// screens people who may edit the Werk get the file workspace
/// ([RdWorkFiles]): table, drag and drop, upload queue, ZIP and keys.
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

    final sharingId = data?.songSharingId;
    final header = Row(
      children: [
        Expanded(
          child: RdSplitScope.of(context)?.isDetail ?? false
              ? const SizedBox(height: 44)
              : RdBackLink(
                  label: l10n.redesignTabWorks,
                  onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.works),
                ),
        ),
        if (sharingId != null && sharingId.isNotEmpty)
          Builder(
            builder: (button) => IconButton(
              tooltip: l10n.redesignWorkShare,
              icon: Icon(Icons.ios_share, color: p.link),
              onPressed: () => rdShareLink(
                button,
                SongUtils.shareLink(sharingId, songId),
                subject: data?.song.name,
                copiedMessage: l10n.songsLinkCopied,
              ),
            ),
          ),
        if (data != null && !data.readOnly)
          RdTextLink(label: l10n.redesignWorkEdit, onTap: () => context.push('/settings/songs/$songId')),
      ],
    );

    if (data == null) {
      return RdPage(children: [
        header,
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
      ]);
    }

    // Last played / planned come from the list (enriched with the history).
    final listed = ref.watch(songsProvider).valueOrNull?.where((s) => s.id == songId).firstOrNull;
    final song = data.song.copyWith(
      lastSung: listed?.lastSung,
      nextPlanned: listed?.nextPlanned,
      conductor: listed?.conductor,
    );
    final groups = ref.watch(groupsProvider).valueOrNull ?? data.instruments;
    final groupId = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.instrument;
    final isMainGroup = groups.where((g) => g.id == groupId).firstOrNull?.maingroup ?? false;
    final lead = rdWorkLead(song, groupId, isMainGroup: isMainGroup);
    final part = rdPartFiles(song, groupId);
    final files = SongUtils.sortedFiles(song.files ?? const <SongFile>[], groups);
    final recording = rdRecording(song);
    final score = rdScore(song);
    final lyrics = files.where((f) => f.instrumentId == rdLyricsCategory).firstOrNull;
    final hasGroupFiles = files.any((f) => (f.instrumentId ?? 0) > rdLyricsCategory);
    final workspace = !data.readOnly && !data.isPublic && width >= rdWorkFilesMinWidth;
    final meta = [
      if (song.fullNumber.isNotEmpty) l10n.redesignWorkNumber(song.fullNumber),
      ...rdCategoryNames(song, data.categories),
    ].join(' · ');

    final rows = <Widget>[
      if (!data.readOnly && !data.isPublic && hasGroupPdfs(files))
        RdListRow(
          leading: RdRowIcon(Icons.print_outlined, color: p.softText, background: p.soft),
          title: l10n.songsPrintGroupPdfs,
          onTap: () => printGroupPdfs(context: context, ref: ref, song: song, files: files, groups: groups),
        ),
      if (!workspace && files.isNotEmpty && lead != RdWorkLead.allParts)
        RdListRow(
          title: hasGroupFiles ? l10n.redesignWorkAllParts : l10n.redesignWorkAllFiles,
          value: l10n.redesignWorkFileCount(files.length),
          onTap: () => _showFiles(context, ref, song, files, groups),
        ),
      if (score != null && lead != RdWorkLead.score)
        RdListRow(
          title: l10n.redesignWorkScore,
          value: rdFileKind(score),
          onTap: () => openSongFile(context, score),
        ),
      if (lyrics != null)
        RdListRow(
          title: l10n.redesignWorkLyrics,
          value: rdFileKind(lyrics),
          onTap: () => openSongFile(context, lyrics),
        ),
      if ((song.link ?? '').isNotEmpty)
        RdListRow(
          title: l10n.redesignWorkLink,
          value: Uri.tryParse(song.link!)?.host ?? song.link!,
          onTap: () => _openLink(context, song.link!),
        ),
      RdListRow(
        title: data.isOrchestra ? l10n.redesignWorkLastPlayed : l10n.redesignWorkLastSung,
        value: song.lastSung == null
            ? l10n.redesignWorkNever
            : [SongUtils.formatDate(song.lastSung), if ((song.conductor ?? '').isNotEmpty) song.conductor!].join(' · '),
        showChevron: false,
      ),
      if (song.nextPlanned != null)
        RdListRow(
          title: l10n.redesignWorkPlanned,
          value: SongUtils.formatDate(song.nextPlanned),
          showChevron: false,
        ),
    ];

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
        Semantics(
          header: true,
          child: Text(song.name, style: RdType.title(p).copyWith(fontSize: 28)),
        ),
        if ((song.composer ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(song.composer!, style: RdType.meta(p, size: 15)),
          ),
        const SizedBox(height: 14),
        ...switch (lead) {
          RdWorkLead.part => [
              _PartCard(
                eyebrow: l10n.redesignWorkYourPart,
                title: groups.where((g) => g.id == groupId).firstOrNull?.name ??
                    SongUtils.fileLabel(part.first, groups),
                detail: [rdFileKind(part.first), if (part.length > 1) l10n.redesignWorkFileCount(part.length)]
                    .join(' · '),
                onOpen: () => openSongFile(context, part.first),
                onShare: (button) => rdShareSongFile(
                  button,
                  ref,
                  part.first,
                  subject: '${song.name} · ${SongUtils.fileLabel(part.first, groups)}',
                  copiedMessage: l10n.songsLinkCopied,
                ),
              ),
              const SizedBox(height: 12),
            ],
          RdWorkLead.score => [
              _PartCard(
                eyebrow: l10n.redesignWorkScore,
                title: score!.fileName,
                detail: rdFileKind(score),
                onOpen: () => openSongFile(context, score),
                onShare: (button) => rdShareSongFile(
                  button,
                  ref,
                  score,
                  subject: '${song.name} · ${l10n.redesignWorkScore}',
                  copiedMessage: l10n.songsLinkCopied,
                ),
              ),
              const SizedBox(height: 12),
            ],
          RdWorkLead.allParts => [
              _PartCard(
                eyebrow: l10n.redesignWorkAllParts,
                title: l10n.redesignWorkFileCount(files.length),
                detail: song.name,
                onOpen: () => _showFiles(context, ref, song, files, groups),
              ),
              const SizedBox(height: 12),
            ],
          RdWorkLead.noPart => [
              RdInfoCard(text: l10n.redesignWorkNoPart, icon: Icons.description_outlined),
              const SizedBox(height: 12),
            ],
          RdWorkLead.none => const <Widget>[],
        },
        if (recording != null) ...[
          _RecordingCard(song: song, file: recording),
          const SizedBox(height: 12),
        ],
        if (workspace) ...[
          const SizedBox(height: 8),
          RdWorkFiles(data: data, groups: groups),
          const SizedBox(height: 24),
        ] else if (files.isEmpty) ...[
          RdInfoCard(text: l10n.redesignWorkNoFiles, icon: Icons.folder_open_outlined),
          const SizedBox(height: 12),
        ],
        RdGroupedList(children: rows),
      ],
    );
    if (!workspace) return page;

    final filesState = ref.watch(rdWorkFilesProvider(songId));
    final controller = ref.read(rdWorkFilesProvider(songId).notifier);
    return RdWorkDropArea(
      data: data,
      child: Stack(
        children: [
          page,
          if (filesState.notice != null)
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
                      text: filesState.notice!,
                      onUndo: controller.canUndoDelete
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

  Future<void> _showFiles(BuildContext context, WidgetRef ref, Song song, List<SongFile> files, List<Group> groups) {
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
          builder: (sheet, controller) => ListView(
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
              Text(song.name, style: RdType.section(p)),
              const SizedBox(height: 12),
              RdGroupedList(children: [
                for (final f in files)
                  RdListRow(
                    leading: RdRowIcon(
                      SongUtils.isAudio(f)
                          ? Icons.graphic_eq
                          : (SongUtils.isPdf(f) ? Icons.description_outlined : Icons.insert_drive_file_outlined),
                      color: p.softText,
                      background: p.soft,
                    ),
                    title: SongUtils.fileLabel(f, groups),
                    subtitle: f.fileName,
                    value: rdFileKind(f),
                    showChevron: false,
                    trailing: Builder(
                      builder: (button) => IconButton(
                        tooltip: sheet.l10n.redesignWorkShareFile(SongUtils.fileLabel(f, groups)),
                        icon: Icon(Icons.ios_share, color: p.link),
                        onPressed: () => rdShareSongFile(
                          button,
                          ref,
                          f,
                          subject: '${song.name} · ${SongUtils.fileLabel(f, groups)}',
                          copiedMessage: sheet.l10n.songsLinkCopied,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheet).pop();
                      if (SongUtils.isAudio(f)) {
                        ref.read(audioPlayerServiceProvider.notifier).playFromUrl(f.url, f.fileName, song.name);
                      } else {
                        openSongFile(context, f);
                      }
                    },
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

/// The top card with "Öffnen": "Deine Stimme" (the person's part), or for
/// conductors the score or all parts.
class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.onOpen,
    this.onShare,
  });

  final String eyebrow;
  final String title;
  final String detail;
  final VoidCallback onOpen;

  /// Shares the file; gets the button as anchor for the share sheet.
  final void Function(BuildContext button)? onShare;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final actions = [
      if (onShare != null)
        Builder(
          builder: (button) => IconButton(
            tooltip: l10n.redesignWorkShareFile(title),
            icon: Icon(Icons.ios_share, color: p.link),
            onPressed: () => onShare!(button),
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
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

/// The recording inline: play / pause, progress (tap to seek), 0,8×.
class _RecordingCard extends ConsumerStatefulWidget {
  const _RecordingCard({required this.song, required this.file});

  final Song song;
  final SongFile file;

  @override
  ConsumerState<_RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends ConsumerState<_RecordingCard> {
  late double _speed = ref.read(audioPlayerServiceProvider.notifier).speed;

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
    final progress = duration.inMilliseconds <= 0 ? 0.0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final created = DateTime.tryParse(widget.file.createdAt ?? '');
    final title = created == null
        ? l10n.redesignWorkRecording
        : l10n.redesignWorkRecordingFrom(DateFormat.Md(currentIntlLocale()).format(created.toLocal()));
    final slow = _speed < 1;

    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
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
                      builder: (context, c) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: !mine || duration == Duration.zero
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
                  onPressed: () {
                    final next = slow ? 1.0 : 0.8;
                    setState(() => _speed = next);
                    service.setSpeed(next);
                  },
                  child: Text('${NumberFormat.decimalPattern(currentIntlLocale()).format(slow ? 0.8 : 1)}×'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _time(RdPalette p) => TextStyle(
        fontSize: 12,
        color: p.text2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
