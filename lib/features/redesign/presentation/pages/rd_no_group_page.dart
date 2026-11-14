import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../tenant_selection/presentation/pages/tenant_create_page.dart'
    show confirmDeleteAccountWithoutGroup;
import '../rd_actions.dart';
import '../widgets/join/rd_join_sheet.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN (UX N1): signed in without any group. Instead of the bare
/// "Neue Instanz" form: join with an invitation (the usual case) or start
/// an own group. Only with the Beta switch on; the default app keeps the
/// Ionic flow.
class RdNoGroupPage extends ConsumerWidget {
  const RdNoGroupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget small(String label, VoidCallback onPressed, {Key? key}) => TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: p.text2, minimumSize: const Size(44, 44)),
      child: Text(label, style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
    );
    return RdPage(
      children: [
        const SizedBox(height: 24),
        Semantics(header: true, child: Text(l10n.redesignJoinWelcomeNoName, style: RdType.largeTitle(p))),
        const SizedBox(height: 8),
        Text(l10n.redesignJoinNoGroup, style: RdType.body(p).copyWith(color: p.text2)),
        const SizedBox(height: 20),
        _Choice(
          icon: Icons.mail_outline,
          title: l10n.redesignJoinHaveInvite,
          hint: l10n.redesignJoinHaveInviteHint,
          button: RdPrimaryButton(
            label: l10n.redesignJoinTitle,
            icon: Icons.group_add_outlined,
            onPressed: () => showRdJoinSheet(context),
          ),
        ),
        // One main action (joining is the usual case): founding a group is
        // a link, "Ausloggen" and "Konto löschen" sit small at the very end.
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RdTextLink(
            key: const Key('rd-no-group-create'),
            label: l10n.redesignJoinCreate,
            onTap: () => context.push('/tenants/new'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(l10n.redesignJoinCreateHint, style: RdType.meta(p, size: 13)),
        ),
        const SizedBox(height: 40),
        // Like the old "Neue Instanz" page (and required by the App Store):
        // the account can be deleted without being in a group.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            small(l10n.redesignMeLogout, () => rdLogout(context, ref), key: const Key('rd-no-group-logout')),
            Text('·', style: RdType.meta(p, size: 13)),
            small(
              l10n.redesignTenantsDeleteAccount,
              () => confirmDeleteAccountWithoutGroup(context, ref),
              key: const Key('rd-no-group-delete'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.hint, required this.button});

  final IconData icon;
  final String title;
  final String hint;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RdRowIcon(icon, color: p.primary, background: p.soft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: RdType.body(p).copyWith(fontWeight: FontWeight.w600)),
                    Text(hint, style: RdType.meta(p, size: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          button,
        ],
      ),
    );
  }
}
