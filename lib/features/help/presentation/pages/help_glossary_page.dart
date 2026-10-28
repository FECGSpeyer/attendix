import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../widgets/help_markdown.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

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
    final service = ref.watch(helpContentServiceProvider);
    final term = _searchTerm.trim().toLowerCase();
    final terms = term.isEmpty
        ? service.getAllGlossaryTerms()
        : service.search(term).glossaryTerms;
    final ios = ionIsIos(context);

    // UX_SETTINGS (WAVE 8): help-glossary.page.html — arrow-back,
    // searchbar toolbar, one inset list of accordions.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.l10n.helpGlossary),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(ios ? 60 : 64),
          child: IonSearchbar(
            controller: _searchController,
            hint: context.l10n.helpSearchTerm,
            onChanged: (v) => setState(() => _searchTerm = v),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
        children: [
          SettingsListSection(
            icons: false,
            children: [
              if (terms.isEmpty)
                ListTile(title: Text(context.l10n.helpNoTerms)),
              for (final g in terms)
                ExpansionTile(
                  key: PageStorageKey('glossary-${g.id}'),
                  title: Text(g.term),
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
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingM,
                    0,
                    AppDimensions.paddingM,
                    AppDimensions.paddingM,
                  ),
                  expandedAlignment: Alignment.centerLeft,
                  children: [HelpMarkdown(data: g.definition)],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
