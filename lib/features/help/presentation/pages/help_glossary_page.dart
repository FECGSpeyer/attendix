import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/help_content_service.dart';
import '../widgets/help_markdown.dart';

/// Alphabetical glossary with search.
///
/// Port of Ionic `settings/help/glossary/help-glossary.page`.
class HelpGlossaryPage extends ConsumerStatefulWidget {
  const HelpGlossaryPage({super.key});

  @override
  ConsumerState<HelpGlossaryPage> createState() => _HelpGlossaryPageState();
}

class _HelpGlossaryPageState extends ConsumerState<HelpGlossaryPage> {
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(helpContentServiceProvider);
    final term = _searchTerm.trim().toLowerCase();
    final terms = term.isEmpty
        ? service.getAllGlossaryTerms()
        : service.search(term).glossaryTerms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glossar'),
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
              decoration: const InputDecoration(
                hintText: 'Begriff suchen...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (terms.isEmpty)
                  const ListTile(title: Text('Keine Begriffe gefunden.')),
                for (final g in terms)
                  ExpansionTile(
                    key: PageStorageKey('glossary-${g.id}'),
                    title: Text(g.term),
                    shape: const Border(),
                    collapsedShape: const Border(),
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
          ),
        ],
      ),
    );
  }
}
