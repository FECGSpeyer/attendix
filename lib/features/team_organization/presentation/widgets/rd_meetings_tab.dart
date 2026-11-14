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
import '../pages/rd_meeting_page.dart' show rdMeetingRoute;
import 'rd_new_meeting_sheet.dart';
import 'tasks_tab.dart' show TeamOrgListSkeleton;

/// Topics page of the Team area (suggestions, Themenspeicher).
const rdTeamTopicsRoute = '/settings/team-organization/topics';

/// Beta tab "Besprechungen": the planned meetings, the topics collected for
/// them and the past meetings with their protocol.
class RdMeetingsTab extends ConsumerStatefulWidget {
  const RdMeetingsTab({super.key});

  @override
  ConsumerState<RdMeetingsTab> createState() => _RdMeetingsTabState();
}

class _RdMeetingsTabState extends ConsumerState<RdMeetingsTab> {
  bool _creating = false;

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final id = await showNewMeetingSheet(context);
      // Straight on to the agenda of the new Besprechung.
      if (id != null && mounted) context.push(rdMeetingRoute(id));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  ProtocolType? _type(String? typeId, List<ProtocolType> types) {
    for (final t in types) {
      if (t.id == typeId) return t;
    }
    return null;
  }

  Widget _dateTile(String? isoDate, {bool highlight = false}) {
    final d = DateTime.tryParse(isoDate ?? '')?.toLocal();
    return RdDateTile(
      weekday: d != null ? weekdayShort(d) : '',
      day: d != null ? '${d.day}' : '–',
      highlight: highlight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final isLeader = ref.watch(isTeamLeaderProvider);
    final upcomingAsync = ref.watch(upcomingProtocolAttendancesProvider);
    final protocolsAsync = ref.watch(protocolsProvider);
    final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
    final topics = splitTopics(ref.watch(agendaItemsProvider).valueOrNull);

    final upcoming = upcomingAsync.valueOrNull ?? const <ProtocolAttendance>[];
    // A protocol started ahead of its meeting stays under "Geplant" only.
    final upcomingIds = upcoming.map((a) => a.id).toSet();
    final protocols = protocolsAsync.valueOrNull ?? const <Protocol>[];
    final past = protocols.where((x) => x.attendanceId != null && !upcomingIds.contains(x.attendanceId)).toList();
    // Leads also see past meetings nobody wrote a protocol for yet (it can
    // still be written); a failed load only leaves them out.
    final withProtocol = {
      for (final x in protocols)
        if (x.attendanceId != null) x.attendanceId!,
    };
    final bare = !isLeader || protocolsAsync.valueOrNull == null
        ? const <ProtocolAttendance>[]
        : [
            for (final a in ref.watch(pastProtocolAttendancesProvider).valueOrNull ?? const <ProtocolAttendance>[])
              if (!withProtocol.contains(a.id)) a,
          ];
    // Both kinds in one list, newest first.
    final pastRows = <({String date, Protocol? protocol, ProtocolAttendance? bare})>[
      for (final x in past) (date: x.attendance?.date ?? '', protocol: x, bare: null),
      for (final a in bare) (date: a.date, protocol: null, bare: a),
    ]..sort((a, b) => b.date.compareTo(a.date));
    // Today's meeting stays under "Geplant" until tomorrow: once its
    // protocol is published the row opens the protocol.
    final publishedIds = {
      for (final x in protocols)
        if (x.status == 'published' && x.attendanceId != null) x.attendanceId!,
    };
    final failed = upcomingAsync.hasError || protocolsAsync.hasError;
    void Function(AsyncValue<Object?>?, AsyncValue<Object?>) onError(String Function() text) => (_, next) {
          if (next is AsyncError && !next.isLoading) ToastHelper.showError(context, text());
        };
    ref.listen(upcomingProtocolAttendancesProvider, onError(() => context.l10n.rdTeamLoadFailed));
    ref.listen(protocolsProvider, onError(() => context.l10n.rdTeamLoadFailed));
    ref.listen(agendaItemsProvider, onError(() => context.l10n.agendaLoadFailed));
    final loading = (upcomingAsync.isLoading && !upcomingAsync.hasValue) ||
        (protocolsAsync.isLoading && !protocolsAsync.hasValue);

    String plannedSubtitle(ProtocolAttendance att) {
      final tops = planTops(att.fields);
      final parts = [formatShortWeekdayDate(att.date)];
      if (publishedIds.contains(att.id)) {
        parts.add(isLeader ? l10n.rdTeamProtocolPublished : l10n.rdTeamProtocolRead);
      } else if (tops.tops.isEmpty) {
        parts.add(l10n.rdTeamNoTopicsYet);
      } else {
        parts.add(l10n.rdTeamTopicsCount(tops.tops.length));
        if (tops.minutes > 0) parts.add(l10n.teamOrgMinutes(tops.minutes));
      }
      return parts.join(' · ');
    }

    String topicsSubtitle() {
      if (!isLeader) return l10n.rdTeamSuggestHint;
      final parts = [
        if (topics.pending.isNotEmpty) l10n.rdTeamNewSuggestions(topics.pending.length),
        if (topics.open.isNotEmpty) l10n.rdTeamOpenTopicsCount(topics.open.length),
      ];
      return parts.isEmpty ? l10n.rdTeamTopicsHint : parts.join(' · ');
    }

    String pastSubtitle(Protocol protocol) {
      final parts = [formatShortWeekdayDate(protocol.attendance?.date)];
      if (protocol.status == 'published') {
        parts.add(isLeader ? l10n.rdTeamProtocolPublished : l10n.rdTeamProtocolRead);
      }
      return parts.where((s) => s.isNotEmpty).join(' · ');
    }

    final children = <Widget>[
      if (loading)
        const TeamOrgListSkeleton()
      else ...[
        if (upcoming.isEmpty && pastRows.isEmpty && !failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.rdTeamEmptyTitle, style: RdType.cardTitle(p)),
                  const SizedBox(height: 4),
                  Text(isLeader ? l10n.rdTeamEmptyLeader : l10n.rdTeamEmptyMember, style: RdType.meta(p)),
                ],
              ),
            ),
          ),
        if (upcoming.isNotEmpty) ...[
          RdGroupLabel(l10n.rdTeamPlanned),
          RdGroupedList(
            children: [
              for (final att in upcoming)
                RdListRow(
                  key: ValueKey('rd-meeting-${att.id}'),
                  leading: _dateTile(att.date, highlight: att == upcoming.first),
                  title: attendanceTitle(att.typeInfo, _type(att.typeId, types)),
                  subtitle: plannedSubtitle(att),
                  onTap: publishedIds.contains(att.id)
                      ? () => context.push('/settings/protocol/${att.id}')
                      : () => context.push(rdMeetingRoute(att.id)),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        RdGroupedList(
          children: [
            RdListRow(
              key: const ValueKey('rd-meeting-topics'),
              leading: RdRowIcon(isLeader ? Icons.forum_outlined : Icons.lightbulb_outline),
              title: isLeader ? l10n.rdTeamOpenTopics : l10n.teamOrgSuggestTopic,
              subtitle: topicsSubtitle(),
              trailing: isLeader && topics.pending.isNotEmpty
                  ? RdCountBadge(topics.pending.length, tone: RdTone.late)
                  : null,
              onTap: () => context.push(rdTeamTopicsRoute),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (pastRows.isNotEmpty) ...[
          RdGroupLabel(l10n.rdTeamPast),
          RdGroupedList(
            children: [
              for (final row in pastRows)
                if (row.protocol case final protocol?)
                  RdListRow(
                    key: ValueKey('rd-meeting-past-${protocol.attendanceId}'),
                    leading: _dateTile(protocol.attendance?.date),
                    title: attendanceTitle(protocol.attendance?.typeInfo, _type(protocol.attendance?.typeId, types)),
                    subtitle: pastSubtitle(protocol),
                    trailing: protocol.status != 'published' ? RdPill(l10n.teamOrgDraft, tone: RdTone.late) : null,
                    onTap: () => context.push('/settings/protocol/${protocol.attendanceId}'),
                  )
                else if (row.bare case final att?)
                  // No protocol yet: the row opens it to write it now.
                  RdListRow(
                    key: ValueKey('rd-meeting-past-${att.id}'),
                    leading: _dateTile(att.date),
                    title: attendanceTitle(att.typeInfo, _type(att.typeId, types)),
                    subtitle: formatShortWeekdayDate(att.date),
                    trailing: RdPill(l10n.rdTeamNoProtocol),
                    onTap: () => context.push('/settings/protocol/${att.id}'),
                  ),
            ],
          ),
        ],
      ],
      SizedBox(height: isLeader ? 72 : 0),
    ];

    return RdPage(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      onRefresh: () => reloadTeamOrgTab(ref, 'topics'),
      floatingActionButton: isLeader
          ? FloatingActionButton(
              heroTag: 'rd-team-new-meeting',
              tooltip: l10n.rdTeamNewMeeting,
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _creating ? null : _create,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      children: children,
    );
  }
}
