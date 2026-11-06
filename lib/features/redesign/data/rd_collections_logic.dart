import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/song/song.dart';
import 'rd_works_logic.dart' show rdNextFreeNumber;

/// REDESIGN: pure logic of the Sammlungen (canvas "Noten-Bereich neu
/// gedacht", supabase/sql/song_collections.sql). "Repertoire" is no row:
/// a Werk without `collection_id`, id `null` everywhere here.

/// Whether a viewer sees [collection]: leads (admin, responsible, viewer)
/// every one, members those for all and, for "bestimmte Gruppen", the ones
/// of their group (by id, or by name like the database for synced
/// libraries). The database enforces the same; this keeps a role preview
/// and stale data in line.
bool rdCollectionVisible(
  SongCollection collection, {
  required bool lead,
  required Group? ownGroup,
  required List<Group> groups,
}) {
  if (lead) return true;
  return switch (collection.visibleTo) {
    SongCollectionVisibility.all => true,
    SongCollectionVisibility.leads => false,
    SongCollectionVisibility.groups =>
      ownGroup != null &&
          (collection.groupIds.contains(ownGroup.id) ||
              groups.any(
                (g) =>
                    collection.groupIds.contains(g.id) &&
                    g.name.trim().toLowerCase() == ownGroup.name.trim().toLowerCase(),
              )),
  };
}

/// The Sammlungen a viewer sees, in their order (see [rdCollectionVisible]).
List<SongCollection> rdVisibleCollections(
  List<SongCollection> collections, {
  required bool lead,
  required Group? ownGroup,
  required List<Group> groups,
}) => [
  for (final c in collections)
    if (c.id != null && rdCollectionVisible(c, lead: lead, ownGroup: ownGroup, groups: groups)) c,
];

/// The Werke a viewer sees: Repertoire and the [visible] Sammlungen (a Werk
/// of a Sammlung the viewer does not see, or one that is gone, stays out).
List<Song> rdVisibleWorks(List<Song> songs, List<SongCollection> visible) {
  final ids = {for (final c in visible) c.id};
  return [
    for (final s in songs)
      if (s.collectionId == null || ids.contains(s.collectionId)) s,
  ];
}

/// The Werke of Sammlung [collectionId] (null = Repertoire).
List<Song> rdWorksIn(List<Song> songs, int? collectionId) => [
  for (final s in songs)
    if (s.collectionId == collectionId) s,
];

/// The Sammlung [id] of [collections]; null for Repertoire or an unknown id.
SongCollection? rdCollectionById(List<SongCollection> collections, int? id) =>
    id == null ? null : collections.where((c) => c.id == id).firstOrNull;

/// Whether Werke of Sammlung [id] may be put into a Termin programme or a
/// plan (Repertoire and unknown ids: yes).
bool rdCollectionPlannable(List<SongCollection>? collections, int? id) =>
    rdCollectionById(collections ?? const [], id)?.plannable ?? true;

/// The Werke that may be put into a programme or plan ([songs] without the
/// Werke of Sammlungen that are not "planbar"). Without Sammlungen (null)
/// all of them.
List<Song> rdPlannableWorks(List<Song> songs, List<SongCollection>? collections) {
  if (collections == null || collections.isEmpty) return songs;
  return [
    for (final s in songs)
      if (rdCollectionPlannable(collections, s.collectionId)) s,
  ];
}

/// The next free number of Sammlung [target] (null = Repertoire): after
/// the highest number with its prefix.
int rdCollectionNextNumber(List<Song> songs, SongCollection? target) =>
    rdNextFreeNumber(songs, target?.prefix ?? '');

/// Prefix and number of [song] after moving it from its Sammlung to
/// [target] (null = Repertoire), or null when both stay. A Sammlung with an
/// own prefix gives its prefix and its next free number; back into a
/// Sammlung without prefix, the prefix of the old Sammlung is dropped (an
/// own prefix of the Werk stays). A Werk without a number gets the next
/// free one.
({String prefix, int number})? rdMoveNumbering(
  Song song,
  SongCollection? target,
  List<SongCollection> collections,
  List<Song> songs,
) {
  final source = rdCollectionById(collections, song.collectionId);
  final sourcePrefix = (source?.prefix ?? '').trim();
  final targetPrefix = (target?.prefix ?? '').trim();
  final current = (song.prefix ?? '').trim();
  final prefix =
      targetPrefix.isNotEmpty
          ? targetPrefix
          : (current.toLowerCase() == sourcePrefix.toLowerCase() ? '' : current);
  if (prefix.toLowerCase() == current.toLowerCase() && song.number != null) return null;
  final others = [
    for (final s in songs)
      if (s.id != song.id) s,
  ];
  return (prefix: prefix, number: rdNextFreeNumber(others, prefix));
}

/// The groups of [collection] by name, in group order ("Violine 1, Viola").
List<Group> rdCollectionGroups(SongCollection collection, List<Group> groups) => [
  for (final g in groups)
    if (collection.groupIds.contains(g.id)) g,
];

/// A prefix suggestion for a new Sammlung: its first letter, upper case.
String rdCollectionPrefixSuggestion(String name) {
  final letter = name.trim().runes.isEmpty ? '' : String.fromCharCode(name.trim().runes.first);
  return letter.toUpperCase();
}
