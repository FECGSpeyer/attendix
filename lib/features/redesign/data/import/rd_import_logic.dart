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
  s = out.toString().replaceAll(RegExp('[̀-ͯ]'), '');
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
      .replaceAllMapped(RegExp(r'(\p{L})\1+', unicode: true), (m) => m[1]!);
  return [for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(s)) m[0]!];
}

/// How alike two titles are, 0 to 1 (shared words, Dice).
double rdImportTitleSimilarity(String a, String b) {
  final wa = rdImportTitleWords(a).toSet();
  final wb = rdImportTitleWords(b).toSet();
  if (wa.isEmpty || wb.isEmpty) return 0;
  return 2 * wa.intersection(wb).length / (wa.length + wb.length);
}

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
  // The best fitting song; [tie] when another one fits as well.
  ({RdImportSong song, double sim, bool tie})? bestOf(Iterable<RdImportSong> candidates, String title) {
    final scored = [for (final s in candidates) (song: s, sim: rdImportTitleSimilarity(title, s.name))]
      ..sort((a, b) => b.sim.compareTo(a.sim));
    if (scored.isEmpty) return null;
    final best = scored.first;
    final tie = scored.length > 1 && scored[1].sim >= best.sim - 0.02;
    return (song: best.song, sim: best.sim, tie: tie);
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
      if (!hasTitle || best.sim >= 0.4) {
        // Without a title, or two Werke with this number fitting as well.
        final ambiguous = candidates.length > 1 && (!hasTitle || best.tie);
        return RdWorkMatch(ambiguous ? RdMatchKind.ambiguous : RdMatchKind.sure, best.song.id);
      }
      final byTitle = bestOf(songs, parsed.title);
      if (byTitle != null && byTitle.sim >= 0.75) {
        return RdWorkMatch(byTitle.tie ? RdMatchKind.ambiguous : RdMatchKind.titleOnly, byTitle.song.id);
      }
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
    if (match.instrumentId != null && match.confidence == MatchConfidence.sure) return true;
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
  var root = 0;
  final first = entries.first.folders;
  while (root < first.length) {
    final seg = first[root];
    final shared = entries.every((e) {
      final f = e.folders;
      return f.length > root + 1 && f[root] == seg;
    });
    if (!shared || _looksLikeWork(seg, songs)) break;
    if (entries.any((e) => _isStructural(e.folders[root + 1], instruments))) break;
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

  final structural = <String, bool>{};
  bool isStructural(String seg) => structural.putIfAbsent(seg, () => _isStructural(seg, instruments));
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
  const RdImportCategory({this.instrumentId, this.note, this.newGroup});

  static const RdImportCategory other = RdImportCategory();

  final int? instrumentId;
  final String? note;

  /// Name of a group created on upload ("Neue Gruppe anlegen").
  final String? newGroup;

  bool get isPart => newGroup != null || (instrumentId != null && instrumentId! > InstrumentMatcher.lyricsId);

  @override
  bool operator ==(Object other) =>
      other is RdImportCategory && other.instrumentId == instrumentId && other.note == note && other.newGroup == newGroup;

  @override
  int get hashCode => Object.hash(instrumentId, note, newGroup);
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

  String get path => entry.path;
  String get name => entry.name;

  RdImportCategory get guessed =>
      RdImportCategory(instrumentId: guess.instrumentId, note: guess.note);
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
}

class RdImportPlan {
  const RdImportPlan({
    required this.works,
    required this.questions,
    required this.songs,
    required this.instruments,
    required this.junk,
    this.isChoir = false,
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

  int get fileCount => works.fold(0, (sum, w) => sum + w.files.length);

  RdImportWork? work(String key) => works.where((w) => w.key == key).firstOrNull;
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
}) {
  final folderOf = rdFindWorkFolders(entries, songs: songs, instruments: instruments);

  // Werk folders → Werke (folders of the same Werk in Attendix, or new ones
  // with the same title, are one Werk).
  final byFolder = <String, List<RdImportEntry>>{};
  for (final e in entries) {
    byFolder.putIfAbsent(folderOf[e.path] ?? '', () => []).add(e);
  }
  final groups = <String, ({List<String> folders, RdWorkMatch match, ({String? prefix, int? number, String title}) parsed})>{};
  for (final folder in byFolder.keys) {
    final name = folder.isEmpty ? '' : folder.split('/').last;
    final match = folder.isEmpty ? RdWorkMatch.none : rdMatchWork(name, songs);
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

    bool isOldKey(String key) => key.split(RegExp(r'[|/]')).any(rdImportIsOldFolder);

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
      var guess = guessFileCategory(e.name, instruments: instruments, isChoir: isChoir);
      // A part named only by its folder ("Violine 1/Seite 1.pdf").
      final folder = folderOf[e.path] ?? '';
      if (guess.confidence == MatchConfidence.none && e.folders.isNotEmpty && e.folders.join('/') != folder) {
        final byFolder = guessFileCategory('${e.folders.last} ${e.name}', instruments: instruments, isChoir: isChoir);
        if (byFolder.instrumentId != null || byFolder.note != null) guess = byFolder;
      }
      raw.add(RdImportFile(entry: e, fassungKey: fassungKeyOf(e), guess: guess, hardSkip: hard));
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
          hardSkip: f.hardSkip ?? (duplicates.contains(f.path) ? RdSkipReason.duplicate : null),
          besidePdf: _textExtensions.contains(f.entry.extension) &&
              pdfStems.contains('${f.entry.folders.join('/')}/${stem(f.name)}'),
          questionKey: f.hardSkip == null &&
                  !duplicates.contains(f.path) &&
                  f.guess.confidence != MatchConfidence.sure &&
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
      final clash = rdImportClashKey(_decided(f, categories, answers, instruments, title));
      keys.putIfAbsent(f.fassungKey, () => <String>{});
      if (clash != null) keys[f.fassungKey]!.add(clash);
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

  // Questions: names that come up in two or more files. Single unknown
  // files are decided in the review of their Werk.
  final questions = <RdImportQuestion>[];
  for (final entry in questionFiles.entries) {
    final list = entry.value;
    if (list.length < 2) continue;
    final labels = <String, int>{};
    final suggestions = <int, int>{};
    for (final q in list) {
      final label = q.label;
      if (label != null) labels[label] = (labels[label] ?? 0) + 1;
      final id = q.file.guess.instrumentId;
      if (id != null) suggestions[id] = (suggestions[id] ?? 0) + 1;
    }
    String top(Map<String, int> counts) => (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final suggestion = suggestions.isEmpty ? null : (suggestions.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    questions.add(RdImportQuestion(
      key: entry.key,
      label: labels.isEmpty ? entry.key : top(labels),
      fileCount: list.length,
      works: {for (final q in list) q.work}.take(2).toList(),
      files: {for (final q in list) q.file.name}.take(3).toList(),
      suggestion: suggestion,
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
  );
}

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
  final taken = number != null &&
      (plan.songs.values.any((s) => s.number == number && norm(s.prefix) == norm(work.prefix)) ||
          plan.works.any((w) =>
              w != work &&
              w.match.songId == null &&
              w.number == number &&
              norm(w.prefix) == norm(work.prefix) &&
              plan.works.indexOf(w) < plan.works.indexOf(work)));
  return RdWorkTarget.create(name: work.title, number: taken ? null : number, prefix: taken ? null : work.prefix);
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
}

RdImportCategory _categoryOf(RdImportDecisions d, RdImportFile f, RdImportWork work, List<InstrumentInfo> instruments) =>
    _decided(f, d.categories, d.answers, instruments, work.title);

/// The part of [f]: chosen by hand, else the answer to its question (with
/// the file's own part number), else the guess.
RdImportCategory _decided(
  RdImportFile f,
  Map<String, RdImportCategory> categories,
  Map<String, RdImportCategory> answers,
  List<InstrumentInfo> instruments,
  String workTitle,
) {
  final own = categories[f.path];
  if (own != null) return own;
  final answer = f.questionKey == null ? null : answers[f.questionKey];
  if (answer != null) {
    final id = answer.instrumentId;
    if (id != null && id > InstrumentMatcher.lyricsId) {
      return RdImportCategory(instrumentId: rdImportSiblingGroup(id, f.name, instruments, workName: workTitle));
    }
    return answer;
  }
  return f.guessed;
}

RdFileState rdFileState(RdImportPlan plan, RdImportDecisions d, RdImportWork work, RdImportFile f) {
  final category = _categoryOf(d, f, work, plan.instruments);
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
              _categoryOf(d, x, work, plan.instruments).instrumentId == InstrumentMatcher.lyricsId));
  if (otherFassung) {
    reason = RdSkipReason.otherFassung;
  } else if (song != null && song.files.any((x) => x.fileName == f.name)) {
    reason = RdSkipReason.sameName;
  } else if (d.skipWordBesidePdf && f.besidePdf) {
    reason = RdSkipReason.wordNextToPdf;
  } else if (song != null) {
    final clash = rdImportClashKey(category);
    if (clash != null &&
        song.files.any((x) => rdImportClashKey(RdImportCategory(instrumentId: x.instrumentId, note: x.instrumentId == null ? x.note : null)) == clash)) {
      reason = RdSkipReason.partExists;
    }
  }
  final manual = d.take[f.path];
  final take = manual ?? reason == null;
  final unclear = take && !byHand && f.guess.confidence != MatchConfidence.sure;
  return RdFileState(
    take: take,
    category: category,
    reason: take ? null : (manual == false ? RdSkipReason.byHand : reason),
    unclear: unclear,
    byHand: byHand,
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
}

class RdWorkState {
  const RdWorkState({
    required this.target,
    required this.files,
    required this.flags,
    required this.confirmed,
  });

  final RdWorkTarget target;
  final Map<String, RdFileState> files;
  final Set<RdWorkFlag> flags;
  final bool confirmed;

  int get takeCount => files.values.where((f) => f.take).length;
  int get skipCount => files.length - takeCount;

  /// Waits for someone to look at it ("bitte prüfen").
  bool get open => !confirmed && !target.skip && flags.isNotEmpty;

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
    if (files.values.any((f) => f.unclear)) RdWorkFlag.unclear,
  };
  return RdWorkState(target: target, files: files, flags: flags, confirmed: d.confirmed.contains(work.key));
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
  const RdUploadItem({required this.work, required this.file, required this.category});

  final RdImportWork work;
  final RdImportFile file;
  final RdImportCategory category;
}

/// Files of the ready Werke, Werk by Werk.
List<RdUploadItem> rdImportUploads(RdImportPlan plan, RdImportDecisions d) => [
      for (final w in plan.works)
        for (final s in [rdWorkState(plan, d, w)])
          if (s.ready)
            for (final f in w.files)
              if (s.files[f.path]!.take) RdUploadItem(work: w, file: f, category: s.files[f.path]!.category),
    ];

/// Group names to create (answers and choices "Neue Gruppe anlegen") used by
/// [items].
List<String> rdImportNewGroups(List<RdUploadItem> items) => {
      for (final i in items)
        if (i.category.newGroup != null) i.category.newGroup!,
    }.toList();

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
