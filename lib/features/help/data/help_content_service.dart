import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/locale_provider.dart';
import 'help_content.dart';
import 'help_content_en.dart';
import 'help_models.dart';

/// Help-center content access + search.
///
/// Port of Ionic `services/help/help-content.service.ts`. Ionic uses Fuse.js
/// (weighted fuzzy search, threshold 0.35); this is a dependency-free
/// approximation: every query token must match a field either as substring or
/// (for tokens of 4+ chars) as a word with edit distance <= 1. Matches are
/// scored with the same field weights as Ionic (title 2, keywords 1.5, body 1;
/// glossary: term 2, aliases 1.5, definition 1).
class HelpContentService {
  const HelpContentService({
    this.categories = helpCategories,
    this.articles = helpArticles,
    this.glossary = glossaryTerms,
  });

  final List<HelpCategory> categories;
  final List<HelpArticle> articles;
  final List<GlossaryTerm> glossary;

  List<HelpCategory> getCategories() =>
      [...categories]..sort((a, b) => a.order.compareTo(b.order));

  List<HelpArticle> getArticlesByCategory(String categoryId) =>
      articles.where((a) => a.categoryId == categoryId).toList();

  HelpArticle? getArticle(String id) {
    for (final a in articles) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<GlossaryTerm> getAllGlossaryTerms() => [...glossary]
    ..sort((a, b) => _collationKey(a.term).compareTo(_collationKey(b.term)));

  GlossaryTerm? getGlossaryTerm(String id) {
    for (final g in glossary) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Matches a glossary term by display name or alias (case-insensitive).
  GlossaryTerm? findGlossaryTermByName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final g in glossary) {
      if (g.term.toLowerCase() == normalized ||
          g.aliases.any((a) => a.toLowerCase() == normalized)) {
        return g;
      }
    }
    return null;
  }

  HelpSearchResults search(String query) {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return HelpSearchResults.empty;

    final scoredArticles = <(HelpArticle, double)>[];
    for (final a in articles) {
      final score = _score(tokens, [
        (_strip(a.title), 2.0),
        (a.keywords.join(' ').toLowerCase(), 1.5),
        (_strip(a.body), 1.0),
      ]);
      if (score > 0) scoredArticles.add((a, score));
    }

    final scoredTerms = <(GlossaryTerm, double)>[];
    for (final g in glossary) {
      final score = _score(tokens, [
        (g.term.toLowerCase(), 2.0),
        (g.aliases.join(' ').toLowerCase(), 1.5),
        (_strip(g.definition), 1.0),
      ]);
      if (score > 0) scoredTerms.add((g, score));
    }

    scoredArticles.sort((a, b) => b.$2.compareTo(a.$2));
    scoredTerms.sort((a, b) => b.$2.compareTo(a.$2));

    return HelpSearchResults(
      articles: scoredArticles.map((e) => e.$1).toList(),
      glossaryTerms: scoredTerms.map((e) => e.$1).toList(),
    );
  }

  // --- internals -----------------------------------------------------------

  static final _wordSplit = RegExp(r'[^\wäöüß]+', unicode: true);

  static List<String> _tokenize(String query) => query
      .trim()
      .toLowerCase()
      .split(_wordSplit)
      .where((t) => t.isNotEmpty)
      .toList();

  /// Lowercases and removes markdown/glossary markup.
  static String _strip(String text) => text
      .replaceAllMapped(
        RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
        (m) => '${m[1]} ${m[2] ?? ''}',
      )
      .replaceAll('*', '')
      .toLowerCase();

  static String _collationKey(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss');

  /// Returns 0 if any token matches no field, otherwise a weighted score.
  static double _score(List<String> tokens, List<(String, double)> fields) {
    var total = 0.0;
    for (final token in tokens) {
      var best = 0.0;
      for (final (text, weight) in fields) {
        if (text.isEmpty) continue;
        double s = 0;
        if (text.contains(token)) {
          s = weight;
        } else if (token.length >= 4 && _fuzzyWordMatch(token, text)) {
          s = weight * 0.6;
        }
        if (s > best) best = s;
      }
      if (best == 0) return 0;
      total += best;
    }
    return total;
  }

  static bool _fuzzyWordMatch(String token, String text) {
    for (final word in text.split(_wordSplit)) {
      if ((word.length - token.length).abs() > 1) {
        // Allow prefix match with one typo for longer words.
        if (word.length > token.length &&
            _withinOneEdit(token, word.substring(0, token.length))) {
          return true;
        }
        continue;
      }
      if (_withinOneEdit(token, word)) return true;
    }
    return false;
  }

  static bool _withinOneEdit(String a, String b) {
    if (a == b) return true;
    if ((a.length - b.length).abs() > 1) return false;
    // Adjacent transposition ("Instnaz" ~ "Instanz") counts as one edit.
    if (a.length == b.length) {
      var k = 0;
      while (k < a.length && a[k] == b[k]) {
        k++;
      }
      if (k + 1 < a.length &&
          a[k] == b[k + 1] &&
          a[k + 1] == b[k] &&
          a.substring(k + 2) == b.substring(k + 2)) {
        return true;
      }
    }
    var i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (a.length < b.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    edits += (a.length - i) + (b.length - j);
    return edits <= 1;
  }
}

/// Help content in the UI language (Ionic `localizeHelp`): untranslated
/// entries stay German; translated glossary terms keep their German name as
/// alias so `[[Begriff]]` links in German articles still resolve.
HelpContentService localizedHelpContentService(String language) {
  if (language != 'en') return const HelpContentService();
  return HelpContentService(
    categories: [
      for (final c in helpCategories)
        HelpCategory(
          id: c.id,
          label: helpCategoriesEn[c.id] ?? c.label,
          icon: c.icon,
          order: c.order,
        ),
    ],
    articles: [
      for (final a in helpArticles)
        if (helpArticlesEn[a.id] case final t?)
          HelpArticle(
            id: a.id,
            title: t.title,
            categoryId: a.categoryId,
            keywords: t.keywords,
            body: t.body,
          )
        else
          a,
    ],
    glossary: [
      for (final g in glossaryTerms)
        if (glossaryTermsEn[g.id] case final t?)
          GlossaryTerm(
            id: g.id,
            term: t.term,
            aliases: [...t.aliases, g.term, ...g.aliases],
            definition: t.definition,
          )
        else
          g,
    ],
  );
}

/// Help content service (German content ported from Ionic, English
/// translation from Ionic content/en), following the UI language.
final helpContentServiceProvider = Provider<HelpContentService>(
  (ref) => localizedHelpContentService(ref.watch(localeProvider).languageCode),
);
