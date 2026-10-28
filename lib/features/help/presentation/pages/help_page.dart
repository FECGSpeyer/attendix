import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/help_content_service.dart';
import '../../data/help_models.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hilfe'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingM,
              0,
              AppDimensions.paddingM,
              AppDimensions.paddingS,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Frage oder Stichwort suchen...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchTerm.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchTerm = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
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
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (results.isEmpty)
                ListTile(title: Text('Keine Treffer für „$term“.')),
              for (final article in results.articles)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(article.title),
                  subtitle: const Text('Artikel'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openArticle(article.id),
                ),
              for (final g in results.glossaryTerms)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(g.term),
                  subtitle: const Text('Glossar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openGlossary,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(HelpContentService service) {
    final categories = service.getCategories();
    final headerStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.medium,
          fontWeight: FontWeight.w600,
        );

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.paddingXS,
          ),
          child: Text('Nachschlagen', style: headerStyle),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Glossar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openGlossary,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.paddingXS,
          ),
          child: Text('Themen', style: headerStyle),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final category in categories)
                ExpansionTile(
                  leading: Icon(helpCategoryIcon(category.icon)),
                  title: Text(category.label),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    for (final article
                        in service.getArticlesByCategory(category.id))
                      ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 72,
                          right: AppDimensions.paddingM,
                        ),
                        title: Text(article.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openArticle(article.id),
                      ),
                  ],
                ),
            ],
          ),
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
