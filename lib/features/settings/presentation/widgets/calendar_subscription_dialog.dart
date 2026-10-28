import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/toast_helper.dart';

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

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Kalender abonnieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kopiere den folgenden Link in deine Kalender-App, um die Termine zu abonnieren:'),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 12)),
            if (personal)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Abgesagte Termine ausblenden'),
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
                  ToastHelper.showError(ctx, 'Link konnte nicht kopiert werden');
                }
                return;
              }
              if (ctx.mounted) {
                ToastHelper.showSuccess(ctx, 'Der Link wurde in die Zwischenablage kopiert');
              }
            },
            child: const Text('Link kopieren'),
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
            child: const Text('Anleitung öffnen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    ),
  );
}
