import '../../l10n/l10n.dart';

/// How sure [InstrumentMatcher.detect] is about a part.
enum MatchConfidence {
  /// Name, synonym or a clear term of the group (incl. matching part number).
  sure,

  /// Something matched, but it is ambiguous (compound word, two groups with
  /// the same score, part number missing, ambiguous abbreviation).
  unsure,

  /// Nothing matched.
  none,
}

/// Result of [InstrumentMatcher.detect].
class PartMatch {
  const PartMatch({required this.instrumentId, required this.confidence, this.term, this.byVision = false});

  static const PartMatch none = PartMatch(instrumentId: null, confidence: MatchConfidence.none);

  final int? instrumentId;
  final MatchConfidence confidence;

  /// The part of the file name the match was based on (for display); for
  /// [byVision] the part name read on the first page.
  final String? term;

  /// Read on the first page by the `part-detect` function, not the name.
  final bool byVision;
}

/// Utility class for matching filenames to instruments / parts.
///
/// Started as a port of Ionic's instrument-matcher.ts (first group with any
/// keyword wins). Now every group is scored and the best, most specific
/// match wins: whole words instead of substrings ("Soundtrack" is no
/// "track"), part numbers ("Violine 2" / "Vl II" is not Violine 1), longer
/// names before shorter ones ("Bassklarinette" is no plain "Klarinette").
class InstrumentMatcher {
  /// Special instrument IDs
  static const int recordingId = 1;
  static const int lyricsId = 2;

  /// Instrument families: key (German, folded) → terms in other languages /
  /// spellings. A group belongs to a family when its name contains the key
  /// as a word or ends with it ("Altsaxophon" → saxophon).
  static const Map<String, List<String>> translations = {
    // Strings
    'violine': ['violin', 'violins', 'geige', 'violino', 'violon', 'скрипка'],
    'viola': ['bratsche', 'alto viola', 'альт'],
    'cello': ['violoncello', 'violoncell', 'violoncelle', 'виолончель'],
    'kontrabass': ['contrabass', 'double bass', 'string bass', 'contrebasse', 'bass', 'контрабас'],

    // Woodwinds
    'piccolo': ['piccoloflöte', 'piccolo flute', 'ottavino'],
    'flöte': ['flute', 'flauto', 'querflöte', 'flote', 'флейта'],
    'oboe': ['hautbois', 'гобой'],
    'englischhorn': ['english horn', 'cor anglais', 'corno inglese'],
    'klarinette': ['clarinet', 'clarinetto', 'clarinette', 'кларнет'],
    'bassklarinette': ['bass clarinet', 'bassclarinet', 'clarinetto basso', 'clarinette basse'],
    'fagott': ['bassoon', 'fagotto', 'basson', 'фагот'],
    'kontrafagott': ['contrabassoon', 'contrafagotto', 'double bassoon'],
    'saxophon': ['saxophone', 'saxofon', 'саксофон'],
    'sopransaxophon': ['soprano sax', 'soprano saxophone', 'sopransax'],
    'altsaxophon': ['alto sax', 'alto saxophone', 'altsax', 'altsaxofon'],
    'tenorsaxophon': ['tenor sax', 'tenor saxophone', 'tenorsax', 'tenorsaxofon'],
    'baritonsaxophon': ['baritone sax', 'baritone saxophone', 'baritonsax', 'baritonsaxofon'],

    // Brass
    'horn': ['french horn', 'corno', 'cor', 'waldhorn', 'валторна'],
    'trompete': ['trumpet', 'tromba', 'trompette', 'труба'],
    'flügelhorn': ['flugelhorn', 'flicorno'],
    'kornett': ['cornet', 'cornetto'],
    'posaune': ['trombone', 'trombon', 'тромбон'],
    'bassposaune': ['bass trombone', 'basstrombone'],
    'tenorhorn': ['tenor horn'],
    'euphonium': ['bariton', 'baritone', 'baritonhorn', 'eufonium'],
    'tuba': ['basstuba', 'туба'],

    // Percussion
    'schlagzeug': ['percussion', 'drums', 'drum set', 'drumset', 'batterie', 'schlagwerk', 'перкуссия'],
    'pauke': ['timpani', 'pauken', 'kettledrum', 'timbales', 'литавры'],
    'glockenspiel': ['mallets', 'xylophon', 'xylophone', 'vibraphon', 'vibraphone', 'marimba'],

    // Keyboard
    'klavier': ['piano', 'pianoforte', 'flügel', 'фортепиано', 'пианино'],
    'orgel': ['organ', 'organo', 'orgue', 'орган'],
    'cembalo': ['harpsichord', 'clavecin', 'клавесин'],
    'keyboard': ['keys', 'synth', 'synthesizer'],

    // Other
    'harfe': ['harp', 'arpa', 'harpe', 'арфа'],
    'gitarre': ['guitar', 'chitarra', 'guitare', 'гитара'],
    'e-bass': ['ebass', 'bass guitar', 'electric bass', 'bassgitarre'],

    // Choir voices
    'sopran': ['soprano', 'сопрано'],
    'alt': ['alto', 'альт'],
    'tenor': ['tenore', 'тенор'],
    'bass': ['basso', 'бас'],

    // Special
    'partitur': ['score', 'full score', 'conductor', 'direktion', 'dirigent', 'партитура'],
    'stimmen': ['parts', 'voices', 'parti', 'голоса'],
  };

  /// Abbreviations mapping (whole words only).
  static const Map<String, List<String>> abbreviations = {
    'violine': ['vl', 'vln', 'vi', 'viol', 'vn', 'vni'],
    'viola': ['va', 'vla', 'br', 'vle'],
    'cello': ['vc', 'vlc', 'vcl', 'vcs'],
    'kontrabass': ['kb', 'cb', 'db'],
    'piccolo': ['picc', 'pic'],
    'flöte': ['fl', 'flt', 'fls'],
    'oboe': ['ob', 'obs'],
    'englischhorn': ['eh', 'ca', 'engl hn'],
    'klarinette': ['cl', 'kl', 'clar', 'klar', 'cls'],
    'bassklarinette': ['bcl', 'bkl', 'bass cl', 'bass kl'],
    'fagott': ['fg', 'bn', 'bsn', 'fag'],
    'saxophon': ['sx', 'sax'],
    'altsaxophon': ['asx', 'asax', 'as'],
    'tenorsaxophon': ['tsx', 'tsax', 'ts'],
    'baritonsaxophon': ['bsx', 'bsax', 'bs'],
    'horn': ['hr', 'hn', 'hrn', 'hns'],
    'trompete': ['tr', 'tp', 'trp', 'tpt', 'trpt'],
    'flügelhorn': ['flgh', 'flghn', 'flh'],
    'posaune': ['pos', 'tb', 'tbn', 'trb'],
    'tuba': ['tu', 'tba'],
    'euphonium': ['euph', 'bar'],
    'schlagzeug': ['perc', 'schlg', 'drs', 'dr'],
    'pauke': ['timp', 'pk', 'pauk'],
    'glockenspiel': ['glsp', 'glock', 'xyl', 'vib'],
    'klavier': ['pf', 'pno', 'kl'],
    'orgel': ['org'],
    'harfe': ['hp', 'hrf', 'hfe'],
    'gitarre': ['gt', 'gtr', 'git'],
    'sopran': ['sop'],
    'tenor': ['ten'],
    'partitur': ['dir', 'cond'],
  };

  /// Terms that also mean something else: a match on them is only "unsure".
  static const Set<String> _ambiguousTerms = {'bass', 'kl', 'bariton', 'baritone', 'cor', 'as', 'bs', 'ts', 'bar', 'dr', 'alto'};

  /// Words that only describe the tuning ("Klarinette in B", "Horn in F").
  static const Set<String> _tuningWords = {
    'in', 'b', 'bb', 'es', 'eb', 'f', 'c', 'd', 'a', 'g', 'e', 'as', 'des', 'ges',
    'sib', 'mib', 'fa', 'do', 'flat', 'sharp', 'dur', 'moll',
  };

  /// Words after a number that make it a movement / Werk number.
  static const Set<String> _movementWords = {
    'satz', 'saetze', 'movement', 'mvt', 'mov', 'mvmt', 'teil', 'akt', 'act', 'szene', 'scene',
  };

  /// Roman numeral patterns
  static const Map<String, int> romanNumerals = {
    'i': 1,
    'ii': 2,
    'iii': 3,
    'iv': 4,
    'v': 5,
  };

  /// Audio file extensions that indicate recordings
  static const List<String> audioExtensions = [
    'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma'
  ];

  /// Keywords that indicate lyrics/text (whole words)
  static const List<String> lyricsKeywords = [
    'text', 'texte', 'lyrics', 'liedtext', 'songtext', 'words', 'parole',
    'текст', 'слова'
  ];

  /// Keywords that indicate recordings (whole words, not for PDFs)
  static const List<String> recordingKeywords = [
    'aufnahme', 'recording', 'audio', 'track', 'запись',
    'registrazione', 'enregistrement'
  ];

  /// Try to match a filename to an instrument
  /// Returns the instrument ID if found, null otherwise
  static int? matchInstrument(String filename, List<InstrumentInfo> instruments) =>
      detect(filename, instruments).instrumentId;

  /// Scores every group against [filename] and returns the best one with
  /// how sure the match is.
  static PartMatch detect(String filename, List<InstrumentInfo> instruments) {
    final extension = _getExtension(filename).toLowerCase();
    if (audioExtensions.contains(extension)) {
      return const PartMatch(instrumentId: recordingId, confidence: MatchConfidence.sure);
    }

    final words = _words(_stripExtension(filename));
    final tokens = words.tokens;
    if (tokens.isEmpty) return PartMatch.none;

    if (extension != 'pdf') {
      final hit = _firstKeyword(tokens, recordingKeywords);
      if (hit != null) {
        return PartMatch(instrumentId: recordingId, confidence: MatchConfidence.sure, term: hit);
      }
    }
    final lyrics = _firstKeyword(tokens, lyricsKeywords);
    if (lyrics != null) {
      return PartMatch(instrumentId: lyricsId, confidence: MatchConfidence.sure, term: lyrics);
    }

    final familySpans = _familySpans(tokens);
    _Hit? best;
    _Hit? second;
    for (final instrument in instruments) {
      final hit = _scoreInstrument(words, instrument, familySpans);
      if (hit == null) continue;
      if (best == null || hit.score > best.score) {
        second = best;
        best = hit;
      } else if (second == null || hit.score > second.score) {
        second = hit;
      }
    }
    if (best == null) return PartMatch.none;

    final tie = second != null && second.score == best.score;
    final confidence = best.weak || tie ? MatchConfidence.unsure : MatchConfidence.sure;
    return PartMatch(instrumentId: best.id, confidence: confidence, term: best.term);
  }

  /// Lower-case words of [text]: umlauts folded (ö → oe), split at every
  /// non-letter/digit and between letters and digits ("Vl2" → vl 2).
  static List<String> tokenize(String text) => _words(text).tokens;

  /// [tokenize] plus whether a hard separator (" - ", "_", "/", "(") stands
  /// before each word: "Sinfonie 2 - Violine" → the 2 is not the part's.
  static _Words _words(String text) {
    final folded = _fold(text.toLowerCase())
        .replaceAllMapped(RegExp(r'(\p{L})(\d)', unicode: true), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'(\d)(\p{L})', unicode: true), (m) => '${m[1]} ${m[2]}');
    final tokens = <String>[];
    final hard = <bool>[];
    final section = <bool>[];
    var last = 0;
    for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(folded)) {
      final gap = folded.substring(last, m.start);
      tokens.add(m[0]!);
      hard.add(tokens.length == 1 || RegExp(r'[-–_/()\[\]+&,;]').hasMatch(gap));
      // A new part of the name: " - ", "–", "(", "/", ",".
      section.add(RegExp(r'\s-|-\s|[–—/(),;\[\]]').hasMatch(gap));
      last = m.end;
    }
    return (tokens: tokens, hardBefore: hard, sectionBefore: section);
  }

  static String _fold(String s) => s
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');

  static String? _firstKeyword(List<String> tokens, List<String> keywords) {
    for (final k in keywords) {
      if (_find(tokens, tokenize(k)) != null) return k;
    }
    return null;
  }

  /// Score of [instrument] for [tokens], or null if it does not match.
  static _Hit? _scoreInstrument(
    _Words words,
    InstrumentInfo instrument,
    List<({int start, int end, String family})> familySpans,
  ) {
    final tokens = words.tokens;
    final nameTokens = tokenize(instrument.name);
    final groupNumber = _numberIn(nameTokens);
    final baseName = nameTokens.where((t) => _tokenNumber(t) == null && !_tuningWords.contains(t)).toList();

    final candidates = <({List<String> term, int base, bool weak, bool explicitNumber, bool synonym})>[];
    void add(String raw, int base, {bool weak = false, bool synonym = false}) {
      final term = tokenize(raw);
      if (term.isEmpty) return;
      final hasNumber = term.any((t) => _tokenNumber(t) != null);
      candidates.add((
        term: synonym ? term : term.where((t) => _tokenNumber(t) == null).toList(),
        base: base,
        // A synonym was given to this group on purpose: never ambiguous.
        weak: weak || (!synonym && term.length == 1 && _ambiguousTerms.contains(term.single)),
        explicitNumber: synonym && hasNumber,
        synonym: synonym,
      ));
    }

    if (baseName.isNotEmpty) add(baseName.join(' '), 100);
    for (final s in (instrument.synonyms ?? '').split(',')) {
      // Given by hand, so above the group name ("violine" learned for
      // Violine 2 beats the bare name of Violine 1).
      if (s.trim().isNotEmpty) add(s.trim(), 110, synonym: true);
    }
    final families = _familiesOf(baseName).toSet();
    for (final family in families) {
      for (final t in translations[family] ?? const <String>[]) {
        add(t, 60);
      }
      for (final a in abbreviations[family] ?? const <String>[]) {
        add(a, 40);
      }
      // The family name itself when the group is called differently
      // ("1. Geige" → violine).
      add(family, 60);
    }

    _Hit? best;
    for (final c in candidates) {
      if (c.term.isEmpty) continue;
      final m = _find(tokens, c.term) ?? (c.base >= 60 ? _findCompound(tokens, c.term) : null);
      if (m == null) continue;
      // More words matched = more specific ("English Horn" before "Horn").
      var score = c.base + c.term.join(' ').length + 50 * (m.end - m.start - 1);
      var weak = c.weak || m.compound;
      if (m.compound) score -= 50;
      // The words are part of a longer name of another instrument
      // ("English Horn" for the group Horn): only unsure.
      if (!c.synonym &&
          familySpans.any((f) =>
              !families.contains(f.family) &&
              f.start <= m.start &&
              f.end >= m.end &&
              f.end - f.start > m.end - m.start)) {
        weak = true;
        score -= 50;
      }

      if (!c.explicitNumber && groupNumber != null) {
        final n = _numberNear(words, m.start, m.end);
        if (n == null) {
          // "Violine.pdf" with groups Violine 1 / Violine 2; a synonym the
          // group was given by hand ("zweite") stands for this group.
          if (!c.synonym) weak = true;
        } else if (n != groupNumber) {
          continue;
        } else {
          score += 10;
        }
      }
      if (best == null || score > best.score || (score == best.score && best.weak && !weak)) {
        best = _Hit(instrument.id, score, weak, tokens.sublist(m.start, m.end).join(' '));
      }
    }
    return best;
  }

  /// Families a group with [nameTokens] belongs to.
  static Iterable<String> _familiesOf(List<String> nameTokens) sync* {
    if (nameTokens.isEmpty) return;
    final name = nameTokens.join(' ');
    for (final key in translations.keys) {
      final k = tokenize(key).join(' ');
      if (k.isEmpty) continue;
      if (_find(nameTokens, tokenize(key)) != null ||
          (k.length >= 4 && !k.contains(' ') && nameTokens.any((t) => t.endsWith(k) && t != k && !_isOwnFamily(t))) ||
          name == k) {
        yield key;
      }
    }
  }

  /// A word that is itself a family ("bassklarinette") does not also belong
  /// to the shorter family it ends with ("klarinette").
  static bool _isOwnFamily(String token) =>
      translations.keys.any((key) => tokenize(key).join(' ') == token);

  /// Start/end of [term] as whole words in [tokens]; a plural ending
  /// ("Violinen", "Pauken") counts as the word.
  static ({int start, int end, bool compound})? _find(List<String> tokens, List<String> term) {
    for (var i = 0; i + term.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < term.length; j++) {
        final t = tokens[i + j];
        final w = term[j];
        if (t == w) continue;
        if (j == term.length - 1 && w.length >= 4 && t.startsWith(w) && const {'n', 'en', 'e', 's', 'i'}.contains(t.substring(w.length))) {
          continue;
        }
        ok = false;
        break;
      }
      if (ok) return (start: i, end: i + term.length, compound: false);
    }
    return null;
  }

  /// A compound word ending with the one-word [term] ("Altsaxophon" for
  /// saxophon): only an unsure match.
  static ({int start, int end, bool compound})? _findCompound(List<String> tokens, List<String> term) {
    if (term.length != 1 || term.single.length < 4) return null;
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].length > term.single.length && tokens[i].endsWith(term.single)) {
        return (start: i, end: i + 1, compound: true);
      }
    }
    return null;
  }

  static int? _tokenNumber(String t) {
    final n = int.tryParse(t);
    if (n != null) return n >= 1 && n <= 9 ? n : null;
    return romanNumerals[t];
  }

  /// Part number right after the matched words (skipping tuning words and
  /// ordinal endings: "Klarinette in B 2", "Vl II", "Horn 2nd") or right
  /// before them ("2. Violine").
  /// A number before the words only counts when it starts its part of the
  /// name ("2. Violine", "Ave Verum - 2. Violine", not "Sinfonie 2 Violine").
  /// A number after the words counts only within their part of the name
  /// and not when it numbers a movement / the Werk ("Violine – 2. Satz",
  /// "Violine 2 Satz", "Violine Nr 2").
  static int? _numberNear(_Words words, int start, int end) {
    final tokens = words.tokens;
    for (var i = end, skipped = 0; i < tokens.length && skipped <= 3; i++) {
      if (words.sectionBefore[i]) break;
      final n = _tokenNumber(tokens[i]);
      if (n != null) {
        final next = i + 1 < tokens.length ? tokens[i + 1] : null;
        if (next != null && _movementWords.contains(next)) return null;
        return n;
      }
      if (!_tuningWords.contains(tokens[i])) break;
      skipped++;
    }
    int? before(int i) {
      if (i < 0) return null;
      final n = int.tryParse(tokens[i]);
      if (n == null || n < 1 || n > 9 || !words.hardBefore[i]) return null;
      return n;
    }
    if (start > 0 && !words.hardBefore[start]) {
      final n = before(start - 1);
      if (n != null) return n;
      if (start > 1 && const {'st', 'nd', 'rd', 'th'}.contains(tokens[start - 1])) return before(start - 2);
    }
    return null;
  }

  /// Where the name of an instrument family (or one of its terms) stands
  /// in [tokens].
  static List<({int start, int end, String family})> _familySpans(List<String> tokens) => [
        for (final e in translations.entries)
          for (final term in [e.key, ...e.value])
            if (_find(tokens, tokenize(term)) case final m?) (start: m.start, end: m.end, family: e.key),
      ];

  static int? _numberIn(List<String> tokens) {
    for (final t in tokens) {
      final n = _tokenNumber(t);
      if (n != null) return n;
    }
    return null;
  }

  /// Get file extension
  static String _getExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  static String _stripExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot > 0 && filename.length - dot <= 6 ? filename.substring(0, dot) : filename;
  }

  /// The part of [filename] that names the part, to remember it as a
  /// synonym of a group: the Werk name, leading numbers and the extension
  /// are removed ("03 Ave Verum - Vl2.pdf" → "Vl2"). Null if nothing short
  /// is left.
  static String? partTerm(String filename, {String? workName}) {
    var stem = _stripExtension(filename).replaceAll(RegExp(r'_+'), ' ');
    // The Werk name with any separators between its words ("Ave_Verum").
    final title = (workName ?? '')
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (title.isNotEmpty) {
      // Whole words only ("Air" is not taken out of "Clairon").
      stem = stem.replaceAll(
        RegExp('(?<![\\p{L}\\p{N}])${title.join(r'[\s_\-.,]+')}(?![\\p{L}\\p{N}])', caseSensitive: false, unicode: true),
        ' ',
      );
    }
    stem = stem
        .replaceFirst(RegExp(r'^\s*\d+[\s.\-]+'), '')
        .replaceAll(RegExp(r'^[\s\-–.,()]+|[\s\-–.,()]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stem.isEmpty || stem.length > 30 || stem.contains(',')) return null;
    if (tokenize(stem).isEmpty) return null;
    return stem;
  }

  /// Extract number from filename (e.g., "Violine 1" -> 1, "Violine II" -> 2)
  static int? extractNumber(String filename) {
    final normalized = filename.toLowerCase();

    // Try Roman numerals first
    for (final entry in romanNumerals.entries) {
      final pattern = RegExp(r'(^|[^a-z])' + entry.key + r'([^a-z]|$)');
      if (pattern.hasMatch(normalized)) {
        return entry.value;
      }
    }

    // Try Arabic numerals
    final numberMatch = RegExp(r'(\d+)').firstMatch(filename);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!);
    }

    return null;
  }

  /// Get a descriptive label for a file based on its instrumentId and note
  static String getFileLabel({
    required int? instrumentId,
    required String? note,
    required List<InstrumentInfo> instruments,
  }) {
    // First check note
    if (note != null && note.isNotEmpty) {
      return note;
    }

    // Check special IDs
    if (instrumentId == recordingId) {
      return l10nWithoutContext.songsRecording;
    }
    if (instrumentId == lyricsId) {
      return l10nWithoutContext.songsLyrics;
    }

    // Find instrument name
    if (instrumentId != null) {
      final instrument = instruments.where((i) => i.id == instrumentId).firstOrNull;
      if (instrument != null) {
        return instrument.name;
      }
    }

    return l10nWithoutContext.songsOther;
  }
}

typedef _Words = ({List<String> tokens, List<bool> hardBefore, List<bool> sectionBefore});

class _Hit {
  _Hit(this.id, this.score, this.weak, this.term);

  final int id;
  final int score;
  final bool weak;
  final String term;
}

/// Simple info class for instrument matching
class InstrumentInfo {
  final int id;
  final String name;
  final String? synonyms;

  const InstrumentInfo({
    required this.id,
    required this.name,
    this.synonyms,
  });
}
