import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.personFlutterMatchFound,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
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
                    ? Icons.account_circle
                    : (m.candidate.person.email?.isNotEmpty ?? false)
                        ? Icons.mail
                        : Icons.help_outline,
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
Future<CrossTenantPersonCandidate?> showEmailTakenDialog(
  BuildContext context,
  List<CrossTenantPersonCandidate> matches,
) {
  if (matches.length == 1) {
    final m = matches.first;
    return showAppDialog<CrossTenantPersonCandidate>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.personEmailTaken),
        content: Text(
          context.l10n.personEmailUsedBy('${m.person.firstName} ${m.person.lastName}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, m),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );
  }
  return showAppDialog<CrossTenantPersonCandidate>(
    context: context,
    builder: (ctx) => AppSimpleDialog(
      title: Text(context.l10n.personEmailTaken),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            context.l10n.personEmailUsedMany,
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
