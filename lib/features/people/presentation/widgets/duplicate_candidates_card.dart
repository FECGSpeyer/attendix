import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import 'package:ionicons/ionicons.dart';
import 'ion/ion_widgets.dart'
    show IonBadge, IonItem, IonItemDivider, IonText;

/// Same-tenant, account-less people similar to a pending applicant
/// (Ionic person.page loadDuplicateCandidates).
final duplicateCandidatesProvider =
    FutureProvider.family<List<RankedMatch<Person>>, Person>((ref, person) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  if (!repo.hasTenantId || person.id == null || !person.pending) return [];
  try {
    return await repo.getPossibleDuplicatesInTenant(
      person.firstName,
      person.lastName,
      excludeId: person.id!,
    );
  } catch (_) {
    return [];
  }
});

/// "Ähnliche Person bereits vorhanden" card with "Zusammenführen" actions
/// for a pending registration (Ionic person.page duplicateCandidates).
class DuplicateCandidatesCard extends ConsumerStatefulWidget {
  const DuplicateCandidatesCard({
    super.key,
    required this.person,
    required this.onMerged,
  });

  final Person person;

  /// Called after a successful merge (the pending row no longer exists).
  final VoidCallback onMerged;

  @override
  ConsumerState<DuplicateCandidatesCard> createState() =>
      _DuplicateCandidatesCardState();
}

class _DuplicateCandidatesCardState
    extends ConsumerState<DuplicateCandidatesCard> {
  bool _merging = false;

  Future<void> _confirmMerge(Person candidate) async {
    final playerRepo = ref.read(playerRepositoryWithTenantProvider);
    final p = widget.person;
    final name = '${p.firstName} ${p.lastName}';
    final candidateName = '${candidate.firstName} ${candidate.lastName}';
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.personMergePeople),
        content: Text(context.l10n.personMergeMessage(name, candidateName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.personMerge),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // The root messenger outlives this card.
    final toastContext = ScaffoldMessenger.of(context).context;
    final l10n = context.l10n;
    setState(() => _merging = true);
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      final approver = tenantUser?.email ??
          ref.read(supabaseClientProvider).auth.currentUser?.email ??
          '';
      await playerRepo
          .mergePendingPlayerIntoExisting(p, candidate, approverEmail: approver);
      if (toastContext.mounted) {
        ToastHelper.showSuccess(toastContext, l10n.personMerged, beta: LegacySnackBar.success);
      }
      widget.onMerged();
    } catch (_) {
      if (toastContext.mounted) {
        ToastHelper.showError(toastContext, l10n.personMergeFailed, beta: LegacySnackBar.danger);
      }
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches =
        ref.watch(duplicateCandidatesProvider(widget.person)).valueOrNull ??
            const [];
    if (matches.isEmpty) return const SizedBox.shrink();
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const {};

    // PEO-24: Ionic `ion-item-divider` + items with a person icon, h3/p,
    // a medium `%` badge and a small outlined merge button
    // (person.html:100-126). Beta keeps its card.
    if (context.rdSkin == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IonItemDivider(text: context.l10n.personSimilarExists),
          if (_merging) const LinearProgressIndicator(),
          for (final m in matches)
            IonItem(
              start: Icon(Ionicons.personOutline, color: AppColors.medium),
              end: [
                IonBadge(
                  text: '${(m.score * 100).round()}%',
                  color: AppColors.medium,
                ),
                const SizedBox(width: 8),
                IonButton(
                  label: context.l10n.personMerge,
                  fill: IonButtonFill.outline,
                  small: true,
                  onPressed:
                      _merging ? null : () => _confirmMerge(m.candidate),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m.candidate.firstName} ${m.candidate.lastName}',
                    style: IonText.h3(context),
                  ),
                  if (m.candidate.instrument != null &&
                      groups[m.candidate.instrument] != null)
                    Text(groups[m.candidate.instrument]!,
                        style: IonText.p(context)),
                  Text(m.reason, style: IonText.p(context)),
                ],
              ),
            ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(AppIcons.peopleAltOutlined, color: AppColors.warning),
            title: Text(
              context.l10n.personSimilarExists,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (_merging) const LinearProgressIndicator(),
          for (final m in matches)
            ListTile(
              title: Text('${m.candidate.firstName} ${m.candidate.lastName}'),
              subtitle: Text([
                if (m.candidate.instrument != null &&
                    groups[m.candidate.instrument] != null)
                  groups[m.candidate.instrument]!,
                m.reason,
              ].join(' · ')),
              trailing: TextButton(
                onPressed: _merging ? null : () => _confirmMerge(m.candidate),
                child: IonButtonLabel(context.l10n.personMerge),
              ),
            ),
        ],
      ),
    );
  }
}
