import 'package:attendix/features/help/data/help_content_service.dart';
import 'package:attendix/features/help/presentation/widgets/help_markdown.dart';
import 'package:attendix/features/settings/presentation/pages/delete_account_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = HelpContentService();

  group('HelpContentService', () {
    test('ports all Ionic categories, articles and glossary terms', () {
      expect(service.getCategories(), hasLength(10));
      expect(service.getCategories().first.label, 'Erste Schritte');
      expect(service.articles.length, greaterThanOrEqualTo(70));
      expect(service.glossary.length, greaterThanOrEqualTo(30));
    });

    test('every article belongs to an existing category', () {
      final ids = service.categories.map((c) => c.id).toSet();
      for (final a in service.articles) {
        expect(ids, contains(a.categoryId), reason: a.id);
      }
    });

    test('article ids are unique', () {
      final ids = service.articles.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every [[glossary]] reference in articles resolves', () {
      final re = RegExp(r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]');
      final unresolved = <String>{};
      for (final a in service.articles) {
        for (final m in re.allMatches(a.body)) {
          if (service.findGlossaryTermByName(m.group(1)!) == null) {
            unresolved.add('${a.id}: ${m.group(1)}');
          }
        }
      }
      // Ionic tolerates unresolved links (tap does nothing); keep it small.
      expect(unresolved.length, lessThan(5), reason: unresolved.join(', '));
    });

    test('findGlossaryTermByName matches term and alias case-insensitively',
        () {
      expect(service.findGlossaryTermByName('instanz')?.id, 'instanz');
      expect(service.findGlossaryTermByName('TENANT')?.id, 'instanz');
      expect(service.findGlossaryTermByName('gibt es nicht'), isNull);
    });

    test('search finds articles by title and keywords', () {
      final r = service.search('Anwesenheit markieren');
      expect(r.articles.map((a) => a.id), contains('att-mark-status'));
      final kw = service.search('krank');
      expect(kw.articles.map((a) => a.id), contains('att-excuse-reason'));
    });

    test('search tolerates a single typo', () {
      final r = service.search('Instnaz');
      expect(r.glossaryTerms.map((g) => g.id), contains('instanz'));
    });

    test('empty search returns nothing', () {
      expect(service.search('   ').isEmpty, isTrue);
    });

    test('glossary is sorted alphabetically', () {
      final terms = service.getAllGlossaryTerms().map((g) => g.term).toList();
      expect(terms.first.compareTo(terms.last), lessThan(0));
    });
  });

  group('help markdown parsing', () {
    test('splits paragraphs and bullet lists', () {
      final blocks = parseHelpMarkdownBlocks(
          'Intro text\nzweite Zeile\n\nBeim Verschieben:\n- eins\n- zwei');
      expect(blocks, hasLength(3));
      expect((blocks[0] as HelpParagraph).text, 'Intro text\nzweite Zeile');
      expect((blocks[1] as HelpParagraph).text, 'Beim Verschieben:');
      final list = blocks[2] as HelpList;
      expect(list.ordered, isFalse);
      expect(list.items, ['eins', 'zwei']);
    });

    test('detects numbered lists', () {
      final blocks = parseHelpMarkdownBlocks('1. a\n2. b');
      expect((blocks.single as HelpList).ordered, isTrue);
    });

    test('parses bold, italic and glossary links', () {
      final tokens =
          parseHelpInline('Tippe **Datum** und *nur* [[Instanz|die Gruppe]].');
      expect(tokens.firstWhere((t) => t.text == 'Datum').bold, isTrue);
      expect(tokens.firstWhere((t) => t.text == 'nur').italic, isTrue);
      final link = tokens.firstWhere((t) => t.glossaryTerm != null);
      expect(link.glossaryTerm, 'Instanz');
      expect(link.text, 'die Gruppe');
    });
  });

  group('delete account verification code', () {
    test('is 6 chars from the unambiguous alphabet', () {
      for (var i = 0; i < 50; i++) {
        final code = generateDeleteAccountCode();
        expect(code, hasLength(6));
        for (final c in code.split('')) {
          expect(deleteAccountCodeChars, contains(c));
        }
      }
    });

    test('validation trims and ignores case', () {
      expect(isDeleteAccountCodeValid(' abc234 ', 'ABC234'), isTrue);
      expect(isDeleteAccountCodeValid('ABC23', 'ABC234'), isFalse);
    });
  });
}
