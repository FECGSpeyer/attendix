import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/utils/toast_helper.dart';
import 'plan_field_dialogs.dart';

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
  String title = 'Exportieren',
  bool withImage = true,
  List<PlanSheetAction<String>> extraActions = const [],
  Future<void> Function(String action)? onExtraAction,
}) async {
  final chatId = planTelegramChatId(ref);
  final action = await showPlanActionSheet<String>(
    context,
    title: title,
    actions: [
      ...extraActions,
      const PlanSheetAction('pdf', 'PDF (A4)', icon: Icons.picture_as_pdf_outlined),
      const PlanSheetAction('pdf2x', 'PDF (2x A5)', icon: Icons.content_copy_outlined),
      if (withImage) const PlanSheetAction('image', 'Bild (A4)', icon: Icons.image_outlined),
      if (chatId != null) ...const [
        PlanSheetAction('telegram', 'Per Telegram senden (PDF)', icon: Icons.send_outlined),
        PlanSheetAction('telegram2x', 'Per Telegram senden (PDF 2x A5)', icon: Icons.send_outlined),
        PlanSheetAction('telegramImage', 'Per Telegram senden (Bild)', icon: Icons.send_outlined),
      ],
    ],
  );
  if (action == null || !context.mounted) return;
  if (extraActions.any((a) => a.value == action)) {
    await onExtraAction?.call(action);
    return;
  }
  final parsed = PlanExportAction.values.byName(action);
  await runPlanExport(context, ref, parsed, pages: pages(), fileName: fileName);
}

/// Runs one export action.
Future<void> runPlanExport(
  BuildContext context,
  WidgetRef ref,
  PlanExportAction action, {
  required List<PlanExportPage> pages,
  required String fileName,
}) async {
  if (pages.isEmpty || pages.every((p) => p.fields.isEmpty)) {
    ToastHelper.showWarning(context, 'Kein Plan verfügbar');
    return;
  }
  final service = ref.read(planExportServiceProvider);
  final sideBySide = action == PlanExportAction.pdf2x || action == PlanExportAction.telegram2x;
  try {
    switch (action) {
      case PlanExportAction.pdf:
      case PlanExportAction.pdf2x:
        await service.sharePdf(pages, sideBySide: sideBySide, fileName: fileName);
      case PlanExportAction.image:
        await service.shareImage(pages, fileName: fileName);
      case PlanExportAction.telegram:
      case PlanExportAction.telegram2x:
      case PlanExportAction.telegramImage:
        final chatId = planTelegramChatId(ref);
        if (chatId == null) {
          if (context.mounted) ToastHelper.showError(context, 'Telegram nicht konfiguriert');
          return;
        }
        final asImage = action == PlanExportAction.telegramImage;
        final bytes = asImage
            ? await service.buildImage(pages)
            : await service.buildPdf(pages, sideBySide: sideBySide);
        await ref.read(telegramServiceProvider).sendPlanPerTelegram(
              fileBytes: bytes,
              name: '${_safeName(fileName)}${sideBySide ? '_2x' : ''}',
              chatId: chatId,
              asImage: asImage,
            );
        if (context.mounted) ToastHelper.showSuccess(context, 'Plan wird per Telegram gesendet...');
    }
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, 'Fehler beim Export: $e');
  }
}

String _safeName(String name) => name.replaceAll('(', '').replaceAll(')', '').replaceAll(' ', '_');

/// Shares a link via the system share sheet, falls back to the clipboard.
Future<void> sharePlanLink(BuildContext context, String url, {String? title}) async {
  try {
    final result = await Share.share(url, subject: title);
    if (result.status == ShareResultStatus.unavailable) {
      throw Exception('unavailable');
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) ToastHelper.showSuccess(context, 'Link in Zwischenablage kopiert');
  }
}

/// Copies text and shows a toast.
Future<void> copyPlanLink(BuildContext context, String url, {String message = 'Link kopiert'}) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) ToastHelper.showSuccess(context, message);
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
