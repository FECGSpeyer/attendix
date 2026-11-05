import 'package:attendix/features/help/data/help_content_service.dart';
import 'package:attendix/features/help/data/help_models.dart';
import 'package:flutter_test/flutter_test.dart';

HelpArticle _article(String id, String title, {List<String> keywords = const [], String body = ''}) =>
    HelpArticle(id: id, title: title, categoryId: 'test', keywords: keywords, body: body);

List<String> _ids(HelpContentService s, String query) => s.search(query).articles.map((a) => a.id).toList();

/// Expected values follow Fuse.js 7 (Ionic help search): weights title 2 /
/// keywords 1.5 / body 1 normalized to 4/9, 3/9, 2/9; threshold 0.35;
/// score = Π s^(weight * norm), norm = 1/sqrt(words); exact text = EPSILON,
/// exact substring = 0.001, otherwise errors / pattern length.
void main() {
  final service = HelpContentService(
    categories: const [],
    glossary: const [],
    articles: [
      _article('a0', 'Noten hochladen', body: 'Vor der Probe die Noten hochladen.'),
      _article('a1', 'Probe planen', body: 'Termin anlegen.'),
      _article('a2', 'Kalender abonnieren', keywords: ['Probe'], body: 'Termine im Kalender.'),
    ],
  );

  group('Help search like Fuse.js', () {
    test('keyword equal to the query, then title, then body', () {
      // a2: keyword == query → EPSILON^(1/3) ≈ 6e-6
      // a1: title substring → 0.001^(4/9 * 0.707) ≈ 0.114
      // a0: body substring → 0.001^(2/9 * 0.408) ≈ 0.535
      expect(_ids(service, 'Probe'), ['a2', 'a1', 'a0']);
    });

    test('typo within the threshold (1 error of 4)', () {
      // 'prbe' vs 'probe' = 1 error → 0.25 per field:
      // a2 0.25^(1/3) ≈ 0.630, a1 0.25^(0.314) ≈ 0.647, a0 0.25^(0.091) ≈ 0.882
      expect(_ids(service, 'Prbe'), ['a2', 'a1', 'a0']);
      // 2 errors of 4 (0.5) are above 0.35.
      expect(_ids(service, 'Pxxe'), isEmpty);
    });

    test('several words are one pattern, not separate words', () {
      final s = HelpContentService(
        categories: const [],
        glossary: const [],
        articles: [
          // Both words, but not as "noten probe" (needs >= 4 of 11 errors).
          _article('b0', 'Probe: Noten hochladen'),
          // One missing space = 1 error of 11.
          _article('b1', 'Notenprobe'),
        ],
      );
      expect(_ids(s, 'Noten Probe'), ['b1']);
    });

    test('patterns longer than 32 characters are searched in chunks', () {
      final s = HelpContentService(
        categories: const [],
        glossary: const [],
        articles: [
          _article('c0', 'Lange Texte', body: 'Hier steht ein sehr langer Satz über das Hochladen von Noten.'),
          _article('c1', 'Anderes', body: 'Nichts davon.'),
        ],
      );
      expect(_ids(s, 'ein sehr langer Satz über das Hochladen von'), ['c0']);
    });
  });
}
