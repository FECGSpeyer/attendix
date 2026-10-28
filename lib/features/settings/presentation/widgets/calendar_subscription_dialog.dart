import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// iCal feed URL of the Supabase edge function `ical-tenant`
/// (Ionic settings `openCalendarSubscription()`).
String calendarSubscriptionLink({required int tenantId, int? personId}) {
  final base = '${SupabaseConfig.supabaseUrl}/functions/v1/ical-tenant?tenantId=$tenantId';
  return personId != null ? '$base&personId=$personId' : base;
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
  final link = calendarSubscriptionLink(tenantId: tenantId, personId: personId);
  final personal = personId != null;
  if (!context.mounted) return;
  final isIos = Theme.of(context).platform == TargetPlatform.iOS;
  var hideExcused = false;

  await showAppDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppAlertDialog(
        title: Text(ctx.l10n.settingsSubscribeCalendar),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.settingsFlutterCalendarIntro),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 12)),
            if (personal)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(ctx.l10n.settingsHideCancelled),
                value: hideExcused,
                onChanged: (v) => setState(() => hideExcused = v ?? false),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
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
            },
            child: Text(ctx.l10n.settingsCopyLink),
          ),
          TextButton(
            onPressed: () async {
              try {
                await launchUrl(
                  Uri.parse(isIos
                      ? 'https://support.apple.com/de-de/102301'
                      : 'https://support.google.com/calendar/answer/37100?hl=de&co=GENIE.Platform%3DAndroid'),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
            },
            child: Text(ctx.l10n.settingsOpenGuide),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.commonClose),
          ),
        ],
      ),
    ),
  );
}
