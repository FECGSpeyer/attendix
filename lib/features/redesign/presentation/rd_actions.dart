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
import '../../../core/utils/dashboard_logic.dart' show homeRouteFor;
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/song/song.dart';

/// REDESIGN: Abmelden, same steps as the settings page (no confirmation,
/// like Ionic).
Future<void> rdLogout(BuildContext context, WidgetRef ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final tenantNotifier = ref.read(currentTenantProvider.notifier);
  await removePushTokenBeforeSignOut(ref);
  await supabase.auth.signOut();
  await tenantNotifier.clearTenant();
  if (context.mounted) context.go('/login');
}

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
/// with [subject] so the chat shows what the link is. Where no share sheet
/// exists (desktop browsers) only the link is copied.
Future<void> rdShareLink(
  BuildContext button,
  String link, {
  String? subject,
  required String copiedMessage,
}) async {
  final box = button.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final text = (subject ?? '').trim().isEmpty ? link : '${subject!.trim()}\n$link';
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
    final box = button.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final bytes = await ref.read(songFileServiceProvider).downloadFileBytes(file.url);
      if (bytes != null) {
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
