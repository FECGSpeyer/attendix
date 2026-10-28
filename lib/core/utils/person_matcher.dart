/// Person Matcher — port of Ionic `utilities/person-matcher.ts`.
///
/// Matches people across linked tenants when adding or editing a person.
/// Returns ranked, scored matches with a short German reason label so the UI
/// can surface them as typeahead suggestions.
///
/// - Diacritic-insensitive (`Müller` ↔ `Mueller` ↔ `Muller`)
/// - Tolerates typos via Levenshtein edit distance
/// - Prefix-friendly so partial input ranks well during typing
/// - Detects swapped first/last name pairs
library;

import 'dart:math' as math;

/// Minimal identity data used for matching.
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

/// A scored candidate.
class RankedMatch<T> {
  const RankedMatch({
    required this.candidate,
    required this.score,
    required this.reason,
  });

  final T candidate;

  /// 0..1 — higher is better
  final double score;

  /// Short German label for the UI
  final String reason;
}

/// German reason labels (Ionic i18n `linkPersons.reason.*`).
abstract final class MatchReason {
  static const swapped = 'Vor-/Nachname vertauscht';
  static const nearlyIdentical = 'Name fast identisch';
  static const sameLastName = 'Nachname identisch';
  static const sameFirstName = 'Vorname identisch';
  static const lastNamePrefix = 'Nachname-Präfix';
  static const firstNamePrefix = 'Vorname-Präfix';
  static const similarName = 'Ähnlicher Name';
  static const linked = 'Verknüpfte Person';
  static const sameEmail = 'E-Mail identisch';
  static const sameBirthday = 'Gleicher Geburtstag';
  static const similarBirthday = 'Ähnlicher Geburtstag';
}

const _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
  'ł': 'l', 'ľ': 'l', 'ĺ': 'l',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ō': 'o', 'ő': 'o',
  'ř': 'r', 'ŕ': 'r',
  'ś': 's', 'š': 's', 'ş': 's', 'ș': 's',
  'ť': 't', 'ţ': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// Lower-cases, transliterates German umlauts (ä→ae …), strips other
/// diacritics and normalises ligatures so `Müller`, `Mueller` collapse to
/// `mueller`. Hyphens are preserved.
String normalizeName(String? s) {
  if (s == null || s.isEmpty) return '';
  var out = s
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp('[äÄ]'), 'ae')
      .replaceAll(RegExp('[öÖ]'), 'oe')
      .replaceAll(RegExp('[üÜ]'), 'ue')
      .replaceAll(RegExp('[æÆ]'), 'ae')
      .replaceAll(RegExp('[œŒ]'), 'oe')
      .replaceAll(RegExp('[øØ]'), 'o')
      .toLowerCase();
  final buffer = StringBuffer();
  for (final rune in out.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  out = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 \-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return out;
}

/// Classic two-row Levenshtein edit distance.
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
      curr[j] = math.min(
        math.min(curr[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// Result of comparing two birthdays.
enum BirthdayCompare { match, close, mismatch, unknown }

/// Compares two ISO birthday strings in UTC.
BirthdayCompare compareBirthdays(String? a, String? b) {
  if (a == null || a.isEmpty || b == null || b.isEmpty) {
    return BirthdayCompare.unknown;
  }
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

  final dist = levenshtein(q, c);
  final editSim = 1 - dist / math.max(q.length, c.length);

  var prefixSim = 0.0;
  if (q.length >= 2 && c.startsWith(q)) {
    prefixSim = 0.7 + 0.3 * (q.length / c.length);
  }

  var initialSim = 0.0;
  if (q.length == 1 && c.isNotEmpty && q[0] == c[0]) {
    initialSim = 0.6;
  }

  return math.max(editSim, math.max(prefixSim, initialSim));
}

/// Combined name similarity in [0..1]; last name weighted higher, detects
/// swapped first/last names.
double nameSimilarity(
  ({String firstName, String lastName}) query,
  ({String firstName, String lastName}) candidate,
) {
  final firstSim = _partSimilarity(query.firstName, candidate.firstName);
  final lastSim = _partSimilarity(query.lastName, candidate.lastName);
  final score = 0.45 * firstSim + 0.55 * lastSim;

  final swapFirst = _partSimilarity(query.firstName, candidate.lastName);
  final swapLast = _partSimilarity(query.lastName, candidate.firstName);
  final swapped = 0.45 * swapFirst + 0.55 * swapLast;

  if (swapped - score > 0.2) {
    return math.max(0, swapped - 0.05);
  }
  return score;
}

String _reasonFor(PersonLike query, PersonLike candidate, double score) {
  final qFirst = normalizeName(query.firstName);
  final qLast = normalizeName(query.lastName);
  final cFirst = normalizeName(candidate.firstName);
  final cLast = normalizeName(candidate.lastName);

  final swapFirst = _partSimilarity(query.firstName, candidate.lastName);
  final swapLast = _partSimilarity(query.lastName, candidate.firstName);
  final straight = 0.45 * _partSimilarity(query.firstName, candidate.firstName) +
      0.55 * _partSimilarity(query.lastName, candidate.lastName);
  final swapped = 0.45 * swapFirst + 0.55 * swapLast;

  if (swapped - straight > 0.2) return MatchReason.swapped;
  if (score >= 0.95) return MatchReason.nearlyIdentical;
  if (qLast.isNotEmpty && cLast.isNotEmpty && qLast == cLast) {
    return MatchReason.sameLastName;
  }
  if (qFirst.isNotEmpty && cFirst.isNotEmpty && qFirst == cFirst) {
    return MatchReason.sameFirstName;
  }
  if (qLast.length >= 2 && cLast.startsWith(qLast)) {
    return MatchReason.lastNamePrefix;
  }
  if (qFirst.length >= 2 && cFirst.startsWith(qFirst)) {
    return MatchReason.firstNamePrefix;
  }
  return MatchReason.similarName;
}

/// Score, filter, sort and dedupe [candidates].
///
/// Identity signals in priority order:
///  1. Shared `global_person_id` → definitive match, score 1.0
///  2. Matching `appId` → score boost +0.1
///  3. Matching `email` → definitive match, score 1.0
///  4. `birthday` corroboration → +0.25 / +0.10 / −0.40
///  5. Fuzzy name similarity
///
/// [toPerson] extracts the identity data from a candidate.
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
  final enforceBothParts =
      bothPartsMinSim > 0 && qFirst.length >= 2 && qLast.length >= 2;
  final qEmail = (query.email ?? '').trim().toLowerCase();
  final qGlobalId = query.globalPersonId;

  int identityRank(PersonLike c) {
    if ((c.appId?.isNotEmpty ?? false) ||
        (c.globalPersonId?.isNotEmpty ?? false)) {
      return 3;
    }
    if (c.email?.isNotEmpty ?? false) return 2;
    if (c.birthday?.isNotEmpty ?? false) return 1;
    return 0;
  }

  final scored = <RankedMatch<T>>[];
  for (final candidate in candidates) {
    final c = toPerson(candidate);

    if (qGlobalId != null &&
        qGlobalId.isNotEmpty &&
        c.globalPersonId != null &&
        qGlobalId == c.globalPersonId) {
      scored.add(RankedMatch(
          candidate: candidate, score: 1.0, reason: MatchReason.linked));
      continue;
    }

    final cEmail = (c.email ?? '').trim().toLowerCase();
    if (qEmail.isNotEmpty && cEmail.isNotEmpty && qEmail == cEmail) {
      scored.add(RankedMatch(
          candidate: candidate, score: 1.0, reason: MatchReason.sameEmail));
      continue;
    }

    if (enforceBothParts) {
      final firstSim = _partSimilarity(query.firstName, c.firstName);
      final lastSim = _partSimilarity(query.lastName, c.lastName);
      final swapFirst = _partSimilarity(query.firstName, c.lastName);
      final swapLast = _partSimilarity(query.lastName, c.firstName);
      final straightOk =
          firstSim >= bothPartsMinSim && lastSim >= bothPartsMinSim;
      final swappedOk =
          swapFirst >= bothPartsMinSim && swapLast >= bothPartsMinSim;
      if (!straightOk && !swappedOk) continue;
    }

    final base = nameSimilarity(
      (firstName: query.firstName, lastName: query.lastName),
      (firstName: c.firstName, lastName: c.lastName),
    );
    final accountBoost = (c.appId?.isNotEmpty ?? false) ? 0.1 : 0.0;
    final bd = compareBirthdays(query.birthday, c.birthday);
    final bdDelta = switch (bd) {
      BirthdayCompare.match => 0.25,
      BirthdayCompare.close => 0.10,
      BirthdayCompare.mismatch => -0.40,
      BirthdayCompare.unknown => 0.0,
    };

    final score = math.min(1.0, math.max(0.0, base + accountBoost + bdDelta));
    if (score >= minScore) {
      final String reason;
      if (bd == BirthdayCompare.match && base >= 0.7) {
        reason = MatchReason.sameBirthday;
      } else if (bd == BirthdayCompare.close && base >= 0.7) {
        reason = MatchReason.similarBirthday;
      } else {
        reason = _reasonFor(query, c, score);
      }
      scored.add(RankedMatch(candidate: candidate, score: score, reason: reason));
    }
  }

  // Dedupe across linked tenants: same normalized name = same person.
  final byKey = <String, RankedMatch<T>>{};
  for (final m in scored) {
    final c = toPerson(m.candidate);
    final key = '${normalizeName(c.firstName)} ${normalizeName(c.lastName)}';
    final prev = byKey[key];
    if (prev == null) {
      byKey[key] = m;
      continue;
    }
    final prevId = identityRank(toPerson(prev.candidate));
    final currId = identityRank(c);
    if (currId > prevId || (currId == prevId && m.score > prev.score)) {
      byKey[key] = m;
    }
  }

  final deduped = byKey.values.toList()
    ..sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      return identityRank(toPerson(b.candidate))
          .compareTo(identityRank(toPerson(a.candidate)));
    });

  return deduped.take(limit).toList();
}

/// Key identifying the same real person across tenants (Ionic stats.page
/// getOrganizationStats): `global_person_id` -> `appId` -> normalized
/// `first|last|birthday`.
String personIdentityKey({
  String? globalPersonId,
  String? appId,
  required String firstName,
  required String lastName,
  String? birthday,
}) {
  if (globalPersonId != null && globalPersonId.isNotEmpty) {
    return 'g:$globalPersonId';
  }
  if (appId != null && appId.isNotEmpty) return 'a:$appId';
  return 'n:${normalizeName(firstName)}|${normalizeName(lastName)}|${birthday ?? ''}';
}
