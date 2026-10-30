import 'package:flutter/material.dart';
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

    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _merging = true);
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      final approver = tenantUser?.email ??
          ref.read(supabaseClientProvider).auth.currentUser?.email ??
          '';
      await playerRepo
          .mergePendingPlayerIntoExisting(p, candidate, approverEmail: approver);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.personMerged),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onMerged();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.personMergeFailed),
          backgroundColor: AppColors.danger,
        ),
      );
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
            leading: const Icon(Icons.people_alt_outlined, color: AppColors.warning),
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
