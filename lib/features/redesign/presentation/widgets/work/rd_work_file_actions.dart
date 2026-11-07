import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../../core/services/native/native_file_service.dart';
import '../../../../../core/services/song_file_service.dart';
import '../../../../../core/services/telegram_service.dart';
import '../../../../../core/services/zip_service.dart';
import '../../../../../core/services/zip_service_stub.dart'
    if (dart.library.io) '../../../../../core/services/zip_service_io.dart'
    if (dart.library.html) '../../../../../core/services/zip_service_web.dart'
    as file_saver;
import '../../../../../core/utils/choir_file_utils.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../songs/data/song_print_service.dart';
import '../../../../songs/presentation/utils/song_utils.dart';
import '../../../../songs/presentation/widgets/copy_to_tenant_sheet.dart';
import '../../../../songs/presentation/widgets/group_pdf_print.dart';
import '../../../../songs/presentation/widgets/song_file_opener.dart';
import '../../../data/rd_work_files_controller.dart';
import '../../../data/rd_work_files_logic.dart';
import '../../rd_actions.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import 'rd_file_category_sheet.dart';

/// REDESIGN: what a tap and "•••" do with the files of a Werk on the
/// phone (canvas "Werke neu gedacht", boards 5 and 6). A tap opens the file
/// right away, "•••" next to it holds everything else.

bool rdIsAudioFile(SongFile file) => SongUtils.isAudio(file) || AudioPlayerService.isAudioFile(file.fileName);

/// Opens [file]: recordings play in the app's player (a second tap pauses),
/// everything else opens in the viewer.
Future<void> rdOpenWorkFile(BuildContext context, WidgetRef ref, Song song, SongFile file) async {
  if (rdIsAudioFile(file)) {
    final audio = ref.read(audioPlayerServiceProvider);
    final service = ref.read(audioPlayerServiceProvider.notifier);
    if (audio.currentUrl == file.url) {
      await service.togglePlayPause();
    } else {
      await service.playFromUrl(file.url, file.fileName, song.name);
    }
    return;
  }
  await openSongFile(context, file);
}

enum _FileAction { share, download, print, telegram, part, rename, delete }

/// "•••" of one file, anchored at [button]: Teilen, Herunterladen, Drucken
/// and Telegram for everybody; people who may edit the Werk also change the
/// part, rename and delete (with "Rückgängig" on the page). A sheet passes
/// [beforeDelete] to close itself, so "Rückgängig" can be reached.
Future<void> rdShowWorkFileActions(
  BuildContext button,
  WidgetRef ref,
  SongDetailData data,
  SongFile file,
  List<Group> groups, {
  VoidCallback? beforeDelete,
}) async {
  final l10n = button.l10n;
  final song = data.song;
  final songId = song.id;
  final label = SongUtils.fileLabel(file, groups);
  final audio = rdIsAudioFile(file);
  final canEdit = !data.readOnly && !data.isPublic && songId != null;
  // Ionic: the iOS app saves PDFs from the viewer, only recordings download.
  final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final chatId = data.isPublic ? null : ref.read(currentTenantUserProvider).valueOrNull?.telegramChatId;

  final action = await showAppActionSheet<_FileAction>(
    button,
    title: label,
    message: file.fileName,
    actions: [
      AppActionSheetAction(value: _FileAction.share, icon: Icons.ios_share, label: l10n.redesignWorkFileShare),
      if (!ios || audio)
        AppActionSheetAction(
          value: _FileAction.download,
          icon: Icons.download_outlined,
          label: l10n.redesignWorkFileDownload,
        ),
      if (!audio)
        AppActionSheetAction(value: _FileAction.print, icon: Icons.print_outlined, label: l10n.redesignWorkFilePrint),
      if (chatId != null && chatId.isNotEmpty)
        AppActionSheetAction(
          value: _FileAction.telegram,
          icon: Icons.send_outlined,
          label: l10n.redesignWorkFileTelegram,
        ),
      if (canEdit) ...[
        AppActionSheetAction(value: _FileAction.part, icon: Icons.swap_horiz, label: l10n.redesignWorkFilePart),
        if (rdCanRename(file))
          AppActionSheetAction(
            value: _FileAction.rename,
            icon: Icons.drive_file_rename_outline,
            label: l10n.redesignWorkFileRename,
          ),
        AppActionSheetAction(
          value: _FileAction.delete,
          icon: Icons.delete_outline,
          label: l10n.redesignWorkFileDelete,
          destructive: true,
        ),
      ],
    ],
  );
  if (action == null || !button.mounted) return;

  Future<void> run(Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      if (button.mounted) ToastHelper.showError(button, friendlyErrorMessage(e));
    }
  }

  switch (action) {
    case _FileAction.share:
      await rdShareSongFile(button, ref, file, subject: '${song.name} · $label', copiedMessage: l10n.songsLinkCopied);
    case _FileAction.download:
      // Ionic 4.17.23: iOS app on a Mac → the browser downloads the file.
      if (await NativeFileService.downloadInMacBrowser(file.url, file.fileName)) return;
      await run(() async {
        final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
        if (bytes == null) throw Exception(l10nWithoutContext.songsFlutterDownloadFileFailed);
        await file_saver.saveZipFile(bytes, file.fileName);
      });
    case _FileAction.print:
      final base = (file.fileName.isNotEmpty ? file.fileName : song.name).replaceAll(RegExp(r'\.[^.]+$'), '');
      await run(() async {
        final result = await ref.read(songPrintServiceProvider).printEntries([
          SongPrintEntry(song: song, file: file),
        ], '$base.pdf');
        if (button.mounted && result != null && result.pageCount == 0) {
          ToastHelper.showWarning(button, l10n.songsFlutterPrintFileFailed);
        }
      });
    case _FileAction.telegram:
      await run(() async {
        await ref.read(telegramServiceProvider).sendDocumentPerTelegram(url: file.url, chatId: chatId!);
        if (button.mounted) ToastHelper.showSuccess(button, l10n.songsFlutterTelegramSent);
      });
    case _FileAction.part:
      // Ionic category modal: Chor (alle) (choirs) / Sonstige (Freitext) /
      // Aufnahme / Liedtext / groups.
      final result = await showRdFileCategorySheet(
        button,
        title: file.fileName,
        instruments: data.instruments,
        isChoir: data.isChoir,
        initialInstrumentId:
            data.isChoir && file.instrumentId == null && ((file.note ?? '').isEmpty || isChoirAllFile(note: file.note))
                ? kChoirAllOptionValue
                : file.instrumentId,
        initialNote:
            isChoirAllFile(instrumentId: file.instrumentId, note: file.note) && data.isChoir ? '' : (file.note ?? ''),
      );
      if (result == null) return;
      if (result.instrumentId == file.instrumentId && (result.instrumentId != null || result.note == file.note)) {
        return;
      }
      await run(
        () => ref
            .read(rdWorkFilesProvider(songId!).notifier)
            .setCategory(file, result.instrumentId, result.note, mainGroupId: data.mainGroupId),
      );
    case _FileAction.rename:
      final input = await showAppPrompt(
        button,
        title: l10n.redesignWorkFileRename,
        initialValue: file.fileName,
        confirmText: l10n.commonSave,
      );
      if (input == null) return;
      final name = rdRenamedFileName(file.fileName, input);
      if (name == null) return;
      await run(() => ref.read(rdWorkFilesProvider(songId!).notifier).rename(file, name));
    case _FileAction.delete:
      beforeDelete?.call();
      ref
          .read(rdWorkFilesProvider(songId!).notifier)
          .delete([file], mainGroupId: data.mainGroupId, notice: l10n.redesignFilesDeletedOne(file.fileName));
  }
}

enum _WorkAction { shareLink, zip, copy, groupPdfs }

/// Whether the "•••" of the Werk has anything to offer (see
/// [rdShowWorkMenu]).
bool rdWorkMenuHasActions(SongDetailData data, List<SongFile> files, List<Tenant> copyTargets) =>
    (data.songSharingId ?? '').isNotEmpty ||
    files.length > 1 ||
    copyTargets.isNotEmpty ||
    (!data.readOnly && !data.isPublic && hasGroupPdfs(files));

/// Groups of the organisation the Werk can be copied to: every other
/// instance where the person is admin or responsible (Ionic: any logged-in
/// user may copy, limited to those).
List<Tenant> rdCopyTargets(List<Tenant> linked, List<Tenant> mine, int? currentId) => [
  for (final t in linked)
    if (t.id != null && t.id != currentId && _leads(mine.where((m) => m.id == t.id).firstOrNull?.role)) t,
];

bool _leads(int? role) => role == 1 || role == 5;

/// "•••" at the top of the Werk: rarely needed actions (canvas board 6).
Future<void> rdShowWorkMenu(
  BuildContext button,
  WidgetRef ref, {
  required SongDetailData data,
  required List<SongFile> files,
  required List<Group> groups,
  required List<Tenant> copyTargets,
}) async {
  final l10n = button.l10n;
  final song = data.song;
  final sharingId = data.songSharingId ?? '';
  final action = await showAppActionSheet<_WorkAction>(
    button,
    title: song.name,
    actions: [
      if (sharingId.isNotEmpty && song.id != null)
        AppActionSheetAction(
          value: _WorkAction.shareLink,
          icon: Icons.link,
          label: l10n.redesignWorkShareLink,
          subtitle: l10n.redesignWorkShareLinkHint,
        ),
      if (files.length > 1)
        AppActionSheetAction(
          value: _WorkAction.zip,
          icon: Icons.folder_zip_outlined,
          label: l10n.redesignWorkZip,
          subtitle: l10n.redesignWorkFileCount(files.length),
        ),
      if (copyTargets.isNotEmpty)
        AppActionSheetAction(
          value: _WorkAction.copy,
          icon: Icons.copy_outlined,
          label: l10n.redesignWorkCopy,
          subtitle: l10n.redesignWorkCopyHint,
        ),
      if (!data.readOnly && !data.isPublic && hasGroupPdfs(files))
        AppActionSheetAction(value: _WorkAction.groupPdfs, icon: Icons.print_outlined, label: l10n.songsPrintGroupPdfs),
    ],
  );
  if (action == null || !button.mounted) return;
  switch (action) {
    case _WorkAction.shareLink:
      await rdShareLink(
        button,
        SongUtils.shareLink(sharingId, song.id!),
        subject: song.name,
        copiedMessage: l10n.songsLinkCopied,
      );
    case _WorkAction.zip:
      try {
        await ref
            .read(zipServiceProvider)
            .downloadSongFilesAsZip(files: files, songName: song.name.isEmpty ? 'songs' : song.name);
      } catch (e) {
        if (button.mounted) ToastHelper.showError(button, friendlyErrorMessage(e));
      }
    case _WorkAction.copy:
      await showModalBottomSheet<void>(
        context: button,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false, // not closable while copying
        showDragHandle: true,
        backgroundColor: button.rd.bg,
        builder:
            (_) =>
                SafeArea(top: false, child: CopyToTenantSheet(song: song, availableTenants: copyTargets, beta: true)),
      );
    case _WorkAction.groupPdfs:
      await printGroupPdfs(context: button, ref: ref, song: song, files: files, groups: groups);
  }
}
