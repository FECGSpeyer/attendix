import 'package:flutter/foundation.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/pdf_branding.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/services/web_window.dart' show shareUrlInBrowser;
import '../../../../core/utils/share_origin.dart';
import '../../../../data/models/attendance/attendance.dart' show AttendanceType;
import '../../../../data/models/plan/plan.dart' show PlanAttendance;
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/theme/app_colors.dart';
import 'ion_items.dart';
import 'plan_field_dialogs.dart';
import 'rd_plan_widgets.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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
  String? pdfLabel,
  String? pdf2xLabel,
  bool withTelegram = true,
  bool alwaysTelegram = false,
  bool pdf2xSuffix = false,
  List<PlanSheetAction<String>> afterPdfActions = const [],
  List<PlanSheetAction<String>> trailingActions = const [],
  String? pdfFileName,
  String? imageFileName,
  Future<PdfBranding?> Function()? branding,
  bool cancelDestructive = false,
}) async {
  // P10_SELF_PLAN: [pdfLabel] / [pdf2xLabel] carry the Ionic wording of the
  // sheet ("PDF exportieren" on the Ablaufplan editor and viewer, "PDF (A4)"
  // on the public planner), [afterPdfActions] sit right after the A4 entry
  // ("PDF exportieren (alle Pläne)") and [trailingActions] after the
  // Telegram entries ("Registerprobenplan erstellen"); [withTelegram] false
  // for the sheets without Telegram (geteilter Plan, Org-Pläne).
  final chatId = withTelegram ? planTelegramChatId(ref) : null;
  final l10n = context.l10n;
  final action = await showPlanActionSheet<String>(
    context,
    title: title ?? l10n.planningExport,
    cancelDestructive: cancelDestructive,
    actions: [
      ...extraActions,
      if (showExports) ...[
        PlanSheetAction('pdf', pdfLabel ?? l10n.planningFlutterPdfA4, icon: AppIcons.pictureAsPdfOutlined),
        ...afterPdfActions,
        PlanSheetAction('pdf2x', pdf2xLabel ?? l10n.planningFlutterPdf2xA5, icon: AppIcons.contentCopyOutlined),
        if (withImage) PlanSheetAction('image', l10n.plansImageA4, icon: AppIcons.imageOutlined),
      ],
      // [alwaysTelegram]: Ionic Termin page lists the Telegram entries even
      // without a linked chat (the export then reports the missing chat).
      if (showExports && withTelegram && (chatId != null || alwaysTelegram)) ...[
        PlanSheetAction('telegram', l10n.attendanceTelegramPdf, icon: AppIcons.sendOutlined),
        PlanSheetAction('telegram2x', l10n.planningFlutterTelegramPdf2x, icon: AppIcons.sendOutlined),
        PlanSheetAction('telegramImage', l10n.attendanceTelegramImage, icon: AppIcons.sendOutlined),
      ],
      ...trailingActions,
    ],
  );
  if (action == null || !context.mounted) return;
  if ([...extraActions, ...afterPdfActions, ...trailingActions].any((a) => a.value == action)) {
    await onExtraAction?.call(action);
    return;
  }
  // Ionic `export()` / `send()` validate (with toast) when clicked.
  if (beforeExport != null && !beforeExport()) return;
  final parsed = PlanExportAction.values.byName(action);
  await runPlanExport(context, ref, parsed,
      pages: pages(),
      fileName: fileName,
      pdfFileName: pdfFileName,
      imageFileName: imageFileName,
      includeBranding: includeBranding,
      pdf2xSuffix: pdf2xSuffix,
      branding: branding);
}

/// Runs one export action.
///
/// [pdf2xSuffix]: kept for callers; the saved 2x A5 PDF always gets `_2x`
/// (Ionic `createPlanExportFile` → `downloadFileNative`).
Future<void> runPlanExport(
  BuildContext context,
  WidgetRef ref,
  PlanExportAction action, {
  required List<PlanExportPage> pages,
  required String fileName,
  bool includeBranding = true,
  bool pdf2xSuffix = false,
  String? pdfFileName,
  String? imageFileName,
  Future<PdfBranding?> Function()? branding,
}) async {
  if (pages.isEmpty || pages.every((p) => p.fields.isEmpty)) {
    ToastHelper.showWarning(context, context.l10n.planningNoPlan);
    return;
  }
  final service = ref.read(planExportServiceProvider);
  final sideBySide = action == PlanExportAction.pdf2x || action == PlanExportAction.telegram2x;
  try {
    // MISC2: tenant/org branding in the letterhead (Ionic buildTenantBranding)
    // [branding] overrides it (Ionic public-planning / shared-plan: the
    // plan's own public branding, never the viewer's instance).
    final PdfBranding? resolved = !includeBranding
        ? null
        : branding != null
            ? await branding()
            : await resolvePdfBranding(ref);
    switch (action) {
      case PlanExportAction.pdf:
      case PlanExportAction.pdf2x:
        // Ionic downloadFileNative: saved, `_2x` added by savePdf.
        await service.savePdf(pages,
            sideBySide: sideBySide, fileName: pdfFileName ?? fileName, branding: resolved);
      case PlanExportAction.image:
        await service.shareImage(pages, fileName: imageFileName ?? fileName, branding: resolved);
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
            ? await service.buildImage(pages, branding: resolved)
            : await service.buildPdf(pages, sideBySide: sideBySide, branding: resolved);
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
///
/// Web (Ionic): Web Share API when the browser has it, otherwise copy +
/// toast. share_plus reports "unavailable" on the web even after a
/// successful share, so it is not used there.
Future<void> sharePlanLink(BuildContext context, String url, {String? title}) async {
  final shared = await shareUrlInBrowser(url, title: title);
  if (shared != null) {
    if (!shared) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) ToastHelper.showSuccess(context, context.l10n.planningLinkCopied);
    }
    return;
  }
  try {
    final result = await Share.share(
      url,
      subject: title,
      sharePositionOrigin: shareOriginFor(context),
    );
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
  if (context.rdSkin != null) {
    return showRdPlanShareSheet(context, currentLabel: currentLabel, planCount: planCount, hasChatId: hasChatId);
  }
  // Ionic openPlanShareSheet: breakpoints [0, 0.75 | 0.5, 1]
  final initial = hasChatId ? 0.75 : 0.5;
  return showIonSheet<PlanShareChoice>(
    context,
    breakpoints: [0, initial, 1],
    initialBreakpoint: initial,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_, scrollController) => _PlanShareSheet(
      currentLabel: currentLabel,
      planCount: planCount,
      hasChatId: hasChatId,
      scrollController: scrollController,
    ),
  );
}

class _PlanShareSheet extends StatefulWidget {
  const _PlanShareSheet({
    required this.currentLabel,
    required this.planCount,
    required this.hasChatId,
    this.scrollController,
  });

  final String currentLabel;
  final int planCount;
  final bool hasChatId;
  final ScrollController? scrollController;

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
    // Ionic plan-share-sheet: toolbar title + close ✕ at the end.
    return IonSheetScaffold(
      title: l10n.attendanceShareRunSheet,
      showClose: true,
      body: Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scrollController,
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
                // ABL-16: Ionic icons document / documents / paper-plane.
                dividerIndent: 56,
                children: [
                  option(AppIcons.documentOutline, l10n.attendanceExportPdf, PlanExportAction.pdf),
                  option(AppIcons.documentsOutline, l10n.attendanceExportPdfA5, PlanExportAction.pdf2x),
                  if (widget.hasChatId) ...[
                    option(AppIcons.paperPlaneOutline, l10n.attendanceTelegramPdf, PlanExportAction.telegram),
                    option(AppIcons.paperPlaneOutline, l10n.attendanceTelegramPdfA5, PlanExportAction.telegram2x),
                    if (!_all) option(AppIcons.imageOutlined, l10n.attendanceTelegramImage, PlanExportAction.telegramImage),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

/// Type of [att] for export titles (Ionic `getPlanningTitle(type, typeInfo)`).
/// Waits for the types of the current instance instead of treating "still
/// loading" as "no type"; an org plan of another instance reads its type in
/// that instance (repository bound to `att.tenantId`, filtered by it).
/// Null when unknown or not readable.
Future<AttendanceType?> resolvePlanAttendanceType(WidgetRef ref, PlanAttendance att) async {
  final typeId = att.typeId;
  if (typeId == null || typeId.isEmpty) return null;
  try {
    final current = ref.read(currentTenantIdProvider);
    final tenantId = att.tenantId;
    if (tenantId == null || tenantId == current) {
      final types = await ref.read(attendanceTypesProvider.future);
      return types.where((t) => t.id == typeId).firstOrNull;
    }
    return await ref.read(attendanceTypeRepositoryForTenantProvider(tenantId)).getTypeById(typeId);
  } catch (_) {
    return null;
  }
}
