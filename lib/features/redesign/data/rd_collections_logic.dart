import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/song/song.dart';
import 'rd_works_logic.dart' show rdNextFreeNumber;

/// REDESIGN: pure logic of the Sammlungen (canvas "Noten-Bereich neu
/// gedacht", supabase/sql/song_collections.sql). "Repertoire" is no row:
/// a Werk without `collection_id`, id `null` everywhere here.

/// Whether a viewer sees [collection]: leads (admin, responsible, viewer)
/// every one, members those for all and, for "bestimmte Gruppen", the ones
/// of their group (by id, or by name like the database). The database
/// enforces the same; this keeps a role preview and stale data in line. A
/// Sammlung of another tenant (synced library, [ownTenantId] differs) names
/// groups of that tenant: the database already matched them by name, so
/// what it returned stays.
bool rdCollectionVisible(
  SongCollection collection, {
  required bool lead,
  required Group? ownGroup,
  required List<Group> groups,
  int? ownTenantId,
}) {
  if (lead) return true;
  final synced = ownTenantId != null && collection.tenantId != null && collection.tenantId != ownTenantId;
  return switch (collection.visibleTo) {
    SongCollectionVisibility.all => true,
    SongCollectionVisibility.leads => false,
    SongCollectionVisibility.groups when synced => true,
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
  int? ownTenantId,
}) => [
  for (final c in collections)
    if (c.id != null &&
        rdCollectionVisible(c, lead: lead, ownGroup: ownGroup, groups: groups, ownTenantId: ownTenantId))
      c,
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

/// A Werk of Sammlung [collectionId] with prefix [from] whose number
/// another Werk already has with prefix [to] (renaming the prefix would
/// take it twice); null when there is none.
Song? rdPrefixClash(List<Song> songs, int collectionId, String from, String to) {
  String norm(String? p) => (p ?? '').trim().toLowerCase();
  if (norm(from) == norm(to)) return null;
  final inside = [
    for (final s in rdWorksIn(songs, collectionId))
      if (norm(s.prefix) == norm(from) && s.number != null) s,
  ];
  for (final s in inside) {
    if (songs.any((o) => o.id != s.id && o.number == s.number && norm(o.prefix) == norm(to))) return s;
  }
  return null;
}

/// The groups of [collection] by name, in group order ("Violine 1, Viola").
List<Group> rdCollectionGroups(SongCollection collection, List<Group> groups) => [
  for (final g in groups)
    if (collection.groupIds.contains(g.id)) g,
];

/// A prefix suggestion for a new Sammlung: its first letter, upper case.
/// When [taken] (the Kürzel of the other Sammlungen and of the Werke)
/// already holds it, the first two, three … letters ("E" taken: "Ei" for
/// "Einspielen"), so the numbers of two Sammlungen never look alike.
String rdCollectionPrefixSuggestion(String name, {Iterable<String?> taken = const []}) {
  final runes = name.trim().runes.toList();
  if (runes.isEmpty) return '';
  final first = String.fromCharCode(runes.first).toUpperCase();
  final used = {
    for (final t in taken)
      if ((t ?? '').trim().isNotEmpty) t!.trim().toLowerCase(),
  };
  if (!used.contains(first.toLowerCase())) return first;
  // Letters and digits of the name only ("Ei", "Ein" …), no spaces.
  final letters = [
    for (final r in runes)
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(String.fromCharCode(r))) String.fromCharCode(r),
  ];
  // A name like "(Alt)" starts with a sign: then its first letter comes first.
  final startsWithLetter = letters.isNotEmpty && letters.first.toUpperCase() == first;
  for (var length = startsWithLetter ? 2 : 1; length <= letters.length; length++) {
    final part = letters.sublist(0, length).join();
    // Never a digit at the end: "E2" + number 1 would read like E's 21st.
    if (RegExp(r'\p{N}$', unicode: true).hasMatch(part)) continue;
    final candidate = part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase();
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
  // Every start of the name is taken: repeat the first letter ("EE").
  for (var n = 2; n <= 4; n++) {
    final candidate = first * n;
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
  return first;
}

/// The Kürzel a new Sammlung must not repeat: those of the Sammlungen and
/// of the Werke.
Set<String> rdTakenPrefixes(List<SongCollection> collections, List<Song> songs) => {
  for (final c in collections)
    if (c.prefix.trim().isNotEmpty) c.prefix.trim(),
  for (final s in songs)
    if ((s.prefix ?? '').trim().isNotEmpty) s.prefix!.trim(),
};
