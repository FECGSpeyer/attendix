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

  await showAppDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AppAlertDialog(
        title: Text(ctx.l10n.settingsSubscribeCalendar),
        // IOS_FORMS1: ion-alert message `settings.calendarMessage` (text +
        // link in one grey 15pt block); the checkbox input sits in its own
        // group below a hairline (iOS).
        contentPadding: useIosLook(ctx) ? EdgeInsets.zero : null,
        content: useIosLook(ctx)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(30, 0, 30, personal ? 21 : 19),
                    child: SelectableText(_htmlMessage(ctx.l10n.settingsCalendarMessage(link))),
                  ),
                  if (personal)
                    _IosAlertCheckbox(
                      label: ctx.l10n.settingsHideCancelled,
                      value: hideExcused,
                      onChanged: (v) => setState(() => hideExcused = v),
                    ),
                ],
              )
            // IOS_FORMS1 (md): message, then the checkbox group between two
            // hairlines (`.alert-checkbox-group` border-top/-bottom) on the
            // dialog background.
            // PARITY_R3: Ionic md alert ≈272 wide (min 250, the long link
            // wraps anywhere instead of widening the alert).
            : SizedBox(
                width: 224,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectableText(_htmlMessage(ctx.l10n.settingsCalendarMessage(link))),
                  if (personal) ...[
                    const SizedBox(height: 16),
                    _MdAlertCheckbox(
                      label: ctx.l10n.settingsHideCancelled,
                      value: hideExcused,
                      onChanged: (v) => setState(() => hideExcused = v),
                    ),
                  ],
                ],
              ),
              ),
        // 3 buttons: stacked (iOS pills / md right-aligned uppercase),
        // laid out centrally by AppAlertDialog.
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

/// IOS_FORMS1 (md): checkbox input of an Ionic md `ion-alert` – hairlines
/// above and below the group, square primary checkbox and the label, no
/// tinted row background.
class _MdAlertCheckbox extends StatelessWidget {
  const _MdAlertCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: Theme.of(context).dividerColor, width: 1);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: line, bottom: line)),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// IOS_FORMS1: checkbox input of an iOS `ion-alert` – hairline above the
/// group, round 22pt check circle (primary when checked) 16pt from the edge
/// and a single-line 14pt label.
class _IosAlertCheckbox extends StatelessWidget {
  const _IosAlertCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: onSurface.withValues(alpha: 0.2), width: 0.55),
        ),
      ),
      child: Semantics(
        checked: value,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? theme.colorScheme.primary : Colors.transparent,
                    border: Border.all(
                      width: 2,
                      color: value
                          ? theme.colorScheme.primary
                          : (theme.brightness == Brightness.dark
                              ? const Color(0xFF545458)
                              : const Color(0xFFC8C7CC)),
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PARITY_R3: ion-alert renders `message` as HTML – line breaks collapse
/// to a space, so the link follows the text inline.
String _htmlMessage(String message) =>
    message.replaceAll(RegExp(r'\s*\n\s*'), ' ');
