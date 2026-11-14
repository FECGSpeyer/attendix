import 'package:flutter/material.dart';
import '../../../../shared/widgets/layout/ion_form_items.dart' show IonArrowBackButton;
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../redesign/presentation/pages/rd_help_pages.dart';
import '../../data/help_models.dart';
import '../../../../l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../settings/presentation/widgets/settings_list.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/adaptive/ion_accordion_tile.dart';

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
    // REDESIGN (E3): Beta page on the same route.
    if (ref.watch(redesignEnabledProvider)) return const RdHelpPage();
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
        // EIB-12: Ionic custom `arrow-back` ion-button (glass circle on iOS).
        leading: IonArrowBackButton(onPressed: () => Navigator.of(context).maybePop()),
        leadingWidth: IonArrowBackButton.leadingWidth(context),
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
      // EIB-21: Ionic inset list margin (iOS 20).
      padding: EdgeInsets.fromLTRB(ionListMargin(context), AppDimensions.paddingM, ionListMargin(context), scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        const IonContentTopInset(),
        SettingsListSection(
          children: [
            if (results.isEmpty)
              ListTile(title: Text(context.l10n.helpNoHits(term))),
            for (final article in results.articles)
              SettingsListTile(
                icon: AppIcons.descriptionOutlined,
                title: article.title,
                subtitle: context.l10n.helpArticles,
                onTap: () => _openArticle(article.id),
              ),
            for (final g in results.glossaryTerms)
              SettingsListTile(
                icon: AppIcons.menuBookOutlined,
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
      // EIB-21: Ionic inset list margin (iOS 20).
      padding: EdgeInsets.fromLTRB(ionListMargin(context), AppDimensions.paddingM, ionListMargin(context), scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        const IonContentTopInset(),
        SettingsListSection(
          title: context.l10n.helpLookup,
          children: [
            SettingsListTile(
              icon: AppIcons.menuBookOutlined,
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
              IonAccordionTile(
                leading: Icon(
                  helpCategoryIcon(category.icon),
                  color: ios ? IonIos.text(context) : null,
                  size: ios ? IonIos.itemIconSize : null,
                ),
                title: Text(category.label),
                children: [
                  for (final article
                      in service.getArticlesByCategory(category.id))
                    // EIB-11: plain `ion-item button detail="true"` (item
                    // padding, Ionic detail chevron) in both looks.
                    SettingsListTile(
                      title: article.title,
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
    'rocket-outline' => AppIcons.rocketLaunchOutlined,
    'checkmark-done-outline' => AppIcons.doneAll,
    'people-outline' => AppIcons.peopleOutline,
    // PARITY_R7: closest glyphs to the Ionicons (bulleted list, two beamed
    // notes, people in a circle, three dots in a circle).
    'list-outline' => AppIcons.formatListBulleted,
    'musical-notes-outline' => AppIcons.cupertinoMusicNote2,
    'person-circle-outline' => AppIcons.accountCircleOutlined,
    'settings-outline' => AppIcons.settingsOutlined,
    'people-circle-outline' => AppIcons.supervisedUserCircleOutlined,
    'headset-outline' => AppIcons.headsetMicOutlined,
    'ellipsis-horizontal-circle-outline' => AppIcons.pendingOutlined,
    _ => AppIcons.helpOutline,
  };
}
