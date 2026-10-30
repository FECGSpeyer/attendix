import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../../data/help_models.dart';
import '../../../../l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../settings/presentation/widgets/settings_list.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

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
      // IOS_R6: Ionic `ion-content fullscreen` under the
      // `ion-header translucent` (no large title: always blurred)
      extendBodyBehindAppBar: ios,
      appBar: IonTranslucentAppBar(child: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, semanticLabel: context.l10n.commonBack),
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
      )),
      body: _noHoverOnIos(
        results != null
            ? _buildSearchResults(results, term)
            : _buildOverview(service),
      ),
    );
  }

  /// IOS_FORMS1: Ionic iOS items have no hover / focus tint, so a tapped
  /// row does not stay highlighted.
  Widget _noHoverOnIos(Widget child) {
    if (!ionIsIos(context)) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      child: child,
    );
  }

  Widget _buildSearchResults(HelpSearchResults results, String term) {
    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        const IonContentTopInset(),
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
        const IonContentTopInset(),
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
              // IOS_FORMS1: ion-accordion header item – start icon and the
              // toggle chevron inherit the black item text colour (iOS).
              ExpansionTile(
                leading: Icon(
                  helpCategoryIcon(category.icon),
                  color: ios ? IonIos.text(context) : null,
                  size: ios ? IonIos.itemIconSize : null,
                ),
                title: Text(category.label),
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: ios
                    ? const EdgeInsets.only(
                        left: IonIos.itemPaddingStart,
                        right: IonIos.itemPaddingEnd,
                      )
                    : null,
                iconColor: ios ? IonIos.text(context) : null,
                collapsedIconColor: ios ? IonIos.text(context) : null,
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
    // PARITY_R7: closest glyphs to the Ionicons (bulleted list, two beamed
    // notes, people in a circle, three dots in a circle).
    'list-outline' => Icons.format_list_bulleted,
    'musical-notes-outline' => CupertinoIcons.music_note_2,
    'person-circle-outline' => Icons.account_circle_outlined,
    'settings-outline' => Icons.settings_outlined,
    'people-circle-outline' => Icons.supervised_user_circle_outlined,
    'headset-outline' => Icons.headset_mic_outlined,
    'ellipsis-horizontal-circle-outline' => Icons.pending_outlined,
    _ => Icons.help_outline,
  };
}
