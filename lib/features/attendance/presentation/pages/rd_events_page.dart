import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart' show orgPlansProvider;
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../duty/presentation/widgets/self_service_duty_section.dart' show showOpenDutiesSheet;
import '../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../../data/providers/rd_events_providers.dart';
import '../../../today/data/providers/rd_today_providers.dart';
import '../widgets/event/rd_absence_sheet.dart';
import '../widgets/event/rd_current_songs_sheet.dart' show showCurrentSongsSheet;
import '../widgets/event/rd_event_create_menu.dart';
import '../widgets/event/rd_parent_event_card.dart';
import '../../../today/presentation/widgets/rd_parent_today.dart' show rdOpenChildren;
import '../../../people/data/providers/parents_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../data/repositories/song_repository.dart' show CurrentSongsGroup;
import '../widgets/event/rd_own_answer_sheet.dart';
import '../widgets/event/rd_signout_sheet.dart';
import '../../../../shared/widgets/redesign/rd_split_view.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart';
import '../../../../core/redesign/rd_dates.dart';
import '../../data/rd_event_phase.dart' show rdEffectiveDurationDays;
import '../../../organisation/presentation/widgets/rd_org_plans_ui.dart';
import '../../../today/presentation/widgets/rd_duty_section.dart';

part 'rd_events_page_cards.dart';
part 'rd_events_page_filters.dart';

/// Segments of the leader "Termine" tab; [orgPlans] is shown only when the
/// group belongs to an organisation.
enum RdEventsSegment { upcoming, past, orgPlans }

/// Tab "Termine" for Dirigent/Helfer/Beobachter, Spieler, and Eltern.
/// Shows Kommend / Vergangen (plus Org-Pläne for org leads), search and type
/// filters, and inline responses for players and parents.
class RdEventsPage extends ConsumerStatefulWidget {
  const RdEventsPage({super.key, this.initialSegment});

  final RdEventsSegment? initialSegment;

  @override
  ConsumerState<RdEventsPage> createState() => _RdEventsPageState();
}

class _RdEventsPageState extends ConsumerState<RdEventsPage> {
  late RdEventsSegment _segment = widget.initialSegment ?? RdEventsSegment.upcoming;
  String? _lastRouteTab;
  String? _type;
  bool _searching = false;
  String _query = '';
  bool _onlyOpen = false;

  bool get _past => _segment == RdEventsSegment.past;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = GoRouter.maybeOf(context)
        ?.routerDelegate
        .currentConfiguration
        .uri
        .queryParameters['tab'];
    if (tab != _lastRouteTab) {
      _lastRouteTab = tab;
      if (tab == 'org') {
        _segment = RdEventsSegment.orgPlans;
      }
    }
  }

  /// Thumb of Kommend / Vergangen while swiping the list.
  /// Notifier so only the segmented control rebuilds while swiping, not
  /// the whole page with every row.
  final _swipePos = ValueNotifier<double?>(null);
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _swipePos.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(effectiveRoleProvider);
    final parent = role.isParent;
    final leader = !parent && role.canSeeAttendanceTab;
    final canCreate = leader && ref.watch(canCreateAttendanceProvider);
    // Helfer are members too: they keep "Abwesend" next to the leader list.
    final player = parent || (leader && !role.canSeeSelfServiceTab)
        ? null
        : ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    // Eltern: "Aktuelle Werke" (no Werke tab).
    final songs = parent ? ref.watch(currentSongsProvider).valueOrNull ?? const <CurrentSongsGroup>[] : const <CurrentSongsGroup>[];
    final canReportAbsence = player != null && ref.watch(canSelfReportAbsenceProvider);
    // Helfer: own answers ("Du ✓") follow recordings and realtime changes.
    final ownInLeaderList = leader && role.canSeeSelfServiceTab;
    if (ownInLeaderList) {
      ref.listen<int>(attendanceRefetchCounter, (_, __) => ref.invalidate(signoutDataProvider));
    }
    // Desktop (list next to the Termin): the one "+" sits in the header.
    final inSplit = RdSplitScope.of(context) != null;

    return RdPage(
      onRefresh: () => _refreshEvents(parent: parent, leader: leader, ownInLeaderList: ownInLeaderList),
      floatingActionButton: canCreate && !inSplit ? const RdEventCreateMenu() : null,
      children: [
        _buildHeader(
          context,
          canReportAbsence: canReportAbsence,
          player: player,
          songs: songs,
          canCreate: canCreate,
          inSplit: inSplit,
        ),
        if (_searching) ...[
          const SizedBox(height: 12),
          _buildSearchField(context),
        ],
        const SizedBox(height: 14),
        if (parent)
          _parentBody(context)
        else if (leader)
          _leaderBody(context)
        else
          _playerBody(context),
      ],
    );
  }

  Future<void> _refreshEvents({required bool parent, required bool leader, required bool ownInLeaderList}) async {
    if (parent) {
      ref.invalidate(currentSongsProvider);
      ref.invalidate(parentChildrenProvider);
      ref.invalidate(childrenAttendancesProvider);
      await ref.read(childrenAttendancesProvider.future).catchError((_) => const <ChildPersonAttendance>[]);
    } else if (leader) {
      ref.read(attendanceRefetchCounter.notifier).state++;
      if (_segment == RdEventsSegment.orgPlans) ref.invalidate(orgPlansProvider);
      if (ownInLeaderList) ref.invalidate(signoutDataProvider);
    } else {
      ref.invalidate(signoutDataProvider);
      await ref.read(rdSignoutDataProvider.future).catchError((_) => const SignoutData());
    }
  }

  // ---------------------------------------------------------------------------
  // Dirigent, Helfer, Beobachter
  // ---------------------------------------------------------------------------

  Widget _leaderBody(BuildContext context) {
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final isOrgLead = role.isAdmin || role.isResponsible;
    final org = isOrgLead ? ref.watch(currentOrganisationProvider).valueOrNull : null;
    final showOrgSegment = org != null;
    final segments = [
      RdEventsSegment.upcoming,
      RdEventsSegment.past,
      if (showOrgSegment) RdEventsSegment.orgPlans,
    ];
    final active = !showOrgSegment && _segment == RdEventsSegment.orgPlans
        ? RdEventsSegment.upcoming
        : _segment;
    final isPast = active == RdEventsSegment.past;
    final isOrgTab = active == RdEventsSegment.orgPlans;

    final async = ref.watch(realtimeAttendanceListProvider);
    final all = async.valueOrNull;
    if (all == null && !isOrgTab) {
      return async.hasError
          ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.read(attendanceRefetchCounter.notifier).state++,
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }
    // All types (hidden ones too): a Termin of a since-hidden Art keeps its
    // title, time, pill and all-day length. Only the filter chips are limited
    // to the visible Arten.
    final allTypes = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final types = allTypes.where((t) => t.visible).toList();
    final typeById = {for (final t in allTypes) t.id: t};
    final past = all == null ? const <Attendance>[] : rdPast(all, types: allTypes);
    final average = rdAveragePercentage(past);
    final source = all == null
        ? const <Attendance>[]
        : (isPast ? past : rdUpcoming(all, types: allTypes));
    final list = source.where((a) {
      if (_type != null && a.typeId != _type) return false;
      final info = rdEventInfo(a, typeById[a.typeId]);
      return _matches(info.title, a.place);
    }).toList();
    final sections = rdGroupEvents(list, (a) => a.date, past: isPast);
    final counts = isPast || isOrgTab
        ? const <int, RdStatusCounts>{}
        : (ref.watch(rdUpcomingCountsProvider).valueOrNull ?? const {});
    final canOpen = role.canAddAttendance;
    final own = role.canSeeSelfServiceTab && !isPast && !isOrgTab
        ? _ownByAttendance()
        : const <int, CrossTenantPersonAttendance>{};

    final pastLabel = showOrgSegment || average == null
        ? l10n.redesignEventsPast
        : l10n.redesignEventsPastAverage(average.round());

    final Widget content = isOrgTab
        ? RdOrgPlansSegmentBody(
            query: _query,
            sectionHeaderBuilder: (section) => _SectionLabel(section: section, past: false),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (types.length > 1) ...[
                const SizedBox(height: 12),
                _buildTypeFilterChips(context, types),
              ],
              const SizedBox(height: 8),
              if (sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RdInfoCard(
                    text: (all ?? const []).isEmpty
                        ? l10n.redesignEventsEmpty
                        : _query.isNotEmpty || _type != null
                            ? l10n.redesignEventsNoMatch
                            : (isPast ? l10n.redesignEventsNoPast : l10n.redesignTodayNoUpcoming),
                    // The one "+" of the page creates the first Termin.
                    icon: Icons.event_available_outlined,
                  ),
                ),
              for (final section in sections) ...[
                _SectionLabel(section: section, past: isPast),
                for (final a in section.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LeaderEventCard(
                      attendance: a,
                      type: typeById[a.typeId],
                      counts: a.id == null ? null : counts[a.id],
                      own: a.id == null ? null : own[a.id],
                      past: isPast,
                      orgName: org?.name,
                      selected: a.id != null && RdSplitScope.of(context)?.selectedId == a.id,
                      onTap: a.id != null && canOpen
                          ? () => RdSplitScope.open(context, RedesignRoutes.event(a.id!))
                          : null,
                    ),
                  ),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<double?>(
          valueListenable: _swipePos,
          builder: (context, pos, _) => RdSegmented<RdEventsSegment>(
            values: segments,
            selected: active,
            position: pos,
            labelOf: (s) => switch (s) {
              RdEventsSegment.upcoming => l10n.redesignEventsUpcoming,
              RdEventsSegment.past => pastLabel,
              RdEventsSegment.orgPlans => l10n.rdOrgEventsTabOrgPlans,
            },
            onChanged: _setSegment,
          ),
        ),
        RdSwipeSwitch<RdEventsSegment>(
          values: segments,
          selected: active,
          onChanged: _setSegment,
          onDrag: (pos) => _swipePos.value = pos,
          child: content,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Spieler, Stimmführer
  // ---------------------------------------------------------------------------

  Widget _playerBody(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(rdSignoutDataProvider);
    // A notification waits for its Termin: after a failed reload the
    // previous Termine would not hold it, so the error shows instead.
    final pending = ref.watch(pendingAttendanceIdProvider);
    final data = async.hasError && pending != null ? null : async.valueOrNull;
    if (data == null) {
      return async.hasError
          ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(signoutDataProvider),
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }
    final tenant = ref.watch(currentTenantProvider);
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    final actions = signoutEventActions(context, ref, tenant: tenant, player: player);
    // A notification, push or "open attendance" link asked for a Termin
    // (like "Meine Termine" does); also when it arrives while open.
    _openPending(data, actions);

    bool waiting(CrossTenantPersonAttendance att) {
      final qa = actions.quickActions(att, anyLate: true);
      return qa != null && att.status == AttendanceStatus.neutral && qa.canSignin;
    }

    final openCount = data.allUpcoming.where(waiting).length;
    final source = _past ? data.past : data.allUpcoming;
    final list = source
        .where((a) => !_onlyOpen || openCount == 0 || waiting(a))
        .where((a) => _matches(a.eventTitle, a.place))
        .toList();
    final sections = rdGroupEvents(list, (a) => a.date, past: _past);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segments(context, pastLabel: l10n.redesignEventsPastOwn(data.percentage)),
        _swipe(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Bitte bestätigen" and "Offene Dienste": unassigned duties are
            // taken over there, not answered in this list.
            if (!_past) const RdDutySection(),
            if (!_past && openCount > 0) ...[
              const SizedBox(height: 12),
              _WaitingBanner(
                count: openCount,
                active: _onlyOpen,
                onTap: () => setState(() => _onlyOpen = !_onlyOpen),
              ),
            ],
            const SizedBox(height: 8),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RdInfoCard(
                  text: _query.isNotEmpty
                      ? l10n.redesignEventsNoMatch
                      : (_past ? l10n.redesignEventsNoPast : l10n.redesignTodayNoUpcoming),
                  icon: Icons.event_available_outlined,
                ),
              ),
            for (final section in sections) ...[
              _SectionLabel(section: section, past: _past),
              for (final att in section.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlayerEventCard(
                    key: ValueKey('rd-own-${att.id ?? att.attendanceId}'),
                    att: att,
                    actions: actions,
                    showAnswer: !_past && waiting(att),
                  ),
                ),
            ],
          ],
        )),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Eltern
  // ---------------------------------------------------------------------------

  Widget _parentBody(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final kidsAsync = ref.watch(parentChildrenProvider);
    final attsAsync = ref.watch(childrenAttendancesProvider);
    ref.watch(pendingAttendanceIdProvider);
    final kids = kidsAsync.valueOrNull;
    // A failed reload shows the error with "retry" instead of the previous
    // Termine, so answers never go to a stale list.
    final error = kidsAsync.hasError || attsAsync.hasError;
    if (kids == null || !attsAsync.hasValue || error) {
      return error
          ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () {
                  ref.invalidate(parentChildrenProvider);
                  ref.invalidate(childrenAttendancesProvider);
                },
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }
    if (kids.isEmpty) return RdInfoCard(text: l10n.redesignTodayNoChildren, icon: Icons.info_outline);
    _openParentPending();

    final upcoming = ref.watch(upcomingParentAttendancesProvider);
    final past = ref.watch(pastParentAttendancesProvider);
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    String titleOf(ParentAttendanceGroup g) => rdParentTitle(types.where((t) => t.id == g.typeId).firstOrNull, g);
    final openCount = upcoming.where((g) => rdOpenChildren(g) > 0).length;
    final source = _past ? past : upcoming;
    final list = source
        .where((g) => _past || !_onlyOpen || openCount == 0 || rdOpenChildren(g) > 0)
        .where((g) => _matches(titleOf(g), g.place))
        .toList();
    final sections = rdGroupEvents(list, (g) => g.date, past: _past);

    // Rate per child, like "Vergangen · 92 % da" of a Spieler.
    final rates = [
      for (final kid in kids)
        if (kid.id != null && ref.watch(childStatsProvider(kid.id!)).totalCount > 0)
          (kid.firstName, ref.watch(childStatsProvider(kid.id!)).percentage),
    ];
    final pastLabel = kids.length == 1 && rates.length == 1
        ? l10n.redesignEventsPastOwn(rates.first.$2)
        : l10n.redesignEventsPast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segments(context, pastLabel: pastLabel),
        _swipe(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_past && kids.length > 1 && rates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  rates.map((r) => l10n.redesignParentsChildRate(r.$1, r.$2)).join('   '),
                  style: RdType.meta(p, size: 13),
                ),
              ),
            if (!_past && openCount > 0) ...[
              const SizedBox(height: 12),
              _WaitingBanner(
                count: openCount,
                active: _onlyOpen,
                onTap: () => setState(() => _onlyOpen = !_onlyOpen),
              ),
            ],
            const SizedBox(height: 8),
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RdInfoCard(
                  text: _query.isNotEmpty
                      ? l10n.redesignEventsNoMatch
                      : (_past ? l10n.redesignEventsNoPast : l10n.redesignTodayNoUpcoming),
                  icon: Icons.event_available_outlined,
                ),
              ),
            for (final section in sections) ...[
              _SectionLabel(section: section, past: _past),
              for (final g in section.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RdParentEventCard(
                    key: ValueKey('rd-parent-${g.attendanceId}'),
                    group: g,
                    past: _past,
                  ),
                ),
            ],
          ],
        )),
      ],
    );
  }
}
