import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../../data/help_models.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

/// Help center overview: search, glossary entry and topic accordions.
///
/// Port of Ionic `settings/help/help.page`.
class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openArticle(String id) => context.push('/settings/help/article/$id');

  void _openGlossary() => context.push('/settings/help/glossary');

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(helpContentServiceProvider);
    final term = _searchTerm.trim();
    final results = term.isEmpty ? null : service.search(term);
    final ios = ionIsIos(context);

    // UX_SETTINGS (WAVE 8): help.page.html — arrow-back, searchbar toolbar,
    // inset lists ("Nachschlagen" + topic accordions) on the light page.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.l10n.helpTitle),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(ios ? 60 : 64),
          child: IonSearchbar(
            controller: _searchController,
            hint: context.l10n.helpSearchPlaceholder,
            onChanged: (v) => setState(() => _searchTerm = v),
          ),
        ),
      ),
      body: results != null
          ? _buildSearchResults(results, term)
          : _buildOverview(service),
    );
  }

  Widget _buildSearchResults(HelpSearchResults results, String term) {
    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        SettingsListSection(
          children: [
            if (results.isEmpty)
              ListTile(title: Text(context.l10n.helpNoHits(term))),
            for (final article in results.articles)
              SettingsListTile(
                icon: Icons.description_outlined,
                title: article.title,
                subtitle: context.l10n.helpArticles,
                onTap: () => _openArticle(article.id),
              ),
            for (final g in results.glossaryTerms)
              SettingsListTile(
                icon: Icons.menu_book_outlined,
                title: g.term,
                subtitle: context.l10n.helpGlossary,
                onTap: _openGlossary,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverview(HelpContentService service) {
    final categories = service.getCategories();
    final ios = ionIsIos(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        SettingsListSection(
          title: context.l10n.helpLookup,
          children: [
            SettingsListTile(
              icon: Icons.menu_book_outlined,
              title: context.l10n.helpGlossary,
              onTap: _openGlossary,
            ),
          ],
        ),
        // ion-accordion-group: header item with start icon, the articles as
        // plain detail items below it.
        SettingsListSection(
          title: context.l10n.helpTopics,
          children: [
            for (final category in categories)
              ExpansionTile(
                leading: Icon(helpCategoryIcon(category.icon)),
                title: Text(category.label),
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: ios
                    ? const EdgeInsets.only(
                        left: IonIos.itemPaddingStart,
                        right: IonIos.itemPaddingEnd,
                      )
                    : null,
                iconColor: ios ? IonIos.text(context).withValues(alpha: 0.5) : null,
                collapsedIconColor:
                    ios ? IonIos.text(context).withValues(alpha: 0.5) : null,
                children: [
                  for (final article
                      in service.getArticlesByCategory(category.id))
                    ListTile(
                      contentPadding: ios
                          ? null
                          : const EdgeInsets.only(
                              left: 72,
                              right: AppDimensions.paddingM,
                            ),
                      title: Text(article.title),
                      trailing: ios
                          ? const IonDetailChevron()
                          : const Icon(Icons.chevron_right),
                      onTap: () => _openArticle(article.id),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Maps the Ionicons names used in the Ionic help categories to Material icons.
IconData helpCategoryIcon(String ionIcon) {
  return switch (ionIcon) {
    'rocket-outline' => Icons.rocket_launch_outlined,
    'checkmark-done-outline' => Icons.done_all,
    'people-outline' => Icons.people_outline,
    'list-outline' => Icons.list_alt_outlined,
    'musical-notes-outline' => Icons.music_note_outlined,
    'person-circle-outline' => Icons.account_circle_outlined,
    'settings-outline' => Icons.settings_outlined,
    'people-circle-outline' => Icons.groups_outlined,
    'headset-outline' => Icons.headset_mic_outlined,
    'ellipsis-horizontal-circle-outline' => Icons.more_horiz,
    _ => Icons.help_outline,
  };
}
