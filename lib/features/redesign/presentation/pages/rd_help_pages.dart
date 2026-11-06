import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../help/data/help_content_service.dart';
import '../../../help/data/help_models.dart';
import '../../../help/presentation/pages/help_page.dart' show helpCategoryIcon;
import '../../../help/presentation/widgets/glossary_term_popover.dart';
import '../../../help/presentation/widgets/help_markdown.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN (Ich und Einstieg, E3): Hilfe, Artikel and Glossar in the new
/// design. Same content and search as the old pages (help_content_service),
/// same routes under /settings/help.

void _back(BuildContext context, String fallback) => rdHelpBack(context, fallback);

/// Back from a help page: pop only when the page was pushed on top of
/// another page. On a direct call (link, reload) the nested route
/// `/settings/help` has `/settings` below it, so `canPop()` would lead
/// there; go to [fallback] instead.
@visibleForTesting
void rdHelpBack(BuildContext context, String fallback) {
  final matches = GoRouter.of(context).routerDelegate.currentConfiguration.matches;
  if (_lastIsPushed(matches) && context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Whether the top page was pushed. Pages inside a `ShellRoute` sit in the
/// shell's own match list, so follow the shells down.
bool _lastIsPushed(List<RouteMatchBase> matches) {
  if (matches.isEmpty) return false;
  final last = matches.last;
  if (last is ImperativeRouteMatch) return true;
  if (last is ShellRouteMatch) return _lastIsPushed(last.matches);
  return false;
}

/// Search field like on the Verwaltung page.
class _RdSearchField extends StatelessWidget {
  const _RdSearchField({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(p.buttonRadius),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, color: p.text2),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: p.text2),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: p.surface,
        border: border,
        enabledBorder: border,
      ),
    );
  }
}

/// /settings/help: search, topics (tap opens the articles below the topic),
/// glossary under "Nachschlagen".
class RdHelpPage extends ConsumerStatefulWidget {
  const RdHelpPage({super.key});

  @override
  ConsumerState<RdHelpPage> createState() => _RdHelpPageState();
}

class _RdHelpPageState extends ConsumerState<RdHelpPage> {
  final _search = TextEditingController();
  String _query = '';
  final Set<String> _open = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openArticle(String id) => context.push('/settings/help/article/$id');

  void _openGlossary() => context.push('/settings/help/glossary');

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final service = ref.watch(helpContentServiceProvider);
    final term = _query.trim();
    final results = term.isEmpty ? null : service.search(term);
    return RdPage(
      children: [
        RdBackLink(label: l10n.redesignTabMe, onTap: () => _back(context, RedesignRoutes.me)),
        Semantics(header: true, child: Text(l10n.helpTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 12),
        _RdSearchField(
          controller: _search,
          hint: l10n.redesignHelpSearch,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (results != null)
          results.isEmpty
              ? RdInfoCard(icon: Icons.search_off, text: l10n.helpNoHits(term))
              : RdGroupedList(
                  children: [
                    for (final a in results.articles)
                      RdListRow(
                        leading: RdRowIcon(Icons.description_outlined, color: p.primary, background: p.soft),
                        title: a.title,
                        subtitle: service.getCategories().where((c) => c.id == a.categoryId).firstOrNull?.label,
                        onTap: () => _openArticle(a.id),
                      ),
                    for (final g in results.glossaryTerms)
                      RdListRow(
                        leading: RdRowIcon(Icons.menu_book_outlined, color: p.primary, background: p.soft),
                        title: g.term,
                        subtitle: l10n.helpGlossary,
                        onTap: _openGlossary,
                      ),
                  ],
                )
        else ...[
          RdGroupLabel(l10n.helpTopics),
          RdGroupedList(
            children: [
              for (final c in service.getCategories()) ..._topic(c, service.getArticlesByCategory(c.id)),
            ],
          ),
          const SizedBox(height: 20),
          RdGroupLabel(l10n.helpLookup),
          RdGroupedList(
            children: [
              RdListRow(
                leading: RdRowIcon(Icons.menu_book_outlined, color: p.primary, background: p.soft),
                title: l10n.helpGlossary,
                subtitle: l10n.redesignHelpGlossaryHint,
                onTap: _openGlossary,
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _topic(HelpCategory c, List<HelpArticle> articles) {
    final p = context.rd;
    final open = _open.contains(c.id);
    return [
      Semantics(
        expanded: open,
        child: RdListRow(
          leading: RdRowIcon(helpCategoryIcon(c.icon), color: p.primary, background: p.soft),
          title: c.label,
          subtitle: context.l10n.redesignHelpArticles(articles.length),
          showChevron: false,
          trailing: Icon(open ? Icons.expand_less : Icons.expand_more, color: p.text2),
          onTap: () => setState(() => open ? _open.remove(c.id) : _open.add(c.id)),
        ),
      ),
      if (open)
        for (final a in articles)
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: RdListRow(title: a.title, onTap: () => _openArticle(a.id)),
          ),
    ];
  }
}

/// /settings/help/article/:id: back link with the topic, title, text in a
/// card; glossary words stay tappable.
class RdHelpArticlePage extends ConsumerWidget {
  const RdHelpArticlePage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final service = ref.watch(helpContentServiceProvider);
    final article = service.getArticle(articleId);
    final topic = article == null
        ? null
        : service.getCategories().where((c) => c.id == article.categoryId).firstOrNull?.label;
    return RdPage(
      children: [
        RdBackLink(label: topic ?? l10n.helpTitle, onTap: () => _back(context, '/settings/help')),
        if (article == null)
          RdInfoCard(icon: Icons.help_outline, text: l10n.helpArticleNotFound)
        else ...[
          Semantics(header: true, child: Text(article.title, style: RdType.largeTitle(p))),
          const SizedBox(height: 16),
          RdCard(
            child: HelpMarkdown(
              data: article.body,
              onGlossaryTap: (name, position) {
                final term = service.findGlossaryTermByName(name);
                if (term == null) return;
                showGlossaryTermPopover(
                  context,
                  term,
                  anchor: Rect.fromCenter(center: position, width: 1, height: 22),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// /settings/help/glossary: search, one term per row with its explanation
/// below.
class RdHelpGlossaryPage extends ConsumerStatefulWidget {
  const RdHelpGlossaryPage({super.key});

  @override
  ConsumerState<RdHelpGlossaryPage> createState() => _RdHelpGlossaryPageState();
}

class _RdHelpGlossaryPageState extends ConsumerState<RdHelpGlossaryPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final service = ref.watch(helpContentServiceProvider);
    final term = _query.trim().toLowerCase();
    final terms = term.isEmpty ? service.getAllGlossaryTerms() : service.search(term).glossaryTerms;
    return RdPage(
      children: [
        RdBackLink(label: l10n.helpTitle, onTap: () => _back(context, '/settings/help')),
        Semantics(header: true, child: Text(l10n.helpGlossary, style: RdType.largeTitle(p))),
        const SizedBox(height: 12),
        _RdSearchField(
          controller: _search,
          hint: l10n.helpSearchTerm,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (terms.isEmpty)
          RdInfoCard(icon: Icons.search_off, text: l10n.helpNoTerms)
        else
          RdGroupedList(
            children: [
              for (final g in terms)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.term, style: RdType.cardTitle(p)),
                      const SizedBox(height: 4),
                      HelpMarkdown(data: g.definition, style: RdType.meta(p, size: 15)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
