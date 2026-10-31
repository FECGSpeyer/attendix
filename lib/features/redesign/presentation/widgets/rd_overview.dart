import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../../songs/presentation/widgets/add_song_sheet.dart';
import '../../data/rd_overview_logic.dart';
import 'rd_widgets.dart';
import 'today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: what the empty detail column of the split view shows while
/// nothing is chosen on the left (Werke, Mitglieder): a short overview with
/// shortcuts instead of one sentence in a large empty box.

/// Rows per section before "und N weitere".
const int rdOverviewRows = 5;

class RdWorksOverviewPanel extends ConsumerWidget {
  const RdWorksOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(songsListDataProvider(null)).valueOrNull;
    if (data == null) return _OverviewPage(hint: l10n.redesignSplitWorksHint, children: const []);
    final role = ref.watch(effectiveRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final o = rdWorksOverview(data.songs);
    final dateFmt = DateFormat.yMMMEd(Localizations.localeOf(context).toLanguageTag());

    void open(Song s) {
      if (s.id != null) context.go(RedesignRoutes.work(s.id!));
    }

    Widget songRow(Song s, {String? value}) => RdListRow(
      key: ValueKey('rd-overview-work-${s.id}'),
      title: s.fullNumber.isEmpty ? s.name : '${s.fullNumber}  ${s.name}',
      value: value,
      onTap: s.id == null ? null : () => open(s),
    );

    return _OverviewPage(
      hint: l10n.redesignSplitWorksHint,
      action:
          isAdmin
              ? RdPrimaryButton(
                label: l10n.redesignWorksAdd,
                icon: Icons.add,
                height: 40,
                onPressed: () async {
                  final id = await showAddSongSheet(context, data);
                  if (id != null && context.mounted) context.go(RedesignRoutes.work(id));
                },
              )
              : null,
      children: [
        Row(
          children: [
            Expanded(child: _Stat(value: o.total, label: l10n.redesignSplitWorksCount)),
            const SizedBox(width: 12),
            Expanded(child: _Stat(value: o.withFiles, label: l10n.redesignSplitWorksWithFiles)),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(value: o.withoutFiles, label: l10n.redesignSplitWorksWithoutFiles, warn: o.withoutFiles > 0),
            ),
          ],
        ),
        if (o.next.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignSplitWorksNext(dateFmt.format(o.nextDate!))),
          RdGroupedList(children: [for (final s in o.next) songRow(s)]),
        ],
        // Only editors can add the missing files.
        if (isAdmin && o.missing.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignSplitWorksMissing),
          RdGroupedList(children: [for (final s in o.missing.take(rdOverviewRows)) songRow(s)]),
          if (o.missing.length > rdOverviewRows) _More(count: o.missing.length - rdOverviewRows),
        ],
        if (o.longAgo.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignSplitWorksLongAgo),
          RdGroupedList(children: [for (final s in o.longAgo) songRow(s, value: SongUtils.formatDate(s.lastSung))]),
        ],
      ],
    );
  }
}

class RdMembersOverviewPanel extends ConsumerWidget {
  const RdMembersOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final people = ref.watch(realtimePlayersProvider).valueOrNull;
    if (people == null) return _OverviewPage(hint: l10n.redesignSplitMembersHint, children: const []);
    final role = ref.watch(effectiveRoleProvider);
    final canApprove = role.isAdmin || role.isResponsible;
    final pending = canApprove ? ref.watch(realtimePendingPlayersProvider).valueOrNull?.length ?? 0 : 0;
    final o = rdMembersOverview(people);
    final dayFmt = DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag());

    void open(int? id) {
      if (id != null) context.go(RedesignRoutes.person(id));
    }

    String birthdayValue(({Person person, int days}) b) {
      final date = DateTime.tryParse(b.person.birthday ?? '');
      final when = switch (b.days) {
        0 => l10n.redesignMembersBirthdayToday,
        1 => l10n.redesignMembersBirthdayTomorrow,
        _ => l10n.redesignMembersBirthdayIn(b.days),
      };
      return date == null ? when : '${dayFmt.format(date)} · $when';
    }

    return _OverviewPage(
      hint: l10n.redesignSplitMembersHint,
      children: [
        Row(
          children: [
            Expanded(child: _Stat(value: o.active, label: l10n.redesignSplitMembersActive)),
            const SizedBox(width: 12),
            Expanded(child: _Stat(value: o.paused, label: l10n.redesignSplitMembersPaused)),
            if (canApprove) ...[
              const SizedBox(width: 12),
              Expanded(child: _Stat(value: pending, label: l10n.redesignSplitMembersPending, warn: pending > 0)),
            ],
          ],
        ),
        if (o.birthdays.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignSplitMembersBirthdays),
          RdGroupedList(
            children: [
              for (final b in o.birthdays.take(rdOverviewRows))
                RdListRow(
                  title: '${b.person.firstName} ${b.person.lastName}',
                  value: birthdayValue(b),
                  onTap: () => open(b.person.id),
                ),
            ],
          ),
        ],
        // Attendance warnings stay with the leads.
        if (canApprove && o.critical.isNotEmpty) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignSplitMembersCritical),
          RdGroupedList(
            children: [
              for (final x in o.critical.take(rdOverviewRows))
                RdListRow(title: '${x.firstName} ${x.lastName}', value: x.groupName, onTap: () => open(x.id)),
            ],
          ),
          if (o.critical.length > rdOverviewRows) _More(count: o.critical.length - rdOverviewRows),
        ],
      ],
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.hint, required this.children, this.action});

  final String hint;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdPage(
      maxWidth: 640,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(l10n.redesignSplitOverviewTitle, style: RdType.title(p))),
                  const SizedBox(height: 4),
                  Text(hint, style: RdType.meta(p)),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action!],
          ],
        ),
        const SizedBox(height: 20),
        if (children.isEmpty) RdInfoCard(text: l10n.redesignTodayLoading, loading: true) else ...children,
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.warn = false});

  final int value;
  final String label;

  /// Something to do (works without sheet music, open requests).
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: RdCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: RdType.title(p).copyWith(color: warn ? p.late : p.text)),
            const SizedBox(height: 2),
            Text(label, style: RdType.meta(p, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _More extends StatelessWidget {
  const _More({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(context.l10n.redesignSplitMore(count), style: RdType.meta(context.rd, size: 13)),
    );
  }
}
