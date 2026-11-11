import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../team_org_utils.dart';
import 'rd_proposals.dart';
import 'tasks_tab.dart' show TeamOrgListSkeleton;
import 'topics_tab.dart' show showSuggestTopicSheet;

/// Beta "Offene Themen": leadership decides on suggestions and sees what
/// still waits for a Besprechung; members suggest topics and follow their
/// own suggestions.
class RdOpenTopics extends ConsumerStatefulWidget {
  const RdOpenTopics({super.key});

  @override
  ConsumerState<RdOpenTopics> createState() => _RdOpenTopicsState();
}

class _RdOpenTopicsState extends ConsumerState<RdOpenTopics> {
  bool _showDone = false;
  final Set<String> _busy = {};

  Future<void> _run(AgendaItem item, Future<void> Function() action) async {
    final id = item.id;
    if (id == null || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final isLeader = ref.watch(isTeamLeaderProvider);
    final itemsAsync = ref.watch(agendaItemsProvider);
    ref.listen(agendaItemsProvider, (_, next) {
      if (next is AsyncError && !next.isLoading) ToastHelper.showError(context, context.l10n.agendaLoadFailed);
    });
    final items = itemsAsync.valueOrNull ?? const <AgendaItem>[];
    final loading = itemsAsync.isLoading && !itemsAsync.hasValue;

    Widget fab(String tooltip, VoidCallback onPressed) => FloatingActionButton(
          heroTag: 'rd-team-topics-add',
          tooltip: tooltip,
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: onPressed,
          child: const Icon(Icons.add, size: 28),
        );

    if (!isLeader) {
      // Own suggestions only (RLS also returns topics of own meetings).
      final myId = ref.watch(teamPersonProvider).valueOrNull?.id;
      final mine = items.where((i) => i.proposedBy != null && i.proposedBy == myId).toList()
        ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return RdPage(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        onRefresh: () => reloadTeamOrgTab(ref, 'topics'),
        floatingActionButton: fab(l10n.teamOrgSuggestTopic, () => showSuggestTopicSheet(context)),
        children: [
          Text(l10n.teamOrgSuggestHint, style: RdType.meta(p)),
          const SizedBox(height: 18),
          RdGroupLabel(l10n.teamOrgMySuggestions),
          if (loading)
            const TeamOrgListSkeleton()
          else if (mine.isEmpty)
            RdCard(child: Text(l10n.teamOrgNothingSuggested, style: RdType.meta(p)))
          else
            RdGroupedList(
              children: [
                for (final item in mine)
                  RdListRow(
                    key: ValueKey('rd-my-suggestion-${item.id}'),
                    title: item.title,
                    subtitle: item.proposalStatus == 'rejected' && item.decisionNote?.isNotEmpty == true
                        ? '„${item.decisionNote}“'
                        : relativeDay(item.createdAt),
                    trailing: RdPill(
                      suggestionStatusLabel(item),
                      tone: switch (item.proposalStatus) {
                        'accepted' => RdTone.present,
                        'rejected' => RdTone.absent,
                        _ => null,
                      },
                    ),
                    showChevron: false,
                  ),
              ],
            ),
          const SizedBox(height: 72),
        ],
      );
    }

    final protocols = ref.watch(protocolsProvider).valueOrNull ?? const <Protocol>[];
    final upcoming = ref.watch(upcomingProtocolAttendancesProvider).valueOrNull ?? const <ProtocolAttendance>[];
    final postponed = postponedAgendaItemIds(protocols);
    final buckets = splitTopics(items);
    final open = sortTopicsForPlanning(buckets.open, postponed);
    // Topic id → date of the first planned meeting that has it on its agenda.
    final plannedOn = <String, String>{};
    for (final att in upcoming) {
      for (final top in planTops(att.fields).tops) {
        plannedOn.putIfAbsent(fieldAgendaItemId(top)!, () => att.date);
      }
    }
    final planned = open.where((i) => plannedOn.containsKey(i.id)).toList();
    final waiting = open.where((i) => !plannedOn.containsKey(i.id)).toList();

    Widget row(AgendaItem item) {
      final parts = [
        if (plannedOn.containsKey(item.id)) formatShortWeekdayDate(plannedOn[item.id]),
        if (item.responsiblePerson.fullName.isNotEmpty) item.responsiblePerson.fullName,
        if (item.proposedBy != null && item.proposer.fullName.isNotEmpty)
          l10n.agendaProposedBy(item.proposer.fullName),
      ];
      return RdListRow(
        key: ValueKey('rd-topic-${item.id}'),
        title: item.title,
        subtitle: parts.isEmpty ? null : parts.join(' · '),
        trailing: postponed.contains(item.id) ? RdPill(l10n.teamOrgPostponedLower, tone: RdTone.late) : null,
        onTap: () => context.push('/settings/agenda-items/${item.id}'),
      );
    }

    return RdPage(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      onRefresh: () => reloadTeamOrgTab(ref, 'topics'),
      floatingActionButton: fab(l10n.teamOrgCreateTopic, () => context.push('/settings/agenda-items/new')),
      children: [
        Text(l10n.rdTeamOpenTopicsIntro, style: RdType.meta(p)),
        const SizedBox(height: 18),
        if (loading) const TeamOrgListSkeleton(),
        if (buckets.pending.isNotEmpty) ...[
          RdGroupLabel(l10n.rdTeamSuggestions),
          for (final item in buckets.pending)
            RdProposalCard(
              key: ValueKey('rd-proposal-${item.id}'),
              item: item,
              busy: _busy.contains(item.id),
              primaryLabel: l10n.rdTeamAccept,
              onPrimary: () => _run(item, () => acceptProposal(context, ref, item)),
              secondaryLabel: l10n.teamOrgReject,
              onSecondary: () => _run(item, () => rejectProposal(context, ref, item)),
            ),
          const SizedBox(height: 8),
        ],
        if (planned.isNotEmpty) ...[
          RdGroupLabel(l10n.rdTeamPlannedGroup),
          RdGroupedList(children: [for (final item in planned) row(item)]),
          const SizedBox(height: 18),
        ],
        if (waiting.isNotEmpty) ...[
          RdGroupLabel(l10n.rdTeamUnplannedGroup),
          RdGroupedList(children: [for (final item in waiting) row(item)]),
          const SizedBox(height: 18),
        ],
        if (!loading && open.isEmpty && buckets.pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: RdCard(child: Text(l10n.teamOrgNoOpenTopics, style: RdType.meta(p))),
          ),
        if (buckets.done.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: RdTextLink(
              label: _showDone ? l10n.rdTeamHideDone : l10n.rdTeamShowDone(buckets.done.length),
              onTap: () => setState(() => _showDone = !_showDone),
            ),
          ),
          if (_showDone) ...[
            const SizedBox(height: 10),
            RdGroupedList(
              children: [
                for (final item in buckets.done)
                  RdListRow(
                    key: ValueKey('rd-topic-done-${item.id}'),
                    title: item.title,
                    titleColor: p.text2,
                    subtitle: item.status == 'dropped' ? l10n.agendaStatusDropped : l10n.agendaStatusDone,
                    onTap: () => context.push('/settings/agenda-items/${item.id}'),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 72),
      ],
    );
  }
}
