import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/services/song_file_service.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/services/zip_service.dart';
import '../../../../core/services/zip_service_stub.dart'
    if (dart.library.io) '../../../../core/services/zip_service_io.dart'
    if (dart.library.js_interop) '../../../../core/services/zip_service_web.dart'
    as file_saver;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/audio_player/audio_player_widget.dart';
import '../../../../shared/widgets/common/error_state_view.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../data/song_print_service.dart';
import '../utils/song_utils.dart';
import '../widgets/song_file_opener.dart';

/// Public read-only song detail page for the share link
/// `/<song_sharing_id>/<songId>` (no login required).
class SongDetailPage extends ConsumerStatefulWidget {
  const SongDetailPage({
    super.key,
    required this.songId,
    required this.songSharingId,
  });

  final String songId;
  final String songSharingId;

  @override
  ConsumerState<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends ConsumerState<SongDetailPage> {
  int? get _songId => int.tryParse(widget.songId);

  SongDetailParams get _params => (
        songId: _songId ?? 0,
        sharingId: widget.songSharingId,
      );

  void _refresh() => ref.invalidate(songDetailDataProvider(_params));

  void _copyShareLink(String sharingId, int songId) {
    Clipboard.setData(ClipboardData(text: SongUtils.shareLink(sharingId, songId)));
    ref.read(trackingServiceProvider).track(TrackingEvent.songShared);
    ToastHelper.showSuccess(context, context.l10n.songsLinkCopied);
  }

  @override
  Widget build(BuildContext context) {
    if (!SongUtils.isValidSharingId(widget.songSharingId)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.songsFlutterSong),
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
    if (_songId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.songsFlutterSong)),
        body: Center(child: Text(context.l10n.songsFlutterInvalidId)),
      );
    }

    final dataAsync = ref.watch(songDetailDataProvider(_params));
    final data = dataAsync.valueOrNull;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.songsFlutterSong),
          leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/${widget.songSharingId}'),
          ),
        ),
        body: dataAsync.isLoading
            ? const Center(child: AppSpinner())
            : dataAsync.hasError
                ? ErrorStateView(
                    error: dataAsync.error,
                    onRetry: _refresh,
                  )
                : ErrorStateView(
                    icon: Icons.link_off,
                    message: context.l10n.songsInvalidShareLink,
                  ),
      );
    }

    final song = data.song;
    final sharingId = data.songSharingId;
    final aufnahme = song.files?.where((f) => f.instrumentId == 1 && SongUtils.isAudio(f)).firstOrNull;
    final title = '${song.number ?? ''} ${song.name}'.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/${widget.songSharingId}'),
        ),
        actions: [
          if (sharingId != null && sharingId.isNotEmpty && song.id != null)
            IconButton(
              tooltip: context.l10n.songsCopyLink,
              icon: const Icon(Icons.link),
              onPressed: () => _copyShareLink(sharingId, song.id!),
            ),
        ],
      ),
      floatingActionButton: aufnahme == null
          ? null
          : FloatingActionButton(
              tooltip: context.l10n.songsPlayRecording,
              onPressed: () => ref.read(audioPlayerServiceProvider.notifier).playFromUrl(
                    aufnahme.url,
                    aufnahme.fileName,
                    song.name,
                  ),
              child: const Icon(Icons.play_arrow),
            ),
      bottomNavigationBar: const AudioPlayerWidget(),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
          await ref.read(songDetailDataProvider(_params).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingM,
            AppDimensions.paddingS,
            AppDimensions.paddingM,
            80,
          ),
          children: [
            if (song.categoryIds?.isNotEmpty ?? false) ...[
              RdGroupLabel(context.l10n.songsCategories),
              RdCard(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in song.categoryIds!)
                      _SongChip(
                        label: data.categories.where((c) => c.id == id).firstOrNull?.name ??
                            context.l10n.songsUnknownCategory,
                        color: AppColors.secondary,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (song.withChoir ||
                song.withSolo ||
                (data.isOrchestra && (song.instrumentIds?.isNotEmpty ?? false))) ...[
              _buildInstrumentation(context, data),
              const SizedBox(height: 16),
            ],
            if (data.history.isNotEmpty) ...[
              _buildHistory(context, data),
              const SizedBox(height: 16),
            ],
            _PublicFilesSection(data: data),
            if (song.link?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              RdGroupedList(
                children: [
                  RdListRow(
                    title: context.l10n.songsOpenExternalLink,
                    titleColor: context.rd.primary,
                    onTap: () => NativeFileService.openLinkInApp(Uri.parse(song.link!)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumentation(BuildContext context, SongDetailData data) {
    final song = data.song;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(context.l10n.songsInstrumentation),
        RdCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (song.withChoir || song.withSolo)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (song.withChoir)
                      _SongChip(label: context.l10n.songsChoirOrchestra, color: AppColors.primary),
                    if (song.withSolo)
                      _SongChip(label: context.l10n.songsWithSoloSinging, color: AppColors.primary),
                  ],
                ),
              if (data.isOrchestra && (song.instrumentIds?.isNotEmpty ?? false))
                Padding(
                  padding: EdgeInsets.only(top: song.withChoir || song.withSolo ? 6 : 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in data.instruments)
                        _SongChip(
                          label: g.name,
                          color: song.instrumentIds!.contains(g.id) ? AppColors.success : AppColors.danger,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(BuildContext context, SongDetailData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(context.l10n.songsHistoryCount(data.history.length)),
        RdGroupedList(
          children: [
            for (final entry in data.history)
              RdListRow(
                title: '${SongUtils.formatDate(entry.attendanceDate ?? entry.date)}'
                    '${(entry.typeTitle?.isNotEmpty ?? false) ? ' · ${entry.typeTitle}' : ''}',
                subtitle: (entry.conductorName?.isNotEmpty ?? false) ? entry.conductorName : null,
                showChevron: false,
              ),
          ],
        ),
      ],
    );
  }
}

class _SongChip extends StatelessWidget {
  const _SongChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: TextStyle(color: color, fontSize: 14)),
      ),
    );
  }
}

class _PublicFilesSection extends ConsumerStatefulWidget {
  const _PublicFilesSection({required this.data});

  final SongDetailData data;

  @override
  ConsumerState<_PublicFilesSection> createState() => _PublicFilesSectionState();
}

class _PublicFilesSectionState extends ConsumerState<_PublicFilesSection> {
  bool _busy = false;

  bool get _isIos => !kIsWeb && Platform.isIOS;

  Song get _song => widget.data.song;
  List<SongFile> get _files => _song.files ?? const [];

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadAll() => _run(() async {
        await ref.read(zipServiceProvider).downloadSongFilesAsZip(
              files: _files,
              songName: _song.name.isEmpty ? 'songs' : _song.name,
            );
      });

  Future<void> _openActions(SongFile file) async {
    final isAudio = SongUtils.isAudio(file) || AudioPlayerService.isAudioFile(file.fileName);

    final action = await showAppActionSheet<String>(
      context,
      title: context.l10n.songsFileActions,
      actions: [
        AppActionSheetAction(
          value: 'open',
          icon: isAudio ? Icons.play_circle_outline : Icons.open_in_new,
          label: isAudio ? context.l10n.songsPlayRecording : context.l10n.songsOpenFile,
        ),
        if (!isAudio)
          AppActionSheetAction(
            value: 'print',
            icon: Icons.print_outlined,
            label: context.l10n.songsPrintFile,
          ),
        if (!_isIos || isAudio)
          AppActionSheetAction(
            value: 'download',
            icon: Icons.download_outlined,
            label: isAudio ? context.l10n.songsDownloadRecording : context.l10n.songsDownloadFile,
          ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'open':
        if (isAudio) {
          await ref.read(audioPlayerServiceProvider.notifier).playFromUrl(
                file.url,
                file.fileName,
                _song.name,
              );
        } else {
          await openSongFile(context, file);
        }
      case 'print':
        final baseName =
            (file.fileName.isNotEmpty ? file.fileName : _song.name).replaceAll(RegExp(r'\.[^.]+$'), '');
        final result = await ref
            .read(songPrintServiceProvider)
            .printEntries([SongPrintEntry(song: _song, file: file)], '$baseName.pdf');
        if (mounted && result != null && result.pageCount == 0) {
          ToastHelper.showWarning(context, context.l10n.songsFlutterPrintFileFailed);
        }
      case 'download':
        if (await NativeFileService.downloadInMacBrowser(file.url, file.fileName)) return;
        await _run(() async {
          final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
          if (bytes == null) throw Exception(l10nWithoutContext.songsFlutterDownloadFileFailed);
          await file_saver.saveZipFile(bytes, file.fileName);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = SongUtils.sortedFiles(_files, widget.data.instruments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdSectionHeader(
          context.l10n.songsFiles,
          action: _files.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.songsDownloadAll,
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _busy ? null : _downloadAll,
                ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        RdGroupedList(
          children: _files.isEmpty
              ? [RdListRow(title: context.l10n.songsNoFiles, showChevron: false)]
              : [
                  for (final file in sorted)
                    RdListRow(
                      title: file.fileName,
                      trailing: SongBadge(
                        color: SongUtils.fileBadgeColor(file),
                        label: SongUtils.fileLabel(file, widget.data.instruments, isChoir: widget.data.isChoir),
                      ),
                      onTap: () => _openActions(file),
                    ),
                ],
        ),
      ],
    );
  }
}
