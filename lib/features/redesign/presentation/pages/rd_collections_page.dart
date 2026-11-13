import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../data/providers/rd_shared_library.dart';
import '../../data/rd_collections_logic.dart';
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/works/rd_collections_ui.dart';

/// REDESIGN: Werke › "Sammlungen verwalten" in the template
/// "Verwaltungsliste" (canvas "Noten-Bereich neu gedacht", board 4).
/// Repertoire on top (always there, not editable), then the own
/// Sammlungen with who sees them and their number of Werke. "+" adds one
/// (name, then "Sammlung bearbeiten"), "Reihenfolge ändern" sits in "•••".
/// Admins and Verantwortliche only (route guard).
class RdCollectionsPage extends ConsumerStatefulWidget {
  const RdCollectionsPage({super.key});

  @override
  ConsumerState<RdCollectionsPage> createState() => _RdCollectionsPageState();
}

class _RdCollectionsPageState extends ConsumerState<RdCollectionsPage> {
  bool _adding = false;

  Future<void> _refresh() async {
    ref.invalidate(songCollectionsProvider);
    ref.invalidate(songsProvider);
    await ref.read(songCollectionsProvider.future).catchError((_) => null);
  }

  Future<void> _add() async {
    if (_adding) return;
    final l10n = context.l10n;
    final name = await DialogHelper.showTextInput(
      context,
      title: l10n.collectionsAddTitle,
      hint: l10n.collectionsAddHint,
      confirmText: l10n.collectionsAdd,
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() => _adding = true);
    final created = await ref
        .read(songCollectionNotifierProvider.notifier)
        .add(SongCollection(name: trimmed, prefix: rdCollectionPrefixSuggestion(trimmed)));
    if (!mounted) return;
    setState(() => _adding = false);
    if (created?.id == null) {
      ToastHelper.showError(context, l10n.collectionsAddFailed);
      return;
    }
    context.push(RedesignRoutes.collection(created!.id!));
  }

  Future<bool> _saveOrder(List<SongCollection> collections, List<RdManageListSection> sections) async {
    final l10n = context.l10n;
    final byId = {for (final c in collections) if (c.id != null) c.id!: c};
    final ordered = [
      for (final s in sections)
        if (s.key == 'own')
          for (final item in s.items)
            if (byId[item.id] != null) byId[item.id]!,
    ];
    final ok = await ref.read(songCollectionNotifierProvider.notifier).reorder(ordered);
    if (!mounted) return ok;
    if (ok) {
      ToastHelper.showSuccess(context, l10n.collectionsOrderSaved);
    } else {
      ToastHelper.showError(context, l10n.collectionsOrderFailed);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    // Sammlungen of another group's Werke: only its leads manage them.
    final isAdmin = (role.isAdmin || role.isResponsible) && ref.watch(rdLibraryEditableProvider);
    final async = ref.watch(songCollectionsProvider);
    final collections = rdLoadedValue(async);
    final songs = ref.watch(songsProvider).valueOrNull;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];

    String? count(int? id) => songs == null ? null : l10n.collectionsWorks(rdWorksIn(songs, id).length);

    return RdManageListPage(
      title: l10n.collectionsTitle,
      intro: l10n.collectionsIntro,
      backLabel: l10n.redesignTabWorks,
      onBack: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.works),
      sections:
          collections == null
              ? null
              : [
                RdManageListSection(
                  key: 'repertoire',
                  items: [
                    RdManageListItem(
                      id: 'repertoire',
                      title: l10n.collectionsRepertoire,
                      subtitle: l10n.collectionsRepertoireHint,
                      icon: Icons.library_music_outlined,
                      count: count(null),
                    ),
                  ],
                ),
                if (collections.isNotEmpty)
                  RdManageListSection(
                    key: 'own',
                    title: l10n.collectionsTitle,
                    items: [
                      for (final c in collections)
                        if (c.id != null)
                          RdManageListItem(
                            id: c.id!,
                            title: c.name,
                            subtitle: [
                              rdCollectionAudience(l10n, c, groups),
                              if (c.prefix.isNotEmpty) '${c.prefix}1, ${c.prefix}2 …',
                              if (!c.plannable) l10n.collectionsNotPlannable,
                            ].join(' · '),
                            icon: rdCollectionIcon(c) ?? Icons.folder_outlined,
                            count: count(c.id),
                            onTap: isAdmin ? () => context.push(RedesignRoutes.collection(c.id!)) : null,
                          ),
                    ],
                  ),
              ],
      // Without Sammlungen in the database (null) there is nothing to show.
      loadFailed: !async.isLoading && (async.hasError || (async.hasValue && async.value == null)),
      onRetry: _refresh,
      emptyText: l10n.collectionsEmpty,
      emptyIcon: Icons.folder_outlined,
      notice: collections != null && collections.isEmpty ? l10n.collectionsEmpty : null,
      addLabel: l10n.collectionsAdd,
      onAdd: isAdmin && collections != null ? _add : null,
      onReorder:
          isAdmin && collections != null && collections.length > 1
              ? (sections) => _saveOrder(collections, sections)
              : null,
      onRefresh: _refresh,
    );
  }
}
