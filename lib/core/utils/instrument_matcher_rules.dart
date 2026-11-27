part of 'instrument_matcher.dart';

typedef _Words = ({
  List<String> tokens,
  List<bool> hardBefore,
  List<bool> sectionBefore,
});

typedef _Candidate = ({
  List<String> term,
  int base,
  bool weak,
  bool explicitNumber,
  bool synonym,
});

typedef _InstrumentTerms = ({
  int? groupNumber,
  Set<String> families,
  List<_Candidate> candidates,
});

class _Hit {
  _Hit(this.id, this.score, this.weak, this.term, {this.onlyAmbiguous = false});

  final int id;
  final int score;
  final bool weak;
  final String term;

  /// Unsure only because [term] also means something else.
  final bool onlyAmbiguous;
}

/// Terms that also mean something else: a match on them is only "unsure".
const Set<String> _ambiguousTerms = {
  'bass', 'kl', 'bariton', 'baritone', 'cor', 'as', 'bs', 'ts', 'bar', 'dr',
  'alto', 'кл', 'тр',
  // Voice or instrument / an English word / "accompaniment".
  'баритон', 'baritono', 'royal', 'acc',
};

/// Words that only describe the tuning ("Klarinette in B", "Horn in F").
const Set<String> _tuningWords = {
  'in', 'b', 'bb', 'es', 'eb', 'f', 'c', 'd', 'a', 'g', 'e', 'as', 'des',
  'ges', 'sib', 'mib', 'fa', 'do', 'flat', 'sharp', 'dur', 'moll',
};

/// Words after a number that make it a movement / Werk number.
const Set<String> _movementWords = {
  'satz', 'saetze', 'movement', 'mvt', 'mov', 'mvmt', 'teil', 'akt', 'act',
  'szene', 'scene',
};

/// Instruments a percussion group plays when they have no group.
const List<String> _percussionParts = [
  'kleine trommel', 'große trommel', 'becken', 'triangel', 'pauke',
  'röhrenglocken', 'glockenspiel',
];

/// Families that are no group of their own (a type of file) and the choir
/// voices, which only choirs get as new groups.
const Set<String> _noGroupFamilies = {'partitur', 'stimmen'};
const Set<String> _voiceFamilies = {'sopran', 'alt', 'tenor', 'bass'};
const List<String> _sopranoWords = ['sopran', 'soprano', 'сопрано'];

final RegExp _letterDigit = RegExp(r'(\p{L})(\d)', unicode: true);
final RegExp _hyphenAbbreviation =
    RegExp(r'(?<![\p{L}])(v|c)-(ni|le|c|b)(?![\p{L}])', unicode: true);
final RegExp _digitLetter = RegExp(r'(\d)(\p{L})', unicode: true);
final RegExp _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final RegExp _hardGap = RegExp(r'[-–_/()\[\]+&,;]');
final RegExp _sectionGap = RegExp(r'\s-|-\s|[–—/(),;\[\]]');
final RegExp _ending = RegExp(r'\.[A-Za-z0-9]{1,5}$');

final Map<String, _Words> _wordsCache = {};
final Map<String, _InstrumentTerms> _termsCache = {};

final _InstrumentTerms _sopranoOutsideChoir = () {
  final sopran = _familyGroups.firstWhere((g) => g.family == 'sopran').terms;
  return (
    groupNumber: null,
    families: sopran.families,
    candidates: [
      for (final c in sopran.candidates)
        if (_sopranoWords.contains(c.term.join(' '))) c,
    ],
  );
}();

final List<({String family, String name, _InstrumentTerms terms})> _familyGroups = [
  for (final family in InstrumentMatcher.translations.keys)
    if (!_noGroupFamilies.contains(family))
      (
        family: family,
        name: family
            .split(' ')
            .map((w) => w
                .split('-')
                .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
                .join('-'))
            .join(' '),
        terms: (
          groupNumber: null,
          families: {family},
          candidates: _familyCandidates(family),
        ),
      ),
];

final Map<String, String> _termFamily = () {
  final families = <String, Set<String>>{};
  for (final e in InstrumentMatcher.translations.entries) {
    if (_noGroupFamilies.contains(e.key)) continue;
    for (final t in e.value) {
      final term = InstrumentMatcher.tokenize(t).join(' ');
      if (term.isEmpty || _ambiguousTerms.contains(term)) continue;
      families.putIfAbsent(term, () => {}).add(e.key);
    }
  }
  return {
    for (final e in families.entries)
      if (e.value.length == 1) e.key: e.value.single,
  };
}();

final Set<String> _familyKeys = {
  for (final key in InstrumentMatcher.translations.keys)
    InstrumentMatcher.tokenize(key).join(' '),
};

final List<List<String>> _abbreviationTerms = [
  for (final list in InstrumentMatcher.abbreviations.values)
    for (final a in list)
      if (InstrumentMatcher.tokenize(a).isNotEmpty) InstrumentMatcher.tokenize(a),
];

final List<({String family, List<String> term})> _familyTerms = [
  for (final e in InstrumentMatcher.translations.entries)
    for (final term in [e.key, ...e.value])
      if (InstrumentMatcher.tokenize(term).isNotEmpty)
        (family: e.key, term: InstrumentMatcher.tokenize(term)),
];

PartMatch _detectPart(String filename, List<InstrumentInfo> instruments) {
  final extension = _getExtension(filename).toLowerCase();
  if (InstrumentMatcher.audioExtensions.contains(extension)) {
    return const PartMatch(
      instrumentId: InstrumentMatcher.recordingId,
      confidence: MatchConfidence.sure,
    );
  }

  final words = _words(_stripExtension(filename));
  final tokens = words.tokens;
  if (tokens.isEmpty) return PartMatch.none;

  if (extension != 'pdf') {
    final hit = _firstKeyword(tokens, InstrumentMatcher.recordingKeywords);
    if (hit != null) {
      return PartMatch(
        instrumentId: InstrumentMatcher.recordingId,
        confidence: MatchConfidence.sure,
        term: hit,
      );
    }
  }
  final lyrics = _firstKeyword(tokens, InstrumentMatcher.lyricsKeywords);
  if (lyrics != null) {
    return PartMatch(
      instrumentId: InstrumentMatcher.lyricsId,
      confidence: MatchConfidence.sure,
      term: lyrics,
    );
  }

  final familySpans = _familySpans(tokens);
  final hits = [
    for (final instrument in instruments)
      if (_scoreInstrument(words, instrument, familySpans) case final hit?)
        (hit: hit, instrument: instrument, at: _spanOf(tokens, hit.term)),
  ];

  bool singers(InstrumentInfo i) {
    final families = _termsOf(i).families;
    return families.contains('sopran') && families.every(_voiceFamilies.contains);
  }

  bool kindOfInstrument(({int start, int end})? at) =>
      at != null &&
      hits.any((o) =>
          !o.hit.weak &&
          !singers(o.instrument) &&
          o.at != null &&
          _adjacent(words, at, o.at!));

  _Hit? best;
  _Hit? second;
  for (final (:hit, :instrument, :at) in hits) {
    if (singers(instrument) && kindOfInstrument(at)) continue;
    if (best == null || hit.score > best.score) {
      second = best;
      best = hit;
    } else if (second == null || hit.score > second.score) {
      second = hit;
    }
  }
  if (best == null) return PartMatch.none;

  final tie = second != null && second.score == best.score;
  final weak = best.weak &&
      !(best.onlyAmbiguous &&
          best.term == 'cor' &&
          _corIsHorn(filename, instruments));
  final confidence = weak || tie ? MatchConfidence.unsure : MatchConfidence.sure;
  return PartMatch(instrumentId: best.id, confidence: confidence, term: best.term);
}

bool _corIsHorn(String filename, List<InstrumentInfo> instruments) {
  const others = {'kornett', 'englischhorn'};
  if (instruments.any((i) => _termsOf(i).families.any(others.contains))) {
    return false;
  }
  final named = _knownGroups(filename);
  return named.isEmpty || (named.length == 1 && named.single == 'Horn');
}

_Words _words(String text) {
  final cached = _wordsCache[text];
  if (cached != null) return cached;
  final folded = _fold(text.toLowerCase())
      .replaceAllMapped(_hyphenAbbreviation, (m) => '${m[1]}${m[2]}')
      .replaceAllMapped(_letterDigit, (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(_digitLetter, (m) => '${m[1]} ${m[2]}');
  final tokens = <String>[];
  final hard = <bool>[];
  final section = <bool>[];
  var last = 0;
  for (final m in _wordPattern.allMatches(folded)) {
    final gap = folded.substring(last, m.start);
    tokens.add(m[0]!);
    hard.add(tokens.length == 1 || _hardGap.hasMatch(gap));
    section.add(_sectionGap.hasMatch(gap));
    last = m.end;
  }
  if (_wordsCache.length > 20000) _wordsCache.clear();
  return _wordsCache[text] = (
    tokens: List.unmodifiable(tokens),
    hardBefore: List.unmodifiable(hard),
    sectionBefore: List.unmodifiable(section),
  );
}

String _fold(String s) => s
    .replaceAll('a\u0308', 'ae')
    .replaceAll('o\u0308', 'oe')
    .replaceAll('u\u0308', 'ue')
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss');

String? _firstKeyword(List<String> tokens, List<String> keywords) {
  for (final k in keywords) {
    if (_find(tokens, InstrumentMatcher.tokenize(k)) != null) return k;
  }
  return null;
}

_Hit? _scoreInstrument(
  _Words words,
  InstrumentInfo instrument,
  List<({int start, int end, String family})> familySpans,
) =>
    _scoreTerms(words, instrument.id, _termsOf(instrument), familySpans);

_Hit? _scoreTerms(
  _Words words,
  int id,
  _InstrumentTerms terms,
  List<({int start, int end, String family})> familySpans,
) {
  final tokens = words.tokens;
  final groupNumber = terms.groupNumber;
  final families = terms.families;
  final lastSection = words.sectionBefore.lastIndexOf(true);

  _Hit? best;
  for (final c in terms.candidates) {
    if (c.term.isEmpty) continue;
    final m = _find(tokens, c.term) ??
        (c.base >= 60 ? _findCompound(tokens, c.term) : null);
    if (m == null) continue;
    var score = c.base + c.term.join(' ').length + 50 * (m.end - m.start - 1);
    if (lastSection > 0 && m.start >= lastSection) score += 40;
    var weak = c.weak || m.compound;
    var otherWeak = m.compound;
    if (m.compound) score -= 50;
    if (!c.synonym &&
        familySpans.any((f) =>
            !families.contains(f.family) &&
            f.start <= m.start &&
            f.end >= m.end &&
            f.end - f.start > m.end - m.start)) {
      weak = true;
      otherWeak = true;
      score -= 50;
    }

    if (!c.explicitNumber && groupNumber != null) {
      final n = _numberNear(words, m.start, m.end);
      if (n == null) {
        if (!c.synonym) {
          weak = true;
          otherWeak = true;
        }
      } else if (n != groupNumber) {
        continue;
      } else {
        score += 10;
      }
    }
    if (best == null ||
        score > best.score ||
        (score == best.score && best.weak && !weak)) {
      best = _Hit(
        id,
        score,
        weak,
        tokens.sublist(m.start, m.end).join(' '),
        onlyAmbiguous: weak && !otherWeak,
      );
    }
  }
  return best;
}

_InstrumentTerms _termsOf(InstrumentInfo instrument) {
  final key = '${instrument.name}\u0000${instrument.synonyms ?? ''}';
  final cached = _termsCache[key];
  if (cached != null) return cached;
  final nameTokens = InstrumentMatcher.tokenize(instrument.name);
  final groupNumber = _numberIn(nameTokens);
  final baseName = nameTokens
      .where((t) => _tokenNumber(t) == null && !_tuningWords.contains(t))
      .toList();

  final candidates = <_Candidate>[];
  void add(String raw, int base, {bool synonym = false}) =>
      _addCandidate(candidates, raw, base, synonym: synonym);

  if (baseName.isNotEmpty) add(baseName.join(' '), 100);
  for (final s in (instrument.synonyms ?? '').split(',')) {
    if (s.trim().isNotEmpty) add(s.trim(), 110, synonym: true);
  }
  final families = _familiesOf(baseName).toSet();
  for (final family in families) {
    _addFamilyTerms(candidates, family, own: 60);
  }
  if (families.contains('schlagzeug')) {
    for (final part in _percussionParts) {
      _addFamilyTerms(candidates, part, own: 30, terms: 30, short: 20);
    }
  }
  if (_termsCache.length > 2000) _termsCache.clear();
  return _termsCache[key] =
      (groupNumber: groupNumber, families: families, candidates: candidates);
}

void _addCandidate(
  List<_Candidate> candidates,
  String raw,
  int base, {
  bool synonym = false,
}) {
  final term = InstrumentMatcher.tokenize(raw);
  if (term.isEmpty) return;
  final hasNumber = term.any((t) => _tokenNumber(t) != null);
  candidates.add((
    term: synonym
        ? term
        : term.where((t) => _tokenNumber(t) == null).toList(),
    base: base,
    weak: !synonym && term.length == 1 && _ambiguousTerms.contains(term.single),
    explicitNumber: synonym && hasNumber,
    synonym: synonym,
  ));
}

void _addFamilyTerms(
  List<_Candidate> candidates,
  String family, {
  required int own,
  int terms = 60,
  int short = 40,
}) {
  for (final t in InstrumentMatcher.translations[family] ?? const <String>[]) {
    _addCandidate(candidates, t, terms);
  }
  for (final a in InstrumentMatcher.abbreviations[family] ?? const <String>[]) {
    _addCandidate(candidates, a, short);
  }
  _addCandidate(candidates, family, own);
}

List<_Candidate> _familyCandidates(String family) {
  final list = <_Candidate>[];
  _addFamilyTerms(list, family, own: 100);
  return list;
}

String? _knownGroup(String filename, {bool isChoir = false}) {
  final words = _words(_stripExtension(filename));
  if (words.tokens.isEmpty) return null;
  _Hit? best;
  _Hit? second;
  for (final (:hit, start: _, end: _) in _knownHits(words, isChoir: isChoir)) {
    if (best == null || hit.score > best.score) {
      second = best;
      best = hit;
    } else if (second == null || hit.score > second.score) {
      second = hit;
    }
  }
  if (best == null ||
      best.weak ||
      (second != null && (!second.weak || second.score == best.score))) {
    return null;
  }
  final group = _familyGroups[best.id];
  if (group.family == 'violine') {
    final at = _find(words.tokens, InstrumentMatcher.tokenize(best.term));
    final n = at == null ? null : _numberNear(words, at.start, at.end);
    if (n != null && n <= 2) return '${group.name} $n';
  }
  return group.name;
}

List<String> _knownGroups(String name, {bool isChoir = false}) {
  final words = _words(_stripExtension(name));
  if (words.tokens.isEmpty) return const [];
  final found = [
    for (final h in _knownHits(words, isChoir: isChoir))
      if (!h.hit.weak) h,
  ]..sort((a, b) => a.start.compareTo(b.start));
  return [for (final f in found) _familyGroups[f.hit.id].name];
}

List<({_Hit hit, int start, int end})> _knownHits(
  _Words words, {
  required bool isChoir,
}) {
  final familySpans = _familySpans(words.tokens);
  final hits = <({_Hit hit, int start, int end})>[];
  for (var i = 0; i < _familyGroups.length; i++) {
    final g = _familyGroups[i];
    final soprano = !isChoir && g.family == 'sopran';
    if (!soprano &&
        (isChoir ? g.family == 'gesang' : _voiceFamilies.contains(g.family))) {
      continue;
    }
    final hit =
        _scoreTerms(words, i, soprano ? _sopranoOutsideChoir : g.terms, familySpans);
    if (hit == null) continue;
    final at = _find(words.tokens, InstrumentMatcher.tokenize(hit.term));
    hits.add((hit: hit, start: at?.start ?? 0, end: at?.end ?? 0));
  }
  final kept = [
    for (final h in hits)
      if (!hits.any((o) =>
          o.hit.score > h.hit.score &&
          o.start <= h.start &&
          o.end >= h.end &&
          o.end > o.start))
        h,
  ];
  final once = [
    for (final h in kept)
      if (!kept.any((o) =>
          o.hit.id == h.hit.id &&
          (o.hit.score > h.hit.score ||
              (o.hit.score == h.hit.score && o.start < h.start))))
        h,
  ];
  if (isChoir) return once;
  bool isSoprano(({_Hit hit, int start, int end}) h) =>
      _familyGroups[h.hit.id].family == 'sopran';
  return [
    for (final h in once)
      if (!isSoprano(h) ||
          !once.any((o) =>
              !isSoprano(o) &&
              !o.hit.weak &&
              _adjacent(words, (start: h.start, end: h.end),
                  (start: o.start, end: o.end))))
        h,
  ];
}

({int start, int end})? _spanOf(List<String> tokens, String term) {
  final at = _find(tokens, InstrumentMatcher.tokenize(term));
  return at == null ? null : (start: at.start, end: at.end);
}

bool _adjacent(_Words words, ({int start, int end}) a, ({int start, int end}) b) {
  final (first, second) = a.start <= b.start ? (a, b) : (b, a);
  return first.end > first.start &&
      second.start == first.end &&
      second.start < words.tokens.length &&
      !words.hardBefore[second.start] &&
      !words.sectionBefore[second.start];
}

Iterable<String> _familiesOf(List<String> nameTokens) sync* {
  if (nameTokens.isEmpty) return;
  final name = nameTokens.join(' ');
  for (final key in InstrumentMatcher.translations.keys) {
    final k = InstrumentMatcher.tokenize(key).join(' ');
    if (k.isEmpty) continue;
    if (_find(nameTokens, InstrumentMatcher.tokenize(key)) != null ||
        (k.length >= 4 &&
            !k.contains(' ') &&
            nameTokens.any((t) => t.endsWith(k) && t != k && !_isOwnFamily(t))) ||
        name == k ||
        _termFamily[name] == key) {
      yield key;
    }
  }
}

bool _isOwnFamily(String token) => _familyKeys.contains(token);

({int start, int end, bool compound})? _find(
  List<String> tokens,
  List<String> term,
) {
  for (var i = 0; i + term.length <= tokens.length; i++) {
    var ok = true;
    for (var j = 0; j < term.length; j++) {
      final t = tokens[i + j];
      final w = term[j];
      if (t == w) continue;
      if (j == term.length - 1 &&
          w.length >= 4 &&
          t.startsWith(w) &&
          const {'n', 'en', 'e', 's', 'i'}.contains(t.substring(w.length))) {
        continue;
      }
      ok = false;
      break;
    }
    if (ok) return (start: i, end: i + term.length, compound: false);
  }
  return null;
}

({int start, int end, bool compound})? _findCompound(
  List<String> tokens,
  List<String> term,
) {
  if (term.length != 1 || term.single.length < 4) return null;
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].length > term.single.length &&
        tokens[i].endsWith(term.single)) {
      return (start: i, end: i + 1, compound: true);
    }
  }
  return null;
}

int? _tokenNumber(String t) {
  final n = int.tryParse(t);
  if (n != null) return n >= 1 && n <= 9 ? n : null;
  return InstrumentMatcher.romanNumerals[t];
}

int? _numberNear(_Words words, int start, int end) {
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
    if (start > 1 && const {'st', 'nd', 'rd', 'th'}.contains(tokens[start - 1])) {
      return before(start - 2);
    }
  }
  return null;
}

List<({int start, int end, String family})> _familySpans(List<String> tokens) =>
    [
      for (final t in _familyTerms)
        if (_find(tokens, t.term) case final m?)
          (start: m.start, end: m.end, family: t.family),
    ];

int? _numberIn(List<String> tokens) {
  for (final t in tokens) {
    final n = _tokenNumber(t);
    if (n != null) return n;
  }
  return null;
}

String _getExtension(String filename) {
  final parts = filename.split('.');
  return parts.length > 1 ? parts.last : '';
}

String _stripExtension(String filename) {
  final ending = _ending.firstMatch(filename);
  return ending != null && ending.start > 0
      ? filename.substring(0, ending.start)
      : filename;
}
