import 'package:flutter/material.dart';

import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Dialog shown when the entered email is already used in a linked tenant
/// (Ionic onEmailBlur). Returns the person whose data should be adopted.
/// [usedBy] / [usedMany] allow custom wording for the calling form.
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
            child: Text(context.l10n.commonCancel),
          ),
        ),
      ],
    ),
  );
}
