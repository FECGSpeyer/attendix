part of 'import_logic.dart';

// Junk filtering, title folding & similarity, work folder matching, and PDF/ZIP date parsing.

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
