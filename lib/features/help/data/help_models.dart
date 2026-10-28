/// Static help-center content types.
///
/// Mirrors Ionic `src/app/settings/help/content/types.ts`. The content is
/// authored in-repo (see `help_content.dart`), so plain const classes are used
/// instead of Freezed models (no JSON, no copyWith needed).
library;

class HelpCategory {
  const HelpCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.order,
  });

  final String id;
  final String label;

  /// Ionicons name from the Ionic source (mapped in the UI layer).
  final String icon;
  final int order;
}

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.keywords,
    required this.body,
  });

  final String id;
  final String title;
  final String categoryId;

  /// Extra search terms beyond the title/body (synonyms, abbreviations, ...).
  final List<String> keywords;

  /// Markdown body; `[[Begriff]]` / `[[Begriff|Text]]` link to the glossary.
  final String body;
}

class GlossaryTerm {
  const GlossaryTerm({
    required this.id,
    required this.term,
    this.aliases = const [],
    required this.definition,
  });

  final String id;
  final String term;

  /// Alternate spellings/synonyms that should also resolve to this entry.
  final List<String> aliases;
  final String definition;
}

class HelpSearchResults {
  const HelpSearchResults({
    required this.articles,
    required this.glossaryTerms,
  });

  static const empty = HelpSearchResults(articles: [], glossaryTerms: []);

  final List<HelpArticle> articles;
  final List<GlossaryTerm> glossaryTerms;

  bool get isEmpty => articles.isEmpty && glossaryTerms.isEmpty;
}

/// English (or other UI language) translation of one German help article,
/// keyed by the article id (Ionic `HelpArticleTranslation`).
class HelpArticleTranslation {
  const HelpArticleTranslation({
    required this.title,
    required this.keywords,
    required this.body,
  });

  final String title;
  final List<String> keywords;
  final String body;
}

/// Translation of one German glossary term (Ionic `GlossaryTermTranslation`).
class GlossaryTermTranslation {
  const GlossaryTermTranslation({
    required this.term,
    this.aliases = const [],
    required this.definition,
  });

  final String term;
  final List<String> aliases;
  final String definition;
}
