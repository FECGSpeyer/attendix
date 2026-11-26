import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show IonSwitch;
import '../../../../core/services/native/native_file_service.dart';

/// iCal feed URL of the Supabase edge function `ical-tenant`
/// (Ionic settings `openCalendarSubscription()`).
///
/// Calendar texts follow the app language: Ionic appends `&lang=<code>`
/// for every language except German (the server default).
String calendarSubscriptionLink({
  required int tenantId,
  int? personId,
  String? language,
}) {
  var link = '${SupabaseConfig.supabaseUrl}/functions/v1/ical-tenant?tenantId=$tenantId';
  if (personId != null) link += '&personId=$personId';
  if (language != null && language != 'de') link += '&lang=$language';
  return link;
}

/// UX_SETTINGS: Ionic settings "Kalender abonnieren" alert.
///
/// Admins/Responsibles get the tenant feed, everybody else the personal feed
/// (`&personId=`), which can leave out cancelled Termine (`&hideExcused=1`).
Future<void> showCalendarSubscriptionDialog(BuildContext context, WidgetRef ref) async {
  final tenantId = ref.read(currentTenantProvider)?.id;
  if (tenantId == null) return;
  final role = ref.read(effectiveRoleProvider);
  int? personId;
  if (!(role.isAdmin || role.isResponsible)) {
    try {
      personId = (await ref.read(ownProfileProvider.future))?.person.id;
    } catch (_) {
      personId = null;
    }
  }
  final link = calendarSubscriptionLink(
    tenantId: tenantId,
    personId: personId,
    language: currentLanguage(),
  );
  final personal = personId != null;
  if (!context.mounted) return;
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;
  var hideExcused = false;

  Future<void> copyLink(BuildContext ctx) async {
    final finalLink = hideExcused ? '$link&hideExcused=1' : link;
    try {
      await Clipboard.setData(ClipboardData(text: finalLink));
    } catch (_) {
      if (ctx.mounted) {
        ToastHelper.showError(ctx, ctx.l10n.settingsFlutterCopyLinkFailed);
      }
      return;
    }
    if (ctx.mounted) {
      ToastHelper.showSuccess(ctx, ctx.l10n.settingsLinkCopied);
    }
  }

  Future<void> openGuide(BuildContext ctx) async {
    // IOS_PAGES3: Ionic handler returns nothing → the alert closes.
    Navigator.of(ctx).pop();
    try {
      await NativeFileService.openLinkInApp(
        Uri.parse(isIos
            ? 'https://support.apple.com/de-de/102301'
            : 'https://support.google.com/calendar/answer/37100?hl=de&co=GENIE.Platform%3DAndroid'),
      );
    } catch (_) {}
  }

  // REDESIGN (E2): Beta sheet – short sentence, the link in a card, "Link
  // kopieren" as main button, "Anleitung öffnen" as second.
  await showRdSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setState) {
          final p = ctx.rd;
          final l10n = ctx.l10n;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(l10n.settingsSubscribeCalendar, style: RdType.section(p))),
                const SizedBox(height: 6),
                Text(
                  // Without an own person (parents, observers) the link holds
                  // every Termin of the group, not only one's own.
                  personal ? l10n.redesignMeCalendarIntro : '${l10n.redesignMeCalendarIntro} ${l10n.rdTextCalendarAllEvents}',
                  style: RdType.meta(p, size: 14),
                ),
                const SizedBox(height: 12),
                RdCard(
                  child: SelectableText(
                    hideExcused ? '$link&hideExcused=1' : link,
                    style: RdType.meta(p, size: 13),
                  ),
                ),
                if (personal) ...[
                  const SizedBox(height: 12),
                  RdGroupedList(
                    children: [
                      RdListRow(
                        title: l10n.settingsHideCancelled,
                        showChevron: false,
                        trailing: IonSwitch(
                          value: hideExcused,
                          activeTrackColor: p.primary,
                          onChanged: (v) => setState(() => hideExcused = v),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                RdPrimaryButton(label: l10n.settingsCopyLink, icon: Icons.copy, onPressed: () => copyLink(ctx)),
                const SizedBox(height: 10),
                RdOutlineButton(label: l10n.settingsOpenGuide, icon: Icons.help_outline, onPressed: () => openGuide(ctx)),
              ],
            ),
          );
        },
      ),
    );
}
