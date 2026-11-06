import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/self_service_providers.dart';
import '../../../../../core/providers/song_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../../../data/rd_collections_logic.dart';
import '../rd_widgets.dart';

/// REDESIGN: Sammlungen in the Werke tab (canvas "Noten-Bereich neu
/// gedacht"): which Sammlungen the viewer sees, the chosen one, the chips,
/// names and "In Sammlung verschieben".

/// The Sammlungen the viewer sees, in their order; null while the database
/// has no Sammlungen (then every Sammlung feature stays hidden) or they are
/// not loaded. Leads (admin, responsible, viewer) see all of them.
final rdVisibleCollectionsProvider = Provider.autoDispose<List<SongCollection>?>((ref) {
  final all = ref.watch(songCollectionsProvider).valueOrNull;
  if (all == null) return null;
  final role = ref.watch(effectiveRoleProvider);
  final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
  final groupId = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.instrument;
  final ownGroup = groups.where((g) => g.id == groupId).firstOrNull;
  return rdVisibleCollections(all, lead: role.isConductor, ownGroup: ownGroup, groups: groups);
});

/// The Sammlung the Werke list shows (null = Repertoire), kept while the
/// app runs, reset when the tenant changes.
final rdWorksCollectionProvider = StateProvider<int?>((ref) {
  ref.watch(currentTenantIdProvider);
  return null;
});

/// The chosen Sammlung when the viewer still sees it, else Repertoire.
int? rdShownCollectionId(int? chosen, List<SongCollection>? visible) =>
    chosen != null && (visible ?? const []).any((c) => c.id == chosen) ? chosen : null;

/// "Repertoire" or the name of Sammlung [id].
String rdCollectionName(AppLocalizations l10n, List<SongCollection>? collections, int? id) =>
    rdCollectionById(collections ?? const [], id)?.name ?? l10n.collectionsRepertoire;

/// Who sees [collection]: "Alle", "Nur Leitung" or the names of its groups.
String rdCollectionAudience(AppLocalizations l10n, SongCollection collection, List<Group> groups) => switch (collection
    .visibleTo) {
  SongCollectionVisibility.all => l10n.collectionsVisAll,
  SongCollectionVisibility.leads => l10n.collectionsVisLeads,
  SongCollectionVisibility.groups => () {
    final names = rdCollectionGroups(collection, groups).map((g) => g.name).toList();
    return names.isEmpty ? l10n.collectionsVisLeads : names.join(', ');
  }(),
};

/// "Nur die Leitung sieht dieses Werk." / "Nur Violine 1 und die Leitung
/// sehen dieses Werk."; null when everybody sees [collection].
String? rdCollectionBanner(AppLocalizations l10n, SongCollection? collection, List<Group> groups) {
  if (collection == null) return null;
  final names = rdCollectionGroups(collection, groups).map((g) => g.name).toList();
  return switch (collection.visibleTo) {
    SongCollectionVisibility.all => null,
    SongCollectionVisibility.groups when names.isNotEmpty => l10n.collectionsBannerGroups(names.join(', ')),
    _ => l10n.collectionsBannerLeads,
  };
}

/// Icon of a Sammlung that not everybody sees (lock: leads, group: groups).
IconData? rdCollectionIcon(SongCollection? collection) => switch (collection?.visibleTo) {
  SongCollectionVisibility.leads => Icons.lock_outline,
  SongCollectionVisibility.groups => Icons.group_outlined,
  _ => null,
};

/// Chips above the Werke list: Repertoire and every visible Sammlung with
/// its number of Werke.
class RdCollectionChips extends StatelessWidget {
  const RdCollectionChips({
    super.key,
    required this.collections,
    required this.songs,
    required this.selected,
    required this.onSelected,
  });

  final List<SongCollection> collections;

  /// The Werke the viewer sees (to count per Sammlung).
  final List<Song> songs;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    int count(int? id) => songs.where((s) => s.collectionId == id).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          RdChoiceChip(
            key: const Key('rd-collection-chip-repertoire'),
            label: l10n.collectionsChip(l10n.collectionsRepertoire, count(null)),
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final c in collections) ...[
            const SizedBox(width: 8),
            RdChoiceChip(
              key: Key('rd-collection-chip-${c.id}'),
              label: l10n.collectionsChip(c.name, count(c.id)),
              icon: rdCollectionIcon(c),
              semanticLabel:
                  c.visibleTo == SongCollectionVisibility.leads
                      ? '${l10n.collectionsChip(c.name, count(c.id))}, ${l10n.collectionsOnlyLeads}'
                      : null,
              selected: selected == c.id,
              onTap: () => onSelected(c.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// "In Sammlung verschieben": picks the Sammlung (or takes [to], -1 =
/// Repertoire) and moves [song] there, with the prefix and next free
/// number of the new Sammlung when they change. Returns true when moved.
Future<bool> rdMoveWorkToCollection(BuildContext context, WidgetRef ref, Song song, {int? to}) async {
  final l10n = context.l10n;
  final id = song.id;
  if (id == null) return false;
  List<SongCollection>? collections;
  List<Song> songs;
  try {
    collections = await ref.read(songCollectionsProvider.future);
    songs = await ref.read(songsProvider.future);
  } catch (_) {
    if (context.mounted) ToastHelper.showError(context, l10n.collectionsMoveFailed);
    return false;
  }
  if (collections == null || !context.mounted) return false;
  final current = songs.where((s) => s.id == id).firstOrNull ?? song;
  final groups = ref.read(groupsProvider).valueOrNull ?? const <Group>[];

  String numberOf(SongCollection? target) {
    final n = rdMoveNumbering(current, target, collections!, songs);
    return n == null ? current.fullNumber : '${n.prefix}${n.number}';
  }

  final target =
      to ??
      await showAppActionSheet<int>(
        context,
        title: l10n.collectionsMove,
        message: l10n.collectionsMoveHint,
        actions: [
          for (final (int value, SongCollection? c) in [(-1, null), for (final c in collections) (c.id ?? -1, c)])
            if (c == null || c.id != null)
              AppActionSheetAction(
                value: value,
                icon: (c?.id ?? -1) == (current.collectionId ?? -1) ? Icons.check : rdCollectionIcon(c),
                label: c?.name ?? l10n.collectionsRepertoire,
                subtitle: [
                  c == null ? l10n.collectionsVisAll : rdCollectionAudience(l10n, c, groups),
                  if ((c?.id ?? -1) != (current.collectionId ?? -1)) l10n.collectionsMoveNext(numberOf(c)),
                ].join(' · '),
              ),
        ],
      );
  if (target == null || !context.mounted) return false;
  final targetId = target < 0 ? null : target;
  if (targetId == current.collectionId) return false;
  final collection = rdCollectionById(collections, targetId);
  if (targetId != null && collection == null) return false;
  final numbering = rdMoveNumbering(current, collection, collections, songs);
  final ok = await ref.read(songCollectionNotifierProvider.notifier).move(targetId, {
    id: (prefix: numbering?.prefix, number: numbering?.number),
  });
  if (!context.mounted) return ok;
  final name = collection?.name ?? l10n.collectionsRepertoire;
  if (!ok) {
    ToastHelper.showError(context, l10n.collectionsMoveFailed);
  } else if (numbering != null) {
    ToastHelper.showSuccess(context, l10n.collectionsMoveDoneNumber(name, '${numbering.prefix}${numbering.number}'));
  } else {
    ToastHelper.showSuccess(context, l10n.collectionsMoveDone(name));
  }
  return ok;
}
