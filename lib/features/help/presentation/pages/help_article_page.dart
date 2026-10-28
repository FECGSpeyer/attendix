import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../widgets/glossary_term_dialog.dart';
import '../widgets/help_markdown.dart';
import '../../../../l10n/l10n.dart';

/// Single help article with tappable glossary references.
///
/// Port of Ionic `settings/help/article/help-article.page`.
class HelpArticlePage extends ConsumerWidget {
  const HelpArticlePage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(helpContentServiceProvider);
    final article = service.getArticle(articleId);

    return Scaffold(
      appBar: AppBar(title: Text(article?.title ?? context.l10n.helpTitle)),
      body: article == null
          ? Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Text(context.l10n.helpArticleNotFound),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: HelpMarkdown(
                    data: article.body,
                    onGlossaryTap: (name) {
                      final term = service.findGlossaryTermByName(name);
                      if (term != null) showGlossaryTermDialog(context, term);
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
