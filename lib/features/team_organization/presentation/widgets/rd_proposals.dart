import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../team_org_utils.dart';

/// Accepts a member's suggestion (it becomes an open topic).
/// [toast] false leaves the success message to the caller.
Future<bool> acceptProposal(BuildContext context, WidgetRef ref, AgendaItem item, {bool toast = true}) =>
    _decide(context, ref, item, {'proposal_status': 'accepted', 'decision_note': null},
        toast ? context.l10n.rdTeamAcceptedLater : null);

/// Asks for an optional reason and rejects a member's suggestion.
Future<bool> rejectProposal(BuildContext context, WidgetRef ref, AgendaItem item) async {
  final l10n = context.l10n;
  final controller = TextEditingController();
  final name = item.proposer.fullName.isNotEmpty ? item.proposer.fullName : l10n.teamOrgThePerson;
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(ctx.l10n.teamOrgRejectSuggestion),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ctx.l10n.teamOrgPersonInformed(name)),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(hintText: ctx.l10n.teamOrgReasonOptional),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(ctx.l10n.teamOrgReject)),
      ],
    ),
  );
  final note = controller.text.trim();
  controller.dispose();
  if (ok != true || !context.mounted) return false;
  return _decide(context, ref, item, {'proposal_status': 'rejected', 'decision_note': note.isEmpty ? null : note},
      l10n.teamOrgSuggestionRejected);
}

Future<bool> _decide(
    BuildContext context, WidgetRef ref, AgendaItem item, Map<String, dynamic> changes, String? doneText) async {
  final id = item.id;
  if (id == null) return false;
  try {
    await ref.read(agendaItemNotifierProvider.notifier).decide(id, changes);
    if (context.mounted && doneText != null) ToastHelper.showSuccess(context, doneText);
    return true;
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.teamOrgDecisionFailed);
    return false;
  }
}

/// One pending suggestion with its two decisions and an optional third as
/// a text link below.
class RdProposalCard extends StatelessWidget {
  const RdProposalCard({
    super.key,
    required this.item,
    required this.busy,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.linkLabel,
    this.onLink,
  });

  final AgendaItem item;
  final bool busy;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final name = item.proposer.fullName.isNotEmpty ? item.proposer.fullName : l10n.teamOrgFlutterMember;
    final description = item.description?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RdCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RdInitials(item.proposer.initials.isNotEmpty ? item.proposer.initials : '?', size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: RdType.body(p).copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(l10n.rdTeamSuggestedBy(name, relativeDay(item.createdAt)), style: RdType.meta(p, size: 13)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(description, style: RdType.meta(p)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: RdOutlineButton(label: secondaryLabel, onPressed: busy ? null : onSecondary)),
                const SizedBox(width: 8),
                Expanded(child: RdPrimaryButton(label: primaryLabel, onPressed: busy ? null : onPrimary)),
              ],
            ),
            if (linkLabel != null && onLink != null) ...[
              const SizedBox(height: 6),
              Center(child: RdTextLink(label: linkLabel!, onTap: busy ? () {} : onLink!)),
            ],
          ],
        ),
      ),
    );
  }
}
