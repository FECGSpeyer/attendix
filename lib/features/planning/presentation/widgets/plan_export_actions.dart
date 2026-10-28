import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/utils/toast_helper.dart';
import 'plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// Export formats of an Ablaufplan.
enum PlanExportAction { pdf, pdf2x, image, telegram, telegram2x, telegramImage }

/// Telegram chat id of the signed-in user (null when not linked or not logged in).
String? planTelegramChatId(WidgetRef ref) {
  final session = ref.read(supabaseClientProvider).auth.currentSession;
  if (session == null) return null;
  final id = ref.read(notificationConfigProvider).valueOrNull?.telegramChatId;
  return (id == null || id.isEmpty) ? null : id;
}

/// Shows the export sheet (PDF, 2x A5, Bild, Telegram) and runs the chosen export.
///
/// [pages] builds the pages to export (allows "alle Pläne").
Future<void> showPlanExportSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<PlanExportPage> Function() pages,
  required String fileName,
  String? title,
  bool withImage = true,
  List<PlanSheetAction<String>> extraActions = const [],
  Future<void> Function(String action)? onExtraAction,
  bool includeBranding = true,
  bool showExports = true,
  bool Function()? beforeExport,
}) async {
  final chatId = planTelegramChatId(ref);
  final l10n = context.l10n;
  final action = await showPlanActionSheet<String>(
    context,
    title: title ?? l10n.planningExport,
    actions: [
      ...extraActions,
      if (showExports) ...[
        PlanSheetAction('pdf', l10n.planningFlutterPdfA4, icon: Icons.picture_as_pdf_outlined),
        PlanSheetAction('pdf2x', l10n.planningFlutterPdf2xA5, icon: Icons.content_copy_outlined),
        if (withImage) PlanSheetAction('image', l10n.plansImageA4, icon: Icons.image_outlined),
      ],
      if (showExports && chatId != null) ...[
        PlanSheetAction('telegram', l10n.attendanceTelegramPdf, icon: Icons.send_outlined),
        PlanSheetAction('telegram2x', l10n.planningFlutterTelegramPdf2x, icon: Icons.send_outlined),
        PlanSheetAction('telegramImage', l10n.attendanceTelegramImage, icon: Icons.send_outlined),
      ],
    ],
  );
  if (action == null || !context.mounted) return;
  if (extraActions.any((a) => a.value == action)) {
    await onExtraAction?.call(action);
    return;
  }
  // Ionic `export()` / `send()` validate (with toast) when clicked.
  if (beforeExport != null && !beforeExport()) return;
  final parsed = PlanExportAction.values.byName(action);
  await runPlanExport(context, ref, parsed,
      pages: pages(), fileName: fileName, includeBranding: includeBranding);
}

/// Runs one export action.
Future<void> runPlanExport(
  BuildContext context,
  WidgetRef ref,
  PlanExportAction action, {
  required List<PlanExportPage> pages,
  required String fileName,
  bool includeBranding = true,
}) async {
  if (pages.isEmpty || pages.every((p) => p.fields.isEmpty)) {
    ToastHelper.showWarning(context, context.l10n.planningNoPlan);
    return;
  }
  final service = ref.read(planExportServiceProvider);
  final sideBySide = action == PlanExportAction.pdf2x || action == PlanExportAction.telegram2x;
  try {
    // MISC2: tenant/org branding in the letterhead (Ionic buildTenantBranding)
    final branding = includeBranding ? await resolvePdfBranding(ref) : null;
    switch (action) {
      case PlanExportAction.pdf:
      case PlanExportAction.pdf2x:
        await service.sharePdf(pages, sideBySide: sideBySide, fileName: fileName, branding: branding);
      case PlanExportAction.image:
        await service.shareImage(pages, fileName: fileName, branding: branding);
      case PlanExportAction.telegram:
      case PlanExportAction.telegram2x:
      case PlanExportAction.telegramImage:
        final chatId = planTelegramChatId(ref);
        if (chatId == null) {
          if (context.mounted) ToastHelper.showError(context, context.l10n.planningFlutterTelegramNotConfigured);
          return;
        }
        final asImage = action == PlanExportAction.telegramImage;
        final bytes = asImage
            ? await service.buildImage(pages, branding: branding)
            : await service.buildPdf(pages, sideBySide: sideBySide, branding: branding);
        await ref.read(telegramServiceProvider).sendPlanPerTelegram(
              fileBytes: bytes,
              name: '${_safeName(fileName)}${sideBySide ? '_2x' : ''}',
              chatId: chatId,
              asImage: asImage,
            );
        if (context.mounted) ToastHelper.showSuccess(context, context.l10n.planningSendingTelegram);
    }
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.planningFlutterExportFailed(friendlyErrorMessage(e)));
  }
}

/// Ionic `send`: `planningTitle.replace('(', '').replace(')', '')` (first
/// occurrence only); the storage key is sanitised by `encodeFilename`.
String _safeName(String name) => name.replaceFirst('(', '').replaceFirst(')', '');

/// Shares a link via the system share sheet, falls back to the clipboard.
Future<void> sharePlanLink(BuildContext context, String url, {String? title}) async {
  try {
    final result = await Share.share(url, subject: title);
    if (result.status == ShareResultStatus.unavailable) {
      throw Exception('unavailable');
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) ToastHelper.showSuccess(context, context.l10n.planningLinkCopied);
  }
}

/// Copies text and shows a toast.
Future<void> copyPlanLink(BuildContext context, String url, {String? message}) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) ToastHelper.showSuccess(context, message ?? context.l10n.plansLinkCopied);
}

/// Public link to a route of this app (e.g. `/plan?key=…`).
///
/// On the web the current origin is used (hash URL strategy), in the native
/// apps the public web app (attendix.de, like Ionic).
String planPublicUrl(String pathAndQuery) {
  if (kIsWeb) {
    return '${Uri.base.origin}${Uri.base.path}#$pathAndQuery';
  }
  return 'https://attendix.de$pathAndQuery';
}
