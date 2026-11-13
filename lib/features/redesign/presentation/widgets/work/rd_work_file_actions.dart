import 'package:file_picker/file_picker.dart';
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
import 'rd_sibelius_actions.dart';
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

enum _FileAction { share, download, print, telegram, word, replace, part, rename, delete }

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
  bool withPart = true,
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
        // The cards at the top only open/share; the Stimme is changed in
        // "Noten & Dateien".
        if (rdEditsInWord(file))
          AppActionSheetAction(value: _FileAction.word, icon: Icons.edit_note, label: l10n.redesignFilesWordEdit),
        if (!audio)
          AppActionSheetAction(
            value: _FileAction.replace,
            icon: Icons.upload_file_outlined,
            label: l10n.redesignFilesReplace,
          ),
        if (withPart)
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
    case _FileAction.word:
      await rdEditInWord(button, ref, data, file);
    case _FileAction.replace:
      await rdReplaceWorkFile(button, ref, songId!, file);
    case _FileAction.part:
      // Ionic category modal: Chor (alle) (choirs) / Sonstige (Freitext) /
      // Aufnahme / Liedtext / groups.
      final result = await showRdFileCategorySheet(
        button,
        title: file.fileName,
        instruments: data.partGroups,
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

/// "Durch neue Version ersetzen …": the person picks the edited file (same
/// type), which takes the place of [file] (name, part and place stay; the
/// old content is deleted). Works on every device, e.g. after editing a
/// Word file in Word on the phone.
Future<void> rdReplaceWorkFile(BuildContext context, WidgetRef ref, int songId, SongFile file) async {
  final l10n = context.l10n;
  final ext = rdStoredExtension(file);
  final FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    return;
  }
  final picked = result?.files.firstOrNull;
  final bytes = picked?.bytes;
  if (picked == null || bytes == null || !context.mounted) return;
  if (bytes.length > rdMaxUploadBytes) {
    ToastHelper.showError(context, l10n.songsFileTooLarge(picked.name));
    return;
  }
  // Same type as the stored file (the display name may have lost its
  // extension by renaming); a file of unknown type is not replaced.
  if (ext.isEmpty || (picked.extension ?? '').toLowerCase() != ext) {
    ToastHelper.showError(
      context,
      ext.isEmpty ? l10n.songsFlutterOpenFileFailed : l10n.redesignFilesReplaceWrongType(ext),
    );
    return;
  }
  final ok = await showAppConfirm(
    context,
    title: l10n.redesignFilesReplaceTitle,
    message: l10n.redesignFilesReplaceMessage(file.fileName, picked.name),
    confirmText: l10n.redesignFilesReplaceConfirm,
  );
  if (!ok || !context.mounted) return;
  try {
    final replaced = await ref.read(rdWorkFilesProvider(songId).notifier).replaceContent(file, bytes);
    if (!context.mounted) return;
    if (replaced == null) {
      ToastHelper.showError(context, l10n.redesignFilesReplaceGone(file.fileName));
    } else {
      ToastHelper.showSuccess(context, l10n.redesignFilesReplaced(file.fileName));
    }
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
  }
}

enum _WorkAction { zip, copy, groupPdfs }

/// Whether the Werk has a public page whose link the share button at the
/// top passes on ([rdShareWorkLink]).
bool rdCanShareWorkLink(SongDetailData data) => (data.songSharingId ?? '').isNotEmpty && data.song.id != null;

/// Share button at the top of the Werk: the link to its public page (no
/// sign-in needed).
Future<void> rdShareWorkLink(BuildContext button, SongDetailData data) => rdShareLink(
  button,
  SongUtils.shareLink(data.songSharingId!, data.song.id!),
  subject: data.song.name,
  copiedMessage: button.l10n.songsLinkCopied,
);

/// Whether the "•••" of the Werk has anything to offer (see
/// [rdShowWorkMenu]).
bool rdWorkMenuHasActions(SongDetailData data, List<SongFile> files, List<Tenant> copyTargets) =>
    files.length > 1 || copyTargets.isNotEmpty || (!data.readOnly && !data.isPublic && hasGroupPdfs(files));

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
  final action = await showAppActionSheet<_WorkAction>(
    button,
    title: song.name,
    actions: [
      if (files.length > 1)
        AppActionSheetAction(
          value: _WorkAction.zip,
          icon: Icons.download_outlined,
          label: l10n.redesignWorkZip,
          subtitle: l10n.redesignWorkZipHint(files.length),
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
    case _WorkAction.zip:
      await _downloadAll(button, ref, song, files);
    case _WorkAction.copy:
      await showModalBottomSheet<void>(
        context: button,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false, // not closable while copying
        // No Material drag handle: it could drag the sheet closed while
        // copying (the sheet draws a decorative one itself).
        backgroundColor: button.rd.bg,
        builder:
            (_) =>
                SafeArea(top: false, child: CopyToTenantSheet(song: song, availableTenants: copyTargets, beta: true)),
      );
    case _WorkAction.groupPdfs:
      await printGroupPdfs(context: button, ref: ref, song: song, files: files, groups: groups);
  }
}

/// "Alle Dateien herunterladen": a small window with "3 von 19" appears
/// right away while the files load, then the share sheet (web: download).
Future<void> _downloadAll(BuildContext context, WidgetRef ref, Song song, List<SongFile> files) async {
  final l10n = context.l10n;
  final progress = ValueNotifier<String>(l10n.redesignWorkZipLoading(0, files.length));
  // Close exactly the overlay's route (see printGroupPdfs).
  Route<dynamic>? overlayRoute;
  var overlay = true;
  void closeOverlay() {
    if (!overlay) return;
    overlay = false;
    final route = overlayRoute;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      overlayRoute ??= ModalRoute.of(ctx);
      if (!overlay) WidgetsBinding.instance.addPostFrameCallback((_) => closeOverlay());
      return ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, message, _) => PrintLoadingOverlay(message: message),
      );
    },
  );
  try {
    await ref
        .read(zipServiceProvider)
        .downloadSongFilesAsZip(
          files: files,
          songName: song.name.isEmpty ? 'songs' : song.name,
          onProgress:
              (done, total) =>
                  progress.value =
                      done < total ? l10n.redesignWorkZipLoading(done, total) : l10n.redesignWorkZipPacking,
          onPacked: closeOverlay,
        );
  } catch (e) {
    closeOverlay();
    if (context.mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
  } finally {
    closeOverlay();
    progress.dispose();
  }
}
