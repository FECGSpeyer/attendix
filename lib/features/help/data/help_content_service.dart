import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/locale_provider.dart';
import 'fuse_search.dart';
import 'help_content.dart';
import 'help_content_app.dart';
import 'help_content_en.dart';
import 'help_models.dart';

/// Help-center content access + search.
///
/// Port of Ionic `services/help/help-content.service.ts`; the search is a
/// Dart port of the Fuse.js search Ionic uses (see [FuseSearch]).
class HelpContentService {
  const HelpContentService({
    this.categories = helpCategories,
    this.articles = allHelpArticles,
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

  /// Fuse.js search like Ionic (raw texts, no markdown stripping): title 2,
  /// keywords 1.5, body 1; glossary term 2, aliases 1.5, definition 1.
  HelpSearchResults search(String query) {
    final term = query.trim();
    if (term.isEmpty) return HelpSearchResults.empty;
    return HelpSearchResults(
      articles: FuseSearch<HelpArticle>(articles, [
        (weight: 2, get: (a) => [a.title]),
        (weight: 1.5, get: (a) => a.keywords),
        (weight: 1, get: (a) => [a.body]),
      ]).search(term),
      glossaryTerms: FuseSearch<GlossaryTerm>(glossary, [
        (weight: 2, get: (g) => [g.term]),
        (weight: 1.5, get: (g) => g.aliases),
        (weight: 1, get: (g) => [g.definition]),
      ]).search(term),
    );
  }

  static String _collationKey(String s) => s
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss');
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
      for (final a in allHelpArticles)
        if (allHelpArticlesEn[a.id] case final t?)
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
