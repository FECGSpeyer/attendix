import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/debug_providers.dart';
import '../../../core/providers/push_providers.dart';
import '../../../core/providers/redesign_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/router/redesign_routes.dart';
import '../../../core/services/song_file_service.dart';
import '../../../core/theme/redesign/rd_theme.dart';
import '../../../core/utils/dashboard_logic.dart' show homeRouteFor;
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/song/song.dart';
import '../../../l10n/l10n.dart';

/// REDESIGN: Abmelden, same steps as the settings page (no confirmation,
/// like Ionic).
Future<void> rdLogout(BuildContext context, WidgetRef ref) async {
  if (_loggingOut) return;
  final supabase = ref.read(supabaseClientProvider);
  final tenantNotifier = ref.read(currentTenantProvider.notifier);
  // Signing out takes a few seconds (push token, session): say so at once
  // instead of a page that seems to ignore the tap.
  final p = context.rd;
  final text = context.l10n.rdTextLoggingOut;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: p.bg.withValues(alpha: 0.92),
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    key: const Key('rd-logging-out'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _loggingOut = true;
  try {
    overlay?.insert(entry);
    await removePushTokenBeforeSignOut(ref);
    await signOutAndClearTenant(
      signOut: supabase.auth.signOut,
      clearTenant: tenantNotifier.clearTenant,
    );
    if (context.mounted) context.go('/login');
  } finally {
    _loggingOut = false;
    if (entry.mounted) entry.remove();
  }
}

/// A sign-out is running ([rdLogout]): a second tap does nothing.
bool _loggingOut = false;

/// Switches "Neues Design (Beta)" on or off and opens the start page of
/// the chosen design ("Heute", or the old start page of the role).
Future<void> rdSetRedesignEnabled(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final router = GoRouter.of(context);
  await ref.read(redesignSettingsProvider.notifier).setEnabled(enabled);
  final target = enabled
      ? RedesignRoutes.today
      : homeRouteFor(
          ref.read(effectiveRoleProvider),
          ref.read(currentTenantProvider)?.id,
          ref.read(supabaseClientProvider).auth.currentUser?.userMetadata,
        );
  router.go(target);
}

/// Opens the system share sheet for [link] (WhatsApp, Telegram, Mail,
/// "Kopieren" …), anchored at [button] (iPad popover). The message starts
/// with [subject] so the chat shows what the link is; a full [message]
/// (which must contain the link itself) replaces that, and [subject] is
/// then only the mail subject. Where no share sheet
/// exists (desktop browsers) only the link is copied.
Future<void> rdShareLink(
  BuildContext button,
  String link, {
  String? subject,
  String? message,
  required String copiedMessage,
}) async {
  final box = button.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final text = (message ?? '').trim().isNotEmpty
        ? message!.trim()
        : (subject ?? '').trim().isEmpty
            ? link
            : '${subject!.trim()}\n$link';
    final result = await Share.share(text, subject: subject, sharePositionOrigin: origin);
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {
    // No share sheet on this platform: copy instead.
  }
  await Clipboard.setData(ClipboardData(text: link));
  if (button.mounted) ToastHelper.showSuccess(button, copiedMessage);
}

/// Shares one file of a work (a part, the score, a recording) through the
/// system share sheet, anchored at [button]: the apps get the file itself
/// (WhatsApp, Mail, AirDrop …). In the browser the file link is shared
/// instead, because the share sheet must open right on the tap and does
/// not wait for a download. If the file cannot be shared its link is
/// shared or copied.
Future<void> rdShareSongFile(
  BuildContext button,
  WidgetRef ref,
  SongFile file, {
  String? subject,
  required String copiedMessage,
}) async {
  final title = (subject ?? '').trim().isEmpty ? file.fileName : subject!.trim();
  if (!kIsWeb) {
    try {
      final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
      // Page or sheet closed during the download: no share sheet any more.
      if (!button.mounted) return;
      if (bytes != null) {
        // Measured after the download: the button may have moved meanwhile.
        final box = button.findRenderObject() as RenderBox?;
        final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
        final name = file.fileName.isEmpty ? 'datei' : file.fileName;
        final result = await Share.shareXFiles(
          [XFile.fromData(bytes, name: name, mimeType: _mimeType(name))],
          subject: title,
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        );
        if (result.status != ShareResultStatus.unavailable) return;
      }
    } catch (_) {
      // No file sharing here: share the link instead.
    }
    if (!button.mounted) return;
  }
  await rdShareLink(button, file.url, subject: title, copiedMessage: copiedMessage);
}

String? _mimeType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    _ => null,
  };
}
