import '../../../core/utils/choir_file_utils.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/instrument/instrument.dart';
import '../../../data/models/song/song.dart';
import '../../../data/repositories/song_repository.dart' show CurrentSongsGroup;
import '../../songs/presentation/utils/song_utils.dart';
import 'rd_dates.dart';

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

/// The viewer's part of [song]: the files of group [groupId] (PDFs first).
/// In a choir without own Noten the "Chor (alle)" files meant for every
/// singer come too, next to an own practice recording ("Meine Mappe",
/// "Meine Noten öffnen", Werk page).
List<SongFile> rdMemberPartFiles(Song song, int? groupId, {required bool choir}) {
  final own = rdPartFiles(song, groupId);
  if (!choir || groupId == null || groupId <= rdLyricsCategory || own.any(rdIsNotes)) return own;
  final all = [
    ...own,
    for (final f in song.files ?? const <SongFile>[])
      if (isChoirAllFile(instrumentId: f.instrumentId, note: f.note)) f,
  ];
  all.sort((a, b) => (SongUtils.isPdf(a) ? 0 : 1).compareTo(SongUtils.isPdf(b) ? 0 : 1));
  return all;
}

/// Whether [file] is Noten: not the recording, the lyrics or an audio
/// file (practice recordings of a voice).
bool rdIsNotes(SongFile file) =>
    file.instrumentId != rdRecordingCategory && file.instrumentId != rdLyricsCategory && !SongUtils.isAudio(file);

/// Whether [song] has any Noten ([rdIsNotes]).
bool rdHasNotes(Song song) => (song.files ?? const <SongFile>[]).any(rdIsNotes);

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
RdWorkLead rdWorkLead(Song song, int? groupId, {required bool isMainGroup, bool choir = false}) {
  if (!isMainGroup && rdMemberPartFiles(song, groupId, choir: choir).isNotEmpty) return RdWorkLead.part;
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

/// The coming Termine with planned Werke, soonest first. The loader groups
/// by "DD.MM.YYYY | Typ", so one group can hold two Termine of a day: they
/// are split by attendance first. Werke come from [songs] when listed there.
List<RdNextEvent> rdNextEvents(List<CurrentSongsGroup> groups, List<Song> songs) {
  final byId = {for (final s in songs) s.id: s};
  final result = <RdNextEvent>[];
  for (final g in groups) {
    final split = g.date.indexOf(' | ');
    final type = split < 0 ? '' : g.date.substring(split + 3);
    final byEvent = <int?, List<SongHistory>>{};
    for (final h in g.history) {
      (byEvent[h.attendanceId] ??= []).add(h);
    }
    for (final entries in byEvent.values) {
      final seen = <int>{};
      final works = <Song>[];
      for (final h in entries) {
        final id = h.songId ?? h.song?.id;
        if (id == null || !seen.add(id)) continue;
        final song = byId[id] ?? h.song;
        if (song != null) works.add(song);
      }
      if (works.isEmpty) continue;
      final first = entries.first;
      result.add(
        RdNextEvent(
          date: DateTime.tryParse(first.attendanceDate ?? first.date ?? '')?.toLocal(),
          type: type,
          attendanceId: first.attendanceId,
          songs: works,
        ),
      );
    }
  }
  final far = DateTime(9999);
  result.sort((a, b) => (a.date ?? far).compareTo(b.date ?? far));
  return result;
}

/// [events] without the Termine that are already over at [now]. The loader
/// ([rdNextEvents]' input) keeps everything from the start of today, so a
/// Termin of this morning would stay until midnight. Over means: the end
/// time (else the start time) of the Termin, from [attendances] or its type
/// in [types], on its last day lies before [now]. Without any time, or with
/// an all-day type (its times are only for the Ablauf), the Termin stays
/// until the end of its (last) day.
List<RdNextEvent> rdWithoutEndedEvents(
  List<RdNextEvent> events, {
  required DateTime now,
  List<Attendance> attendances = const [],
  List<AttendanceType> types = const [],
}) {
  final byId = {for (final a in attendances) a.id: a};
  return [
    for (final e in events)
      if (!_rdEventOver(e, byId[e.attendanceId], types, now)) e,
  ];
}

bool _rdEventOver(RdNextEvent event, Attendance? att, List<AttendanceType> types, DateTime now) {
  final date = event.date;
  if (date == null) return false;
  final type = att?.typeId == null ? null : types.where((t) => t.id == att!.typeId).firstOrNull;
  final days = (att?.durationDays ?? 1) < 1 ? 1 : (att?.durationDays ?? 1);
  final lastDay = rdAddDays(date, days - 1);
  if (type?.allDay ?? false) return !now.isBefore(rdAddDays(lastDay, 1));
  // Start and end from one source: the Termin's own times, else its type's
  // (a Termin at 19:00 with a type ending at 12:00 is not overnight).
  final own = _rdClock(att?.startTime) != null || _rdClock(att?.endTime) != null;
  final start = _rdClock(own ? att?.startTime : type?.startTime);
  final end = _rdClock(own ? att?.endTime : type?.endTime);
  final time = end ?? start;
  if (time == null) return !now.isBefore(rdAddDays(lastDay, 1));
  // An end before the start (e.g. 20:00–01:00) is on the next day.
  final overnight = end != null && start != null && end < start && days == 1;
  final day = overnight ? rdAddDays(lastDay, 1) : lastDay;
  return DateTime(day.year, day.month, day.day, time ~/ 60, time % 60).isBefore(now);
}

/// Minutes after midnight of "HH:mm" (also "HH:mm:ss"), null without one.
int? _rdClock(String? time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time?.trim() ?? '');
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

/// "Nur zeigen" of the Werke filter that the old filter does not know.
enum RdWorksOnly { missing, myPart, recording }

/// Groups of an orchestra Werk with players but without Noten
/// ([rdMissingGroups] over the Noten only, so a practice recording does
/// not count).
List<Group> rdWorkMissingGroups(Song song, List<Group> groups, Map<int, int>? playerCounts) =>
    rdMissingGroups([...?song.files?.where(rdIsNotes)], groups, playerCounts);

/// Whether [song] still lacks Noten: none at all (a recording or the lyrics
/// alone do not count), or (orchestras) a group with players has none.
bool rdWorkLacksNotes(Song song, List<Group> groups, Map<int, int>? playerCounts, {required bool orchestra}) {
  if (!rdHasNotes(song)) return true;
  return orchestra && rdWorkMissingGroups(song, groups, playerCounts).isNotEmpty;
}

/// Keeps the Werke that match every chosen [only] filter.
List<Song> rdApplyOnly(
  List<Song> songs,
  Set<RdWorksOnly> only, {
  required int? groupId,
  required List<Group> groups,
  required Map<int, int>? playerCounts,
  required bool orchestra,
  required bool choir,
}) {
  if (only.isEmpty) return songs;
  return [
    for (final s in songs)
      if ((!only.contains(RdWorksOnly.myPart) || rdMemberPartFiles(s, groupId, choir: choir).isNotEmpty) &&
          (!only.contains(RdWorksOnly.recording) || rdRecording(s) != null) &&
          (!only.contains(RdWorksOnly.missing) || rdWorkLacksNotes(s, groups, playerCounts, orchestra: orchestra)))
        s,
  ];
}
