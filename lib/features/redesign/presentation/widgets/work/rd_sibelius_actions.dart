import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/services/song_file_service.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../shared/widgets/adaptive/app_dialog.dart';
import '../../../data/sibelius/rd_sibelius_logic.dart';
import '../../../data/sibelius/rd_sibelius_sync.dart';
import '../rd_widgets.dart';

/// REDESIGN (Mac app): the actions of "In Sibelius bearbeiten" (see
/// rd_sibelius_logic.dart).

const String _introSeenKey = 'rd_sibelius_intro_seen';

enum _IntroChoice { plugin, open }

/// Opens [file] of the Werk in Sibelius; saves there come back by
/// themselves. The first time it explains how, with the plug-in.
Future<void> rdEditInSibelius(BuildContext context, WidgetRef ref, SongDetailData data, SongFile file) async {
  final l10n = context.l10n;
  final songId = data.song.id;
  if (songId == null) return;

  var introSeen = true;
  try {
    introSeen = (await SharedPreferences.getInstance()).getBool(_introSeenKey) ?? false;
  } catch (_) {
    // Without preferences the explanation is skipped.
  }
  if (!introSeen && context.mounted) {
    final choice = await showAppDialog<_IntroChoice>(
      context: context,
      builder:
          (ctx) => AppAlertDialog(
            title: Text(l10n.redesignFilesSibeliusIntroTitle),
            content: SizedBox(width: 480, child: Text(l10n.redesignFilesSibeliusIntro(file.fileName))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _IntroChoice.plugin),
                child: Text(l10n.redesignFilesSibeliusPlugin),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _IntroChoice.open),
                child: Text(l10n.redesignFilesSibeliusOpen),
              ),
            ],
          ),
    );
    if (choice == null || !context.mounted) return;
    try {
      await (await SharedPreferences.getInstance()).setBool(_introSeenKey, true);
    } catch (_) {
      // Shown again next time.
    }
    if (choice == _IntroChoice.plugin) {
      if (!context.mounted) return;
      await rdInstallSibeliusPlugin(context, ref);
      if (!context.mounted) return;
    }
  }

  await _editOnMac(context, ref, data, file);
}

/// Opens the Word document [file] of the Werk in Word (Mac app, the same
/// flow as Sibelius without plug-in): every save there replaces the file.
Future<void> rdEditInWord(BuildContext context, WidgetRef ref, SongDetailData data, SongFile file) =>
    _editOnMac(context, ref, data, file);

Future<void> _editOnMac(BuildContext context, WidgetRef ref, SongDetailData data, SongFile file) async {
  final l10n = context.l10n;
  final songId = data.song.id;
  if (songId == null) return;
  final word = rdIsWordFile(file);
  try {
    final service = await ref.read(readySongFileServiceProvider.future);
    final result = await ref
        .read(rdSibeliusSyncProvider.notifier)
        .edit(
          service: service,
          songId: songId,
          songName: data.song.name,
          songNumber: data.song.number,
          groupName: ref.read(currentTenantProvider)?.name ?? '',
          mainGroupId: data.mainGroupId,
          file: file,
        );
    if (!context.mounted) return;
    switch (result) {
      case RdSibeliusOpen.opened:
        ToastHelper.showInfo(
          context,
          word ? l10n.redesignFilesWordOpened(file.fileName) : l10n.redesignFilesSibeliusOpened(file.fileName),
        );
      case RdSibeliusOpen.noFolder:
        ToastHelper.showError(context, l10n.redesignFilesSibeliusNoFolder);
      case RdSibeliusOpen.notOpened:
        ToastHelper.showError(context, word ? l10n.redesignFilesWordNotOpened : l10n.redesignFilesSibeliusNotOpened);
    }
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
  }
}

/// Saves the Attendix plug-in into the Sibelius plug-ins folder
/// (`~/Library/Application Support/Avid/Sibelius/Plugins/Attendix/…`). The
/// Mac app may write there directly; without that right (older build) the
/// user picks the folder.
Future<void> rdInstallSibeliusPlugin(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final home = await ref.read(rdSibeliusSyncProvider.notifier).home();
  if (home != null) {
    try {
      await _writePlugin(rdSibeliusPluginsFolder(home));
      await rdRememberSibeliusPluginInstalled();
      if (!context.mounted) return;
      ref.invalidate(rdSibeliusPluginInstalledProvider);
      ToastHelper.showSuccess(context, l10n.redesignFilesSibeliusPluginInstalled);
      return;
    } catch (e) {
      debugPrint('[Sibelius] plug-in not written directly: $e');
    }
  }
  if (!context.mounted) return;
  final String? picked;
  try {
    picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.redesignFilesSibeliusPluginPick,
      initialDirectory: home == null ? null : rdSibeliusPluginsFolder(home),
    );
  } catch (e) {
    if (context.mounted) {
      ToastHelper.showError(context, l10n.redesignFilesSibeliusPluginFailed(friendlyErrorMessage(e)));
    }
    return;
  }
  if (picked == null || !context.mounted) return;
  try {
    await _writePlugin(picked);
    if (!context.mounted) return;
    final inPlugins = picked.replaceAll(RegExp(r'/+$'), '').endsWith('/Avid/Sibelius/Plugins');
    if (inPlugins) {
      await rdRememberSibeliusPluginInstalled();
      if (!context.mounted) return;
      ref.invalidate(rdSibeliusPluginInstalledProvider);
      ToastHelper.showSuccess(context, l10n.redesignFilesSibeliusPluginInstalled);
    } else {
      ToastHelper.showWarning(context, l10n.redesignFilesSibeliusPluginWrongFolder);
    }
  } catch (e) {
    if (context.mounted) {
      ToastHelper.showError(context, l10n.redesignFilesSibeliusPluginFailed(friendlyErrorMessage(e)));
    }
  }
}

Future<void> _writePlugin(String pluginsFolder) async {
  final dir = Directory('$pluginsFolder/$rdSibeliusPluginCategory');
  await dir.create(recursive: true);
  await File('${dir.path}/$rdSibeliusPluginFileName').writeAsBytes(rdSibeliusPluginOfThisApp(), flush: true);
}

/// Starts keeping open Sibelius copies in step (Mac app) and shows what
/// happened with each save as a toast.
void rdStartSibeliusSync(WidgetRef ref, GoRouter router) {
  if (!rdSibeliusSupported) return;
  final sync = ref.read(rdSibeliusSyncProvider.notifier);
  sync.events.listen((event) {
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = context.l10n;
    final word = rdIsWordName(event.fileName);
    switch (event) {
      case RdSibeliusSaved():
        ToastHelper.showSuccess(
          context,
          switch ((event.afterRetry, word)) {
            (true, true) => l10n.redesignFilesWordUploadedLater(event.fileName),
            (true, false) => l10n.redesignFilesSibeliusUploadedLater(event.fileName),
            (false, true) => l10n.redesignFilesWordSaved(event.fileName),
            (false, false) => l10n.redesignFilesSibeliusSaved(event.fileName),
          },
        );
      case RdSibeliusSavedAsCopy():
        ToastHelper.showWarning(
          context,
          word
              ? l10n.redesignFilesWordSavedAsCopy(event.fileName, event.copyName)
              : l10n.redesignFilesSibeliusSavedAsCopy(event.fileName, event.copyName),
        );
      case RdSibeliusWorkGone():
        ToastHelper.showWarning(context, l10n.redesignFilesSibeliusWorkGone(event.fileName));
      case RdSibeliusPartsReady(:final parts):
        // A Werk page showing them takes them at once; else open the Werk.
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (sync.isOffered(parts.folder) || ref.read(rdSibeliusSyncProvider).parts[parts.folder] == null) return;
          if (ref.read(songFileServiceProvider).tenantId != parts.tenantId) return;
          router.goNamed('redesignWork', pathParameters: {'id': '${parts.songId}'});
        });
      case RdSibeliusSaveFailed():
        ToastHelper.showError(
          context,
          l10n.redesignFilesSibeliusSaveFailed(event.fileName, friendlyErrorMessage(event.error)),
        );
    }
  });
  unawaited(sync.start());
}

/// Whether [file] opens in Sibelius here (Mac app, .sib).
bool rdOpensInSibelius(SongFile file) => rdSibeliusSupported && rdIsSibeliusFile(file);

/// Whether "In Word bearbeiten" is offered for [file] (Mac app, .docx; a
/// click still opens the in-app viewer).
bool rdEditsInWord(SongFile file) => rdSibeliusSupported && rdIsWordFile(file);

/// The service the parts of a Werk are written with (its tenant decides
/// whether waiting parts belong to the Werk page shown). Watches it: call in
/// build.
int? rdSongTenantId(WidgetRef ref) => ref.watch(songFileServiceProvider).tenantId;

/// "Stimmen direkt aus Sibelius" above the files of a Werk with a Sibelius
/// score (Mac app), until the plug-in is installed or the hint is closed:
/// the plug-in is easy to miss otherwise.
class RdSibeliusPluginHintRow extends ConsumerWidget {
  const RdSibeliusPluginHintRow({super.key, required this.files});

  final List<SongFile> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!rdSibeliusSupported || !files.any(rdIsSibeliusFile)) return const SizedBox.shrink();
    if (!(ref.watch(rdSibeliusPluginHintProvider).valueOrNull ?? false)) return const SizedBox.shrink();
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RdGroupedList(
        children: [
          RdListRow(
            leading: RdRowIcon(Icons.extension_outlined, color: p.softText, background: p.soft),
            title: l10n.redesignFilesSibeliusHintTitle,
            subtitle: l10n.redesignFilesSibeliusHint,
            showChevron: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: p.link,
                    minimumSize: const Size(0, 40),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => rdInstallSibeliusPlugin(context, ref),
                  child: Text(l10n.redesignFilesSibeliusHintInstall),
                ),
                IconButton(
                  tooltip: l10n.redesignFilesDismiss,
                  icon: Icon(Icons.close, size: 20, color: p.text2),
                  onPressed: () => ref.read(rdSibeliusPluginHintProvider.notifier).dismiss(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
