import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/song/song.dart';
import '../../../data/repositories/song_repository.dart' show CurrentSongsGroup;
import '../../songs/presentation/utils/song_utils.dart';

/// REDESIGN: pure logic of the Werke tab (canvas "WerkeListe", "WerkDetail").

/// File category ids of `songs.files` (Ionic `getInstrumentName`).
const int rdRecordingCategory = 1;
const int rdLyricsCategory = 2;

/// Search over title, composer, number and the last conductor.
bool rdWorkMatches(Song song, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = [song.name, song.composer ?? '', song.fullNumber, song.conductor ?? ''].join(' ').toLowerCase();
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Works planned for the coming Termine ("Gerade geprobt"), soonest first,
/// each once. Songs come from [songs] (enriched list) when loaded.
List<Song> rdCurrentWorks(List<CurrentSongsGroup> groups, List<Song> songs) {
  final byId = {for (final s in songs) s.id: s};
  final sorted = [...groups]..sort((a, b) => a.date.compareTo(b.date));
  final seen = <int>{};
  final result = <Song>[];
  for (final g in sorted) {
    for (final h in g.history) {
      final id = h.songId ?? h.song?.id;
      if (id == null || !seen.add(id)) continue;
      final song = byId[id] ?? h.song;
      if (song != null) result.add(song);
    }
  }
  return result;
}

/// Files of the group [groupId] (the person's instrument / voice), PDFs
/// first.
List<SongFile> rdPartFiles(Song song, int? groupId) {
  if (groupId == null || groupId <= rdLyricsCategory) return const [];
  final files = [
    for (final f in song.files ?? const <SongFile>[])
      if (f.instrumentId == groupId) f,
  ];
  files.sort((a, b) => (SongUtils.isPdf(a) ? 0 : 1).compareTo(SongUtils.isPdf(b) ? 0 : 1));
  return files;
}

/// The recording of the work (category "Aufnahme").
SongFile? rdRecording(Song song) =>
    (song.files ?? const <SongFile>[])
        .where((f) => f.instrumentId == rdRecordingCategory && SongUtils.isAudio(f))
        .firstOrNull;

/// The score (file note "Partitur").
SongFile? rdScore(Song song) =>
    (song.files ?? const <SongFile>[]).where((f) => f.instrumentId == null && f.note == 'Partitur').firstOrNull;

/// Names of the song's categories in category order.
List<String> rdCategoryNames(Song song, List<SongCategory> categories) {
  final ids = song.categoryIds ?? const <String>[];
  final sorted = [...categories]..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final c in sorted)
      if (c.id != null && ids.contains(c.id)) c.name,
  ];
}

/// "PDF", "MP3" … from the file type or name.
String rdFileKind(SongFile file) {
  if (SongUtils.isPdf(file)) return 'PDF';
  final dot = file.fileName.lastIndexOf('.');
  if (dot >= 0 && dot < file.fileName.length - 1) return file.fileName.substring(dot + 1).toUpperCase();
  final slash = file.fileType.lastIndexOf('/');
  return (slash >= 0 ? file.fileType.substring(slash + 1) : file.fileType).toUpperCase();
}

/// What the top card of the work page offers the viewer.
enum RdWorkLead {
  /// "Deine Stimme" with the files of the viewer's group.
  part,

  /// The viewer's group has no files, other groups do.
  noPart,

  /// Conductors (main group, or no group): the score.
  score,

  /// Conductors without a score: all parts.
  allParts,

  /// Nothing to show on top.
  none,
}

/// The top card for a viewer in group [groupId]. The main group (Dirigent)
/// gets no parts of its own (the file upload skips it), so conductors and
/// persons without a group see the score or all parts, never "no part".
RdWorkLead rdWorkLead(Song song, int? groupId, {required bool isMainGroup}) {
  if (!isMainGroup && rdPartFiles(song, groupId).isNotEmpty) return RdWorkLead.part;
  final hasGroupFiles = (song.files ?? const <SongFile>[]).any((f) => (f.instrumentId ?? 0) > rdLyricsCategory);
  if (groupId == null || isMainGroup) {
    if (rdScore(song) != null) return RdWorkLead.score;
    return hasGroupFiles ? RdWorkLead.allParts : RdWorkLead.none;
  }
  return hasGroupFiles ? RdWorkLead.noPart : RdWorkLead.none;
}

/// Whether [file] is a part of a group (not Aufnahme, Liedtext or a free
/// category such as the score).
bool rdIsGroupPart(SongFile file) => (file.instrumentId ?? 0) > rdLyricsCategory;

/// The groups that have Noten of the work, in group order. This is the
/// Besetzung: the upload sets `instrument_ids` from the files as well.
List<Group> rdFileGroups(List<SongFile> files, List<Group> groups) {
  final ids = {
    for (final f in files)
      if (rdIsGroupPart(f)) f.instrumentId,
  };
  return [
    for (final g in groups)
      if (g.maingroup != true && ids.contains(g.id)) g,
  ];
}

/// Groups still without Noten: somebody plays in them ([playerCounts]
/// active persons per group; null = unknown, every group counts) but no
/// part is theirs. Empty while the work has no parts at all: then the page
/// asks for Noten instead.
List<Group> rdMissingGroups(List<SongFile> files, List<Group> groups, Map<int, int>? playerCounts) {
  final have = {for (final g in rdFileGroups(files, groups)) g.id};
  if (have.isEmpty) return const [];
  return [
    for (final g in groups)
      if (g.maingroup != true &&
          g.id != null &&
          g.id! > rdLyricsCategory &&
          !have.contains(g.id) &&
          (playerCounts == null || (playerCounts[g.id] ?? 0) > 0))
        g,
  ];
}

/// What a member sees of [files] (sorted): everything but the parts of
/// other groups ([others], behind "Alle Stimmen") and the [recording],
/// which has its own card.
({List<SongFile> shown, List<SongFile> others}) rdMemberFiles(List<SongFile> files, int? groupId, SongFile? recording) {
  final shown = <SongFile>[];
  final others = <SongFile>[];
  for (final f in files) {
    if (recording != null && f.url == recording.url) continue;
    if (rdIsGroupPart(f) && f.instrumentId != groupId) {
      others.add(f);
    } else {
      shown.add(f);
    }
  }
  return (shown: shown, others: others);
}

/// "Werk bearbeiten": the other Werk that already has [prefix] [number]
/// (prefix compared without case and spaces), or null when the number is
/// free or empty.
Song? rdNumberTakenBy(List<Song> songs, int? songId, String prefix, int? number) {
  if (number == null) return null;
  final wanted = prefix.trim().toLowerCase();
  return songs
      .where((s) => s.id != songId && s.number == number && (s.prefix ?? '').trim().toLowerCase() == wanted)
      .firstOrNull;
}

/// "Neues Werk": the number after the highest one with [prefix] (1 when
/// there is none).
int rdNextFreeNumber(List<Song> songs, String prefix) {
  final wanted = prefix.trim().toLowerCase();
  var max = 0;
  for (final s in songs) {
    final n = s.number ?? 0;
    if ((s.prefix ?? '').trim().toLowerCase() == wanted && n > max) max = n;
  }
  return max + 1;
}

/// A coming Termin with its Werke ("Als Nächstes" of the Werke tab).
class RdNextEvent {
  const RdNextEvent({required this.date, required this.type, required this.attendanceId, required this.songs});

  final DateTime? date;

  /// Info text or type name of the Termin ("Probe"), may be empty.
  final String type;
  final int? attendanceId;
  final List<Song> songs;
}

/// The coming Termine with planned Werke, soonest first (the loader groups
/// by "DD.MM.YYYY | Typ"); Werke come from [songs] when listed there.
List<RdNextEvent> rdNextEvents(List<CurrentSongsGroup> groups, List<Song> songs) {
  final byId = {for (final s in songs) s.id: s};
  final result = <RdNextEvent>[];
  for (final g in groups) {
    final first = g.history.firstOrNull;
    final seen = <int>{};
    final works = <Song>[];
    for (final h in g.history) {
      final id = h.songId ?? h.song?.id;
      if (id == null || !seen.add(id)) continue;
      final song = byId[id] ?? h.song;
      if (song != null) works.add(song);
    }
    if (works.isEmpty) continue;
    final split = g.date.indexOf(' | ');
    result.add(
      RdNextEvent(
        date: DateTime.tryParse(first?.attendanceDate ?? first?.date ?? '')?.toLocal(),
        type: split < 0 ? '' : g.date.substring(split + 3),
        attendanceId: first?.attendanceId,
        songs: works,
      ),
    );
  }
  final far = DateTime(9999);
  result.sort((a, b) => (a.date ?? far).compareTo(b.date ?? far));
  return result;
}

/// "Nur zeigen" of the Werke filter that the old filter does not know.
enum RdWorksOnly { missing, myPart, recording }

/// Whether [song] still lacks Noten: no file at all, or (orchestras) a
/// group with players has none ([rdMissingGroups]).
bool rdWorkLacksNotes(Song song, List<Group> groups, Map<int, int>? playerCounts, {required bool orchestra}) {
  final files = song.files ?? const <SongFile>[];
  if (files.isEmpty) return true;
  return orchestra && rdMissingGroups(files, groups, playerCounts).isNotEmpty;
}

/// Keeps the Werke that match every chosen [only] filter.
List<Song> rdApplyOnly(
  List<Song> songs,
  Set<RdWorksOnly> only, {
  required int? groupId,
  required List<Group> groups,
  required Map<int, int>? playerCounts,
  required bool orchestra,
}) {
  if (only.isEmpty) return songs;
  return [
    for (final s in songs)
      if ((!only.contains(RdWorksOnly.myPart) || rdPartFiles(s, groupId).isNotEmpty) &&
          (!only.contains(RdWorksOnly.recording) || rdRecording(s) != null) &&
          (!only.contains(RdWorksOnly.missing) || rdWorkLacksNotes(s, groups, playerCounts, orchestra: orchestra)))
        s,
  ];
}
