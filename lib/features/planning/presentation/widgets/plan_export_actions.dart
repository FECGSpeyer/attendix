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
import '../../../../core/theme/app_colors.dart';
import 'ion_items.dart';
import 'plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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

/// Choice of the Ionic `PlanShareSheetComponent`.
typedef PlanShareChoice = ({bool all, PlanExportAction action});

/// Ionic `openPlanShareSheet`: sheet "Ablaufplan teilen" with a segment
/// (only this plan / all plans) and the export options of a Termin with
/// several Ablaufpläne.
Future<PlanShareChoice?> showPlanShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required String currentLabel,
  required int planCount,
}) {
  final hasChatId = planTelegramChatId(ref) != null;
  return showModalBottomSheet<PlanShareChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => FractionallySizedBox(
      heightFactor: hasChatId ? 0.75 : 0.5,
      child: _PlanShareSheet(currentLabel: currentLabel, planCount: planCount, hasChatId: hasChatId),
    ),
  );
}

class _PlanShareSheet extends StatefulWidget {
  const _PlanShareSheet({required this.currentLabel, required this.planCount, required this.hasChatId});

  final String currentLabel;
  final int planCount;
  final bool hasChatId;

  @override
  State<_PlanShareSheet> createState() => _PlanShareSheetState();
}

class _PlanShareSheetState extends State<_PlanShareSheet> {
  bool _all = false;

  void _choose(PlanExportAction action) => Navigator.of(context).pop((all: _all, action: action));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final segments = {
      false: l10n.planningOnlyLabel(widget.currentLabel),
      true: l10n.planningAllPlans(widget.planCount),
    };
    Widget option(IconData icon, String label, PlanExportAction action) => ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label),
          onTap: () => _choose(action),
        );
    return Column(
      children: [
        AppBar(
          automaticallyImplyLeading: false,
          primary: false,
          title: Text(l10n.attendanceShareRunSheet),
          actions: [
            IconButton(
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                // Shared adaptive `ion-segment` (IOS_LOOK).
                child: IonSegment<bool>(
                  items: [
                    for (final e in segments.entries)
                      IonSegmentItem<bool>(value: e.key, label: Text(e.value)),
                  ],
                  value: _all,
                  onChanged: (v) => setState(() => _all = v),
                ),
              ),
              IonInsetList(
                dividerIndent: 56,
                children: [
                  option(Icons.description_outlined, l10n.attendanceExportPdf, PlanExportAction.pdf),
                  option(Icons.file_copy_outlined, l10n.attendanceExportPdfA5, PlanExportAction.pdf2x),
                  if (widget.hasChatId) ...[
                    option(Icons.send_outlined, l10n.attendanceTelegramPdf, PlanExportAction.telegram),
                    option(Icons.send_outlined, l10n.attendanceTelegramPdfA5, PlanExportAction.telegram2x),
                    if (!_all) option(Icons.image_outlined, l10n.attendanceTelegramImage, PlanExportAction.telegramImage),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
