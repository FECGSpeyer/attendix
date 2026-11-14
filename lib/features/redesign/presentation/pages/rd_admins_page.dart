import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/admin_repository.dart' show TenantAdmin;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../settings/presentation/widgets/settings_admins_sheet.dart'
    show removeAdminWithConfirmation, showAddAdminDialog;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/rd_widgets.dart' show rdBack;

/// REDESIGN: Verwaltung › Admins in the template "Verwaltungsliste"
/// (replaces the old admins sheet while the Beta is on; super admins only,
/// see `RedesignRoutes.roleRedirect`). The admins with "Erstellt am", "+"
/// adds one by e-mail (old dialog), a tap offers "Admin entfernen" (old
/// confirmation); the own entry cannot be removed, as before.
class RdAdminsPage extends ConsumerWidget {
  const RdAdminsPage({super.key});

  Future<void> _onTap(BuildContext context, WidgetRef ref, TenantAdmin admin, {required bool own}) async {
    final l10n = context.l10n;
    // Old sheet: tapping the own entry only explains it.
    if (own) {
      ToastHelper.showError(context, l10n.settingsCannotRemoveSelf);
      return;
    }
    // TENANT: bound to the group of the shown list before the first await.
    final repo = ref.read(adminRepositoryWithTenantProvider);
    final remove = await showAppActionSheet<bool>(
      context,
      title: admin.email,
      actions: [
        AppActionSheetAction(
          value: true,
          icon: Icons.person_remove_outlined,
          label: l10n.redesignAdminsListRemove,
          destructive: true,
        ),
      ],
    );
    if (remove != true || !context.mounted) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD (the old entry is hidden in the demo)
    await removeAdminWithConfirmation(context, ref, admin, repo: repo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(adminsProvider);
    final busy = ref.watch(adminNotifierProvider).isLoading;
    final ownId = ref.watch(currentAuthUserIdProvider);
    // TENANT: never the old group's list after a group or account switch.
    final admins = rdLoadedValue(async);
    final format = DateFormat(dateFmt());

    String? subtitle(TenantAdmin a) {
      final parts = [
        if (a.userId == ownId) l10n.redesignAdminsListYou,
        if (a.createdAt != null) l10n.commonCreatedAt(format.format(a.createdAt!.toLocal())),
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.admins),
      // A row of Rollen und Rechte: back leads there, also on wide screens.
      backLabel: rdManageTitle(l10n, RdManageEntry.rolesPermissions),
      onBack: () => rdBack(context, RedesignRoutes.rolePermissions),
      backInSplit: true,
      intro: l10n.redesignAdminsListIntro,
      sections: admins == null
          ? null
          : [
              RdManageListSection(
                items: [
                  for (final a in admins)
                    RdManageListItem(
                      id: a.userId,
                      title: a.email ?? '',
                      subtitle: subtitle(a),
                      icon: Icons.verified_user_outlined,
                      onTap: () => _onTap(context, ref, a, own: a.userId == ownId),
                    ),
                ],
              ),
            ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(adminsProvider),
      emptyText: l10n.redesignAdminsListEmpty,
      emptyIcon: Icons.verified_user_outlined,
      addLabel: l10n.redesignAdminsListAdd,
      // Old sheet: "+" waits while an admin is added or removed.
      onAdd: busy || admins == null
          ? null
          : () {
              if (DemoGuard.blocked()) return; // DEMO_GUARD
              showAddAdminDialog(context, ref);
            },
      onRefresh: () async {
        ref.invalidate(adminsProvider);
        await ref.read(adminsProvider.future).catchError((_) => const <TenantAdmin>[]);
      },
    );
  }
}
