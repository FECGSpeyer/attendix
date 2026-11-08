import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../data/models/parent/parent_model.dart';
import '../../../../data/models/viewer/viewer.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../settings/presentation/pages/parents_page.dart' show ParentsPage;
import '../../../settings/presentation/pages/viewers_page.dart' show ViewersPage;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';
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
    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.parents),
      intro: l10n.redesignParentsListIntro,
      // The switch of the old "Allgemein".
      header: const RdTenantSettingsBlock(sections: [RdTenantSettings.parents]),
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
            ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(parentsProvider),
      emptyText: l10n.redesignParentsListEmpty,
      emptyIcon: Icons.favorite_border,
      addLabel: l10n.redesignParentsListAdd,
      onAdd: parents == null ? null : () => ParentsPage.showAddParentDialog(context, ref),
      onRefresh: () async {
        ref.invalidate(parentsProvider);
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
    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.viewers),
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
            ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(viewersProvider),
      emptyText: l10n.redesignViewersListEmpty,
      emptyIcon: Icons.visibility_outlined,
      addLabel: l10n.redesignViewersListAdd,
      onAdd: viewers == null ? null : () => ViewersPage.showAddViewerDialog(context, ref),
      onRefresh: () async {
        ref.invalidate(viewersProvider);
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
