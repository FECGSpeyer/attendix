import 'package:flutter/material.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart' show RdSkinContext;
import 'package:attendix/core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:ionicons/ionicons.dart';
import 'ion/ion_widgets.dart'
    show IonBadge, IonItem, IonText, ionLightColor;

/// Inline typeahead list of possible matches in linked tenants
/// (Ionic person.page `name-suggestions`).
class PersonMatchSuggestions extends StatelessWidget {
  const PersonMatchSuggestions({
    super.key,
    required this.matches,
    required this.onSelected,
    required this.onDismiss,
  });

  final List<RankedMatch<CrossTenantPersonCandidate>> matches;
  final void Function(CrossTenantPersonCandidate) onSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (context.rdSkin == null) return _buildIonic(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Icon(AppIcons.peopleAltOutlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.personFlutterMatchFound,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.close),
                  tooltip: context.l10n.personCloseSuggestions,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
          for (final m in matches)
            ListTile(
              dense: true,
              leading: Icon(
                m.candidate.person.appId != null
                    ? AppIcons.accountCircle
                    : (m.candidate.person.email?.isNotEmpty ?? false)
                        ? AppIcons.mail
                        : AppIcons.helpOutline,
                color: m.candidate.person.appId != null
                    ? AppColors.success
                    : (m.candidate.person.email?.isNotEmpty ?? false)
                        ? AppColors.primary
                        : AppColors.medium,
              ),
              title: Text(
                  '${m.candidate.person.firstName} ${m.candidate.person.lastName}'),
              subtitle: Text(
                '${m.candidate.groupName ?? '?'} · ${m.candidate.tenantName ?? '?'}\n${m.reason}',
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (m.candidate.person.appId != null)
                    _Badge(text: context.l10n.personAccountBadge, color: AppColors.success)
                  else if (m.candidate.person.email?.isNotEmpty ?? false)
                    _Badge(text: context.l10n.peopleEmail, color: AppColors.primary),
                  const SizedBox(height: 4),
                  _Badge(
                    text: '${(m.score * 100).round()}%',
                    color: AppColors.medium,
                  ),
                ],
              ),
              onTap: () => onSelected(m.candidate),
            ),
        ],
      ),
    );
  }
}

extension on PersonMatchSuggestions {
  /// PEO-24: Ionic `.name-suggestions` – `ion-list lines="full"` on light
  /// background with rounded corners, a small solid round close button top
  /// right, a coloured start icon and solid badges (person.html:127-158,
  /// person.page.scss:132-160).
  Widget _buildIonic(BuildContext context) {
    final light = ionLightColor(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: light,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 48, 4),
                child: Text(
                  context.l10n.personFlutterMatchFound,
                  style: IonText.h3(context),
                ),
              ),
              for (final m in matches)
                IonItem(
                  background: light,
                  onTap: () => onSelected(m.candidate),
                  start: Icon(
                    m.candidate.person.appId != null
                        ? Ionicons.personCircleOutline
                        : (m.candidate.person.email?.isNotEmpty ?? false)
                            ? Ionicons.mailOutline
                            : Ionicons.helpCircleOutline,
                    color: m.candidate.person.appId != null
                        ? AppColors.success
                        : (m.candidate.person.email?.isNotEmpty ?? false)
                            ? AppColors.primary
                            : AppColors.medium,
                  ),
                  end: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (m.candidate.person.appId != null)
                          IonBadge(
                            text: context.l10n.personAccountBadge,
                            color: AppColors.success,
                          )
                        else if (m.candidate.person.email?.isNotEmpty ?? false)
                          IonBadge(text: context.l10n.peopleEmail),
                        const SizedBox(height: 4),
                        IonBadge(
                          text: '${(m.score * 100).round()}%',
                          color: AppColors.medium,
                        ),
                      ],
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${m.candidate.person.firstName} ${m.candidate.person.lastName}',
                        style: IonText.h3(context),
                      ),
                      Text(
                        '${m.candidate.groupName ?? '?'} · ${m.candidate.tenantName ?? '?'}',
                        style: IonText.p(context),
                      ),
                      Text(m.reason, style: IonText.p(context)),
                    ],
                  ),
                ),
            ],
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Semantics(
              button: true,
              label: context.l10n.personCloseSuggestions,
              child: Material(
                color: AppColors.medium,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Ionicons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Dialog shown when the entered email is already used in a linked tenant
/// (Ionic onEmailBlur). Returns the person whose data should be adopted.
/// [usedBy] / [usedMany] replace the messages (the Beta says "Gruppe").
Future<CrossTenantPersonCandidate?> showEmailTakenDialog(
  BuildContext context,
  List<CrossTenantPersonCandidate> matches, {
  String Function(String name)? usedBy,
  String? usedMany,
}) {
  if (matches.length == 1) {
    final m = matches.first;
    final name = '${m.person.firstName} ${m.person.lastName}';
    return showAppDialog<CrossTenantPersonCandidate>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.personEmailTaken),
        content: Text(
          usedBy?.call(name) ?? context.l10n.personEmailUsedBy(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            // PEO-13: Ionic "Abbrechen" role destructive.
            style: appAlertDestructiveStyle(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          if (context.rdSkin == null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(context.l10n.commonYes),
            )
          else
          FilledButton(
            onPressed: () => Navigator.pop(ctx, m),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );
  }
  if (context.rdSkin == null) {
    // PEO-16: Ionic alert with radio inputs (first checked), Abbrechen
    // (destructive) / Ja.
    return showAppRadioAlert<int>(
      context,
      title: context.l10n.personEmailTaken,
      subtitle: usedMany ?? context.l10n.personEmailUsedMany,
      options: [for (var i = 0; i < matches.length; i++) (i, matches[i].label)],
      initialValue: 0,
      confirmText: context.l10n.commonYes,
      cancelDestructive: true,
    ).then((r) => r == null ? null : matches[r.value ?? 0]);
  }
  return showAppDialog<CrossTenantPersonCandidate>(
    context: context,
    builder: (ctx) => AppSimpleDialog(
      title: Text(context.l10n.personEmailTaken),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            usedMany ?? context.l10n.personEmailUsedMany,
          ),
        ),
        for (final m in matches)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, m),
            child: Text(m.label),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: IonButtonLabel(context.l10n.commonCancel),
          ),
        ),
      ],
    ),
  );
}
