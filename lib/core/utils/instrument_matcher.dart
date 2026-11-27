import '../../l10n/l10n.dart';

part 'instrument_matcher_rules.dart';

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
  const PartMatch({
    required this.instrumentId,
    required this.confidence,
    this.term,
    this.byVision = false,
  });

  static const PartMatch none =
      PartMatch(instrumentId: null, confidence: MatchConfidence.none);

  final int? instrumentId;
  final MatchConfidence confidence;

  /// The part of the file name the match was based on (for display); for
  /// [byVision] the part name read on the first page.
  final String? term;

  /// Read on the first page by the `part-detect` function, not the name.
  final bool byVision;
}

/// Simple info class for instrument matching.
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
    'violine': ['violin', 'violins', 'geige', 'violino', 'violini', 'violon', 'скрипка', 'скрипки', 'skripka'],
    'viola': ['bratsche', 'alto viola', 'viole', 'альт', 'альты'],
    'cello': ['violoncello', 'violoncelli', 'violoncell', 'violoncelle', 'виолончель', 'виолончели', 'violonchel'],
    'kontrabass': ['contrabass', 'contrabbasso', 'contrabbassi', 'double bass', 'string bass', 'contrebasse', 'bass', 'контрабас', 'контрабасы'],

    // Woodwinds
    'piccolo': ['piccoloflöte', 'piccolo flute', 'ottavino', 'pikkoloflöte', 'пикколо', 'малая флейта'],
    'flöte': ['flute', 'flauto', 'flauti', 'querflöte', 'flote', 'флейта', 'флейты', 'fleita', 'flauta'],
    'blockflöte': ['recorder', 'блокфлейта', 'blokfleita', 'flauto dolce'],
    'oboe': ['hautbois', 'oboi', 'гобой', 'гобои', 'goboi', 'goboj'],
    'englischhorn': ['english horn', 'cor anglais', 'corno inglese', 'cor ang', 'cor angl', 'cor ingl', 'corno ingl'],
    'klarinette': ['clarinet', 'clarinetto', 'clarinetti', 'clarinette', 'кларнет', 'кларнеты', 'klarnet'],
    'bassklarinette': ['bass clarinet', 'bassclarinet', 'clarinetto basso', 'clarinette basse'],
    'fagott': ['bassoon', 'fagotto', 'fagotti', 'basson', 'фагот', 'фаготы'],
    'kontrafagott': ['contrabassoon', 'contrafagotto', 'double bassoon', 'контрафагот'],
    'saxophon': ['saxophone', 'saxofon', 'саксофон', 'saksofon', 'sassofono'],
    'sopransaxophon': ['soprano sax', 'soprano saxophone', 'sopransax'],
    'altsaxophon': ['alto sax', 'alto saxophone', 'altsax', 'altsaxofon'],
    'tenorsaxophon': ['tenor sax', 'tenor saxophone', 'tenorsax', 'tenorsaxofon'],
    'baritonsaxophon': ['baritone sax', 'baritone saxophone', 'baritonsax', 'baritonsaxofon'],

    // Brass
    'horn': ['french horn', 'corno', 'corni', 'cor', 'waldhorn', 'валторна', 'валторны', 'valtorna', 'рог'],
    'trompete': ['trumpet', 'tromba', 'trombe', 'trompette', 'труба', 'трубы', 'truba'],
    'flügelhorn': ['flugelhorn', 'flicorno'],
    'kornett': ['cornet', 'cornetto', 'корнет', 'cornetta'],
    'posaune': ['trombone', 'tromboni', 'trombon', 'тромбон', 'тромбоны'],
    'bassposaune': ['bass trombone', 'basstrombone'],
    'tenorhorn': ['tenor horn'],
    // Also the baritone voice (Ionic: baritone → баритон, baritono), so
    // these are ambiguous terms.
    'euphonium': ['bariton', 'baritone', 'baritonhorn', 'eufonium', 'эуфониум', 'eufonio', 'баритон', 'baritono'],
    'tuba': ['basstuba', 'туба'],

    // Percussion
    'schlagzeug': [
      'percussion', 'drums', 'drum set', 'drumset', 'batterie', 'schlagwerk', 'перкуссия',
      'ударные', 'udarnye', 'барабан', 'baraban', 'batteria', 'percussioni',
    ],
    'kleine trommel': ['snare', 'малый барабан', 'rullante'],
    'große trommel': ['bass drum', 'большой барабан', 'gran cassa'],
    'becken': ['cymbals', 'тарелки', 'tarelki', 'piatti'],
    'triangel': ['triangle', 'треугольник', 'treugolnik', 'triangolo'],
    'pauke': ['timpani', 'pauken', 'kettledrum', 'timbales', 'литавры', 'litavry', 'litavri'],
    'röhrenglocken': ['chimes', 'tubular bells', 'campane tubolari', 'campane', 'колокола', 'kolokola'],
    'glockenspiel': [
      'mallets', 'xylophon', 'xylophone', 'vibraphon', 'vibraphone', 'marimba',
      'ксилофон', 'ksilofon', 'xilofono', 'колокольчики', 'kolokolchiki', 'campanelli', 'campanella',
      'marimbaphon', 'маримба', 'вибрафон', 'vibrafon', 'vibrafono',
    ],

    // Keyboard
    'klavier': ['piano', 'pianoforte', 'flügel', 'фортепиано', 'пианино', 'fortepiano', 'рояль', 'royal'],
    'orgel': ['organ', 'organo', 'orgue', 'орган'],
    'cembalo': ['harpsichord', 'clavecin', 'клавесин', 'klavesin', 'clavicembalo'],
    'celesta': ['челеста', 'chelesta'],
    'keyboard': ['keys', 'synth', 'synthesizer', 'tastatur', 'клавишные', 'tastiera'],
    'akkordeon': ['accordion', 'аккордеон', 'баян', 'bayan', 'гармонь', 'fisarmonica'],

    // Other
    'harfe': ['harp', 'arpa', 'harpe', 'арфа', 'arfa'],
    'gitarre': ['guitar', 'chitarra', 'guitare', 'гитара', 'gitara'],
    'e-bass': ['ebass', 'bass guitar', 'electric bass', 'bassgitarre'],
    'mandoline': ['mandolin', 'мандолина', 'mandolina', 'mandolino'],
    'banjo': ['банджо', 'bandzho'],

    // A sung part outside a choir (solo, melody).
    'gesang': ['vokal', 'vocal', 'vocals', 'вокал', 'singstimme', 'gesangsstimme'],

    // Choir voices
    'sopran': ['soprano', 'сопрано'],
    'alt': ['alto', 'альт', 'contralto'],
    'tenor': ['tenore', 'тенор'],
    'bass': ['basso', 'бас'],

    // Special
    'partitur': [
      'score', 'full score', 'conductor', 'direktion', 'dirigent', 'partitura', 'партитура',
      'generalpartitur', 'dirigierpartitur', 'dirigentenpartitur', 'dirigentenauszug', 'direktionsstimme',
      'studienpartitur', 'gesamtpartitur',
    ],
    'stimmen': ['parts', 'voices', 'parti', 'голоса'],
  };

  /// Abbreviations mapping (whole words only).
  static const Map<String, List<String>> abbreviations = {
    'violine': ['vl', 'vln', 'vi', 'viol', 'vn', 'vni', 'скр'],
    'viola': ['va', 'vla', 'br', 'vle'],
    'cello': ['vc', 'vlc', 'vcl', 'vcs', 'влч', 'вчл', 'вл ч'],
    'kontrabass': ['kb', 'cb', 'db', 'кб', 'к бас', 'кбас', 'к-б'],
    'piccolo': ['picc', 'pic'],
    'flöte': ['fl', 'flt', 'fls', 'фл'],
    'oboe': ['ob', 'obs', 'гоб'],
    'englischhorn': ['eh', 'ca', 'engl hn'],
    'klarinette': ['cl', 'kl', 'clar', 'klar', 'cls', 'кл', 'кларн'],
    'bassklarinette': ['bcl', 'bkl', 'bass cl', 'bass kl'],
    'fagott': ['fg', 'bn', 'bsn', 'fag', 'фаг'],
    'saxophon': ['sx', 'sax'],
    'altsaxophon': ['asx', 'asax', 'as'],
    'tenorsaxophon': ['tsx', 'tsax', 'ts'],
    'baritonsaxophon': ['bsx', 'bsax', 'bs'],
    'horn': ['hr', 'hn', 'hrn', 'hns', 'валт', 'влт'],
    'trompete': ['tr', 'tp', 'trp', 'tpt', 'trpt', 'тр', 'труб'],
    'flügelhorn': ['flgh', 'flghn', 'flh'],
    'posaune': ['pos', 'tb', 'tbn', 'trb', 'тромб', 'трб'],
    'tuba': ['tu', 'tba', 'туб'],
    'euphonium': ['euph', 'bar'],
    'schlagzeug': ['perc', 'schlg', 'drs', 'dr', 'уд'],
    'pauke': ['timp', 'pk', 'pauk', 'лит'],
    'glockenspiel': ['glsp', 'glock', 'xyl', 'vib'],
    'klavier': ['pf', 'pno', 'kl', 'ф-но'],
    'orgel': ['org'],
    'akkordeon': ['acc'],
    'harfe': ['hp', 'hrf', 'hfe', 'арф'],
    'gitarre': ['gt', 'gtr', 'git'],
    'sopran': ['sop'],
    'tenor': ['ten'],
    'partitur': ['dir', 'cond'],
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
    'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'wma',
  ];

  /// Keywords that indicate lyrics/text (whole words)
  static const List<String> lyricsKeywords = [
    'text', 'texte', 'lyrics', 'liedtext', 'songtext', 'words', 'parole',
    'текст', 'слова',
  ];

  /// Keywords that indicate recordings (whole words, not for PDFs)
  static const List<String> recordingKeywords = [
    'aufnahme', 'recording', 'audio', 'track', 'запись',
    'registrazione', 'enregistrement',
  ];

  /// Try to match a filename to an instrument.
  /// Returns the instrument ID if found, null otherwise.
  static int? matchInstrument(String filename, List<InstrumentInfo> instruments) =>
      detect(filename, instruments).instrumentId;

  /// Scores every group against [filename] and returns the best one with
  /// how sure the match is.
  static PartMatch detect(String filename, List<InstrumentInfo> instruments) =>
      _detectPart(filename, instruments);

  /// Whether [name] says nothing but the part [term] with numbers and
  /// tuning ("1. Violine", "Horn in F"), not "12 Le viole" (a Werk).
  static bool namesOnlyPart(String name, String term) {
    final own = tokenize(term).toSet();
    return tokenize(name).every(
      (w) => own.contains(w) || _tokenNumber(w) != null || _tuningWords.contains(w),
    );
  }

  /// Lower-case words of [text]: umlauts folded (ö → oe), split at every
  /// non-letter/digit and between letters and digits ("Vl2" → vl 2).
  /// The list is shared (cached): read it, never change it.
  static List<String> tokenize(String text) => _words(text).tokens;

  /// A known instrument in [filename] for which no group exists yet, as the
  /// name of the group to create ("Alto Saxophone 2.pdf" → Altsaxophon).
  /// Only a sure match counts; "Violine 2" keeps its number (first and
  /// second violins are groups of their own). Null when none is clear.
  static String? knownGroup(String filename, {bool isChoir = false}) =>
      _knownGroup(filename, isChoir: isChoir);

  /// The instruments (dictionary groups) [name] names for sure, in the
  /// order they appear: two or more for a part like "Posaune und Tuba",
  /// which is never one group.
  static List<String> knownGroups(String name, {bool isChoir = false}) =>
      _knownGroups(name, isChoir: isChoir);

  /// The part of [filename] that names the part, to remember it as a
  /// synonym of a group: the Werk name, leading numbers and the extension
  /// are removed ("03 Ave Verum - Vl2.pdf" → "Vl2"). Null if nothing short
  /// is left.
  static String? partTerm(String filename, {String? workName}) {
    final key = '$filename\u0000${workName ?? ''}';
    if (_partTermCache.containsKey(key)) return _partTermCache[key];
    if (_partTermCache.length > 20000) _partTermCache.clear();
    return _partTermCache[key] = _partTerm(filename, workName: workName);
  }

  /// Extract number from filename (e.g., "Violine 1" -> 1, "Violine II" -> 2)
  static int? extractNumber(String filename) {
    final normalized = filename.toLowerCase();
    for (final entry in romanNumerals.entries) {
      final pattern = RegExp(r'(^|[^a-z])' + entry.key + r'([^a-z]|$)');
      if (pattern.hasMatch(normalized)) return entry.value;
    }
    final numberMatch = RegExp(r'(\d+)').firstMatch(filename);
    return numberMatch != null ? int.tryParse(numberMatch.group(1)!) : null;
  }

  /// Get a descriptive label for a file based on its instrumentId and note
  static String getFileLabel({
    required int? instrumentId,
    required String? note,
    required List<InstrumentInfo> instruments,
  }) {
    if (note != null && note.isNotEmpty) return note;
    if (instrumentId == recordingId) return l10nWithoutContext.songsRecording;
    if (instrumentId == lyricsId) return l10nWithoutContext.songsLyrics;
    if (instrumentId != null) {
      final instrument =
          instruments.where((i) => i.id == instrumentId).firstOrNull;
      if (instrument != null) return instrument.name;
    }
    return l10nWithoutContext.songsOther;
  }

  static final Map<String, String?> _partTermCache = {};

  static String? _partTerm(String filename, {String? workName}) {
    var stem = _stripExtension(filename).replaceAll(RegExp(r'_+'), ' ');
    final title = (workName ?? '')
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (title.isNotEmpty) {
      stem = stem.replaceAll(
        RegExp(
          '(?<![\\p{L}\\p{N}])${title.join(r'[\s_\-.,]+')}(?![\\p{L}\\p{N}])',
          caseSensitive: false,
          unicode: true,
        ),
        ' ',
      );
    }
    String trim(String text) => text
        .replaceAll(RegExp(r'^[\s\-–.,()]+|[\s\-–.,()]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    stem = trim(stem.replaceFirst(RegExp(r'^\s*\d+[\s.\-]+'), ''));
    final sections = stem
        .split(RegExp(r'\s+[-–—]\s+|\s*[–—]\s*'))
        .map(trim)
        .where((x) => x.isNotEmpty)
        .toList();
    if (sections.length > 1) {
      var bestRank = 0;
      String? chosen;
      for (final section in sections) {
        final rank = _instrumentRank(section);
        if (rank > 0 && rank >= bestRank) {
          bestRank = rank;
          chosen = section;
        }
      }
      if (chosen != null) {
        stem = chosen;
      } else if (stem.length > 30) {
        stem = sections.last;
      }
    }
    if (stem.isEmpty || stem.length > 30 || stem.contains(',')) return null;
    if (tokenize(stem).isEmpty) return null;
    return stem;
  }

  static final Map<String, int> _rankCache = {};
  static final RegExp _romanPattern = RegExp(r'^[ivx]+$');

  static int _instrumentRank(String text) {
    final cached = _rankCache[text];
    if (cached != null) return cached;
    if (_rankCache.length > 20000) _rankCache.clear();
    return _rankCache[text] = _rankOf(tokenize(text));
  }

  static int _rankOf(List<String> tokens) {
    if (tokens.isEmpty) return 0;
    var rank = 0;
    bool ambiguous(List<String> term) =>
        term.length == 1 &&
        (_ambiguousTerms.contains(term.single) || term.single == 'alt');
    for (final f in _familyTerms) {
      final t = f.term;
      if (_find(tokens, t) == null &&
          !(t.length == 1 &&
              t.single.length >= 5 &&
              _findCompound(tokens, t) != null)) {
        continue;
      }
      if (!ambiguous(t)) return 2;
      rank = 1;
    }
    for (final t in _abbreviationTerms) {
      if (_find(tokens, t) == null) continue;
      if (!ambiguous(t) &&
          !(t.length == 1 && _romanPattern.hasMatch(t.single))) {
        return 2;
      }
      rank = 1;
    }
    return rank;
  }
}
