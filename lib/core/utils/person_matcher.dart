/// Person Matcher (Port von src/app/utilities/person-matcher.ts)
///
/// Findet dieselbe Person über verknüpfte Instanzen hinweg. Pure Funktionen,
/// keine Riverpod-/Supabase-Abhängigkeiten.
library;

import 'dart:math' as math;

/// Minimale Personendaten für den Abgleich
class PersonLike {
  const PersonLike({
    required this.firstName,
    required this.lastName,
    this.email,
    this.appId,
    this.globalPersonId,
    this.birthday,
  });

  final String firstName;
  final String lastName;
  final String? email;
  final String? appId;
  final String? globalPersonId;
  final String? birthday;
}

/// Bewerteter Treffer
class RankedMatch<T> {
  const RankedMatch({required this.candidate, required this.score, required this.reason});

  final T candidate;

  /// 0..1 – höher ist besser
  final double score;

  /// Kurzes deutsches Label für die UI
  final String reason;
}

const _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  'š': 's', 'ž': 'z', 'č': 'c', 'ř': 'r', 'ł': 'l', 'ś': 's', 'ć': 'c', 'ń': 'n', 'ź': 'z', 'ż': 'z',
};

/// Lowercase, Umlaute transliterieren, Diakritika entfernen.
/// `Müller`, `Mueller` und `Muller`(teilweise) werden vergleichbar.
String normalizeName(String s) {
  if (s.isEmpty) return '';
  var r = s
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp('[äÄ]'), 'ae')
      .replaceAll(RegExp('[öÖ]'), 'oe')
      .replaceAll(RegExp('[üÜ]'), 'ue')
      .replaceAll(RegExp('[æÆ]'), 'ae')
      .replaceAll(RegExp('[œŒ]'), 'oe')
      .replaceAll(RegExp('[øØ]'), 'o')
      .toLowerCase();
  final buffer = StringBuffer();
  for (final rune in r.runes) {
    final c = String.fromCharCode(rune);
    buffer.write(_diacritics[c] ?? c);
  }
  r = buffer.toString();
  return r
      .replaceAll(RegExp(r'[^a-z0-9 \-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Klassische Levenshtein-Distanz
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = math.min(math.min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

enum BirthdayCompare { match, close, mismatch, unknown }

BirthdayCompare compareBirthdays(String? a, String? b) {
  if (a == null || b == null || a.isEmpty || b.isEmpty) return BirthdayCompare.unknown;
  final da = DateTime.tryParse(a)?.toUtc();
  final db = DateTime.tryParse(b)?.toUtc();
  if (da == null || db == null) return BirthdayCompare.unknown;
  final yearDiff = (da.year - db.year).abs();
  final sameDay = da.month == db.month && da.day == db.day;
  if (yearDiff == 0 && sameDay) return BirthdayCompare.match;
  if (yearDiff == 1 && sameDay) return BirthdayCompare.close;
  return BirthdayCompare.mismatch;
}

double _partSimilarity(String query, String candidate) {
  final q = normalizeName(query);
  final c = normalizeName(candidate);
  if (q.isEmpty || c.isEmpty) return 0;
  if (q == c) return 1;
  final editSim = 1 - levenshtein(q, c) / math.max(q.length, c.length);
  var prefixSim = 0.0;
  if (q.length >= 2 && c.startsWith(q)) prefixSim = 0.7 + 0.3 * (q.length / c.length);
  var initialSim = 0.0;
  if (q.length == 1 && c.isNotEmpty && q[0] == c[0]) initialSim = 0.6;
  return [editSim, prefixSim, initialSim].reduce(math.max);
}

/// Kombinierte Namensähnlichkeit (Nachname stärker gewichtet, Vertauschung erkannt)
double nameSimilarity(PersonLike query, PersonLike candidate) {
  final score = 0.45 * _partSimilarity(query.firstName, candidate.firstName) +
      0.55 * _partSimilarity(query.lastName, candidate.lastName);
  final swapped = 0.45 * _partSimilarity(query.firstName, candidate.lastName) +
      0.55 * _partSimilarity(query.lastName, candidate.firstName);
  if (swapped - score > 0.2) return math.max(0, swapped - 0.05);
  return score;
}

String _reasonFor(PersonLike query, PersonLike candidate, double score) {
  final qFirst = normalizeName(query.firstName);
  final qLast = normalizeName(query.lastName);
  final cFirst = normalizeName(candidate.firstName);
  final cLast = normalizeName(candidate.lastName);
  final straight = 0.45 * _partSimilarity(query.firstName, candidate.firstName) +
      0.55 * _partSimilarity(query.lastName, candidate.lastName);
  final swapped = 0.45 * _partSimilarity(query.firstName, candidate.lastName) +
      0.55 * _partSimilarity(query.lastName, candidate.firstName);

  if (swapped - straight > 0.2) return 'Vor-/Nachname vertauscht';
  if (score >= 0.95) return 'Name fast identisch';
  if (qLast.isNotEmpty && qLast == cLast) return 'Nachname identisch';
  if (qFirst.isNotEmpty && qFirst == cFirst) return 'Vorname identisch';
  if (qLast.length >= 2 && cLast.startsWith(qLast)) return 'Nachname-Präfix';
  if (qFirst.length >= 2 && cFirst.startsWith(qFirst)) return 'Vorname-Präfix';
  return 'Ähnlicher Name';
}

/// Bewertet, filtert, sortiert und dedupliziert [candidates].
List<RankedMatch<T>> rankCandidates<T>(
  PersonLike query,
  List<T> candidates,
  PersonLike Function(T) toPerson, {
  double? threshold,
  int limit = 10,
  bool prefixMode = false,
  double bothPartsMinSim = 0.5,
}) {
  final minScore = threshold ?? (prefixMode ? 0.5 : 0.55);
  final qFirst = normalizeName(query.firstName);
  final qLast = normalizeName(query.lastName);
  final enforceBothParts = bothPartsMinSim > 0 && qFirst.length >= 2 && qLast.length >= 2;
  final qEmail = (query.email ?? '').trim().toLowerCase();
  final qGlobalId = query.globalPersonId;

  int identityRank(PersonLike c) => ((c.appId?.isNotEmpty ?? false) || (c.globalPersonId?.isNotEmpty ?? false))
      ? 3
      : (c.email?.isNotEmpty ?? false)
          ? 2
          : (c.birthday?.isNotEmpty ?? false)
              ? 1
              : 0;

  final scored = <RankedMatch<T>>[];
  for (final candidate in candidates) {
    final c = toPerson(candidate);
    if (qGlobalId != null && c.globalPersonId != null && qGlobalId == c.globalPersonId) {
      scored.add(RankedMatch(candidate: candidate, score: 1, reason: 'Verknüpfte Person'));
      continue;
    }
    final cEmail = (c.email ?? '').trim().toLowerCase();
    if (qEmail.isNotEmpty && cEmail.isNotEmpty && qEmail == cEmail) {
      scored.add(RankedMatch(candidate: candidate, score: 1, reason: 'E-Mail identisch'));
      continue;
    }

    if (enforceBothParts) {
      final straightOk = _partSimilarity(query.firstName, c.firstName) >= bothPartsMinSim &&
          _partSimilarity(query.lastName, c.lastName) >= bothPartsMinSim;
      final swappedOk = _partSimilarity(query.firstName, c.lastName) >= bothPartsMinSim &&
          _partSimilarity(query.lastName, c.firstName) >= bothPartsMinSim;
      if (!straightOk && !swappedOk) continue;
    }

    final base = nameSimilarity(query, c);
    final accountBoost = (c.appId?.isNotEmpty ?? false) ? 0.1 : 0.0;
    final bd = compareBirthdays(query.birthday, c.birthday);
    final bdDelta = switch (bd) {
      BirthdayCompare.match => 0.25,
      BirthdayCompare.close => 0.10,
      BirthdayCompare.mismatch => -0.40,
      BirthdayCompare.unknown => 0.0,
    };
    final score = (base + accountBoost + bdDelta).clamp(0.0, 1.0);
    if (score >= minScore) {
      final reason = bd == BirthdayCompare.match && base >= 0.7
          ? 'Gleicher Geburtstag'
          : bd == BirthdayCompare.close && base >= 0.7
              ? 'Ähnlicher Geburtstag'
              : _reasonFor(query, c, score);
      scored.add(RankedMatch(candidate: candidate, score: score, reason: reason));
    }
  }

  final byKey = <String, RankedMatch<T>>{};
  for (final m in scored) {
    final p = toPerson(m.candidate);
    final key = '${normalizeName(p.firstName)} ${normalizeName(p.lastName)}';
    final prev = byKey[key];
    if (prev == null) {
      byKey[key] = m;
      continue;
    }
    final prevId = identityRank(toPerson(prev.candidate));
    final currId = identityRank(p);
    if (currId > prevId || (currId == prevId && m.score > prev.score)) byKey[key] = m;
  }

  final deduped = byKey.values.toList()
    ..sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      return identityRank(toPerson(b.candidate)).compareTo(identityRank(toPerson(a.candidate)));
    });
  return deduped.take(limit).toList();
}
