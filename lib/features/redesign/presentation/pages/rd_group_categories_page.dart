import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/manage/rd_settings_sheets.dart';

/// REDESIGN: Gruppen › Kategorien in the template "Verwaltungsliste" (like
/// Werk-Kategorien). Replaces the old categories sheet while the Beta is on:
/// the categories with the number of groups, "+" adds one, a tap offers
/// rename and delete, "Reihenfolge ändern" behind "•••". Same notifier,
/// questions and toasts as the old sheet; a new order also renumbers the
/// groups (old sheet `saveCategoryOrder`).
class RdGroupCategoriesPage extends ConsumerStatefulWidget {
  const RdGroupCategoriesPage({super.key});

  @override
  ConsumerState<RdGroupCategoriesPage> createState() => _RdGroupCategoriesPageState();
}

class _RdGroupCategoriesPageState extends ConsumerState<RdGroupCategoriesPage> {
  /// Whether [tenantId] (read when an action started) is still the current
  /// group; an action that started in another group writes nothing.
  bool _stillIn(int? tenantId) => mounted && tenantId != null && ref.read(currentTenantIdProvider) == tenantId;

  Future<void> _refresh() async {
    ref.invalidate(groupCategoriesProvider);
    ref.invalidate(groupsProvider);
    await ref.read(groupCategoriesProvider.future).catchError((_) => const <GroupCategory>[]);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.groups);
    }
  }

  /// Old sheet: an empty name shows "Bitte gib einem Namen an".
  Future<String?> _askName({required String title, String initial = ''}) async {
    final l10n = context.l10n;
    final name = await showRdTextSheet(context, title: title, initial: initial, hint: l10n.instrumentsCategoryName);
    if (name == null || !mounted) return null;
    if (name.trim().isEmpty) {
      ToastHelper.showError(context, l10n.instrumentsEnterName);
      return null;
    }
    return name.trim();
  }

  Future<void> _add() async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final name = await _askName(title: l10n.instrumentsNewCategory);
    if (name == null || !_stillIn(tenantId)) return;
    final created = await ref.read(groupNotifierProvider.notifier).createGroupCategory(name);
    if (created == null && mounted) ToastHelper.showError(context, l10n.svcAddCategoryFailed);
  }

  Future<void> _actions(GroupCategory category) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final id = category.id;
    final action = await showAppActionSheet<String>(
      context,
      title: category.name,
      actions: [
        AppActionSheetAction(value: 'rename', label: l10n.instrumentsEditCategory, icon: Icons.edit_outlined),
        AppActionSheetAction(value: 'delete', label: l10n.commonDelete, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (action == null || id == null || !_stillIn(tenantId)) return;
    final notifier = ref.read(groupNotifierProvider.notifier);
    if (action == 'rename') {
      final name = await _askName(title: l10n.instrumentsEditCategory, initial: category.name);
      if (name == null || !_stillIn(tenantId)) return;
      final updated = await notifier.updateGroupCategory(id, {'name': name});
      if (updated == null && mounted) ToastHelper.showError(context, l10n.svcUpdateCategoryFailed);
    } else {
      final confirmed = await showAppConfirm(
        context,
        title: l10n.commonConfirm,
        message: l10n.instrumentsDeleteCategory,
        confirmText: l10n.commonDelete,
        destructive: true,
      );
      if (!confirmed || !_stillIn(tenantId)) return;
      await notifier.deleteGroupCategory(id);
      if (mounted && ref.read(groupNotifierProvider).hasError) {
        ToastHelper.showError(context, l10n.svcDeleteCategoryFailed);
      }
    }
  }

  /// Old sheet: category sort_order 1..n and the resulting order of all
  /// groups (Ionic `saveCategoryOrder` + `updateGlobalSortOrder`).
  Future<bool> _saveOrder(int? tenantId, List<GroupCategory> categories, List<RdManageListSection> sections) async {
    final l10n = context.l10n;
    final byId = {
      for (final c in categories)
        if (c.id != null) '${c.id}': c,
    };
    final ordered = [
      for (final s in sections)
        for (final item in s.items)
          if (byId[item.id] != null) byId[item.id]!,
    ];
    if (!_stillIn(tenantId)) return false;
    final categoryOrders = <int, int>{};
    final updated = <GroupCategory>[];
    for (final (i, c) in ordered.indexed) {
      if (c.id != null) categoryOrders[c.id!] = i + 1;
      updated.add(c.copyWith(sortOrder: i + 1));
    }
    final groups = ref.read(groupsProvider).valueOrNull ?? const <Group>[];
    final ok = await ref
        .read(groupNotifierProvider.notifier)
        .saveCategoryOrder(
          categoryOrders,
          groupSortOrders: computeGlobalSortOrder(groupInstrumentsByCategory(groups, updated)),
        );
    if (!mounted) return ok;
    if (ok) {
      ToastHelper.showSuccess(context, l10n.typeSettingsOrderSaved);
    } else {
      ToastHelper.showError(context, l10n.instrumentsOrderFailed);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Keys the list so a sort started in one group is dropped on a switch.
    final tenantId = ref.watch(currentTenantIdProvider);
    final async = ref.watch(groupCategoriesProvider);
    // Only lists that surely belong to the current group.
    final categories = rdLoadedValue(async);
    final groups = rdLoadedValue(ref.watch(groupsProvider));
    int? count(int? id) => groups == null || id == null ? null : groups.where((g) => g.categoryId == id).length;

    return RdManageListPage(
      key: ValueKey(tenantId),
      title: l10n.instrumentsCategories,
      intro: l10n.redesignGroupCategoriesIntro,
      backLabel: l10n.redesignGroupCategoriesBack,
      onBack: _back,
      sections:
          categories == null
              ? null
              : [
                RdManageListSection(
                  items: [
                    for (final (i, c) in categories.indexed)
                      RdManageListItem(
                        id: c.id == null ? 'unsaved-$i' : '${c.id}',
                        title: c.name,
                        count: count(c.id) == null ? null : l10n.redesignGroupCategoriesCount(count(c.id)!),
                        onTap: c.id == null ? null : () => _actions(c),
                      ),
                  ],
                ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(groupCategoriesProvider),
      emptyText: l10n.instrumentsFlutterNoCategories,
      emptyIcon: Icons.sell_outlined,
      addLabel: l10n.instrumentsNewCategory,
      onAdd: _add,
      onReorder: categories == null ? null : (sections) => _saveOrder(tenantId, categories, sections),
      onRefresh: _refresh,
    );
  }
}
