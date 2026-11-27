import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart'
    show currentAuthUserIdProvider;
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/offline_queue_service.dart'
    show connectivityCheckProvider;
import '../../../../core/utils/demo_guard.dart' show DemoModeException;
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../data/catalog_import.dart';
import '../../data/catalog_selection.dart';
import '../../data/group_options.dart' show groupClefLabel;
import '../widgets/instrument_catalog_sheet.dart';
import '../widgets/instrument_categories_sheet.dart';
import '../../../settings/data/rd_manage_logic.dart' show RdManageEntry;
import '../../../../core/redesign/rd_words.dart';
import '../../../settings/presentation/widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../../../settings/presentation/widgets/manage/rd_manage_list.dart';
import '../../../settings/presentation/widgets/manage/rd_settings_sheets.dart' show showRdTextSheet;

/// REDESIGN: Verwaltung › Gruppen in the template "Verwaltungsliste"
/// (replaces `/settings/instruments` while the Beta is on). The groups by
/// category as sections, the main group or tuning and clefs as subtitle, the
/// number of persons on the right. "Reihenfolge ändern" and "Kategorien
/// verwalten" sit behind "•••", "+" opens the collection (general groups
/// keep their name sheet), a tap opens
/// "Gruppe bearbeiten". Loading, saving and rights as on the old page.
class RdGroupsPage extends ConsumerStatefulWidget {
  const RdGroupsPage({super.key});

  @override
  ConsumerState<RdGroupsPage> createState() => _RdGroupsPageState();
}

class _RdGroupsPageState extends ConsumerState<RdGroupsPage> {
  bool _adding = false;

  void _invalidateGroups() {
    ref.invalidate(groupsProvider);
    ref.invalidate(groupsMapProvider);
    ref.invalidate(groupCategoriesProvider);
    ref.invalidate(playerCountsForGroupsProvider);
  }

  Future<void> _refresh() async {
    _invalidateGroups();
    await ref.read(groupsProvider.future).catchError((_) => const <Group>[]);
  }

  /// Old page: the order runs across the sections (category order first),
  /// 1..n like Ionic `updateGlobalSortOrder`.
  Future<bool> _saveOrder(
    List<Group> groups,
    List<RdManageListSection> sections,
  ) async {
    final l10n = context.l10n;
    final byId = {
      for (final g in groups)
        if (g.id != null) g.id!: g,
    };
    final ordered = [
      for (final s in sections)
        InstrumentCategorySection(
          categoryId: s.key as int?,
          name: s.title ?? '',
          sortOrder: null,
          groups: [
            for (final item in s.items)
              if (byId[item.id] != null) byId[item.id]!,
          ],
        ),
    ];
    final ok = await ref
        .read(groupNotifierProvider.notifier)
        .saveGroupOrder(computeGlobalSortOrder(ordered));
    if (!mounted) return ok;
    if (ok) {
      ToastHelper.showSuccess(context, l10n.typeSettingsOrderSaved);
    } else {
      // Rows are renumbered one by one: show what is stored now.
      ref.invalidate(groupsProvider);
      ToastHelper.showError(context, l10n.redesignManageListOrderFailed);
    }
    return ok;
  }

  /// Bind the account, ensemble and permission before the picker opens.
  /// The collection itself is offline; only importing requires a connection.
  Future<void> _add() async {
    if (_adding) return;
    final l10n = context.l10n;
    final tenant = ref.read(currentTenantProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    final accountId = ref.read(currentAuthUserIdProvider);
    final role = ref.read(effectiveRoleProvider);
    final actualRole = ref.read(currentRoleProvider);
    if (tenantId == null ||
        accountId == null ||
        (!role.isAdmin && !role.isResponsible)) {
      return;
    }
    final kind = tenant?.type ?? '';
    final repository = ref.read(groupRepositoryForTenantProvider(tenantId));
    bool isCurrent() =>
        mounted &&
        ref.read(currentTenantIdProvider) == tenantId &&
        ref.read(currentAuthUserIdProvider) == accountId &&
        (ref.read(currentTenantProvider)?.type ?? '') == kind &&
        ref.read(effectiveRoleProvider) == role &&
        ref.read(currentRoleProvider) == actualRole;
    setState(() => _adding = true);
    CatalogImportResult? result;
    List<CatalogGroupDraft>? drafts;
    try {
      if (kind != 'orchestra' && kind != 'choir') {
        final name = await showRdTextSheet(
          context,
          title: l10n.rdWordsNewGroup(kind),
          hint: l10n.instrumentsGroupPh,
          required: true,
        );
        if (!mounted || name == null || name.isEmpty || !isCurrent()) return;
        final created = await ref
            .read(groupNotifierProvider.notifier)
            .createGroup({'name': name, 'maingroup': false});
        if (!mounted || !isCurrent()) return;
        if (created?.id == null) {
          ToastHelper.showError(context, l10n.instrumentsFlutterAddFailed);
          return;
        }
        await context.push(RedesignRoutes.groupEdit(created!.id!));
        return;
      }
      final selection = await showInstrumentCatalogSheet(
        context,
        tenantType: kind,
        existingGroups: ref.read(groupsProvider).valueOrNull ?? const <Group>[],
      );
      drafts = selection?.drafts;
      if (!mounted || drafts == null || drafts.isEmpty || !isCurrent()) return;
      final online = await ref.read(connectivityCheckProvider)();
      if (!mounted || !isCurrent()) return;
      if (!online) {
        ToastHelper.showWarning(context, l10n.catalogOffline);
        return;
      }
      result = await importCatalogGroups(
        repository,
        drafts,
        isCurrent: isCurrent,
      );
    } on CatalogImportCancelled {
      // No result belongs to the newly selected account or ensemble.
      return;
    } on DemoModeException {
      if (mounted && isCurrent()) {
        ToastHelper.showWarning(context, l10n.dbDemoRestricted);
      }
    } catch (_) {
      if (mounted && isCurrent()) {
        ToastHelper.showError(context, l10n.catalogImportFailed);
      }
    } finally {
      // Also after an ambiguous network failure: read what is stored now.
      if (mounted) {
        _invalidateGroups();
        setState(() => _adding = false);
      }
    }
    if (!mounted || !isCurrent() || result == null) return;
    ToastHelper.showSuccess(context, l10n.catalogImportSuccess(result.added));
    // A single custom entry keeps the familiar next step: its full editor.
    // Mixed selections can be edited individually from the refreshed list.
    if (drafts?.length == 1 &&
        drafts!.single.instrumentId.isEmpty &&
        result.added == 1) {
      final groups = await ref
          .read(groupsProvider.future)
          .catchError((_) => const <Group>[]);
      if (!mounted || !isCurrent()) return;
      final name = normalizeCatalogName(drafts.single.name);
      final created =
          groups
              .where(
                (group) =>
                    group.maingroup != true &&
                    normalizeCatalogName(group.name) == name,
              )
              .firstOrNull;
      if (created?.id != null) {
        await context.push(RedesignRoutes.groupEdit(created!.id!));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    // Old page: isAdmin = Admin or Verantwortliche (the route checks it too).
    final isAdmin = role.isAdmin || role.isResponsible;
    final groupsAsync = ref.watch(groupsProvider);
    final categories =
        ref.watch(groupCategoriesProvider).valueOrNull ??
        const <GroupCategory>[];
    final counts = ref.watch(playerCountsForGroupsProvider).valueOrNull;
    final tenantType = ref.watch(currentTenantProvider)?.type;
    final kind = ref.watch(rdGroupKindProvider);
    final groups = groupsAsync.valueOrNull;

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.groups, kind: kind),
      intro: l10n.redesignGroupsListIntro(kind),
      sections:
          groups == null
              ? null
              : rdGroupSections(
                l10n,
                groups,
                categories,
                counts: counts,
                tenantType: tenantType,
                onTap:
                    isAdmin
                        ? (id) => context.push(RedesignRoutes.groupEdit(id))
                        : null,
              ),
      loadFailed: groupsAsync.hasError && !groupsAsync.isLoading,
      onRetry: () => ref.invalidate(groupsProvider),
      emptyText: l10n.redesignGroupsListEmpty(kind),
      emptyIcon: Icons.groups_outlined,
      addLabel: l10n.redesignGroupsListAdd(kind),
      onAdd: isAdmin && !_adding ? _add : null,
      actions: [
        // A choir has no level above its Stimmen: only offered there while
        // categories from before still exist.
        if (isAdmin && rdOffersCategories(kind, categories))
          RdManageListAction(
            label: l10n.redesignGroupsListManageCategories(kind),
            icon: Icons.sell_outlined,
            onSelected: () => showInstrumentCategoriesSheet(context),
          ),
      ],
      onReorder:
          isAdmin && groups != null
              ? (sections) => _saveOrder(groups, sections)
              : null,
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
    final clefs = (g.clefs ?? const <String>[])
        .map((c) => groupClefLabel(l10n, c))
        .join(', ');
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
          ? [
            InstrumentCategorySection(
              categoryId: null,
              name: '',
              sortOrder: null,
              groups: sortGroupsBySortOrder(groups),
            ),
          ]
          : groupInstrumentsByCategory(
            groups,
            categories,
            noCategoryLabel: l10n.rdWordsNoCategory(tenantType ?? ''),
          );
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
              // An empty group is no error: a quiet "–" instead of a red
              // "0 Personen".
              count:
                  counts == null
                      ? null
                      : ((counts[g.id] ?? 0) == 0
                          ? '–'
                          : l10n.commonPersons(counts[g.id] ?? 0)),
              onTap: onTap == null || g.id == null ? null : () => onTap(g.id!),
            ),
        ],
      ),
  ];
}
