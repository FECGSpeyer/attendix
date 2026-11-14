import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart' show Role;
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../data/models/parent/parent_model.dart';
import '../../../../data/models/viewer/viewer.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../settings/presentation/pages/parents_page.dart' show ParentsPage;
import '../../../settings/presentation/pages/user_management_page.dart' show TenantUser, tenantUsersProvider;
import '../../../settings/presentation/pages/viewers_page.dart' show ViewersPage;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/members/rd_invite_sheet.dart' show showRdInviteSheet;
import '../widgets/rd_widgets.dart' show RdPrimaryButton, rdBack;
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import 'rd_general_settings_page.dart' show RdTenantSettings, RdTenantSettingsBlock;

/// REDESIGN: Verwaltung › Eltern in the template "Verwaltungsliste"
/// (replaces the old parents sheet while the Beta is on; leads only). Name
/// and e-mail, "+" invites (old dialog incl. account), a tap offers
/// "Elternteil entfernen" (old confirmation).
class RdParentsPage extends ConsumerWidget {
  const RdParentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(parentsProvider);
    // TENANT: never the old group's list after a group or account switch.
    final parents = rdLoadedValue(async);
    final accounts = parents == null
        ? const <TenantUser>[]
        : rdRoleAccountsWithoutEntry(ref.watch(tenantUsersProvider), Role.parent, {for (final p in parents) p.appId});
    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.parents),
      // A row of Rollen und Rechte: back leads there, also on wide screens.
      backLabel: rdManageTitle(l10n, RdManageEntry.rolesPermissions),
      onBack: () => rdBack(context, RedesignRoutes.rolePermissions),
      backInSplit: true,
      intro: l10n.redesignParentsListIntro,
      // The switch of the old "Allgemein", then the one main action: the
      // sign-up link, where parents register their child ("Mein Kind").
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RdTenantSettingsBlock(sections: [RdTenantSettings.parents]),
          const SizedBox(height: 12),
          RdInfoCard(
            key: const Key('rd-parents-share'),
            icon: Icons.link,
            text: '${l10n.parentRegisterShareTitle} ${l10n.parentRegisterShareHint}',
            action: RdPrimaryButton(
              label: l10n.parentRegisterShareButton,
              icon: Icons.ios_share,
              onPressed: () => showRdInviteSheet(context),
            ),
          ),
        ],
      ),
      sections: parents == null
          ? null
          : [
              RdManageListSection(
                items: [
                  for (final p in parents)
                    RdManageListItem(
                      id: p.id ?? p.email,
                      title: p.fullName,
                      subtitle: p.email,
                      onTap: () => _onTap(context, ref, p),
                    ),
                ],
              ),
              _accountsSection(l10n.redesignParentsListAccounts, accounts),
            ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(parentsProvider),
      emptyText: l10n.redesignParentsListEmpty,
      emptyIcon: Icons.favorite_border,
      // Inviting by e-mail stays, in the "•••" menu (one main action).
      actions: [
        RdManageListAction(
          label: l10n.parentRegisterInviteByEmail,
          icon: Icons.mail_outline,
          onSelected: () => ParentsPage.showAddParentDialog(context, ref),
        ),
      ],
      onRefresh: () async {
        ref.invalidate(parentsProvider);
        ref.invalidate(tenantUsersProvider);
        await ref.read(parentsProvider.future).catchError((_) => const <ParentModel>[]);
      },
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref, ParentModel parent) async {
    // TENANT: bound to the group of the shown list before the first await.
    final repo = ref.read(parentRepositoryWithTenantProvider);
    if (!await rdConfirmRemoveAction(context, parent.fullName, context.l10n.redesignParentsListRemove)) return;
    if (context.mounted) await ParentsPage.removeParentWithConfirmation(context, ref, parent, repo: repo);
  }
}

/// REDESIGN: Verwaltung › Beobachter in the template "Verwaltungsliste"
/// (replaces the old viewers sheet while the Beta is on; leads only). Like
/// [RdParentsPage].
class RdViewersPage extends ConsumerWidget {
  const RdViewersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(viewersProvider);
    // TENANT: never the old group's list after a group or account switch.
    final viewers = rdLoadedValue(async);
    final accounts = viewers == null
        ? const <TenantUser>[]
        : rdRoleAccountsWithoutEntry(ref.watch(tenantUsersProvider), Role.viewer, {for (final v in viewers) v.appId});
    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.viewers),
      // A row of Rollen und Rechte: back leads there, also on wide screens.
      backLabel: rdManageTitle(l10n, RdManageEntry.rolesPermissions),
      onBack: () => rdBack(context, RedesignRoutes.rolePermissions),
      backInSplit: true,
      intro: l10n.redesignViewersListIntro,
      sections: viewers == null
          ? null
          : [
              RdManageListSection(
                items: [
                  for (final v in viewers)
                    RdManageListItem(
                      id: v.id ?? v.email,
                      title: v.fullName,
                      subtitle: v.email,
                      onTap: () => _onTap(context, ref, v),
                    ),
                ],
              ),
              _accountsSection(l10n.redesignViewersListAccounts, accounts),
            ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(viewersProvider),
      emptyText: l10n.redesignViewersListEmpty,
      emptyIcon: Icons.visibility_outlined,
      addLabel: l10n.redesignViewersListAdd,
      onAdd: viewers == null ? null : () => ViewersPage.showAddViewerDialog(context, ref),
      onRefresh: () async {
        ref.invalidate(viewersProvider);
        ref.invalidate(tenantUsersProvider);
        await ref.read(viewersProvider.future).catchError((_) => const <Viewer>[]);
      },
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref, Viewer viewer) async {
    // TENANT: bound to the group of the shown list before the first await.
    final repo = ref.read(viewerRepositoryWithTenantProvider);
    if (!await rdConfirmRemoveAction(context, viewer.fullName, context.l10n.redesignViewersListRemove)) return;
    if (context.mounted) await ViewersPage.removeViewerWithConfirmation(context, ref, viewer, repo: repo);
  }
}

/// The accounts of the group with [role] that no entry of the list stands
/// for ([entryAppIds]: the accounts of the invited Eltern / Beobachter). A
/// role given another way (e.g. changed in the user list) wrote no entry,
/// so the list looked empty although somebody has that access. Empty while
/// the accounts load or cannot be read.
List<TenantUser> rdRoleAccountsWithoutEntry(AsyncValue<List<TenantUser>> users, Role role, Set<String> entryAppIds) => [
  for (final u in rdLoadedValue(users) ?? const <TenantUser>[])
    if (u.roleEnum == role && !entryAppIds.contains(u.userId)) u,
];

/// The accounts without an entry as an own section (name unknown: only the
/// e-mail; nothing to remove here, the entry is missing).
RdManageListSection _accountsSection(String title, List<TenantUser> accounts) => RdManageListSection(
  key: 'accounts',
  title: title,
  items: [
    for (final u in accounts)
      RdManageListItem(id: 'account-${u.userId}', title: u.email ?? '–', icon: Icons.person_outline),
  ],
);

/// Action sheet of a row with the one action "… entfernen"; true when it
/// was chosen (the old confirmation follows).
Future<bool> rdConfirmRemoveAction(BuildContext context, String title, String label) async {
  final remove = await showAppActionSheet<bool>(
    context,
    title: title,
    actions: [
      AppActionSheetAction(value: true, icon: Icons.person_remove_outlined, label: label, destructive: true),
    ],
  );
  return remove == true;
}
