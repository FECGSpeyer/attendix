import '../../../../core/utils/choir_file_utils.dart' show kChoirAllNote;
import '../../../../core/utils/instrument_matcher.dart';
import '../../../../data/models/song/song.dart';
import '../../../songs/presentation/widgets/file_upload_sheet.dart' show FileCategoryGuess, guessFileCategory, learnableTerm;
import '../rd_work_files_logic.dart' show rdMaxUploadBytes;

/// REDESIGN: "Noten importieren" (Werke aus einer ZIP von Google Drive,
/// Dropbox oder dem Rechner). The rules, free of widgets so they can be
/// tested: which folder is a Werk, which Werk in Attendix it belongs to,
/// Fassungen, duplicates, the questions about unknown part names and what
/// is uploaded in the end.
///
/// Lessons from the Speyer import (2,304 files): part names are mostly clear
/// from the file name, unknown names are asked once for all files; which
/// Fassung is current is decided by the date inside the files, never by the
/// number of files; files already in Attendix are never replaced; Werke with
/// Fassungen or an unsure Werk are only uploaded once someone looked at them.

// ---------------------------------------------------------------------------
// Input

/// A file of the source (one entry of the ZIP).
class RdImportEntry {
  const RdImportEntry({required this.path, required this.size, this.modified});

  /// Path inside the source with "/" ("Noten/120 Wie wunderbar/Violine 1.pdf").
  final String path;
  final int size;

  /// Last change stored in the ZIP (Google Drive: when it was uploaded there).
  final DateTime? modified;

  String get name => path.substring(path.lastIndexOf('/') + 1);

  /// The folders above the file, top first.
  List<String> get folders {
    final parts = path.split('/');
    return [for (final p in parts.sublist(0, parts.length - 1)) if (p.trim().isNotEmpty) p];
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }
}

/// A Werk already in Attendix, as far as the import needs it.
class RdImportSong {
  const RdImportSong({required this.id, required this.name, this.number, this.prefix, this.files = const []});

  final int id;
  final String name;
  final int? number;
  final String? prefix;
  final List<SongFile> files;

  String get label => [if ((prefix ?? '').trim().isNotEmpty || number != null) '${(prefix ?? '').trim()}${number ?? ''}', name].join(' ');
}

// ---------------------------------------------------------------------------
// Files that are left out on reading

/// System files that are never shown (macOS, Windows, Office lock files).
bool rdImportIsJunk(String path) {
  if (path.endsWith('/')) return true;
  final parts = path.split('/');
  for (final p in parts) {
    if (p == '__MACOSX') return true;
    if (p.startsWith('.') && p.length > 1) return true;
  }
  final name = parts.last;
  final lower = name.toLowerCase();
  return lower.isEmpty ||
      lower == 'thumbs.db' ||
      lower == 'desktop.ini' ||
      lower.startsWith('~\$') ||
      name == 'Icon\r';
}

/// File types Attendix keeps for a Werk: notes, scans, recordings, notation
/// programs and texts.
const Set<String> rdImportExtensions = {
  'pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'tif', 'tiff', 'bmp', //
  'mp3', 'wav', 'ogg', 'oga', 'opus', 'm4a', 'aac', 'flac', 'aif', 'aiff', 'wma', 'weba', //
  'mp4', 'm4v', 'mov', //
  'mid', 'midi', 'sib', 'mus', 'musx', 'mscz', 'mscx', 'musicxml', 'mxl', //
  'doc', 'docx', 'odt', 'rtf', 'txt',
};

const Set<String> _textExtensions = {'doc', 'docx', 'odt', 'rtf', 'txt'};

// ---------------------------------------------------------------------------
// Names: folding, Cyrillic, similarity

const Map<String, String> _cyrillic = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e', 'ж': 'zh', 'з': 'z', 'и': 'i', //
  'й': 'i', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', //
  'у': 'u', 'ф': 'f', 'х': 'h', 'ц': 'c', 'ч': 'ch', 'ш': 'sh', 'щ': 'sh', 'ъ': '', 'ы': 'i', 'ь': '', //
  'э': 'e', 'ю': 'iu', 'я': 'ia', 'і': 'i', 'ї': 'i', 'є': 'e', 'ґ': 'g', 'ў': 'u',
};

const Map<String, String> _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

/// Words of a title to compare titles across spellings: lower case, umlauts
/// and accents folded, Cyrillic written in Latin letters and spellings of
/// the same sound made equal ("Мой Господь" = "Moj Gospod'" = "Moy Gospod").
List<String> rdImportTitleWords(String text) {
  final cached = _titleWordsCache[text];
  if (cached != null) return cached;
  if (_titleWordsCache.length > 20000) _titleWordsCache.clear();
  return _titleWordsCache[text] = List.unmodifiable(_titleWords(text));
}

/// [rdImportTitleWords] of titles seen before: every folder is compared
/// with every Werk.
final Map<String, List<String>> _titleWordsCache = {};

final RegExp _combiningMarks = RegExp('[̀-ͯ]');
final RegExp _doubledLetters = RegExp(r'(\p{L})\1+', unicode: true);
final RegExp _titleWord = RegExp(r'[\p{L}\p{N}]+', unicode: true);

List<String> _titleWords(String text) {
  var s = text.toLowerCase();
  // macOS / Drive spell ä as a + U+0308.
  s = s
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll('й', 'й')
      .replaceAll('ё', 'ё');
  final out = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_cyrillic[ch] ?? _accents[ch] ?? ch);
  }
  s = out.toString().replaceAll(_combiningMarks, '');
  s = s
      .replaceAll('tsch', 'ch')
      .replaceAll('sch', 'sh')
      .replaceAll('kh', 'h')
      .replaceAll('tz', 'c')
      .replaceAll('ts', 'c')
      .replaceAll('ph', 'f')
      .replaceAll('ck', 'k')
      .replaceAll('j', 'i')
      .replaceAll('y', 'i')
      .replaceAll('w', 'v')
      .replaceAllMapped(_doubledLetters, (m) => m[1]!);
  return [for (final m in _titleWord.allMatches(s)) m[0]!];
}

/// How alike two titles are, 0 to 1: shared words or, for typos and other
/// spellings ("Hallelujah" / "Haleluja"), shared groups of three letters
/// (Dice), whichever is higher.
double rdImportTitleSimilarity(String a, String b) {
  final s = _titleSimilarity(a, b);
  return s.words > s.letters ? s.words : s.letters;
}

/// Shared words and shared groups of three letters of two titles (Dice).
({double words, double letters}) _titleSimilarity(String a, String b) {
  final wa = rdImportTitleWords(a);
  final wb = rdImportTitleWords(b);
  if (wa.isEmpty || wb.isEmpty) return (words: 0, letters: 0);
  final sa = wa.toSet();
  final sb = wb.toSet();
  final words = 2 * sa.intersection(sb).length / (sa.length + sb.length);
  final ta = _trigrams(wa);
  final tb = _trigrams(wb);
  final letters = ta.isEmpty || tb.isEmpty ? 0.0 : 2 * ta.intersection(tb).length / (ta.length + tb.length);
  return (words: words, letters: letters);
}

/// Groups of three letters of a title's words (" ha", "hal", …, "ja ").
Set<String> _trigrams(List<String> words) {
  final key = words.join(' ');
  final cached = _trigramCache[key];
  if (cached != null) return cached;
  if (_trigramCache.length > 20000) _trigramCache.clear();
  final padded = ' $key ';
  return _trigramCache[key] = {for (var i = 0; i + 3 <= padded.length; i++) padded.substring(i, i + 3)};
}

final Map<String, Set<String>> _trigramCache = {};

/// Number and title of a Werk folder ("120 Wie wunderbar", "HZ 1 Die wahre
/// Liebe", "07_Мой Господь").
({String? prefix, int? number, String title}) rdParseWorkName(String name) {
  final m = RegExp(r'^\s*(?:([A-ZÄÖÜ]{1,3})\s*)?(\d{1,4})(?:[\s._\-–—)]+|$)(.*)$').firstMatch(name);
  if (m == null) return (prefix: null, number: null, title: name.trim());
  final title = m[3]!.replaceAll(RegExp(r'^[\s._\-–—)]+|[\s._\-–—(]+$'), '').trim();
  return (prefix: m[1], number: int.parse(m[2]!), title: title);
}

/// How sure the Werk in Attendix is.
enum RdMatchKind {
  /// Number and title fit (or the very same title without number).
  sure,

  /// The number fits, the title does not.
  numberOnly,

  /// The title fits, the number is another one or missing.
  titleOnly,

  /// Several Werke fit equally well ("A1 Stille Nacht", "B1 Stille Nacht"
  /// for the folder "1 Stille Nacht").
  ambiguous,

  /// The KI named this Werk (other spelling, translation): to be checked.
  byAi,

  /// No Werk fits: a new one is created.
  none,
}

class RdWorkMatch {
  const RdWorkMatch(this.kind, [this.songId]);

  static const RdWorkMatch none = RdWorkMatch(RdMatchKind.none);

  final RdMatchKind kind;
  final int? songId;
}

/// The Werk in Attendix a folder belongs to.
RdWorkMatch rdMatchWork(String folderName, List<RdImportSong> songs) {
  final parsed = rdParseWorkName(folderName);
  // The best fitting song; [tie] when another one fits as well; [words]
  // how far its words alone fit.
  ({RdImportSong song, double sim, double words, bool tie})? bestOf(Iterable<RdImportSong> candidates, String title) {
    final scored = [
      for (final s in candidates)
        if (_titleSimilarity(title, s.name) case final t)
          (song: s, sim: t.words > t.letters ? t.words : t.letters, words: t.words),
    ]..sort((a, b) => b.sim.compareTo(a.sim));
    if (scored.isEmpty) return null;
    final best = scored.first;
    final tie = scored.length > 1 && scored[1].sim >= best.sim - 0.02;
    return (song: best.song, sim: best.sim, words: best.words, tie: tie);
  }

  final hasTitle = rdImportTitleWords(parsed.title).isNotEmpty;
  if (parsed.number != null) {
    String norm(String? p) => (p ?? '').trim().toUpperCase();
    final sameNumber = songs.where((s) => s.number == parsed.number).toList();
    final samePrefix = sameNumber.where((s) => norm(s.prefix) == norm(parsed.prefix)).toList();
    // Folders often leave out a prefix the library uses ("A120" → "120").
    final candidates = samePrefix.isNotEmpty ? samePrefix : (parsed.prefix == null ? sameNumber : const <RdImportSong>[]);
    if (candidates.isNotEmpty) {
      final best = bestOf(candidates, parsed.title)!;
      // A Werk with this very title under another number comes first
      // ("12 Abendsegen" is not the 12 "Morgensegen" when "Abendsegen" is
      // there too).
      final byTitle = hasTitle && best.sim < 0.999 ? bestOf(songs, parsed.title) : null;
      final exactElsewhere = byTitle != null && byTitle.sim >= 0.999;
      if (!hasTitle || (best.words >= 0.4 && !exactElsewhere)) {
        // Without a title, or two Werke with this number fitting as well.
        final ambiguous = candidates.length > 1 && (!hasTitle || best.tie);
        return RdWorkMatch(ambiguous ? RdMatchKind.ambiguous : RdMatchKind.sure, best.song.id);
      }
      if (byTitle != null && byTitle.sim >= 0.75 && byTitle.sim > best.sim) {
        return RdWorkMatch(byTitle.tie ? RdMatchKind.ambiguous : RdMatchKind.titleOnly, byTitle.song.id);
      }
      // The title fits only by its letters (a typo, or another Werk with
      // similar words): to be checked, never sure.
      return RdWorkMatch(RdMatchKind.numberOnly, best.song.id);
    }
  }
  if (!hasTitle) return RdWorkMatch.none;
  final byTitle = bestOf(songs, parsed.title);
  if (byTitle == null || byTitle.sim < 0.75) return RdWorkMatch.none;
  if (byTitle.tie) return RdWorkMatch(RdMatchKind.ambiguous, byTitle.song.id);
  if (byTitle.sim >= 0.999 && parsed.number == null) return RdWorkMatch(RdMatchKind.sure, byTitle.song.id);
  return RdWorkMatch(RdMatchKind.titleOnly, byTitle.song.id);
}

// ---------------------------------------------------------------------------
// Which folder is a Werk

String _folded(String s) => rdImportTitleWords(s).join(' ');

/// Folders that only sort files of a Werk ("Stimmen", "PDF").
const Set<String> _formatFolders = {
  'stimmen', 'einzelstimmen', 'stimme', 'parts', 'part', 'pdf', 'pdfs', 'noten', 'scores', 'score', //
  'partitur', 'partituren', 'sibelius', 'sib', 'midi', 'mid', 'audio', 'mp3', 'aufnahmen', 'aufnahme', //
  'recordings', 'texte', 'text', 'liedtext', 'liedtexte', 'lirics', 'scans', 'scan', 'druck', 'print', //
  'finale', 'musescore', 'xml', 'musicxml', 'dateien', 'files',
};

/// Sections of an ensemble as folder names inside a Werk.
const Set<String> _sectionFolders = {
  'blaeser', 'blechblaeser', 'holzblaeser', 'blech', 'holz', 'streicher', 'strings', 'brass', 'woodwinds', //
  'winds', 'percussion', 'schlagwerk', 'chor', 'khor', 'hor', 'choir', 'gesang', 'vocal', 'vocals', 'solo', //
  'solisten', 'orchester', 'orchestra', 'band', 'rhithmus', 'rhithm',
};

/// [words] spelled as [rdImportTitleWords] spells folder names.
Set<String> _normalized(Set<String> words) => {for (final w in words) rdImportTitleWords(w).join(' ')};

final Set<String> _formatFoldersN = _normalized(_formatFolders);
final Set<String> _sectionFoldersN = _normalized(_sectionFolders);
final Set<String> _versionWordsN = _normalized(_versionWords);
final Set<String> _oldWordsN = _normalized(_oldWords);

/// Folders of a version inside a Werk ("Fassung 2019", "Version 2").
const Set<String> _versionWords = {'fassung', 'fassungen', 'version', 'versionen', 'bearbeitung', 'arrangement', 'neu', 'original'};

/// First words of folders with old versions ("Alt", "Alte Version").
const Set<String> _oldWords = {'alt', 'alte', 'alter', 'altes', 'old', 'older', 'archiv', 'archive', 'veraltet', 'backup', 'frueher'};

/// Choir voices besides "Alt" as folder names: next to them "Alt" is the
/// voice, not an old version.
const Set<String> _voiceFolders = {'sopran', 'soprano', 'mezzosopran', 'tenor', 'tenore', 'bass', 'basso', 'bariton', 'baritone'};

final Set<String> _voiceFoldersN = _normalized(_voiceFolders);

/// "Alt", "Alt 1", "Alt II": the voice when the Werk has voice folders.
bool _isAltVoice(String name) {
  final words = rdImportTitleWords(name);
  return words.isNotEmpty &&
      words.first == 'alt' &&
      words.skip(1).every((w) => RegExp(r'^\d$').hasMatch(w) || w == 'i' || w == 'ii');
}

/// "Alt", "Alte Version 2019", "Archiv": files there are older versions.
bool rdImportIsOldFolder(String name) {
  final words = rdImportTitleWords(name);
  return words.isNotEmpty && _oldWordsN.contains(words.first) && words.length <= 4;
}

bool _isYear(String w) {
  final n = int.tryParse(w);
  return n != null && w.length == 4 && n >= 1900 && n <= 2100;
}

/// A folder that sorts files inside a Werk, not a Werk itself.
bool _isStructural(String name, List<InstrumentInfo> instruments) {
  final words = rdImportTitleWords(name);
  if (words.isEmpty) return true;
  final joined = words.join(' ');
  if (_formatFoldersN.contains(joined) || _sectionFoldersN.contains(joined)) return true;
  if (rdImportIsOldFolder(name)) return true;
  if (words.every((w) => _isYear(w) || _versionWordsN.contains(w) || RegExp(r'^v\d+$').hasMatch(w))) return true;
  if (_versionWordsN.contains(words.first)) return true;
  if (instruments.isNotEmpty) {
    final match = InstrumentMatcher.detect('$name.pdf', instruments);
    if (match.instrumentId != null && match.confidence == MatchConfidence.sure) {
      // A number before more than the part is a Werk ("12 Le viole").
      final term = match.term;
      return rdParseWorkName(name).number == null || term == null || InstrumentMatcher.namesOnlyPart(name, term);
    }
  }
  return false;
}

/// A folder that names a Werk for sure: a number with a title, or the title
/// or number of a Werk in Attendix.
bool _looksLikeWork(String name, List<RdImportSong> songs) {
  final parsed = rdParseWorkName(name);
  if (parsed.number != null) {
    if (rdImportTitleWords(parsed.title).any((w) => !_isYear(w))) return true;
    return songs.any((s) => s.number == parsed.number);
  }
  return rdMatchWork(name, songs).kind != RdMatchKind.none;
}

/// The Werk folder of every file: path → folder path (null when the file
/// lies outside any folder). Leading folders all files share (the folder
/// the ZIP was made of) are skipped.
Map<String, String?> rdFindWorkFolders(
  List<RdImportEntry> entries, {
  required List<RdImportSong> songs,
  required List<InstrumentInfo> instruments,
}) {
  final result = <String, String?>{};
  if (entries.isEmpty) return result;

  // The common root, unless it is a Werk itself (ZIP of one Werk: its
  // name, or only sorting folders below it).
  final structural = <String, bool>{};
  bool isStructural(String seg) => structural.putIfAbsent(seg, () => _isStructural(seg, instruments));
  var root = 0;
  final first = entries.first.folders;
  while (root < first.length) {
    final seg = first[root];
    final shared = entries.every((e) {
      final f = e.folders;
      return f.length > root + 1 && f[root] == seg;
    });
    if (!shared || _looksLikeWork(seg, songs)) break;
    if (entries.any((e) => isStructural(e.folders[root + 1]))) break;
    root++;
  }

  final children = <String, Set<String>>{};
  final withFiles = <String>{};
  for (final e in entries) {
    final f = e.folders;
    for (var i = root; i < f.length; i++) {
      final parent = f.sublist(0, i).join('/');
      children.putIfAbsent(parent, () => <String>{}).add(f[i]);
    }
    withFiles.add(f.join('/'));
  }

  final workLike = <String, bool>{};
  bool looksLikeWork(String seg) => workLike.putIfAbsent(seg, () => _looksLikeWork(seg, songs));

  int? depthOf(List<String> f) {
    // 1. A numbered folder or one named like a Werk in Attendix.
    for (var i = root; i < f.length; i++) {
      if (!isStructural(f[i]) && looksLikeWork(f[i])) return i;
    }
    // 2. Otherwise by the tree: the first folder with files of its own or
    //    with only sorting folders below it.
    for (var i = root; i < f.length; i++) {
      if (isStructural(f[i])) return i > root ? i - 1 : null;
      final path = f.sublist(0, i + 1).join('/');
      if (withFiles.contains(path)) return i;
      final kids = children[path] ?? const <String>{};
      final own = kids.where((k) => !isStructural(k)).length;
      if (own >= 2) continue;
      if (own == 0 || kids.length > own) return i;
    }
    return f.length > root ? f.length - 1 : null;
  }

  for (final e in entries) {
    final f = e.folders;
    final depth = depthOf(f);
    result[e.path] = depth == null ? null : f.sublist(0, depth + 1).join('/');
  }
  return result;
}

// ---------------------------------------------------------------------------
// Categories

/// What a file becomes in Attendix: a group (part), a type (Partitur …),
/// a group still to be created, or "Sonstige" (all null).
class RdImportCategory {
  const RdImportCategory({this.instrumentId, this.note, this.newGroup}) : groups = const [];

  /// A part for several groups ("Posaune und Tuba"): the file is stored once
  /// for each of [groups] (Leon, 07.11.2026).
  const RdImportCategory.several(this.groups)
      : instrumentId = null,
        note = null,
        newGroup = null;

  static const RdImportCategory other = RdImportCategory();

  final int? instrumentId;
  final String? note;

  /// Name of a group created on upload ("Neue Gruppe anlegen").
  final String? newGroup;

  /// The groups of a part for several groups (each a group or a new group);
  /// empty for any other category.
  final List<RdImportCategory> groups;

  bool get isSeveral => groups.isNotEmpty;

  /// What a file of this category is stored as: once per group of a part
  /// for several groups, else once as it is.
  List<RdImportCategory> get each => groups.isEmpty ? [this] : groups;

  bool get isPart => isSeveral || newGroup != null || (instrumentId != null && instrumentId! > InstrumentMatcher.lyricsId);

  @override
  bool operator ==(Object other) =>
      other is RdImportCategory &&
      other.instrumentId == instrumentId &&
      other.note == note &&
      other.newGroup == newGroup &&
      other.groups.length == groups.length &&
      Iterable.generate(groups.length).every((i) => other.groups[i] == groups[i]);

  @override
  int get hashCode => Object.hash(instrumentId, note, newGroup, Object.hashAll(groups));
}

/// Types that clash with the same type already at the Werk.
const Set<String> _uniqueNotes = {'Partitur', 'Klavierauszug', 'Sibelius', 'Chor'};

/// Key of a category for "already there" and Fassungen; null for kinds a
/// Werk often has several of (recordings, texts, MIDI, Sonstige).
String? rdImportClashKey(RdImportCategory c) {
  if (c.newGroup != null) return 'new:${c.newGroup}';
  final id = c.instrumentId;
  if (id != null) return id > InstrumentMatcher.lyricsId ? 'g$id' : null;
  final note = c.note;
  return note != null && _uniqueNotes.contains(note) ? 'n$note' : null;
}

/// Whether the Werk [song] already has a file of [c]'s kind (its part).
bool _atSong(RdImportSong song, RdImportCategory c) {
  final clash = rdImportClashKey(c);
  return clash != null &&
      song.files.any((x) => rdImportClashKey(RdImportCategory(instrumentId: x.instrumentId, note: x.instrumentId == null ? x.note : null)) == clash);
}

/// Whether the Werk [song] has a file named [name] already; for a part for
/// several groups only when every group has it ("Posaune und Tuba.pdf" at
/// Posaune only: Tuba still gets it).
bool _sameName(RdImportSong song, String name, RdImportCategory c) {
  final same = song.files.where((x) => x.fileName == name);
  if (!c.isSeveral) return same.isNotEmpty;
  return c.groups.every((g) => same.any((x) =>
      rdImportClashKey(RdImportCategory(instrumentId: x.instrumentId, note: x.instrumentId == null ? x.note : null)) ==
      rdImportClashKey(g)));
}

/// Roman numerals as part numbers ("Violine II").
const Map<String, int> _roman = {'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6};

int? _numberWord(String w) => int.tryParse(w) ?? _roman[w];

/// The name of a group without its part number and the number
/// ("Flöte 2" → (flöte, 2)).
({String base, int? number}) _splitPartNumber(String name) {
  final words = InstrumentMatcher.tokenize(name);
  if (words.length > 1) {
    final n = _numberWord(words.last);
    if (n != null) return (base: words.sublist(0, words.length - 1).join(' '), number: n);
  }
  return (base: words.join(' '), number: null);
}

/// The group of the same family with the part number of [fileName]: the
/// answer "фл → Flöte 1" puts "фл2.pdf" to Flöte 2 when that group exists.
int rdImportSiblingGroup(int groupId, String fileName, List<InstrumentInfo> groups, {String? workName}) {
  final group = groups.where((g) => g.id == groupId).firstOrNull;
  if (group == null) return groupId;
  final own = _splitPartNumber(group.name);
  if (own.number == null) return groupId;
  final term = InstrumentMatcher.partTerm(fileName, workName: workName) ?? fileName;
  final words = InstrumentMatcher.tokenize(term);
  int? fileNumber;
  for (final w in words.reversed) {
    fileNumber = _numberWord(w);
    if (fileNumber != null) break;
  }
  if (fileNumber == null || fileNumber == own.number) return groupId;
  for (final g in groups) {
    final other = _splitPartNumber(g.name);
    if (other.base == own.base && other.number == fileNumber) return g.id;
  }
  return groupId;
}

/// The words of a part name the questions are grouped by: without part
/// numbers ("Sax 1" and "Sax 2" are one question).
String? rdImportQuestionKey(String fileName, {String? workName}) {
  final term = InstrumentMatcher.partTerm(fileName, workName: workName);
  if (term == null) return null;
  final words = InstrumentMatcher.tokenize(term).where((w) => _numberWord(w) == null).toList();
  return words.isEmpty ? null : words.join(' ');
}

/// [rdImportQuestionKey] as written in the file name ("Sax", "фл").
String? _questionLabel(String fileName, {String? workName}) {
  final term = InstrumentMatcher.partTerm(fileName, workName: workName);
  if (term == null) return null;
  final label = term
      .replaceAll(RegExp(r'(?<![\p{L}])(\d+|[IVX]+|[ivx]{1,3})(?![\p{L}])', unicode: true), ' ')
      .replaceAll(RegExp(r'^[\s\-–.,()_]+|[\s\-–.,()_]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return label.isEmpty ? null : label;
}

// ---------------------------------------------------------------------------
// The plan

/// Why a file is left out.
enum RdSkipReason {
  /// File type Attendix does not keep (ZIP inside, Excel, shortcut …).
  unsupported,

  /// Larger than an upload may be.
  tooLarge,

  /// The same file once more (same size and content).
  duplicate,

  /// The Werk is not imported.
  workSkipped,

  /// Belongs to a Fassung that is not taken.
  otherFassung,

  /// A file of that name is already at the Werk in Attendix.
  sameName,

  /// A Word file next to a PDF of the same name.
  wordNextToPdf,

  /// The Werk in Attendix already has this part.
  partExists,

  /// Left out by hand.
  byHand,
}

/// A file in the plan.
class RdImportFile {
  const RdImportFile({
    required this.entry,
    required this.fassungKey,
    required this.guess,
    this.questionKey,
    this.hardSkip,
    this.besidePdf = false,
    this.newGroup,
    this.several = const [],
  });

  final RdImportEntry entry;

  /// The sub-folder (version) it lies in.
  final String fassungKey;

  /// Category read from the name.
  final FileCategoryGuess guess;

  /// Question it is part of ([RdImportQuestion.key]).
  final String? questionKey;

  /// Left out whatever is decided (type, size, duplicate).
  final RdSkipReason? hardSkip;

  /// Word/text file with a PDF of the same name next to it.
  final bool besidePdf;

  /// A known instrument without a group in Attendix ("Oboe"): becomes a new
  /// group unless the person decides otherwise.
  final String? newGroup;

  /// The name names two or more instruments ("Posaune und Tuba"): their
  /// groups (or new groups), the file goes to each of them.
  final List<RdImportCategory> several;

  String get path => entry.path;
  String get name => entry.name;

  RdImportCategory get guessed => several.isNotEmpty
      ? RdImportCategory.several(several)
      : guess.instrumentId == null && guess.note == null && newGroup != null
          ? RdImportCategory(newGroup: newGroup)
          : RdImportCategory(instrumentId: guess.instrumentId, note: guess.note);
}

/// A version of a Werk: the files of one sub-folder.
class RdImportFassung {
  const RdImportFassung({required this.key, required this.label, required this.fileCount, this.newest, this.isOld = false});

  final String key;

  /// Folder shown ("Alt", "Dirigenten"); empty = the Werk folder itself.
  final String label;
  final int fileCount;

  /// Newest date of its files (inside the PDFs, else from the ZIP).
  final DateTime? newest;

  /// In a folder like "Alt" or "Alte Version".
  final bool isOld;
}

/// A Werk of the import: one or more folders that belong to the same Werk.
class RdImportWork {
  const RdImportWork({
    required this.key,
    required this.title,
    required this.folders,
    required this.match,
    required this.files,
    this.number,
    this.prefix,
    this.fassungen = const [],
    this.defaultFassung,
  });

  final String key;

  /// Title from the folder name (number taken off).
  final String title;
  final int? number;
  final String? prefix;

  /// Folder paths in the source.
  final List<String> folders;
  final RdWorkMatch match;
  final List<RdImportFile> files;

  /// Two or more competing versions (empty when there is only one).
  final List<RdImportFassung> fassungen;

  /// Proposed version ([RdImportFassung.key]); null = all.
  final String? defaultFassung;

  /// Name in the source ("120 Wie wunderbar").
  String get folderName => folders.isEmpty ? title : folders.first.split('/').last;
}

/// A part name Attendix does not know, asked once for all its files.
class RdImportQuestion {
  const RdImportQuestion({
    required this.key,
    required this.label,
    required this.fileCount,
    required this.works,
    this.files = const [],
    this.suggestion,
    this.newGroup,
    this.several = const [],
  });

  final String key;

  /// As written in the files ("Sax", "фл").
  final String label;
  final int fileCount;

  /// Titles of some Werke it appears in.
  final List<String> works;

  /// Names of some files it appears in ("Sax 1.pdf").
  final List<String> files;

  /// Group the name might mean (unsure match).
  final int? suggestion;

  /// A known instrument without a group: "Neue Gruppe" with this name is
  /// the answer while the person gives none.
  final String? newGroup;

  /// The groups a part for several groups goes to while the person gives no
  /// answer ("Posaune und Tuba", one of them new).
  final List<RdImportCategory> several;

  /// The answer that counts while none is given.
  RdImportCategory? get proposed => several.isNotEmpty
      ? RdImportCategory.several(several)
      : newGroup == null
          ? null
          : RdImportCategory(newGroup: newGroup);
}

class RdImportPlan {
  const RdImportPlan({
    required this.works,
    required this.questions,
    required this.songs,
    required this.instruments,
    required this.junk,
    this.isChoir = false,
    this.newPrefix,
    this.takenNumbers = const {},
    this.pageReads = const {},
  });

  final List<RdImportWork> works;
  final List<RdImportQuestion> questions;

  /// The Werke in Attendix by id.
  final Map<int, RdImportSong> songs;

  /// The groups (without main group).
  final List<InstrumentInfo> instruments;
  final bool isChoir;

  /// System files left out on reading.
  final int junk;

  /// Kürzel of new Werke: the Sammlung's, when the Noten go into one (null:
  /// Repertoire, the folder's own prefix).
  final String? newPrefix;

  /// Numbers in use anywhere in the group ([rdImportNumberKey]), also in
  /// other Sammlungen than [songs].
  final Set<String> takenNumbers;

  /// What the KI read on page 1 of files whose name says no part, by path.
  final Map<String, RdImportPageRead> pageReads;

  int get fileCount => works.fold(0, (sum, w) => sum + w.files.length);

  RdImportWork? work(String key) => works.where((w) => w.key == key).firstOrNull;
}

/// The part the KI read on the first page of a file ([rdImportPagesToRead]).
class RdImportPageRead {
  const RdImportPageRead(this.category, {this.label, this.sure = false});

  final RdImportCategory category;

  /// The part name as printed ("1. Violine").
  final String? label;

  /// Taken without a look; otherwise only proposed and the file stays
  /// "Stimme unklar".
  final bool sure;
}

/// Files of the same size whose content must be compared (hash) to find
/// duplicates.
Set<String> rdImportPathsToHash(List<RdImportEntry> entries) {
  final bySize = <int, List<String>>{};
  for (final e in entries) {
    // Files that are never uploaded are never read.
    if (!rdImportExtensions.contains(e.extension) || e.size > rdMaxUploadBytes) continue;
    bySize.putIfAbsent(e.size, () => []).add(e.path);
  }
  return {for (final list in bySize.values) if (list.length > 1) ...list};
}

/// Files whose date inside the file decides the Fassung (PDFs of Werke with
/// several Fassungen).
Set<String> rdImportPathsToDate(RdImportPlan plan) => {
      for (final w in plan.works)
        if (w.fassungen.length > 1)
          for (final f in w.files)
            if (f.hardSkip == null && f.entry.extension == 'pdf') f.path,
    };

/// Builds the plan: Werk folders, the Werk in Attendix, categories,
/// duplicates (by [hashes]), Fassungen (newest by [dates], the date inside
/// a PDF) and the questions.
/// What [rdBuildImportPlan] reads from the names alone. Kept while files,
/// Werke and groups stay the same: an answer or a change by hand only
/// changes the rest, so the plan is made again in a moment.
class RdImportPlanCache {
  Map<String, String?>? _folders;
  final Map<String, RdWorkMatch> _matches = {};
  final Map<String, ({FileCategoryGuess guess, String? newGroup, List<RdImportCategory> several})> _files = {};
}

/// The part of [e] read from its name (or its folder's), and the new group
/// a known instrument without a group in Attendix becomes ("Oboe").
({FileCategoryGuess guess, String? newGroup, List<RdImportCategory> several}) _readName(
  RdImportEntry e,
  String folder,
  List<InstrumentInfo> instruments,
  bool isChoir,
  Set<String> groupNames,
  String workName,
) {
  var guess = guessFileCategory(e.name, instruments: instruments, isChoir: isChoir);
  // A part named only by its folder ("Violine 1/Seite 1.pdf").
  final byFolderName = e.folders.isNotEmpty && e.folders.join('/') != folder ? '${e.folders.last} ${e.name}' : null;
  if (guess.confidence == MatchConfidence.none && byFolderName != null) {
    final byFolder = guessFileCategory(byFolderName, instruments: instruments, isChoir: isChoir);
    if (byFolder.instrumentId != null || byFolder.note != null) guess = byFolder;
  }
  bool open(FileCategoryGuess g) => g.confidence == MatchConfidence.none && g.instrumentId == null && g.note == null;
  // In a choir every sheet without a group is "Chor"; a voice that has no
  // group yet ("Tenor.pdf") comes first.
  final choirOnly = isChoir &&
      guess.note == kChoirAllNote &&
      open(guessFileCategory(e.name, instruments: instruments, isChoir: false));
  String? newGroup;
  if (open(guess) || choirOnly) {
    newGroup = InstrumentMatcher.knownGroup(e.name, isChoir: isChoir);
    if (newGroup == null && byFolderName != null && !choirOnly) {
      newGroup = InstrumentMatcher.knownGroup(byFolderName, isChoir: isChoir);
    }
    if (newGroup != null && groupNames.contains(newGroup.toLowerCase())) newGroup = null;
    if (newGroup != null && choirOnly) guess = const FileCategoryGuess(instrumentId: null, note: null, confidence: MatchConfidence.none);
  }
  var several = const <RdImportCategory>[];
  // Only the part of the name counts: "Le viole - Vl II.pdf" names no viola.
  final part = rdImportWithoutWorkName(e.name, workName);
  if (newGroup == null && _maybeSeveral(part, guess, instruments, isChoir, choirOnly: choirOnly)) {
    final named = rdImportNamedGroups(part, instruments, isChoir: isChoir);
    if (named.groups.length > 1) {
      if (named.sure) {
        several = named.groups;
      } else if (guess.confidence == MatchConfidence.sure) {
        // An instrument whose group is not sure ("Posaune 1 und Tuba" with
        // only "Posaune 1/2" … ): asked, not taken for one group.
        guess = FileCategoryGuess(instrumentId: guess.instrumentId, note: guess.note, confidence: MatchConfidence.unsure);
      }
    }
  }
  return (guess: guess, newGroup: newGroup, several: several);
}

/// Whether a part named [name] may go to several groups: it names two or
/// more instruments and is not a group of its own ("Posaune/Tuba"), a
/// recording, text or note like Partitur, nor a sheet with three or more
/// choir voices (the choir).
bool _maybeSeveral(String name, FileCategoryGuess guess, List<InstrumentInfo> instruments, bool isChoir, {required bool choirOnly}) {
  final id = guess.instrumentId;
  // In a choir a sheet of voices without groups is "Chor" only for now.
  if (guess.note != null && !choirOnly) return false;
  if (id != null && id <= InstrumentMatcher.lyricsId) return false;
  final named = InstrumentMatcher.knownGroups(name, isChoir: isChoir);
  if (named.length < 2) return false;
  if (isChoir && named.length >= 3 && InstrumentMatcher.knownGroups(name).isEmpty) return false;
  if (id != null && guess.confidence == MatchConfidence.sure) {
    final own = instruments.where((g) => g.id == id).firstOrNull;
    if (own != null && InstrumentMatcher.knownGroups(own.name, isChoir: isChoir).length > 1) return false;
  }
  return true;
}

/// [name] without its file ending and the Werk name [workName] in it ("Le
/// viole - Vl II.pdf" of "Le viole" → "Vl II"), for the instruments it names.
String rdImportWithoutWorkName(String name, String? workName) {
  var stem = name.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '');
  final words = (workName ?? '')
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .map(RegExp.escape)
      .toList();
  if (words.isEmpty) return stem;
  // With the Werk number in front of it ("02 Air Violine und Cello"): no
  // part number.
  stem = stem.replaceAll(
    RegExp('(?:^\\s*\\d+[\\s._\\-]*)?(?<![\\p{L}\\p{N}])${words.join(r'[\s_\-.,]+')}(?![\\p{L}\\p{N}])',
        caseSensitive: false, unicode: true),
    ' ',
  );
  final rest = stem.replaceAll(RegExp(r'^[\s\-–.,()]+|[\s\-–.,()]+$'), '').trim();
  return rest.isEmpty ? name : rest;
}

/// The groups of the instruments [name] names ("Posaune 1 und Tuba"): each
/// matched with its own number where it is written apart, a known
/// instrument without a group as a new group. [sure] is false when a group
/// is not sure (several groups "Posaune 1", "Posaune 2" for "Posaune"); the
/// likely one is in [groups] then.
({List<RdImportCategory> groups, bool sure}) rdImportNamedGroups(
  String name,
  List<InstrumentInfo> instruments, {
  required bool isChoir,
}) {
  final stem = name.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '');
  final pieces = stem.split(RegExp(r'\s+(?:und|u\.?|and|&|\+)\s+|\s*[,;&+]\s*|\s+[-–]\s+', caseSensitive: false));
  final groups = <RdImportCategory>[];
  var sure = true;
  int? group(PartMatch m) => m.instrumentId != null && m.instrumentId! > InstrumentMatcher.lyricsId ? m.instrumentId : null;
  String? missingNumbered(String piece, List<String> names) {
    if (names.length != 1) return null;
    final numbered = InstrumentMatcher.knownGroup(piece, isChoir: isChoir);
    if (numbered == null || numbered == names.single) return null;
    return instruments.any((g) => g.name.trim().toLowerCase() == numbered.toLowerCase()) ? null : numbered;
  }
  for (final piece in pieces) {
    final names = InstrumentMatcher.knownGroups(piece, isChoir: isChoir);
    for (final n in names) {
      // A piece for one instrument is matched with its number ("Posaune 1").
      final own = InstrumentMatcher.detect(names.length == 1 ? piece : n, instruments);
      final byName = names.length == 1 ? InstrumentMatcher.detect(n, instruments) : own;
      final RdImportCategory c;
      if (group(own) != null && own.confidence == MatchConfidence.sure) {
        c = RdImportCategory(instrumentId: group(own));
      } else if (group(byName) != null && byName.confidence == MatchConfidence.sure) {
        c = RdImportCategory(instrumentId: group(byName));
      } else if (group(own) == null && group(byName) == null) {
        // As for one part: "Violine 1" keeps its number.
        c = RdImportCategory(newGroup: names.length == 1 ? InstrumentMatcher.knownGroup(piece, isChoir: isChoir) ?? n : n);
      } else if (missingNumbered(piece, names) case final numbered?) {
        // "Violine 2" named, only "Violine 1" there: a new group, not Violine 1.
        c = RdImportCategory(newGroup: numbered);
      } else {
        sure = false;
        c = RdImportCategory(instrumentId: group(own) ?? group(byName));
      }
      if (!groups.contains(c)) groups.add(c);
    }
  }
  return (groups: groups, sure: sure);
}

RdImportPlan rdBuildImportPlan(
  List<RdImportEntry> entries, {
  required List<RdImportSong> songs,
  required List<InstrumentInfo> instruments,
  required bool isChoir,
  Map<String, String> hashes = const {},
  Map<String, DateTime> dates = const {},
  int junk = 0,
  Map<String, RdImportCategory> answers = const {},
  Map<String, RdImportCategory> categories = const {},
  Map<String, int> aiWorks = const {},
  RdImportPlanCache? cache,
  String? newPrefix,
  Set<String> takenNumbers = const {},
  Map<String, RdImportPageRead> pageReads = const {},
}) {
  final folderOf = cache == null
      ? rdFindWorkFolders(entries, songs: songs, instruments: instruments)
      : cache._folders ??= rdFindWorkFolders(entries, songs: songs, instruments: instruments);
  final groupNames = {for (final g in instruments) g.name.trim().toLowerCase()};

  // Werk folders → Werke (folders of the same Werk in Attendix, or new ones
  // with the same title, are one Werk).
  final byFolder = <String, List<RdImportEntry>>{};
  for (final e in entries) {
    byFolder.putIfAbsent(folderOf[e.path] ?? '', () => []).add(e);
  }
  final groups = <String, ({List<String> folders, RdWorkMatch match, ({String? prefix, int? number, String title}) parsed})>{};
  for (final folder in byFolder.keys) {
    final name = folder.isEmpty ? '' : folder.split('/').last;
    var match = folder.isEmpty
        ? RdWorkMatch.none
        : cache == null
            ? rdMatchWork(name, songs)
            : cache._matches.putIfAbsent(name, () => rdMatchWork(name, songs));
    // The Werk the KI named when the comparison is not sure.
    final hint = aiWorks[name];
    if (hint != null && match.kind != RdMatchKind.sure && songs.any((s) => s.id == hint)) {
      match = RdWorkMatch(RdMatchKind.byAi, hint);
    }
    final parsed = rdParseWorkName(name);
    // Only sure folders of the same Werk are put together; an unsure one
    // ("120 Anderes Lied" next to "120 Wie wunderbar") stays a Werk of its
    // own, to be checked.
    final key = match.songId != null
        ? (match.kind == RdMatchKind.sure ? 'song:${match.songId}' : 'song:${match.songId}~${_folded(name)}')
        : folder.isEmpty
            ? 'loose'
            : 'new:${_folded(parsed.title.isEmpty ? name : parsed.title)}';
    final existing = groups[key];
    if (existing == null) {
      groups[key] = (folders: [folder], match: match, parsed: parsed);
    } else {
      existing.folders.add(folder);
    }
  }

  final works = <RdImportWork>[];
  final questionFiles = <String, List<({RdImportFile file, String work, String? label})>>{};
  for (final entry in groups.entries) {
    final g = entry.value;
    // An unsure Werk shows the folder's name; the target names the Werk.
    final song = g.match.songId == null || g.match.kind != RdMatchKind.sure
        ? null
        : songs.firstWhere((s) => s.id == g.match.songId);
    final title = song?.name ?? (g.parsed.title.isEmpty ? (g.folders.first.split('/').last) : g.parsed.title);
    final parents = {for (final f in g.folders) f.contains('/') ? f.substring(0, f.lastIndexOf('/')) : ''};
    final werkEntries = [for (final f in g.folders) ...byFolder[f]!];

    String fassungKeyOf(RdImportEntry e) {
      final folder = folderOf[e.path] ?? '';
      final depth = folder.isEmpty ? 0 : folder.split('/').length;
      final rel = e.folders.sublist(depth.clamp(0, e.folders.length)).where((s) => !_formatFoldersN.contains(_folded(s))).join('/');
      final parent = folder.contains('/') ? folder.substring(0, folder.lastIndexOf('/')) : '';
      return parents.length > 1 ? '$parent|$rel' : rel;
    }

    String labelOf(String key) {
      final parts = key.split('|');
      final rel = parts.last;
      if (parts.length == 1) return rel;
      final parent = parts.first.isEmpty ? '' : parts.first.split('/').last;
      return [parent, rel].where((s) => s.isNotEmpty).join(' › ');
    }

    // "Alt" is the choir voice, not an old version, only next to other
    // voice folders (Sopran, Tenor …) in the same folder. A lone "Alt"
    // folder stays an old version, also in a choir: when in doubt the Werk
    // is checked.
    Iterable<(String, String)> levels(String key) sync* {
      var start = 0;
      for (final m in RegExp(r'[|/]').allMatches('$key/')) {
        if (m.start > start) yield (key.substring(0, start), key.substring(start, m.start));
        start = m.end;
      }
    }

    final siblings = <String, Set<String>>{};
    for (final e in werkEntries) {
      for (final (parent, name) in levels(fassungKeyOf(e))) {
        siblings.putIfAbsent(parent, () => {}).add(_folded(name));
      }
    }
    bool isVoice(String s) => _voiceFoldersN.contains(s) || _voiceFoldersN.contains(s.split(' ').first);
    bool isOldKey(String key) => levels(key).any(
          (l) => rdImportIsOldFolder(l.$2) && !(_isAltVoice(l.$2) && (siblings[l.$1] ?? const {}).any(isVoice)),
        );

    // Categories and hard reasons.
    final workName = g.parsed.title.isEmpty ? title : g.parsed.title;
    final raw = <RdImportFile>[];
    for (final e in werkEntries) {
      RdSkipReason? hard;
      if (!rdImportExtensions.contains(e.extension)) {
        hard = RdSkipReason.unsupported;
      } else if (e.size > rdMaxUploadBytes) {
        hard = RdSkipReason.tooLarge;
      }
      final read = cache?._files[e.path] ?? _readName(e, folderOf[e.path] ?? '', instruments, isChoir, groupNames, workName);
      cache?._files[e.path] = read;
      raw.add(RdImportFile(
        entry: e,
        fassungKey: fassungKeyOf(e),
        guess: read.guess,
        hardSkip: hard,
        newGroup: hard == null ? read.newGroup : null,
        several: hard == null ? read.several : const [],
      ));
    }

    // Duplicates: same size and content; the copy outside "Alt" folders and
    // with the shorter path is kept.
    final keep = <String, RdImportFile>{};
    final duplicates = <String>{};
    final ordered = [...raw]..sort((a, b) {
        final old = (isOldKey(a.fassungKey) ? 1 : 0) - (isOldKey(b.fassungKey) ? 1 : 0);
        if (old != 0) return old;
        final len = a.path.length - b.path.length;
        return len != 0 ? len : a.path.compareTo(b.path);
      });
    for (final f in ordered) {
      if (f.hardSkip != null) continue;
      final hash = hashes[f.path];
      if (hash == null) continue;
      final id = '${f.entry.size}:$hash';
      if (keep.containsKey(id)) {
        duplicates.add(f.path);
      } else {
        keep[id] = f;
      }
    }

    // Word next to a PDF of the same name.
    String stem(String name) {
      final dot = name.lastIndexOf('.');
      return (dot > 0 ? name.substring(0, dot) : name).toLowerCase();
    }

    final pdfStems = {for (final f in raw) if (f.entry.extension == 'pdf') '${f.entry.folders.join('/')}/${stem(f.name)}'};

    final files = <RdImportFile>[
      for (final f in raw)
        RdImportFile(
          entry: f.entry,
          fassungKey: f.fassungKey,
          guess: f.guess,
          newGroup: f.newGroup,
          several: f.several,
          hardSkip: f.hardSkip ?? (duplicates.contains(f.path) ? RdSkipReason.duplicate : null),
          besidePdf: _textExtensions.contains(f.entry.extension) &&
              pdfStems.contains('${f.entry.folders.join('/')}/${stem(f.name)}'),
          questionKey: f.hardSkip == null &&
                  !duplicates.contains(f.path) &&
                  // A part for several groups is asked about only when it
                  // makes a new group.
                  (f.several.isEmpty
                      ? f.guess.confidence != MatchConfidence.sure
                      : f.several.any((c) => c.newGroup != null)) &&
                  f.entry.extension != 'sib'
              ? rdImportQuestionKey(f.name, workName: workName)
              : null,
        ),
    ];
    files.sort((a, b) => a.path.compareTo(b.path));

    // Fassungen: sub-folders with the same part, or an "Alt" folder next to
    // others. The newest by date is proposed, "Alt" folders never.
    // The parts as decided so far (answers, changes by hand) count.
    final live = files.where((f) => f.hardSkip == null).toList();
    final keys = <String, Set<String>>{};
    for (final f in live) {
      keys.putIfAbsent(f.fassungKey, () => <String>{});
      // A part for several groups counts for each of them.
      for (final c in _decided(f, categories, answers, instruments, title, pageReads, isChoir).each) {
        final clash = rdImportClashKey(c);
        if (clash != null) keys[f.fassungKey]!.add(clash);
      }
    }
    final competing = <String>{};
    final keyList = keys.keys.toList();
    for (var i = 0; i < keyList.length; i++) {
      for (var j = i + 1; j < keyList.length; j++) {
        if (keys[keyList[i]]!.intersection(keys[keyList[j]]!).isNotEmpty) {
          competing
            ..add(keyList[i])
            ..add(keyList[j]);
        }
      }
    }
    if (keyList.length > 1) {
      competing.addAll(keyList.where(isOldKey));
      if (competing.isNotEmpty && competing.every(isOldKey)) {
        // Only "Alt" folders compete: the files outside them are the other side.
        competing.addAll(keyList.where((k) => !isOldKey(k)));
      }
    }
    var fassungen = <RdImportFassung>[];
    String? chosen;
    if (competing.length > 1) {
      DateTime? newest(Iterable<DateTime?> list) =>
          list.whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      DateTime? inFiles(String k) => newest(live.where((f) => f.fassungKey == k).map((f) => dates[f.path]));
      DateTime? inZip(String k) => newest(live.where((f) => f.fassungKey == k).map((f) => f.entry.modified));
      // The dates inside the files when every Fassung has one; the ZIP's
      // dates (upload to Drive) are not comparable with them.
      final byFiles = competing.every((k) => inFiles(k) != null);
      fassungen = [
        for (final k in competing)
          RdImportFassung(
            key: k,
            label: labelOf(k),
            fileCount: live.where((f) => f.fassungKey == k).length,
            newest: byFiles ? inFiles(k) : inZip(k),
            isOld: isOldKey(k),
          ),
      ]..sort((a, b) {
          final old = (a.isOld ? 1 : 0) - (b.isOld ? 1 : 0);
          if (old != 0) return old;
          final da = a.newest;
          final db = b.newest;
          if (da != null && db != null && da != db) return db.compareTo(da);
          if ((da == null) != (db == null)) return da == null ? 1 : -1;
          final count = b.fileCount - a.fileCount;
          return count != 0 ? count : a.label.compareTo(b.label);
        });
      chosen = fassungen.first.key;
    }

    final work = RdImportWork(
      key: entry.key,
      title: title,
      number: song?.number ?? g.parsed.number,
      prefix: song?.prefix ?? g.parsed.prefix,
      folders: g.folders..sort(),
      match: g.match,
      files: files,
      fassungen: fassungen,
      defaultFassung: chosen,
    );
    works.add(work);
    for (final f in files) {
      final key = f.questionKey;
      if (key == null) continue;
      questionFiles.putIfAbsent(key, () => []).add((file: f, work: work.title, label: _questionLabel(f.name, workName: workName)));
    }
  }

  works.sort((a, b) {
    final na = a.number ?? 1 << 30;
    final nb = b.number ?? 1 << 30;
    return na != nb ? na.compareTo(nb) : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  // Questions: names that come up in two or more files, and every known
  // instrument that would become a new group. Other single unknown files
  // are decided in the review of their Werk.
  final questions = <RdImportQuestion>[];
  for (final entry in questionFiles.entries) {
    final list = entry.value;
    final labels = <String, int>{};
    final suggestions = <int, int>{};
    final newGroups = <String, int>{};
    final severals = <RdImportCategory, int>{};
    for (final q in list) {
      final label = q.label;
      if (label != null) labels[label] = (labels[label] ?? 0) + 1;
      final id = q.file.guess.instrumentId;
      if (id != null) suggestions[id] = (suggestions[id] ?? 0) + 1;
      final group = q.file.newGroup;
      if (group != null) newGroups[group] = (newGroups[group] ?? 0) + 1;
      if (q.file.several.isNotEmpty) {
        final c = RdImportCategory.several(q.file.several);
        severals[c] = (severals[c] ?? 0) + 1;
      }
    }
    // A new group is asked about even for one file: it is created on upload.
    if (list.length < 2 && newGroups.isEmpty && severals.isEmpty) continue;
    String top(Map<String, int> counts) => (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final suggestion = suggestions.isEmpty ? null : (suggestions.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    // A part for several groups is the answer only when at least half of
    // the files are one (in any numbers: "Posaune 1 und Tuba" … "Posaune 3
    // und Tuba"): a single "Klavier - Oboe" does not decide for 96 files
    // "Oboe".
    final severalFiles = list.where((q) => q.file.several.isNotEmpty).length;
    final several = severals.isEmpty ? null : (severals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    questions.add(RdImportQuestion(
      key: entry.key,
      label: labels.isEmpty ? entry.key : top(labels),
      fileCount: list.length,
      works: {for (final q in list) q.work}.take(2).toList(),
      files: {for (final q in list) q.file.name}.take(3).toList(),
      suggestion: suggestion,
      newGroup: newGroups.isEmpty ? null : top(newGroups),
      several: several == null || severalFiles * 2 < list.length ? const [] : several.key.groups,
    ));
  }
  questions.sort((a, b) => b.fileCount != a.fileCount ? b.fileCount.compareTo(a.fileCount) : a.label.compareTo(b.label));

  return RdImportPlan(
    works: works,
    questions: questions,
    songs: {for (final s in songs) s.id: s},
    instruments: instruments,
    isChoir: isChoir,
    junk: junk,
    newPrefix: newPrefix,
    takenNumbers: takenNumbers,
    pageReads: pageReads,
  );
}

/// Key of a Werk number for [RdImportPlan.takenNumbers] ("S|12").
String rdImportNumberKey(String? prefix, int number) => '${(prefix ?? '').trim().toUpperCase()}|$number';

// ---------------------------------------------------------------------------
// Decisions and what follows from them

/// Where the files of a Werk go.
class RdWorkTarget {
  const RdWorkTarget.song(int this.songId)
      : name = null,
        number = null,
        prefix = null,
        skip = false;

  const RdWorkTarget.create({required String this.name, this.number, this.prefix})
      : songId = null,
        skip = false;

  const RdWorkTarget.skip()
      : songId = null,
        name = null,
        number = null,
        prefix = null,
        skip = true;

  /// Existing Werk.
  final int? songId;

  /// New Werk.
  final String? name;
  final int? number;
  final String? prefix;
  final bool skip;

  bool get isNew => name != null;

  @override
  bool operator ==(Object other) =>
      other is RdWorkTarget &&
      other.songId == songId &&
      other.name == name &&
      other.number == number &&
      other.prefix == prefix &&
      other.skip == skip;

  @override
  int get hashCode => Object.hash(songId, name, number, prefix, skip);
}

/// What the person decided while checking. Everything not decided follows
/// the plan.
class RdImportDecisions {
  const RdImportDecisions({
    this.targets = const {},
    this.fassungen = const {},
    this.take = const {},
    this.categories = const {},
    this.answers = const {},
    this.confirmed = const {},
    this.recheck = const {},
    this.skipWordBesidePdf = true,
    this.proposeFassung = true,
  });

  /// Werk key → where its files go.
  final Map<String, RdWorkTarget> targets;

  /// Werk key → chosen Fassung key (null = all Fassungen).
  final Map<String, String?> fassungen;

  /// File path → take (true) or leave out (false) by hand.
  final Map<String, bool> take;

  /// File path → category chosen by hand.
  final Map<String, RdImportCategory> categories;

  /// Question key → answer.
  final Map<String, RdImportCategory> answers;

  /// Werke someone looked at ("Passt so").
  final Set<String> confirmed;

  /// Werke whose "Passt so" a later change took back: they wait for
  /// another look, even when nothing is flagged any more.
  final Set<String> recheck;

  /// Switch "Word weglassen, wenn PDF daneben liegt".
  final bool skipWordBesidePdf;

  /// Switch "Neueste Fassung vorschlagen" (off: all Fassungen).
  final bool proposeFassung;

  RdImportDecisions copyWith({
    Map<String, RdWorkTarget>? targets,
    Map<String, String?>? fassungen,
    Map<String, bool>? take,
    Map<String, RdImportCategory>? categories,
    Map<String, RdImportCategory>? answers,
    Set<String>? confirmed,
    Set<String>? recheck,
    bool? skipWordBesidePdf,
    bool? proposeFassung,
  }) =>
      RdImportDecisions(
        targets: targets ?? this.targets,
        fassungen: fassungen ?? this.fassungen,
        take: take ?? this.take,
        categories: categories ?? this.categories,
        answers: answers ?? this.answers,
        confirmed: confirmed ?? this.confirmed,
        recheck: recheck ?? this.recheck,
        skipWordBesidePdf: skipWordBesidePdf ?? this.skipWordBesidePdf,
        proposeFassung: proposeFassung ?? this.proposeFassung,
      );
}

/// Proposed target of [work]: the Werk found, or a new Werk with the folder's
/// number when that number is still free.
RdWorkTarget rdDefaultTarget(RdImportPlan plan, RdImportWork work) {
  final id = work.match.songId;
  if (id != null) return RdWorkTarget.song(id);
  if (work.key == 'loose') return const RdWorkTarget.skip();
  final number = work.number;
  String norm(String? p) => (p ?? '').trim().toUpperCase();
  // In a Sammlung new Werke get its Kürzel.
  String? prefixOf(RdImportWork w) => plan.newPrefix ?? w.prefix;
  final prefix = prefixOf(work);
  final taken = number != null &&
      (plan.takenNumbers.contains(rdImportNumberKey(prefix, number)) ||
          plan.songs.values.any((s) => s.number == number && norm(s.prefix) == norm(prefix)) ||
          plan.works.any((w) =>
              w != work &&
              w.match.songId == null &&
              w.number == number &&
              norm(prefixOf(w)) == norm(prefix) &&
              plan.works.indexOf(w) < plan.works.indexOf(work)));
  return RdWorkTarget.create(name: work.title, number: taken ? null : number, prefix: taken ? plan.newPrefix : prefix);
}

RdWorkTarget rdTargetOf(RdImportPlan plan, RdImportDecisions d, RdImportWork work) =>
    d.targets[work.key] ?? rdDefaultTarget(plan, work);

/// Chosen Fassung of [work]; null = all files.
String? rdFassungOf(RdImportDecisions d, RdImportWork work) {
  if (work.fassungen.length < 2) return null;
  if (d.fassungen.containsKey(work.key)) return d.fassungen[work.key];
  return d.proposeFassung ? work.defaultFassung : null;
}

/// State of one file after all decisions.
class RdFileState {
  const RdFileState({
    required this.take,
    required this.category,
    this.reason,
    this.canToggle = true,
    this.unclear = false,
    this.byHand = false,
    this.pageRead,
  });

  final bool take;
  final RdImportCategory category;

  /// Why it is left out (null when taken).
  final RdSkipReason? reason;

  /// Can be taken / left out by hand.
  final bool canToggle;

  /// Taken, but nobody knows which part it is.
  final bool unclear;

  /// Category chosen by hand or by an answer (remembered as synonym).
  final bool byHand;

  /// The part the KI read on page 1, while nobody chose one ([unclear]
  /// still when it is not sure).
  final RdImportPageRead? pageRead;

  /// [unclear], but the KI proposed the part from page 1: shown as its
  /// proposal to check, not as "Stimme unklar".
  bool get proposedByAi => unclear && pageRead != null;
}

RdImportCategory _categoryOf(RdImportPlan plan, RdImportDecisions d, RdImportFile f, RdImportWork work) =>
    _decided(f, d.categories, d.answers, plan.instruments, work.title, plan.pageReads, plan.isChoir);

/// The part of [f]: chosen by hand, else the answer to its question (with
/// the file's own part number), else what the KI read on page 1, else the
/// guess.
RdImportCategory _decided(
  RdImportFile f,
  Map<String, RdImportCategory> categories,
  Map<String, RdImportCategory> answers,
  List<InstrumentInfo> instruments,
  String workTitle,
  Map<String, RdImportPageRead> pageReads,
  bool isChoir,
) {
  final own = categories[f.path];
  if (own != null) return own;
  final answer = f.questionKey == null ? null : answers[f.questionKey];
  if (answer != null) {
    final id = answer.instrumentId;
    if (id != null && id > InstrumentMatcher.lyricsId) {
      return RdImportCategory(instrumentId: rdImportSiblingGroup(id, f.name, instruments, workName: workTitle));
    }
    if (answer.isSeveral) return _severalOf(answer, f, instruments, isChoir, workTitle);
    return answer;
  }
  return pageReads[f.path]?.category ?? f.guessed;
}

/// An answer for several groups as file [f] has it: one answer is given for
/// "Posaune 1 und Tuba" and "Posaune 2 und Tuba", so a group of the same
/// instrument that the file's own name gives for sure ("Posaune 2", "Violine
/// 2 (neu)") takes the place of the answer's.
RdImportCategory _severalOf(
  RdImportCategory answer,
  RdImportFile f,
  List<InstrumentInfo> instruments,
  bool isChoir,
  String workTitle,
) {
  var own = f.several;
  if (own.isEmpty) {
    final named = rdImportNamedGroups(rdImportWithoutWorkName(f.name, workTitle), instruments, isChoir: isChoir);
    if (named.sure) own = named.groups;
  }
  if (own.isEmpty) return answer;
  String? instrument(RdImportCategory c) {
    final name = c.newGroup ?? instruments.where((g) => g.id == c.instrumentId).firstOrNull?.name;
    final known = name == null ? const <String>[] : InstrumentMatcher.knownGroups(name, isChoir: isChoir);
    return known.length == 1 ? known.single : null;
  }

  final mine = <String, RdImportCategory>{
    for (final c in own)
      if (instrument(c) case final k?) k: c,
  };
  final groups = <RdImportCategory>[];
  for (final c in answer.groups) {
    final k = instrument(c);
    final g = (k == null ? null : mine[k]) ?? c;
    if (!groups.contains(g)) groups.add(g);
  }
  return groups.length > 1 ? RdImportCategory.several(groups) : groups.single;
}

RdFileState rdFileState(RdImportPlan plan, RdImportDecisions d, RdImportWork work, RdImportFile f) {
  final category = _categoryOf(plan, d, f, work);
  final byHand = d.categories.containsKey(f.path) || (f.questionKey != null && d.answers.containsKey(f.questionKey));
  if (f.hardSkip != null) return RdFileState(take: false, category: category, reason: f.hardSkip, canToggle: false);
  final target = rdTargetOf(plan, d, work);
  if (target.skip) return RdFileState(take: false, category: category, reason: RdSkipReason.workSkipped, canToggle: false);

  RdSkipReason? reason;
  final fassung = rdFassungOf(d, work);
  final song = target.songId == null ? null : plan.songs[target.songId];
  final otherFassung = fassung != null &&
      f.fassungKey != fassung &&
      work.fassungen.any((x) => x.key == f.fassungKey) &&
      // Lyrics fit every Fassung: kept while the chosen one has none.
      (category.instrumentId != InstrumentMatcher.lyricsId ||
          work.files.any((x) =>
              x.fassungKey == fassung &&
              x.hardSkip == null &&
              _categoryOf(plan, d, x, work).instrumentId == InstrumentMatcher.lyricsId));
  if (otherFassung) {
    reason = RdSkipReason.otherFassung;
  } else if (song != null && _sameName(song, f.name, category)) {
    reason = RdSkipReason.sameName;
  } else if (d.skipWordBesidePdf && f.besidePdf) {
    reason = RdSkipReason.wordNextToPdf;
  } else if (song != null && category.each.every((c) => _atSong(song, c))) {
    // A part for several groups is left out only when every group has it.
    reason = RdSkipReason.partExists;
  }
  final manual = d.take[f.path];
  final take = manual ?? reason == null;
  final pageRead = byHand ? null : plan.pageReads[f.path];
  final unclear =
      take && !byHand && f.guess.confidence != MatchConfidence.sure && f.newGroup == null && f.several.isEmpty && !(pageRead?.sure ?? false);
  return RdFileState(
    take: take,
    category: category,
    reason: take ? null : (manual == false ? RdSkipReason.byHand : reason),
    unclear: unclear,
    byHand: byHand,
    pageRead: pageRead,
  );
}

/// Why a Werk needs a look before it is uploaded.
enum RdWorkFlag {
  /// The Werk in Attendix is not sure.
  unsureMatch,

  /// Two or more Fassungen.
  fassungen,

  /// Parts it would add are already at the Werk.
  partExists,

  /// Files without a clear part.
  unclear,

  /// Files with a part the KI proposed from page 1, not sure enough to be
  /// taken without a look.
  aiProposal,
}

class RdWorkState {
  const RdWorkState({
    required this.target,
    required this.files,
    required this.flags,
    required this.confirmed,
    this.recheck = false,
  });

  final RdWorkTarget target;
  final Map<String, RdFileState> files;
  final Set<RdWorkFlag> flags;
  final bool confirmed;

  /// Its "Passt so" was taken back by a change ([RdImportDecisions.recheck]).
  final bool recheck;

  int get takeCount => files.values.where((f) => f.take).length;
  int get skipCount => files.length - takeCount;

  /// Waits for someone to look at it ("bitte prüfen"): flagged and not
  /// confirmed, or changed since it was.
  bool get open => !confirmed && !target.skip && (flags.isNotEmpty || recheck);

  /// Its files are uploaded.
  bool get ready => !open && !target.skip && takeCount > 0;
}

RdWorkState rdWorkState(RdImportPlan plan, RdImportDecisions d, RdImportWork work) {
  final target = rdTargetOf(plan, d, work);
  final files = {for (final f in work.files) f.path: rdFileState(plan, d, work, f)};
  final flags = <RdWorkFlag>{
    if (!d.targets.containsKey(work.key) && work.match.kind != RdMatchKind.sure && work.match.songId != null) RdWorkFlag.unsureMatch,
    if (work.fassungen.length > 1) RdWorkFlag.fassungen,
    if (files.values.any((f) => f.reason == RdSkipReason.partExists)) RdWorkFlag.partExists,
    if (files.values.any((f) => f.unclear && !f.proposedByAi)) RdWorkFlag.unclear,
    if (files.values.any((f) => f.proposedByAi)) RdWorkFlag.aiProposal,
  };
  return RdWorkState(
    target: target,
    files: files,
    flags: flags,
    confirmed: d.confirmed.contains(work.key),
    recheck: d.recheck.contains(work.key),
  );
}

/// What a Werk shows and will upload, as one text: target, Fassung, flags
/// and every file taken with its part. "Passt so" holds for this selection
/// only; when it changes (an answer, a category, a Fassung that shows only
/// then, dates read later) the Werk has to be checked again.
String rdWorkSelection(RdImportPlan plan, RdImportDecisions d, RdImportWork work) {
  final s = rdWorkState(plan, d, work);
  final t = s.target;
  String category(RdImportCategory c) =>
      c.isSeveral ? '[${c.groups.map(category).join(',')}]' : '${c.instrumentId}|${c.note}|${c.newGroup}';
  return [
    'target ${t.skip}|${t.songId}|${t.prefix}|${t.number}|${t.name}',
    'fassung ${rdFassungOf(d, work)}',
    'flags ${(s.flags.map((f) => f.name).toList()..sort()).join(',')}',
    for (final f in work.files)
      if (s.files[f.path]!.take) 'file ${f.path} ${category(s.files[f.path]!.category)}',
  ].join('\n');
}

/// Counts for the overview and the upload button.
class RdImportSummary {
  const RdImportSummary({
    required this.works,
    required this.open,
    required this.ready,
    required this.newWorks,
    required this.skippedWorks,
    required this.take,
    required this.skip,
    required this.openQuestions,
  });

  final int works;

  /// Werke waiting for a look.
  final int open;

  /// Werke whose files are uploaded.
  final int ready;

  /// Of [ready]: new Werke.
  final int newWorks;
  final int skippedWorks;

  /// Files uploaded (of [ready] Werke).
  final int take;

  /// Files left out (all reasons, without files of open Werke).
  final int skip;
  final int openQuestions;
}

RdImportSummary rdImportSummary(RdImportPlan plan, RdImportDecisions d) {
  var open = 0, ready = 0, newWorks = 0, skippedWorks = 0, take = 0, skip = 0;
  for (final w in plan.works) {
    final s = rdWorkState(plan, d, w);
    if (s.target.skip) {
      skippedWorks++;
      skip += s.files.length;
    } else if (s.open) {
      open++;
    } else {
      if (s.takeCount > 0) {
        ready++;
        if (s.target.isNew) newWorks++;
      }
      take += s.takeCount;
      skip += s.skipCount;
    }
  }
  return RdImportSummary(
    works: plan.works.length,
    open: open,
    ready: ready,
    newWorks: newWorks,
    skippedWorks: skippedWorks,
    take: take,
    skip: skip,
    openQuestions: plan.questions.where((q) => !d.answers.containsKey(q.key)).length,
  );
}

/// One file to upload.
class RdUploadItem {
  RdUploadItem({required this.work, required this.file, required this.category, List<RdImportCategory>? stores})
      : stores = stores ?? category.each;

  final RdImportWork work;
  final RdImportFile file;
  final RdImportCategory category;

  /// What the file is stored as: once, or once per group of a part for
  /// several groups (without the groups the Werk already has the part of).
  final List<RdImportCategory> stores;
}

/// Files of the ready Werke, Werk by Werk.
List<RdUploadItem> rdImportUploads(RdImportPlan plan, RdImportDecisions d) => [
      for (final w in plan.works)
        for (final s in [rdWorkState(plan, d, w)])
          if (s.ready)
            for (final f in w.files)
              if (s.files[f.path]!.take)
                RdUploadItem(
                  work: w,
                  file: f,
                  category: s.files[f.path]!.category,
                  stores: _toStore(s.files[f.path]!.category, plan.songs[s.target.songId]),
                ),
    ];

/// The groups a part for several groups still lacks at [song]; all of them
/// when it lacks none (taken by hand) or the Werk is new.
List<RdImportCategory> _toStore(RdImportCategory c, RdImportSong? song) {
  if (!c.isSeveral || song == null) return c.each;
  final missing = [for (final g in c.groups) if (!_atSong(song, g)) g];
  return missing.isEmpty ? c.groups : missing;
}

/// Group names to create (answers and choices "Neue Gruppe anlegen") used by
/// [items].
List<String> rdImportNewGroups(List<RdUploadItem> items) => {
      for (final i in items)
        for (final c in i.stores)
          if (c.newGroup != null) c.newGroup!,
    }.toList();

/// The folder names of Werke the comparison is not sure about (new, only
/// the number fits, several fit), to ask the KI about ([rdBuildImportPlan]
/// `aiWorks`).
List<String> rdImportWorksToAsk(RdImportPlan plan) => {
      for (final w in plan.works)
        if (w.match.kind != RdMatchKind.sure && w.match.kind != RdMatchKind.byAi && plan.songs.isNotEmpty)
          for (final f in w.folders)
            if (f.isNotEmpty) f.split('/').last,
    }.toList();

/// Werke whose key changed from [before] to [after], old key → new key: the
/// KI's hint came or went, so "new:…" became "song:…~…" or back. What the
/// person decided about such a Werk stays with its folder.
Map<String, String> rdImportMovedWorks(RdImportPlan before, RdImportPlan after) {
  final oldKeyOf = {
    for (final w in before.works)
      for (final f in w.folders) f: w.key,
  };
  final oldKeys = {for (final w in before.works) w.key};
  final newKeys = {for (final w in after.works) w.key};
  final moved = <String, String>{};
  final split = <String>{};
  for (final w in after.works) {
    if (oldKeys.contains(w.key)) continue;
    final olds = {
      for (final f in w.folders)
        if (oldKeyOf[f] case final k? when !newKeys.contains(k)) k,
    };
    if (olds.length != 1) continue;
    // One old Werk now in two: nothing is carried over.
    if (moved.containsKey(olds.single)) split.add(olds.single);
    moved[olds.single] = w.key;
  }
  return moved..removeWhere((k, _) => split.contains(k));
}

/// Files whose part nobody knows yet and the KI did not read: their first
/// page is read ([RdImportPageRead]), in the order of the Werke. Werke with
/// "Passt so" stay as they were confirmed.
List<String> rdImportPagesToRead(RdImportPlan plan, RdImportDecisions d) => [
      for (final w in plan.works)
        if (!d.confirmed.contains(w.key))
          for (final e in rdWorkState(plan, d, w).files.entries)
            if (e.value.unclear && e.value.pageRead == null && !plan.pageReads.containsKey(e.key)) e.key,
    ];

/// The new groups the files go to as decided so far, to pick them for other
/// files too before they exist ("Neue Gruppe: Oboe").
List<String> rdImportPendingGroups(RdImportPlan plan, RdImportDecisions d) {
  final existing = {for (final g in plan.instruments) g.name.trim().toLowerCase()};
  final names = <String, String>{};
  for (final work in plan.works) {
    for (final f in work.files) {
      if (f.hardSkip != null) continue;
      for (final c in _decided(f, d.categories, d.answers, plan.instruments, work.title, plan.pageReads, plan.isChoir).each) {
        final name = c.newGroup;
        if (name == null || existing.contains(name.trim().toLowerCase())) continue;
        names.putIfAbsent(name.trim().toLowerCase(), () => name);
      }
    }
  }
  return names.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Terms to remember as synonyms: the part names of files whose group was
/// chosen by hand or by an answer ("künftig so erkennen"). [groupIds] maps
/// new group names to their ids; [instruments] includes the new groups.
Map<int, List<String>> rdImportLearnedTerms(
  RdImportPlan plan,
  RdImportDecisions d,
  List<RdUploadItem> items, {
  required List<InstrumentInfo> instruments,
  Map<String, int> groupIds = const {},
}) {
  final terms = <int, Set<String>>{};
  for (final i in items) {
    final byHand = d.categories.containsKey(i.file.path) || (i.file.questionKey != null && d.answers.containsKey(i.file.questionKey));
    if (!byHand) continue;
    // "Posaune und Tuba" is never a term of one group.
    if (InstrumentMatcher.knownGroups(i.file.name, isChoir: plan.isChoir).length > 1) continue;
    final id = i.category.newGroup != null ? groupIds[i.category.newGroup] : i.category.instrumentId;
    if (id == null) continue;
    final term = learnableTerm(i.file.name, chosenId: id, instruments: instruments, workName: i.work.title);
    if (term == null) continue;
    terms.putIfAbsent(id, () => <String>{}).add(term);
  }
  return {for (final e in terms.entries) e.key: e.value.toList()..sort()};
}

/// Date inside a PDF: the creation date (when the notes were exported),
/// else the date of the last change. Read from the document info or the
/// XMP metadata; null when the file has neither.
DateTime? rdPdfDate(List<int> bytes) {
  // The dates sit at the start or the end of the file.
  const window = 256 * 1024;
  String latin(List<int> part) => String.fromCharCodes(part);
  final head = latin(bytes.length <= window * 2 ? bytes : bytes.sublist(0, window));
  final tail = bytes.length <= window * 2 ? '' : latin(bytes.sublist(bytes.length - window));
  final text = '$head\n$tail';
  DateTime? info(String key) {
    final m = RegExp('/$key\\s*\\(D:(\\d{4})(\\d{2})?(\\d{2})?(\\d{2})?(\\d{2})?').firstMatch(text);
    if (m == null) return null;
    return _date(m[1], m[2], m[3], m[4], m[5]);
  }

  DateTime? xmp(String key) {
    final m = RegExp('$key>\\s*(\\d{4})-(\\d{2})-(\\d{2})(?:T(\\d{2}):(\\d{2}))?').firstMatch(text) ??
        RegExp('$key="(\\d{4})-(\\d{2})-(\\d{2})(?:T(\\d{2}):(\\d{2}))?').firstMatch(text);
    if (m == null) return null;
    return _date(m[1], m[2], m[3], m[4], m[5]);
  }

  return info('CreationDate') ?? xmp('xmp:CreateDate') ?? info('ModDate') ?? xmp('xmp:ModifyDate');
}

DateTime? _date(String? y, String? mo, String? d, String? h, String? mi) {
  final year = int.tryParse(y ?? '');
  if (year == null || year < 1980 || year > 2100) return null;
  int part(String? s, int fallback, int max) {
    final v = int.tryParse(s ?? '');
    return v == null || v < 0 || v > max ? fallback : v;
  }

  return DateTime(year, part(mo, 1, 12).clamp(1, 12), part(d, 1, 31).clamp(1, 31), part(h, 0, 23), part(mi, 0, 59));
}

/// Date of a ZIP entry (MS-DOS date and time as stored by the archive).
DateTime? rdZipDate(int dosDateTime) {
  final date = dosDateTime >> 16;
  final time = dosDateTime & 0xffff;
  final year = ((date >> 9) & 0x7f) + 1980;
  final month = (date >> 5) & 0x0f;
  final day = date & 0x1f;
  if (date == 0 || month < 1 || month > 12 || day < 1) return null;
  return DateTime(year, month, day, (time >> 11) & 0x1f, (time >> 5) & 0x3f, (time & 0x1f) * 2);
}

/// Questions about names that most likely mean the same ([category]: the
/// answer, the KI's answer, the proposed new group or the matcher's guess;
/// null when nobody has a guess), to answer many with one tap ("Alle als
/// Trompete").
class RdImportQuestionGroup {
  const RdImportQuestionGroup(this.category, this.questions);

  final RdImportCategory? category;
  final List<RdImportQuestion> questions;

  int get fileCount => questions.fold(0, (n, q) => n + q.fileCount);
}

/// [questions] by what they most likely mean: the answer given ([answers],
/// also the ones the KI filled in), the KI's answer ([ai]), the proposed
/// new group, the matcher's guess. The group without a guess comes first,
/// then the ones with the most files. An answered question goes to the
/// group of its answer, so "Alle als …" never takes another one.
List<RdImportQuestionGroup> rdImportQuestionGroups(
  List<RdImportQuestion> questions, {
  Map<String, RdImportCategory> answers = const {},
  Map<String, RdImportCategory> ai = const {},
}) {
  final byCategory = <RdImportCategory?, List<RdImportQuestion>>{};
  for (final q in questions) {
    final guess = answers[q.key] ??
        ai[q.key] ??
        q.proposed ??
        (q.suggestion == null ? null : RdImportCategory(instrumentId: q.suggestion));
    byCategory.putIfAbsent(guess, () => []).add(q);
  }
  final groups = [for (final e in byCategory.entries) RdImportQuestionGroup(e.key, e.value)];
  int rank(RdImportQuestionGroup g) => g.category == null ? 0 : 1;
  groups.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : b.fileCount.compareTo(a.fileCount));
  return groups;
}
