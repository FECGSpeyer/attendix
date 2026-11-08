import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart' show rdBack;

/// REDESIGN: Verwaltung › Werk-Kategorien in the template "Verwaltungsliste"
/// (canvas "Beta: Gruppe und Daten", board "G4 Werk-Kategorien"). Replaces
/// the old categories sheet while the Beta is on: the categories with the
/// number of works, "+" adds one, a tap offers rename and delete,
/// "Reihenfolge ändern" behind "•••". Same notifier and rules as the sheet
/// (an empty name is refused with the same toast).
class RdWorkCategoriesPage extends ConsumerStatefulWidget {
  const RdWorkCategoriesPage({super.key});

  @override
  ConsumerState<RdWorkCategoriesPage> createState() => _RdWorkCategoriesPageState();
}

class _RdWorkCategoriesPageState extends ConsumerState<RdWorkCategoriesPage> {
  /// Whether [tenantId] (read when an action started) is still the current
  /// group; an action that started in another group writes nothing.
  bool _stillIn(int? tenantId) => mounted && tenantId != null && ref.read(currentTenantIdProvider) == tenantId;

  Future<void> _refresh() async {
    ref.invalidate(songCategoriesProvider);
    await ref.read(songCategoriesProvider.future).catchError((_) => const <SongCategory>[]);
  }

  Future<String?> _askName({required String title, String initial = ''}) async {
    final l10n = context.l10n;
    final name = await showRdTextSheet(
      context,
      title: title,
      initial: initial,
      hint: l10n.songsCategoryName,
      capitalization: TextCapitalization.sentences,
    );
    if (name == null || !mounted) return null;
    if (name.trim().isEmpty) {
      ToastHelper.showError(context, l10n.songsCategoryNameEmpty);
      return null;
    }
    return name.trim();
  }

  Future<void> _add() async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final notifier = ref.read(songCategoryNotifierProvider.notifier);
    final name = await _askName(title: l10n.songsAddCategory);
    if (name == null || !_stillIn(tenantId)) return;
    final created = await notifier.add(name, stillValid: () => _stillIn(tenantId));
    if (created != null && mounted) ToastHelper.showSuccess(context, l10n.songsCategoryAdded);
  }

  Future<void> _actions(SongCategory category) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final notifier = ref.read(songCategoryNotifierProvider.notifier);
    final action = await showAppActionSheet<String>(
      context,
      title: category.name,
      actions: [
        AppActionSheetAction(value: 'rename', label: l10n.songsEditCategory, icon: Icons.edit_outlined),
        AppActionSheetAction(
          value: 'delete',
          label: l10n.songsDeleteCategory,
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    if (action == null || !_stillIn(tenantId) || category.id == null) return;
    if (action == 'rename') {
      final name = await _askName(title: l10n.songsEditCategory, initial: category.name);
      if (name == null || !_stillIn(tenantId)) return;
      final ok = await notifier.update(category.id!, name);
      if (ok && mounted) ToastHelper.showSuccess(context, l10n.songsCategorySaved);
    } else {
      final confirmed = await showAppConfirm(
        context,
        title: l10n.songsDeleteCategory,
        message: l10n.songsDeleteCategoryMessage,
        confirmText: l10n.commonDelete,
        destructive: true,
      );
      if (!confirmed || !_stillIn(tenantId)) return;
      final ok = await notifier.delete(category.id!);
      if (ok && mounted) ToastHelper.showSuccess(context, l10n.songsCategoryDeleted);
    }
  }

  /// Old sheet: the categories in the new order (`reorder`).
  Future<bool> _saveOrder(int? tenantId, List<SongCategory> categories, List<RdManageListSection> sections) async {
    final l10n = context.l10n;
    final byId = {
      for (final c in categories)
        if (c.id != null) c.id!: c,
    };
    final ordered = [
      for (final s in sections)
        for (final item in s.items)
          if (byId[item.id] != null) byId[item.id]!,
    ];
    if (!_stillIn(tenantId)) return false;
    final ok = await ref
        .read(songCategoryNotifierProvider.notifier)
        .reorder(ordered, stillValid: () => _stillIn(tenantId));
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
    // Like the old entry: not in general groups (open by URL → Ich).
    if (ref.watch(currentTenantProvider.select((t) => t?.type == 'general'))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RedesignRoutes.me);
      });
      return const SizedBox.shrink();
    }
    // The origin group of the list; keys the list so a sort started in one
    // group is dropped on a switch and saved only into that group.
    final tenantId = ref.watch(currentTenantIdProvider);
    final async = ref.watch(songCategoriesProvider);
    // Only lists that surely belong to the current group (no stale values
    // while reloading after a group switch).
    final categories = rdLoadedValue(async);
    final songs = rdLoadedValue(ref.watch(songsProvider));
    int? count(String? id) =>
        songs == null || id == null ? null : songs.where((s) => s.categoryIds?.contains(id) ?? false).length;

    return RdManageListPage(
      key: ValueKey(tenantId),
      title: rdManageTitle(l10n, RdManageEntry.workCategories),
      // Opened from the Werke tab's "•••" (and Werk bearbeiten).
      backLabel: l10n.redesignTabWorks,
      onBack: () => rdBack(context, RedesignRoutes.works),
      intro: l10n.rdWmCategoriesIntro,
      sections:
          categories == null
              ? null
              : [
                RdManageListSection(
                  items: [
                    for (final (i, c) in categories.indexed)
                      RdManageListItem(
                        id: c.id ?? 'unsaved-$i',
                        title: c.name,
                        count: count(c.id) == null ? null : l10n.rdWmWorksCount(count(c.id)!),
                        onTap: c.id == null ? null : () => _actions(c),
                      ),
                  ],
                ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(songCategoriesProvider),
      emptyText: l10n.songsNoCategories,
      emptyIcon: Icons.sell_outlined,
      addLabel: l10n.songsAddCategory,
      onAdd: _add,
      onReorder: categories == null ? null : (sections) => _saveOrder(tenantId, categories, sections),
      onRefresh: _refresh,
    );
  }
}
