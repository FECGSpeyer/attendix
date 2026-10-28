import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../team_org_utils.dart';
import 'agenda_picker_sheet.dart';
import 'quick_create_attendance.dart';
import 'tasks_tab.dart' show TeamOrgBadge, TeamOrgListSkeleton, priorityColor;
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

/// Tab "Themen": leadership reviews suggestions, plans the next Termin and
/// keeps the Themenspeicher; members suggest topics and see their suggestions.
class TopicsTab extends ConsumerWidget {
  const TopicsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    if (isLeader) return const _LeaderTopics();
    if (ref.watch(inTeamCircleProvider)) return const _MemberTopics();
    // Ionic `.topic-empty` (chatbubbles icon, grey text).
    return ListView(children: [
      IonEmptyState(
        icon: Icons.forum_outlined,
        iconSize: 48,
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
        text: context.l10n.teamOrgLeadersPlan,
      ),
    ]);
  }
}

// ── Leadership ───────────────────────────────────────────────

class _LeaderTopics extends ConsumerStatefulWidget {
  const _LeaderTopics();

  @override
  ConsumerState<_LeaderTopics> createState() => _LeaderTopicsState();
}

class _LeaderTopicsState extends ConsumerState<_LeaderTopics> {
  int? _chosenAttendanceId;
  bool _showDone = false;
  final Set<String> _deciding = {};

  ProtocolType? _typeOf(ProtocolAttendance att, List<ProtocolType> types) {
    for (final t in types) {
      if (t.id == att.typeId) return t;
    }
    return null;
  }

  String _attendanceTitle(ProtocolAttendance att, List<ProtocolType> types) =>
      '${attendanceTitle(att.typeInfo, _typeOf(att, types))} · ${formatShortWeekdayDate(att.date)}';

  Future<void> _changeAttendance(
      List<ProtocolAttendance> upcoming, ProtocolAttendance? current, List<ProtocolType> types) async {
    final choice = await showAppActionSheet<Object>(
      context,
      title: context.l10n.teamOrgPlanForWhich,
      actions: [
        for (final att in upcoming.take(8))
          AppActionSheetAction(
            value: att.id,
            icon: att.id == current?.id ? Icons.check : null,
            label: _attendanceTitle(att, types),
          ),
        if (current != null)
          AppActionSheetAction(
            value: 'date',
            icon: Icons.calendar_today_outlined,
            label: context.l10n.teamOrgChangeDate,
          ),
        AppActionSheetAction(
          value: 'new',
          icon: Icons.add_circle_outline,
          label: context.l10n.agendaNewEvent,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice is int) {
      setState(() => _chosenAttendanceId = choice);
    } else if (choice == 'date' && current != null) {
      // Date changes happen on the attendance page.
      await context.push('/attendance/${current.id}');
      ref.invalidate(upcomingProtocolAttendancesProvider);
    } else if (choice == 'new') {
      await _createAttendance();
    }
  }

  /// "Termin anlegen" (Ionic `createAttendance`): quick-create and select it.
  Future<void> _createAttendance() async {
    final id = await promptCreateProtocolAttendance(context, ref);
    if (id == null || !mounted) return;
    setState(() => _chosenAttendanceId = id);
    ref.invalidate(upcomingProtocolAttendancesProvider);
  }

  Future<void> _topAction(PlanField top, ProtocolAttendance att, ProtocolType? type) async {
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    final action = await showAppActionSheet<String>(
      context,
      title: fieldName(top),
      actions: [
        AppActionSheetAction(value: 'open', label: context.l10n.teamOrgOpenTopic),
        AppActionSheetAction(value: 'remove', label: context.l10n.teamOrgRemoveFromEvent, destructive: true),
      ],
    );
    if (!mounted) return;
    final agendaId = fieldAgendaItemId(top);
    if (action == 'open' && agendaId != null) {
      context.push('/settings/agenda-items/$agendaId');
    } else if (action == 'remove' && agendaId != null) {
      try {
        await addTopicsToAttendance(protocolRepo, att, type, const [],
            removeIds: [agendaId]);
        ref.invalidate(upcomingProtocolAttendancesProvider);
        if (mounted) ToastHelper.showInfo(context, context.l10n.teamOrgRemovedStays);
      } catch (_) {
        if (mounted) ToastHelper.showError(context, context.l10n.teamOrgRemoveFailed);
      }
    }
  }

  Future<void> _accept(AgendaItem item) async {
    final l10n = context.l10n;
    var priority = item.priority;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(ctx.l10n.teamOrgAcceptSuggestion),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.l10n.teamOrgWhichPriority),
              for (final p in const ['high', 'medium', 'low'])
                RadioListTile<String>(
                  value: p,
                  groupValue: priority,
                  title: Text(priorityLabels[p]!),
                  onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(ctx.l10n.commonApply)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _decide(item, {'proposal_status': 'accepted', 'priority': priority, 'decision_note': null},
        l10n.teamOrgSuggestionAccepted);
  }

  Future<void> _reject(AgendaItem item) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final name = item.proposer.fullName.isNotEmpty ? item.proposer.fullName : l10n.teamOrgThePerson;
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.teamOrgRejectSuggestion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.l10n.teamOrgPersonInformed(name)),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(hintText: ctx.l10n.teamOrgReasonOptional),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(ctx.l10n.teamOrgReject)),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (ok != true) return;
    await _decide(item, {'proposal_status': 'rejected', 'decision_note': note.isEmpty ? null : note},
        l10n.teamOrgSuggestionRejected);
  }

  Future<void> _decide(AgendaItem item, Map<String, dynamic> changes, String doneText) async {
    final id = item.id;
    if (id == null || _deciding.contains(id)) return;
    setState(() => _deciding.add(id));
    try {
      await ref.read(agendaItemNotifierProvider.notifier).decide(id, changes);
      if (mounted) ToastHelper.showSuccess(context, doneText);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.teamOrgDecisionFailed);
    } finally {
      if (mounted) setState(() => _deciding.remove(id));
    }
  }

  Future<void> _openReview() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final items = ref.watch(agendaItemsProvider).valueOrNull ?? const <AgendaItem>[];
        final pending = splitTopics(items).pending;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: ctx.l10n.commonClose,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                title: Text(ctx.l10n.teamOrgSuggestions),
              ),
              Expanded(
                child: ColoredBox(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Ionic `.sheet-hint`
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Text(pending.isEmpty ? ctx.l10n.teamOrgAllDecided : ctx.l10n.teamOrgSuggestionsHint,
                            style: const TextStyle(fontSize: 13, color: AppColors.medium)),
                      ),
                      for (final item in pending)
                        IonInsetList(
                          dividerIndent: null,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryDark,
                                child: Text(
                                  item.proposer.initials.isNotEmpty ? item.proposer.initials : '?',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                              title: Text(
                                item.proposer.fullName.isNotEmpty ? item.proposer.fullName : ctx.l10n.teamOrgFlutterMember,
                                style: const TextStyle(fontSize: 15),
                              ),
                              subtitle: Text(relativeDay(item.createdAt), style: const TextStyle(color: AppColors.medium)),
                            ),
                            ListTile(
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: item.description?.isNotEmpty == true
                                  ? Text(item.description!, style: const TextStyle(color: AppColors.medium))
                                  : null,
                            ),
                            // Ionic `.proposal-actions`: two equal buttons.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.medium,
                                        side: const BorderSide(color: AppColors.medium),
                                      ),
                                      onPressed: _deciding.contains(item.id) ? null : () => _reject(item),
                                      child: Text(ctx.l10n.teamOrgReject),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _deciding.contains(item.id) ? null : () => _accept(item),
                                      child: Text(ctx.l10n.commonApply),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _topicSubtitle(AgendaItem item) {
    final l10n = context.l10n;
    final parts = [
      item.responsiblePerson.fullName.isNotEmpty ? item.responsiblePerson.fullName : l10n.teamOrgNobodyResponsible,
    ];
    if (item.proposedBy != null) {
      final by = item.proposer.fullName;
      parts.add(by.isNotEmpty ? l10n.agendaProposedBy(by) : l10n.teamOrgProposal);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(agendaItemsProvider);
    final protocols = ref.watch(protocolsProvider).valueOrNull ?? const <Protocol>[];
    final upcoming = ref.watch(upcomingProtocolAttendancesProvider).valueOrNull ?? const <ProtocolAttendance>[];
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
    final l10n = context.l10n;

    return Scaffold(
      floatingActionButton: TabBarFab.wrap(FloatingActionButton(
        heroTag: 'team-org-add-topic',
        tooltip: l10n.teamOrgCreateTopic,
        onPressed: () => context.push('/settings/agenda-items/new'),
        child: const Icon(Icons.add),
      )),
      body: itemsAsync.when(
        loading: () => const TeamOrgListSkeleton(), // Ionic ion-skeleton-text (3 rows)
        error: (_, __) => Center(child: Text(l10n.agendaLoadFailed)),
        data: (items) {
          final postponed = postponedAgendaItemIds(protocols);
          final buckets = splitTopics(items);
          final openTopics = sortTopicsForPlanning(buckets.open, postponed);
          ProtocolAttendance? next;
          for (final a in upcoming) {
            if (a.id == _chosenAttendanceId) next = a;
          }
          next ??= upcoming.isNotEmpty ? upcoming.first : null;
          final nextType = next != null ? _typeOf(next, types) : null;
          final tops = planTops(next?.fields);
          final numbers = topNumbers(next?.fields);
          final nextAgendaIds = tops.tops.map(fieldAgendaItemId).toSet();

          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(agendaItemsProvider);
              ref.invalidate(protocolsProvider);
              ref.invalidate(upcomingProtocolAttendancesProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 72)),
              children: [
                // Neue Vorschläge (Ionic `.proposal-banner`)
                if (buckets.pending.isNotEmpty)
                  IonInsetList(children: [
                    ListTile(
                      leading: const Icon(Icons.lightbulb_outline, color: AppColors.warning),
                      title: Text(l10n.teamOrgFlutterNewSuggestions(buckets.pending.length)),
                      subtitle: Text(l10n.teamOrgSubmittedByMembers, style: const TextStyle(color: AppColors.medium)),
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 32),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _openReview,
                        child: Text(l10n.teamOrgReview),
                      ),
                      onTap: _openReview,
                    ),
                  ]),
                // Nächster Termin
                if (next != null)
                  IonInsetList(
                    header: next.id != upcoming.first.id ? l10n.teamOrgChosenEvent : l10n.teamOrgNextEvent,
                    headerTrailing: TextButton(
                      onPressed: () => _changeAttendance(upcoming, next, types),
                      child: Text(l10n.teamOrgChange),
                    ),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                        title: Text(_attendanceTitle(next, types)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (tops.minutes > 0) IonNote(l10n.teamOrgMinutes(tops.minutes)),
                          const SizedBox(width: 4),
                          const IonDetailIcon(),
                        ]),
                        onTap: () => context.push('/attendance/${next!.id}'),
                      ),
                      for (final top in tops.tops)
                        ListTile(
                          title: Text(l10n.teamOrgTopName(numbers[fieldId(top)] ?? 0, fieldName(top)),
                              style: const TextStyle(fontSize: 15)),
                          subtitle: fieldConductor(top) != null
                              ? Text(fieldConductor(top)!, style: const TextStyle(color: AppColors.medium))
                              : null,
                          trailing: IonNote(l10n.teamOrgMinutes(fieldMinutes(top))),
                          onTap: () => _topAction(top, next!, nextType),
                        ),
                      if (tops.tops.isEmpty)
                        ListTile(
                          title: Text(l10n.teamOrgNoTopsYet, style: const TextStyle(color: AppColors.medium)),
                        ),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        title: Text(l10n.teamOrgAddTopics, style: const TextStyle(color: AppColors.primary)),
                        onTap: () async {
                          await showAgendaPickerSheet(context, attendance: next!, type: nextType);
                        },
                      ),
                    ],
                  )
                else
                  IonInsetList(
                    header: l10n.teamOrgNextEvent,
                    children: [
                      ListTile(
                        title: Text(l10n.teamOrgNoProtocolEvent, style: const TextStyle(color: AppColors.medium)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        title: Text(l10n.teamOrgCreateEvent, style: const TextStyle(color: AppColors.primary)),
                        onTap: _createAttendance,
                      ),
                    ],
                  ),
                // Themenspeicher
                IonInsetList(
                  header: l10n.agendaTopicStore,
                  headerTrailing: Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 4),
                    child: IonNote(l10n.teamOrgOpenCount(openTopics.length), style: const TextStyle(fontSize: 14)),
                  ),
                  children: [
                    for (final item in openTopics)
                      ListTile(
                        title: Text(item.title),
                        subtitle: Text.rich(
                          TextSpan(children: [
                            if (postponed.contains(item.id))
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: TeamOrgBadge(label: l10n.teamOrgPostponedLower, color: AppColors.warning),
                                ),
                              ),
                            if (nextAgendaIds.contains(item.id))
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: TeamOrgBadge(label: l10n.teamOrgPlannedLower, color: AppColors.primary),
                                ),
                              ),
                            TextSpan(text: _topicSubtitle(item)),
                          ]),
                          style: const TextStyle(color: AppColors.medium),
                        ),
                        trailing: TeamOrgBadge(
                          label: priorityLabels[item.priority] ?? item.priority,
                          color: priorityColor(item.priority),
                        ),
                        onTap: () => context.push('/settings/agenda-items/${item.id}'),
                      ),
                    if (openTopics.isEmpty)
                      ListTile(
                        title: Text(l10n.teamOrgNoOpenTopics, style: const TextStyle(color: AppColors.medium)),
                      ),
                  ],
                ),
                if (buckets.done.isNotEmpty)
                  IonInsetList(
                    children: [
                      SwitchListTile.adaptive(
                        value: _showDone,
                        onChanged: (v) => setState(() => _showDone = v),
                        title: Text(l10n.teamOrgShowDone(buckets.done.length)),
                      ),
                      if (_showDone)
                        for (final item in buckets.done)
                          ListTile(
                            title: Text(item.title,
                                style: const TextStyle(
                                    color: AppColors.medium, decoration: TextDecoration.lineThrough)),
                            subtitle: Text(
                              [
                                item.status == 'dropped' ? l10n.agendaStatusDropped : l10n.agendaStatusDone,
                                if (item.responsiblePerson.fullName.isNotEmpty) item.responsiblePerson.fullName,
                              ].join(' · '),
                              style: const TextStyle(color: AppColors.medium),
                            ),
                            onTap: () => context.push('/settings/agenda-items/${item.id}'),
                          ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Members ──────────────────────────────────────────────────

class _MemberTopics extends ConsumerWidget {
  const _MemberTopics();

  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => const _SuggestSheet(),
    );
    if (result == true && context.mounted) ToastHelper.showSuccess(context, context.l10n.teamOrgSuggestionSent);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(agendaItemsProvider);
    final l10n = context.l10n;
    return RefreshIndicator.adaptive(
      onRefresh: () async => ref.invalidate(agendaItemsProvider),
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
                subtitle: Text(l10n.teamOrgSuggestHint, style: const TextStyle(color: AppColors.medium)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _suggest(context, ref),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(l10n.teamOrgSuggestTopic),
                ),
              ),
            ],
          ),
          itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: AppSpinner()),
            ),
            error: (_, __) => Padding(padding: const EdgeInsets.all(16), child: Text(l10n.agendaLoadFailed)),
            data: (items) {
              final sorted = [...items]..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
              return IonInsetList(
                header: l10n.teamOrgMySuggestions,
                children: [
                  if (sorted.isEmpty)
                    ListTile(
                      title: Text(l10n.teamOrgNothingSuggested, style: const TextStyle(color: AppColors.medium)),
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
                            style: const TextStyle(color: AppColors.medium),
                          ),
                          if (item.proposalStatus == 'rejected' && item.decisionNote?.isNotEmpty == true)
                            Text('„${item.decisionNote}“',
                                style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.medium)),
                        ],
                      ),
                      trailing: TeamOrgBadge(
                        label: suggestionStatusLabel(item),
                        color: switch (item.proposalStatus) {
                          'accepted' => AppColors.success,
                          'rejected' => AppColors.danger,
                          _ => AppColors.medium,
                        },
                      ),
                    ),
                ],
              );
            },
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            leading: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
            leadingWidth: 100,
            title: Text(l10n.teamOrgSuggestTopic),
          ),
          // Ionic: sheet hint, inset list with stacked title/description, block button.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(l10n.teamOrgSuggestHint, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
          ),
          IonInsetList(
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
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _title.text.trim().isEmpty || _sending ? null : _send,
                  child: Text(l10n.teamOrgSendSuggestion),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
