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

bool rdHasPdf(Song song) => (song.files ?? const <SongFile>[]).any(SongUtils.isPdf);

bool rdHasAudio(Song song) => (song.files ?? const <SongFile>[]).any(SongUtils.isAudio);

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
SongFile? rdRecording(Song song) => (song.files ?? const <SongFile>[])
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
