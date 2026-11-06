import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../instruments/presentation/pages/instruments_list_page.dart'
    show groupClefLabel, showAddGroupSheet;
import '../../../instruments/presentation/widgets/instrument_categories_sheet.dart';
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';

/// REDESIGN: Verwaltung › Gruppen in the template "Verwaltungsliste"
/// (replaces `/settings/instruments` while the Beta is on). The groups by
/// category as sections, the main group or tuning and clefs as subtitle, the
/// number of persons on the right. "Reihenfolge ändern" and "Kategorien
/// verwalten" sit behind "•••", "+" adds a group (the old sheet), a tap opens
/// "Gruppe bearbeiten". Loading, saving and rights as on the old page.
class RdGroupsPage extends ConsumerStatefulWidget {
  const RdGroupsPage({super.key});

  @override
  ConsumerState<RdGroupsPage> createState() => _RdGroupsPageState();
}

class _RdGroupsPageState extends ConsumerState<RdGroupsPage> {
  Future<void> _refresh() async {
    ref.invalidate(groupsProvider);
    ref.invalidate(groupCategoriesProvider);
    ref.invalidate(playerCountsForGroupsProvider);
    await ref.read(groupsProvider.future).catchError((_) => const <Group>[]);
  }

  /// Old page: the order runs across the sections (category order first),
  /// 1..n like Ionic `updateGlobalSortOrder`.
  Future<bool> _saveOrder(List<Group> groups, List<RdManageListSection> sections) async {
    final l10n = context.l10n;
    final byId = {for (final g in groups) if (g.id != null) g.id!: g};
    final ordered = [
      for (final s in sections)
        InstrumentCategorySection(
          categoryId: s.key as int?,
          name: s.title ?? '',
          sortOrder: null,
          groups: [for (final item in s.items) if (byId[item.id] != null) byId[item.id]!],
        ),
    ];
    final ok = await ref.read(groupNotifierProvider.notifier).saveGroupOrder(computeGlobalSortOrder(ordered));
    if (!mounted) return ok;
    if (ok) {
      ToastHelper.showSuccess(context, l10n.typeSettingsOrderSaved);
    } else {
      ToastHelper.showError(context, l10n.redesignManageListOrderFailed);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    // Old page: isAdmin = Admin or Verantwortliche (the route checks it too).
    final isAdmin = role.isAdmin || role.isResponsible;
    final groupsAsync = ref.watch(groupsProvider);
    final categories = ref.watch(groupCategoriesProvider).valueOrNull ?? const <GroupCategory>[];
    final counts = ref.watch(playerCountsForGroupsProvider).valueOrNull;
    final tenantType = ref.watch(currentTenantProvider)?.type;
    final groups = groupsAsync.valueOrNull;

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.groups),
      intro: l10n.redesignGroupsListIntro,
      sections:
          groups == null
              ? null
              : rdGroupSections(
                l10n,
                groups,
                categories,
                counts: counts,
                tenantType: tenantType,
                onTap: isAdmin ? (id) => context.push(RedesignRoutes.groupEdit(id)) : null,
              ),
      loadFailed: groupsAsync.hasError && !groupsAsync.isLoading,
      onRetry: () => ref.invalidate(groupsProvider),
      emptyText: l10n.redesignGroupsListEmpty,
      emptyIcon: Icons.groups_outlined,
      addLabel: l10n.redesignGroupsListAdd,
      onAdd: isAdmin ? () => showAddGroupSheet(context, ref, categories) : null,
      actions: [
        if (isAdmin)
          RdManageListAction(
            label: l10n.redesignGroupsListManageCategories,
            icon: Icons.sell_outlined,
            onSelected: () => showInstrumentCategoriesSheet(context),
          ),
      ],
      onReorder: isAdmin && groups != null ? (sections) => _saveOrder(groups, sections) : null,
      onRefresh: _refresh,
    );
  }
}

/// The groups as sections of the template: by category in the order of the
/// old page (`groupInstrumentsByCategory`); without any category one list
/// without a heading. [counts] null while the numbers load.
List<RdManageListSection> rdGroupSections(
  AppLocalizations l10n,
  List<Group> groups,
  List<GroupCategory> categories, {
  Map<int, int>? counts,
  String? tenantType,
  void Function(int id)? onTap,
}) {
  final musical = tenantType != 'choir' && tenantType != 'general';
  String? subtitle(Group g) {
    if (g.maingroup == true) return l10n.redesignGroupsListMainGroup;
    if (!musical) return null;
    final clefs = (g.clefs ?? const <String>[]).map((c) => groupClefLabel(l10n, c)).join(', ');
    final parts = [
      if ((g.tuning ?? '').isNotEmpty) '${l10n.instrumentsTuning} ${g.tuning}',
      if (clefs.isNotEmpty) clefs,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // Without categories one list (also when groups still point to a deleted
  // category).
  final sections =
      categories.isEmpty
          ? [InstrumentCategorySection(categoryId: null, name: '', sortOrder: null, groups: sortGroupsBySortOrder(groups))]
          : groupInstrumentsByCategory(groups, categories, noCategoryLabel: l10n.instrumentsNoCategory);
  return [
    for (final s in sections)
      RdManageListSection(
        key: s.categoryId,
        title: categories.isEmpty ? null : s.name,
        items: [
          for (final g in s.groups)
            RdManageListItem(
              id: g.id ?? g.name,
              title: g.name,
              subtitle: subtitle(g),
              count: counts == null ? null : l10n.commonPersons(counts[g.id] ?? 0),
              countWarn: counts != null && (counts[g.id] ?? 0) == 0,
              onTap: onTap == null || g.id == null ? null : () => onTap(g.id!),
            ),
        ],
      ),
  ];
}
