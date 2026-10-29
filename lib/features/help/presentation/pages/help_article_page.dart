import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../widgets/glossary_term_dialog.dart';
import '../widgets/help_markdown.dart';
import '../../../../l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset; // IOS_R6
import 'package:attendix/shared/widgets/adaptive/adaptive_platform.dart' show useIosLook; // IOS_R6
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

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
      // UX_SETTINGS (WAVE 8): help-article.page.html — arrow-back button.
      // IOS_R6: Ionic `ion-content fullscreen` under the
      // `ion-header translucent` (no large title: always blurred)
      extendBodyBehindAppBar: useIosLook(context),
      appBar: IonTranslucentAppBar(child: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(article?.title ?? context.l10n.helpTitle),
      )),
      body: article == null
          ? SafeArea( // IOS_R6: below the translucent toolbar
              bottom: false,
              child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Text(context.l10n.helpArticleNotFound),
            ))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
              child: Column(
                children: [
                  const IonContentTopInset(), // IOS_R6
                  Center(
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
                ],
              ),
            ),
    );
  }
}
