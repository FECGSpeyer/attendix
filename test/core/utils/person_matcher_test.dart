import 'package:attendix/core/utils/person_matcher.dart';
import 'package:attendix/core/utils/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

PersonLike _p(
  String first,
  String last, {
  String? email,
  String? globalPersonId,
  String? birthday,
}) =>
    PersonLike(
      firstName: first,
      lastName: last,
      email: email,
      globalPersonId: globalPersonId,
      birthday: birthday,
    );

void main() {
  group('normalizeName', () {
    test('transliterates umlauts and strips diacritics', () {
      expect(normalizeName('Müller'), 'mueller');
      expect(normalizeName('Mueller'), 'mueller');
      expect(normalizeName('Strauß'), 'strauss');
      expect(normalizeName('José'), 'jose');
      expect(normalizeName(null), '');
    });
  });

  group('levenshtein', () {
    test('computes edit distance', () {
      expect(levenshtein('', ''), 0);
      expect(levenshtein('abc', 'abc'), 0);
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('', 'abc'), 3);
    });
  });

  group('rankCandidates', () {
    final candidates = [
      _p('Max', 'Mustermann'),
      _p('Erika', 'Musterfrau'),
      _p('Hans', 'Müller'),
      _p('Peter', 'Schmidt'),
    ];

    test('ranks typo match on top', () {
      final result = rankCandidates(
        _p('Max', 'Mustermnn'),
        candidates,
        (c) => c,
      );
      expect(result, isNotEmpty);
      expect(result.first.candidate.lastName, 'Mustermann');
    });

    test('is diacritic-insensitive', () {
      final result = rankCandidates(_p('Hans', 'Mueller'), candidates, (c) => c);
      expect(result.first.candidate.lastName, 'Müller');
      expect(result.first.score, greaterThan(0.9));
    });

    test('detects swapped first/last name', () {
      final result =
          rankCandidates(_p('Schmidt', 'Peter'), candidates, (c) => c);
      expect(result.first.candidate.lastName, 'Schmidt');
      expect(result.first.reason, MatchReason.swapped);
    });

    test('unrelated names are filtered out', () {
      final result =
          rankCandidates(_p('Zacharias', 'Quast'), candidates, (c) => c);
      expect(result, isEmpty);
    });

    test('same email is a definitive match', () {
      final result = rankCandidates(
        _p('X', 'Y', email: 'PETER@example.com'),
        [_p('Peter', 'Schmidt', email: 'peter@example.com')],
        (c) => c,
      );
      expect(result.single.score, 1.0);
    });

    test('shared global_person_id is a definitive match', () {
      final result = rankCandidates(
        _p('A', 'B', globalPersonId: 'g-1'),
        [_p('Peter', 'Schmidt', globalPersonId: 'g-1')],
        (c) => c,
      );
      expect(result.single.score, 1.0);
    });

    test('respects limit', () {
      final many = List.generate(20, (i) => _p('Max', 'Mustermann'));
      final result = rankCandidates(_p('Max', 'Mustermann'), many, (c) => c,
          limit: 5);
      expect(result.length, lessThanOrEqualTo(5));
    });
  });

  group('personIdentityKey (org stats dedupe)', () {
    test('prefers global_person_id, then appId, then normalized name', () {
      expect(
        personIdentityKey(
            globalPersonId: 'g', appId: 'a', firstName: 'x', lastName: 'y'),
        'g:g',
      );
      expect(
        personIdentityKey(appId: 'a', firstName: 'x', lastName: 'y'),
        'a:a',
      );
      expect(
        personIdentityKey(
            firstName: 'Jürgen', lastName: 'Groß', birthday: '2000-01-01'),
        personIdentityKey(
            firstName: 'juergen', lastName: 'gross', birthday: '2000-01-01'),
      );
    });
  });

  group('text_utils', () {
    test('emails match case-insensitively and trimmed', () {
      expect(emailsMatch(' Max@Example.com ', 'max@example.com'), isTrue);
      expect(emailsMatch('', ''), isFalse);
      expect(emailsMatch(null, null), isFalse);
      expect(normalizeEmailForMatch('  '), isNull);
    });

    test('escapeLikePattern escapes wildcards', () {
      expect(escapeLikePattern('a_b%c'), r'a\_b\%c');
    });
  });
}
