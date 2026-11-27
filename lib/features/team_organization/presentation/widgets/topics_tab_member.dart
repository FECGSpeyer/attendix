part of 'topics_tab.dart';

// ── Members ──────────────────────────────────────────────────

/// "Thema vorschlagen": the member's suggestion sheet.
Future<void> showSuggestTopicSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => const _SuggestSheet(),
  );
  if (result == true && context.mounted) ToastHelper.showSuccess(context, context.l10n.teamOrgSuggestionSent);
}

class _MemberTopics extends ConsumerWidget {
  const _MemberTopics();

  Future<void> _suggest(BuildContext context, WidgetRef ref) => showSuggestTopicSheet(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(agendaItemsProvider);
    final l10n = context.l10n;
    ref.listen(agendaItemsProvider, (_, next) {
      if (next is AsyncError && !next.isLoading) ToastHelper.showError(context, l10n.agendaLoadFailed);
    });

    Widget content(List<AgendaItem> items) {
              final sorted = [...items]..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
              return IonInsetList(
                header: l10n.teamOrgMySuggestions,
                children: [
                  if (sorted.isEmpty)
                    ListTile(
                      title: Text(l10n.teamOrgNothingSuggested, style: TextStyle(color: AppColors.mediumOf(context))),
                    ),
                  for (final item in sorted)
                    ListTile(
                      title: Text(item.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.proposalStatus == 'accepted'
                                ? l10n.teamOrgAcceptedByLeaders
                                : l10n.teamOrgSubmittedOn(_date(item.createdAt)),
                            style: TextStyle(color: AppColors.mediumOf(context)),
                          ),
                          if (item.proposalStatus == 'rejected' && item.decisionNote?.isNotEmpty == true)
                            Text('„${item.decisionNote}“',
                                style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.mediumOf(context))),
                        ],
                      ),
                      trailing: TeamOrgBadge(
                        label: suggestionStatusLabel(item),
                        color: switch (item.proposalStatus) {
                          'accepted' => AppColors.success,
                          'rejected' => AppColors.danger,
                          _ => AppColors.mediumOf(context),
                        },
                      ),
                    ),
                ],
              );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () => reloadTeamOrgTab(ref, 'topics'),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Ionic: inset list with the hint item and a block button.
          IonInsetList(
            dividerIndent: null,
            children: [
              ListTile(
                title: Text(l10n.teamOrgSuggestTopic),
                subtitle: Text(l10n.teamOrgSuggestHint, style: TextStyle(color: AppColors.mediumOf(context))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _suggest(context, ref),
                  icon: Icon(AppIcons.lightbulbOutline),
                  label: IonButtonLabel(l10n.teamOrgSuggestTopic),
                ),
              ),
            ],
          ),
          // Ionic: on an error a red toast, the list stays (none → empty).
          itemsAsync.when(
            skipError: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: AppSpinner()),
            ),
            error: (_, __) => content(const []),
            data: content,
          ),
        ],
      ),
    );
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    return d == null ? '' : DateFormat(dateFmt()).format(d);
  }
}

class _SuggestSheet extends ConsumerStatefulWidget {
  const _SuggestSheet();

  @override
  ConsumerState<_SuggestSheet> createState() => _SuggestSheetState();
}

class _SuggestSheetState extends ConsumerState<_SuggestSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.agendaEnterTitle);
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final desc = _description.text.trim();
      await ref.read(agendaItemNotifierProvider.notifier).propose(title, desc.isEmpty ? null : desc);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.teamOrgSuggestionFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Ionic: sheet hint, inset list with stacked title/description, block button.
    final hint = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(l10n.teamOrgSuggestHint, style: TextStyle(fontSize: 13, color: AppColors.mediumOf(context))),
    );
    final fields = IonInsetList(
      children: [
        IonStackedInput(
          controller: _title,
          label: l10n.tasksTitle,
          hint: l10n.teamOrgTitlePlaceholder,
        ),
        IonStackedInput(
          controller: _description,
          label: l10n.tasksDescription,
          hint: l10n.teamOrgDescPlaceholder,
          minLines: 4,
          maxLines: 8,
        ),
      ],
    );
    final button = FilledButton(
      onPressed: _title.text.trim().isEmpty || _sending ? null : _send,
      child: IonButtonLabel(l10n.teamOrgSendSuggestion),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            toolbarHeight: ionModalToolbarHeight(context),
            automaticallyImplyLeading: false,
            leading: TextButton(onPressed: () => Navigator.of(context).pop(), child: IonButtonLabel(l10n.commonCancel)),
            leadingWidth: 100,
            title: Text(l10n.teamOrgSuggestTopic),
          ),
          hint,
          fields,
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, child: button),
            ),
          ),
        ],
      ),
    );
  }
}
