import 'package:flutter/material.dart';
import '../../../../shared/widgets/layout/ion_form_items.dart' show IonArrowBackButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../redesign/presentation/pages/rd_help_pages.dart';
import '../widgets/help_markdown.dart';
import '../../../../l10n/l10n.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../settings/presentation/widgets/settings_list.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import 'package:attendix/shared/widgets/adaptive/ion_accordion_tile.dart';

/// Alphabetical glossary with search.
///
/// Port of Ionic `settings/help/glossary/help-glossary.page`.
class HelpGlossaryPage extends ConsumerStatefulWidget {
  const HelpGlossaryPage({super.key});

  @override
  ConsumerState<HelpGlossaryPage> createState() => _HelpGlossaryPageState();
}

class _HelpGlossaryPageState extends ConsumerState<HelpGlossaryPage> {
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // REDESIGN (E3): Beta page on the same route.
    if (ref.watch(redesignEnabledProvider)) return const RdHelpGlossaryPage();
    final service = ref.watch(helpContentServiceProvider);
    final term = _searchTerm.trim().toLowerCase();
    final terms = term.isEmpty
        ? service.getAllGlossaryTerms()
        : service.search(term).glossaryTerms;
    final ios = ionIsIos(context);

    // UX_SETTINGS (WAVE 8): help-glossary.page.html — arrow-back,
    // searchbar toolbar, one inset list of accordions.
    return Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the
      // `ion-header translucent` (no large title: always blurred)
      extendBodyBehindAppBar: ios,
      appBar: IonTranslucentAppBar(child: AppBar(
        // EIB-12: Ionic custom `arrow-back` ion-button (glass circle on iOS).
        leading: IonArrowBackButton(onPressed: () => Navigator.of(context).maybePop()),
        leadingWidth: IonArrowBackButton.leadingWidth(context),
        title: Text(context.l10n.helpGlossary),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(ios ? 60 : 64),
          child: IonSearchbar(
            controller: _searchController,
            hint: context.l10n.helpSearchTerm,
            onChanged: (v) => setState(() => _searchTerm = v),
          ),
        ),
      )),
      body: ListView(
        // EIB-21: Ionic inset list margin (iOS 20).
      padding: EdgeInsets.fromLTRB(ionListMargin(context), AppDimensions.paddingM, ionListMargin(context), scrollEndPadding(context, base: AppDimensions.paddingM)),
        children: [
          const IonContentTopInset(),
          SettingsListSection(
            icons: false,
            children: [
              if (terms.isEmpty)
                ListTile(title: Text(context.l10n.helpNoTerms)),
              for (final g in terms)
                IonAccordionTile(
                  key: PageStorageKey('glossary-${g.id}'),
                  title: Text(g.term),
                  chevronColor: ios ? IonIos.text(context).withValues(alpha: 0.5) : null,
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingM,
                    0,
                    AppDimensions.paddingM,
                    AppDimensions.paddingM,
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [HelpMarkdown(data: g.definition)],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
