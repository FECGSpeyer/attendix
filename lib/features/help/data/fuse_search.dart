import 'dart:math' as math;

/// A search key of [FuseSearch]: its weight and the texts of an item
/// (one for a text field, every element for a list field).
typedef FuseKey<T> = ({double weight, Iterable<String> Function(T item) get});

/// Small Dart port of the Fuse.js 7 search the Ionic app uses for the help
/// center (`new Fuse(list, {keys, threshold, ignoreLocation: true})`, all
/// other options at their defaults: case-insensitive, no diacritics folding,
/// sorted by score, field norm weight 1, no extended search).
///
/// - The whole query is one pattern, matched with the Bitap algorithm
///   (Levenshtein errors / pattern length must stay within [threshold]);
///   patterns longer than 32 characters are split into chunks like Fuse.
/// - Every text of a key that matches counts, weighted with the normalized
///   key weight and the field norm `1 / sqrt(number of words)`.
/// - Results are sorted by score (0 = perfect), ties by list index.
class FuseSearch<T> {
  FuseSearch(this.items, List<FuseKey<T>> keys, {this.threshold = 0.35})
      : _keys = _normalize(keys);

  final List<T> items;
  final double threshold;
  final List<FuseKey<T>> _keys;

  /// Fuse `Number.EPSILON`: an exact match (score 0) still gets a weight.
  static final double _epsilon = math.pow(2, -52).toDouble();

  static List<FuseKey<T>> _normalize<T>(List<FuseKey<T>> keys) {
    final total = keys.fold<double>(0, (sum, k) => sum + k.weight);
    return [for (final k in keys) (weight: k.weight / total, get: k.get)];
  }

  List<T> search(String query) {
    final searcher = _BitapSearcher(query, threshold);
    if (searcher.chunks.isEmpty) return const [];

    final results = <({int index, double score})>[];
    for (var index = 0; index < items.length; index++) {
      var score = 1.0;
      var matched = false;
      for (final key in _keys) {
        for (final text in key.get(items[index])) {
          if (text.trim().isEmpty) continue;
          final m = searcher.searchIn(text);
          if (!m.isMatch) continue;
          matched = true;
          // Fuse computeScore: Π score ^ (weight * norm).
          score *= math.pow(m.score == 0 ? _epsilon : m.score, key.weight * _norm(text));
        }
      }
      if (matched) results.add((index: index, score: score));
    }
    results.sort((a, b) => a.score == b.score ? a.index.compareTo(b.index) : a.score.compareTo(b.score));
    return [for (final r in results) items[r.index]];
  }

  static final _word = RegExp(r'[^ ]+');

  /// Fuse field norm: 1 / sqrt(words split at spaces), 3 decimals.
  static double _norm(String text) {
    final words = _word.allMatches(text).length;
    return (1 / math.pow(words, 0.5) * 1000).round() / 1000;
  }
}

class _Chunk {
  _Chunk(this.pattern, this.startIndex) {
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern.codeUnitAt(i);
      alphabet[c] = (alphabet[c] ?? 0) | (1 << (pattern.length - i - 1));
    }
  }

  final String pattern;
  final int startIndex;
  final Map<int, int> alphabet = {};
}

/// Fuse `BitapSearch` with `location: 0`, `ignoreLocation: true`.
class _BitapSearcher {
  _BitapSearcher(String query, this.threshold) : pattern = query.toLowerCase() {
    final len = pattern.length;
    if (len == 0) return;
    if (len <= _maxBits) {
      chunks.add(_Chunk(pattern, 0));
      return;
    }
    final remainder = len % _maxBits;
    for (var i = 0; i < len - remainder; i += _maxBits) {
      chunks.add(_Chunk(pattern.substring(i, i + _maxBits), i));
    }
    if (remainder > 0) {
      chunks.add(_Chunk(pattern.substring(len - _maxBits), len - _maxBits));
    }
  }

  static const _maxBits = 32;

  final String pattern;
  final double threshold;
  final List<_Chunk> chunks = [];

  ({bool isMatch, double score}) searchIn(String text) {
    final lower = text.toLowerCase();
    if (lower == pattern) return (isMatch: true, score: 0);

    var total = 0.0;
    var hasMatches = false;
    for (final chunk in chunks) {
      final r = _search(lower, chunk);
      if (r.isMatch) hasMatches = true;
      total += r.score;
    }
    return (isMatch: hasMatches, score: hasMatches ? total / chunks.length : 1);
  }

  /// Fuse `search` (Bitap, diff-match-patch style). With `ignoreLocation`
  /// the score is just errors / pattern length.
  ({bool isMatch, double score}) _search(String text, _Chunk chunk) {
    final pattern = chunk.pattern;
    final alphabet = chunk.alphabet;
    final patternLen = pattern.length;
    final textLen = text.length;
    final expectedLocation = math.max(0, math.min(chunk.startIndex, textLen));
    double score(int errors) => errors / patternLen;

    var currentThreshold = threshold;
    // Exact matches (Fuse only looks from the expected location on).
    if (text.indexOf(pattern, expectedLocation) >= 0) {
      currentThreshold = math.min(score(0), currentThreshold);
    }

    var bestLocation = -1;
    var lastBitArr = <int>[];
    var finalScore = 1.0;
    var binMax = patternLen + textLen;
    final mask = 1 << (patternLen - 1);
    int at(List<int> list, int i) => i < list.length ? list[i] : 0;

    for (var i = 0; i < patternLen; i++) {
      var binMin = 0;
      var binMid = binMax;
      while (binMin < binMid) {
        if (score(i) <= currentThreshold) {
          binMin = binMid;
        } else {
          binMax = binMid;
        }
        binMid = (binMax - binMin) ~/ 2 + binMin;
      }
      binMax = binMid;

      var start = math.max(1, expectedLocation - binMid + 1);
      final finish = math.min(expectedLocation + binMid, textLen) + patternLen;
      final bitArr = List<int>.filled(finish + 2, 0);
      bitArr[finish + 1] = (1 << i) - 1;

      for (var j = finish; j >= start; j--) {
        final currentLocation = j - 1;
        final charMatch = currentLocation < textLen ? (alphabet[text.codeUnitAt(currentLocation)] ?? 0) : 0;
        var bits = ((bitArr[j + 1] << 1) | 1) & charMatch;
        if (i > 0) {
          bits |= ((at(lastBitArr, j + 1) | at(lastBitArr, j)) << 1) | 1 | at(lastBitArr, j + 1);
        }
        bitArr[j] = bits & 0xFFFFFFFF;

        if (bitArr[j] & mask != 0) {
          finalScore = score(i);
          if (finalScore <= currentThreshold) {
            currentThreshold = finalScore;
            bestLocation = currentLocation;
            if (bestLocation <= expectedLocation) break;
            start = math.max(1, 2 * expectedLocation - bestLocation);
          }
        }
      }

      if (score(i + 1) > currentThreshold) break;
      lastBitArr = bitArr;
    }

    return (isMatch: bestLocation >= 0, score: math.max(0.001, finalScore));
  }
}
