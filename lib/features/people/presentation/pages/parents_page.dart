import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart' show Role;
import '../../../../core/providers/admin_providers.dart' show TenantUser, tenantUsersProvider;
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/parent/parent_model.dart';
import '../../../../data/models/viewer/viewer.dart';
import '../../../../data/repositories/parent_repository.dart';
import '../../../../data/repositories/user_registration_repository.dart' show AccountFlowException;
import '../../../../data/repositories/viewer_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/data/manage_logic.dart' show RdManageEntry;
import '../../../settings/presentation/widgets/manage/manage_entries.dart' show rdManageTitle;
import '../../../settings/presentation/widgets/manage/manage_list.dart';
import '../widgets/members/invite_sheet.dart' show showRdInviteSheet;
import '../../../../shared/widgets/components/components.dart' show RdPrimaryButton, rdBack;
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;
import '../../../settings/presentation/pages/general_settings_page.dart' show RdTenantSettings, RdTenantSettingsBlock;

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
          onSelected: () => _showAddParentDialog(context, ref),
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
    if (context.mounted) await _removeParentWithConfirmation(context, ref, parent, repo: repo);
  }
}

/// REDESIGN: Verwaltung › Beobachter in the template "Verwaltungsliste"
/// (leads only). Like [RdParentsPage].
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
      onAdd: viewers == null ? null : () => _showAddViewerDialog(context, ref),
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
    if (context.mounted) await _removeViewerWithConfirmation(context, ref, viewer, repo: repo);
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

Future<({String email, String firstName, String lastName})?> _showInviteDialog(
  BuildContext context, {
  required String title,
}) async {
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: context.l10n.settingsEmailAddress,
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.settingsFlutterEmailRequired;
                }
                if (!value.contains('@')) {
                  return context.l10n.registerModalInvalidEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingM),
            TextFormField(
              controller: firstNameController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFirstName,
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.settingsFlutterFirstNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingM),
            TextFormField(
              controller: lastNameController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleLastName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.settingsFlutterLastNameRequired;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(ctx).pop(true);
            }
          },
          child: Text(context.l10n.settingsInvite),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;
  return (
    email: emailController.text,
    firstName: firstNameController.text,
    lastName: lastNameController.text,
  );
}

Future<void> _showAddParentDialog(BuildContext context, WidgetRef ref) async {
  // TENANT: both repositories bound before dialog.
  final repo = ref.read(parentRepositoryWithTenantProvider);
  final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
  final values = await _showInviteDialog(context, title: context.l10n.settingsAddParent);
  if (values == null || !context.mounted) return;
  try {
    await ref.read(parentNotifierProvider.notifier).invite(
          email: values.email,
          firstName: values.firstName,
          lastName: values.lastName,
          repo: repo,
          registration: registration,
        );
    if (context.mounted) {
      ToastHelper.showSuccess(context, context.l10n.settingsUserCreated);
    }
  } on AccountFlowException catch (e) {
    if (context.mounted) ToastHelper.showError(context, e.message);
  } catch (e) {
    if (context.mounted) {
      ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
    }
  }
}

Future<void> _removeParentWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  ParentModel parent, {
  required ParentRepository repo,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.settingsRemoveParent),
      content: Text(context.l10n.settingsRemoveMessage(parent.firstName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(context.l10n.commonYes),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await ref.read(parentNotifierProvider.notifier).deleteParent(parent.id!, appId: parent.appId, repo: repo);
      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsFlutterParentRemoved);
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
      }
    }
  }
}

Future<void> _showAddViewerDialog(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(viewerRepositoryWithTenantProvider);
  final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
  final values = await _showInviteDialog(context, title: context.l10n.settingsAddViewer);
  if (values == null || !context.mounted) return;
  try {
    await ref.read(viewerNotifierProvider.notifier).invite(
          email: values.email,
          firstName: values.firstName,
          lastName: values.lastName,
          repo: repo,
          registration: registration,
        );
    if (context.mounted) {
      ToastHelper.showSuccess(context, context.l10n.settingsUserCreated);
    }
  } on AccountFlowException catch (e) {
    if (context.mounted) ToastHelper.showError(context, e.message);
  } catch (e) {
    if (context.mounted) {
      ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
    }
  }
}

Future<void> _removeViewerWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Viewer viewer, {
  required ViewerRepository repo,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.settingsRemoveViewer),
      content: Text(context.l10n.settingsRemoveMessage(viewer.firstName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(context.l10n.commonYes),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      await ref.read(viewerNotifierProvider.notifier).deleteViewer(viewer.id!, appId: viewer.appId, repo: repo);
      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsFlutterViewerRemoved);
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
      }
    }
  }
}
