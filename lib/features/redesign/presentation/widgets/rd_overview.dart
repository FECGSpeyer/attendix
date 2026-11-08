import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../songs/presentation/utils/song_utils.dart';
import '../../data/providers/rd_members_providers.dart';
import '../../data/rd_collections_logic.dart';
import '../../data/rd_members_logic.dart' show RdMembersFilter;
import '../../data/rd_overview_logic.dart';
import '../../data/rd_works_logic.dart';
import '../pages/rd_folder_page.dart' show rdEventLabel;
import 'rd_widgets.dart';
import 'today/rd_today_common.dart' show RdInfoCard;
import 'works/rd_collections_ui.dart';
import 'works/rd_current_works.dart' show rdOpenCurrentWork;

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
    final async = ref.watch(songsListDataProvider(null));
    final data = async.valueOrNull;
    if (data == null) {
      return _OverviewPage(
        hint: l10n.redesignSplitWorksEmpty,
        failed: async.hasError && !async.isLoading,
        // The sources too: a failed one would keep its stored error.
        onRetry: () {
          ref.invalidate(songTenantSettingsProvider);
          ref.invalidate(songsProvider);
          ref.invalidate(songCategoriesProvider);
          ref.invalidate(groupsProvider);
          ref.invalidate(groupCategoriesProvider);
          ref.invalidate(currentSongsProvider);
          ref.invalidate(songsListDataProvider(null));
        },
        children: const [],
      );
    }
    final role = ref.watch(effectiveRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    // With Sammlungen: the Werke of the one the list shows.
    final collections = ref.watch(rdVisibleCollectionsProvider);
    final o = rdWorksOverview(
      collections == null
          // Visibility unknown (loading/failed): members only see the Werke
          // outside every Sammlung, leads all.
          ? (role.isConductor ? data.songs : rdVisibleWorks(data.songs, const []))
          // No visible Sammlung: only the Werke outside every Sammlung.
          : collections.isEmpty
          ? rdVisibleWorks(data.songs, collections)
          : rdWorksIn(
            rdVisibleWorks(data.songs, collections),
            rdShownCollectionId(ref.watch(rdWorksCollectionProvider), collections),
          ),
    );
    final dateFmt = DateFormat.yMMMEd(Localizations.localeOf(context).toLanguageTag());

    // Members: their current Noten by Termin instead of the counts, which
    // only matter to whoever looks after the Werke.
    if (!role.isConductor) {
      final current = _MemberCurrentWorks.sections(context, ref, data, collections);
      if (current != null) return _OverviewPage(hint: l10n.redesignSplitWorksCurrentHint, children: current);
    }

    void open(Song s) {
      if (s.id != null) context.go(RedesignRoutes.work(s.id!));
    }

    Widget songRow(Song s, {String? value}) => RdListRow(
      key: ValueKey('rd-overview-work-${s.id}'),
      title: s.fullNumber.isEmpty ? s.name : '${s.fullNumber}  ${s.name}',
      value: value,
      onTap: s.id == null ? null : () => open(s),
    );

    // No own "+" here: adding lives in the list's header only.
    return _OverviewPage(
      hint: l10n.redesignSplitWorksEmpty,
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
    final async = ref.watch(realtimePlayersProvider);
    final people = async.valueOrNull;
    if (people == null) {
      return _OverviewPage(
        hint: l10n.redesignSplitMembersHint,
        failed: async.hasError && !async.isLoading,
        // groupsMapProvider is kept alive: a failed load stays until reset.
        onRetry: () {
          ref.invalidate(groupsMapProvider);
          ref.invalidate(realtimePlayersProvider);
        },
        children: const [],
      );
    }
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
              Expanded(
                child: _Stat(
                  value: pending,
                  label: l10n.redesignSplitMembersPending,
                  warn: pending > 0,
                  // Opens "Wartet" in the list beside it.
                  onTap:
                      pending > 0
                          ? () => ref.read(rdMembersTabProvider.notifier).state = RdMembersFilter.pending
                          : null,
                ),
              ),
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

/// The members' overview of the Werke: "Aktuell" ([rdCurrentWorkCards])
/// grouped by Termin, then the Werke played lately; a tap opens the own
/// part like the cards of the list.
abstract final class _MemberCurrentWorks {
  /// The sections, null when nothing is current.
  static List<Widget>? sections(
    BuildContext context,
    WidgetRef ref,
    SongsListData data,
    List<SongCollection>? collections,
  ) {
    final l10n = context.l10n;
    final own = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.instrument;
    final ownGroup = data.groups.where((g) => g.id == own && g.maingroup != true).firstOrNull;
    final now = DateTime.now();
    final works = rdCurrentWorkCards(
      rdWithoutEndedEvents(
        rdNextEvents(data.currentSongs, data.songs),
        now: now,
        attendances: ref.watch(realtimeAttendanceListProvider).valueOrNull ?? const [],
        types: ref.watch(attendanceTypesProvider).valueOrNull ?? const [],
      ),
      rdVisibleWorks(data.songs, collections ?? const []),
      now: now,
    );
    if (works.isEmpty) return null;
    final played = data.isOrchestra ? l10n.redesignWorksSortLastPlayed : l10n.redesignWorksSortLastSung;
    // One section per Termin (two of a day stay apart, then with their
    // time), the played ones last.
    final byEvent = <(int?, DateTime?)?, List<RdCurrentWork>>{};
    for (final w in works) {
      (byEvent[w.event == null ? null : (w.event!.attendanceId, w.event!.date)] ??= []).add(w);
    }
    final labels = {
      for (final w in works)
        if (w.event != null) (w.event!.attendanceId, w.event!.date): rdEventLabel(w.event!),
    };
    String label((int?, DateTime?)? key) {
      if (key == null) return played;
      final text = labels[key]!;
      final date = key.$2;
      final twice = labels.values.where((l) => l == text).length > 1;
      return twice && date != null ? '$text · ${DateFormat.Hm(currentIntlLocale()).format(date)}' : text;
    }

    return [
      for (final MapEntry(:key, value: list) in byEvent.entries) ...[
        RdGroupLabel(label(key)),
        RdGroupedList(
          children: [
            for (final w in list)
              RdListRow(
                key: ValueKey('rd-overview-current-${w.song.id}'),
                title: w.song.fullNumber.isEmpty ? w.song.name : '${w.song.fullNumber}  ${w.song.name}',
                subtitle:
                    ownGroup == null
                        ? null
                        : rdMemberPartFiles(w.song, ownGroup.id, choir: data.isChoir).any(rdIsNotes)
                        ? l10n.redesignWorksStatusPart
                        : l10n.redesignWorksStatusNoPart(ownGroup.name),
                value: w.lastPlayed == null ? null : SongUtils.formatDate(w.song.lastSung),
                onTap: () => rdOpenCurrentWork(context, ref, w.song, ownGroup?.id, choir: data.isChoir),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    ];
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.hint, required this.children, this.failed = false, this.onRetry});

  final String hint;

  /// Empty while the data loads ([failed]: it could not be loaded).
  final List<Widget> children;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdPage(
      maxWidth: 640,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Semantics(header: true, child: Text(l10n.redesignSplitOverviewTitle, style: RdType.title(p))),
        const SizedBox(height: 4),
        Text(hint, style: RdType.meta(p)),
        const SizedBox(height: 20),
        if (children.isNotEmpty)
          ...children
        else if (failed)
          RdInfoCard(
            text: l10n.redesignTodayLoadFailed,
            icon: Icons.cloud_off_outlined,
            action: onRetry == null ? null : RdOutlineButton(label: l10n.redesignCommonRetry, onPressed: onRetry),
          )
        else
          RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.warn = false, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  /// Something to do (works without sheet music, open requests).
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      label: '$value $label',
      button: onTap != null,
      // The InkWell below is excluded: the tap must sit here.
      onTap: onTap,
      excludeSemantics: true,
      child: RdCard(
        onTap: onTap,
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
