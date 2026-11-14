import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart' show archivedPlayersProvider, playersProvider;
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/certificate_service.dart' show isVorkursTenantName;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../export/presentation/pages/export_page.dart' show showExportModal;
import '../../data/providers/rd_stats_providers.dart';
import '../../data/rd_stats_logic.dart';
import '../../data/rd_words.dart';
import '../widgets/manage/rd_data_sheets.dart' show rdGenerateCertificates;
import '../widgets/stats/rd_stats_fields.dart';
import '../widgets/stats/rd_stats_levels.dart';
import '../widgets/stats/rd_stats_widgets.dart';
import 'rd_general_settings_page.dart' show RdTenantSettings, RdTenantSettingsBlock;
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/rd_widgets.dart';
import '../widgets/rd_split_view.dart' show RdManageBackLink;

/// REDESIGN: Verwaltung › Auswertung (canvas "Auswertung neu gedacht",
/// variant B): period (presets or Von / Bis) and filter (Terminart,
/// Register) on top, then the levels Überblick (figures with the change
/// against the period before, Verlauf, "Fällt auf", status split, Register,
/// Terminarten) and Termine (every Termin, sortable; a tap shows who was
/// missing). Everything is counted one way ([rdComputeStats]); the Termine
/// come from the providers of the old statistics page.
class RdStatsPage extends ConsumerStatefulWidget {
  const RdStatsPage({super.key});

  @override
  ConsumerState<RdStatsPage> createState() => _RdStatsPageState();
}

enum _Level { overview, events, register, people }

class _RdStatsPageState extends ConsumerState<RdStatsPage> {
  /// At most this many bars; older Termine are left out of the chart.
  static const _maxBars = 20;

  _Level _level = _Level.overview;
  final _swipePos = ValueNotifier<double?>(null);

  /// While pulled to refresh the shown numbers stay until the new ones are
  /// there; otherwise a reload (other group, other period) shows loading.
  bool _refreshing = false;

  /// Counts the refreshes: only the latest one ends [_refreshing], and
  /// another period or group ends it at once.
  int _refreshGen = 0;

  void _stopRefreshing() {
    _refreshing = false;
    _refreshGen++;
  }

  @override
  void initState() {
    super.initState();
    // The date range is shared with the old statistics page: apply the
    // chosen preset again (a custom range stays as it is).
    // On the same days it only reloads quietly, the numbers stay meanwhile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final range = ref.read(rdStatsRangeProvider);
      if (range == RdStatsRange.custom) return;
      final now = DateTime.now();
      final current = ref.read(statisticsDateRangeProvider);
      final start = rdStatsRangeStart(range, now, seasonStart: ref.read(currentTenantProvider)?.seasonStart);
      if (DateUtils.isSameDay(current.start, start) && DateUtils.isSameDay(current.end, now)) {
        _refresh();
      } else {
        _setRange(range);
      }
    });
  }

  @override
  void dispose() {
    _swipePos.dispose();
    super.dispose();
  }

  void _setRange(RdStatsRange range) {
    if (!mounted) return;
    _stopRefreshing();
    ref.read(rdStatsRangeProvider.notifier).state = range;
    final now = DateTime.now();
    final start = rdStatsRangeStart(range, now, seasonStart: ref.read(currentTenantProvider)?.seasonStart);
    ref.read(statisticsDateRangeProvider.notifier).setRange(start, now);
  }

  Future<void> _pickCustom() async {
    final current = ref.read(statisticsDateRangeProvider);
    final picked = await showRdStatsRangeSheet(context, DateTimeRange(start: current.start, end: current.end));
    if (picked == null || !mounted) return;
    _stopRefreshing();
    ref.read(rdStatsRangeProvider.notifier).state = RdStatsRange.custom;
    ref.read(statisticsDateRangeProvider.notifier).setRange(picked.start, picked.end);
  }

  Future<void> _refresh() async {
    final gen = ++_refreshGen;
    setState(() => _refreshing = true);
    ref.invalidate(filteredAttendancesForStatsProvider);
    ref.invalidate(activePlayersForStatsProvider);
    ref.invalidate(rdStatsPreviousDataProvider);
    // Mitglieder and Zusatzfelder (the Personen level) count these.
    ref.invalidate(playersProvider);
    ref.invalidate(archivedPlayersProvider);
    Future<void> done(Future<Object?> f) => f.then((_) {}, onError: (Object _) {});
    try {
      await Future.wait([
        done(ref.read(allPersonAttendancesForStatsProvider.future)),
        done(ref.read(activePlayersForStatsProvider.future)),
        done(ref.read(rdStatsPreviousDataProvider.future)),
        done(ref.read(playersProvider.future)),
        done(ref.read(archivedPlayersProvider.future)),
      ]);
    } finally {
      if (mounted && gen == _refreshGen) setState(() => _refreshing = false);
    }
  }

  void _setFilter(RdStatsFilter next) => ref.read(rdStatsFilterProvider.notifier).state = next;

  void _setLevel(_Level level) => setState(() => _level = level);

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final range = ref.watch(rdStatsRangeProvider);
    // A new Saisonbeginn (changed below) moves the range "Saison".
    ref.listen(currentTenantProvider.select((t) => t?.seasonStart), (before, now) {
      if (before != now && ref.read(rdStatsRangeProvider) == RdStatsRange.season) _setRange(RdStatsRange.season);
    });
    final attendancesAsync = ref.watch(filteredAttendancesForStatsProvider);
    final rowsAsync = ref.watch(allPersonAttendancesForStatsProvider);
    final result = ref.watch(rdStatsResultProvider);
    final filter = ref.watch(rdStatsFilterProvider);
    // Another group shows loading, not the numbers kept while refreshing.
    ref.listen(currentTenantIdProvider, (before, now) {
      if (before != now) _stopRefreshing();
    });
    final tenantId = ref.watch(currentTenantIdProvider);
    final types = rdStatsTypesOf(ref.watch(attendanceTypesProvider), tenantId);
    final groups = rdStatsGroupsOf(ref.watch(groupsProvider), tenantId);
    final tenant = ref.watch(currentTenantProvider);
    final dates = ref.watch(statisticsDateRangeProvider);
    // Watched on every level, so a refresh can wait for it.
    final previous = ref.watch(rdStatsPreviousResultProvider);
    // Riverpod keeps the old values while reloading, also those of the group
    // before: only a pull to refresh shows them meanwhile.
    bool waiting(AsyncValue<Object?> a) => a.isLoading && (!a.hasValue || !_refreshing);
    final loading =
        waiting(attendancesAsync) || ((attendancesAsync.valueOrNull?.isNotEmpty ?? false) && waiting(rowsAsync));
    final shortDate = DateFormat(dateFmt(DateFmtKind.short));

    return RdPage(
      onRefresh: _refresh,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RdManageBackLink(
            label: l10n.redesignAdminTitle,
            onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.redesignStatsTitle, style: RdType.largeTitle(p))),
        const SizedBox(height: 14),
        // Period and "Filter" in one line, the active filters below.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in RdStatsRange.values)
                    RdChoiceChip(
                      label: switch (r) {
                        RdStatsRange.season => l10n.redesignStatsRangeSeason,
                        RdStatsRange.threeMonths => l10n.redesignStatsRange3m,
                        RdStatsRange.twelveMonths => l10n.redesignStatsRange12m,
                        RdStatsRange.custom =>
                          range == RdStatsRange.custom
                              ? '${shortDate.format(dates.start)} – ${shortDate.format(dates.end)}'
                              : l10n.rdStatsRangeCustom,
                      },
                      selected: r == range,
                      onTap: () => r == RdStatsRange.custom ? _pickCustom() : _setRange(r),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            RdFilterLink(
              key: const Key('rd-stats-filter'),
              label: filter.count > 0 ? '${l10n.redesignWorksFilter} · ${filter.count}' : l10n.redesignWorksFilter,
              onTap: () => showRdStatsFilterSheet(
                context,
                types: types,
                groups: groups,
                sort: switch (_level) {
                  _Level.events => RdStatsSortFor.events,
                  _Level.people => RdStatsSortFor.people,
                  _ => null,
                },
              ),
            ),
          ],
        ),
        if (filter.count > 0) ...[
          const SizedBox(height: 8),
          _FilterChips(filter: filter, types: types, groups: groups),
        ],
        const SizedBox(height: 14),
        ValueListenableBuilder<double?>(
          valueListenable: _swipePos,
          builder:
              (context, pos, _) => RdSegmented<_Level>(
                values: _Level.values,
                selected: _level,
                position: pos,
                semanticLabel: l10n.rdStatsTabsLabel,
                labelOf:
                    (level) => switch (level) {
                      _Level.overview => l10n.rdStatsTabOverview,
                      _Level.events => l10n.rdStatsTabEvents,
                      _Level.register => l10n.rdWordsGroups(ref.watch(rdGroupKindProvider)),
                      _Level.people => l10n.rdStatsTabPeople,
                    },
                onChanged: _setLevel,
              ),
        ),
        const SizedBox(height: 14),
        RdSwipeSwitch<_Level>(
          values: _Level.values,
          selected: _level,
          onChanged: _setLevel,
          onDrag: (pos) => _swipePos.value = pos,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              else if (attendancesAsync.hasError)
                RdInfoCard(
                  text: l10n.redesignTodayLoadFailed,
                  icon: Icons.cloud_off_outlined,
                  action: RdOutlineButton(
                    label: l10n.redesignCommonRetry,
                    onPressed: () => ref.invalidate(filteredAttendancesForStatsProvider),
                  ),
                )
              else if (result.events.isEmpty)
                RdCard(child: Text(l10n.redesignStatsEmpty, style: RdType.body(p)))
              else
                ...switch (_level) {
                  _Level.overview => _overview(context, result, previous, filter, types, groups),
                  _Level.events => _events(context, result, groups),
                  _Level.register => _register(context, result, filter),
                  _Level.people => _people(context, result, groups),
                },
              if (_level == _Level.people && !loading && !attendancesAsync.hasError) ...[
                // Ionic stats: Mitglieder and Alter (all Register),
                // Zusatzfelder and the organisation.
                const SizedBox(height: 24),
                const RdStatsMembersCard(),
                const SizedBox(height: 12),
                const RdStatsAgeCard(),
                const SizedBox(height: 24),
                RdStatsFieldsCard(filter: filter),
                const SizedBox(height: 24),
                const RdStatsOrganisationCard(),
              ],
              if (_level == _Level.overview) ...[
                // Saison and Zählweise (from the old "Allgemein"), which
                // Terminarten count, Export and Urkunden (Vorkurs).
                const SizedBox(height: 24),
                // One section: since when, Arbeit/Schicht and which Terminarten.
                RdTenantSettingsBlock(sections: const [RdTenantSettings.counting], label: l10n.rdAdminCounting),
                const SizedBox(height: 8),
                const RdStatsCountedTypes(),
                const SizedBox(height: 24),
                RdGroupLabel(l10n.rdAdminData),
                RdGroupedList(
                  children: [
                    RdListRow(
                      leading: const RdRowIcon(Icons.download_outlined),
                      title: l10n.settingsExport,
                      subtitle: l10n.rdAdminExportHint,
                      onTap: () => showExportModal(context),
                    ),
                    if (isVorkursTenantName(tenant?.shortName, tenant?.longName))
                      RdListRow(
                        leading: const RdRowIcon(Icons.workspace_premium_outlined),
                        title: l10n.rdAdminCertificates,
                        subtitle: l10n.rdAdminCertificatesHint,
                        onTap: () => rdGenerateCertificates(context, ref),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Überblick: figures, Verlauf, "Fällt auf", status split, Register and
  /// Terminarten (a tap on those narrows the filter).
  List<Widget> _overview(
    BuildContext context,
    RdStatsResult result,
    RdStatsResult? previous,
    RdStatsFilter filter,
    List<AttendanceType> types,
    List<Group> groups,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final players = rdStatsPeopleOf(ref.watch(activePlayersForStatsProvider), ref.watch(currentTenantIdProvider));
    final active =
        filter.groupIds.isEmpty
            ? players.length
            : players.where((pl) => filter.groupIds.contains(pl.instrument)).length;
    final bars =
        result.events.length > _maxBars ? result.events.sublist(result.events.length - _maxBars) : result.events;
    final byType = rdStatsByType(result.events);
    // "Fällt auf": a Register shows its people, the people below 50 % the
    // Personen level, weakest first.
    void onGroup(Group g) {
      _setFilter(filter.withGroups({g.id!}));
      _setLevel(_Level.people);
    }

    void onLow() {
      ref.read(rdStatsPersonSortProvider.notifier).state = RdStatsPersonSort.fewest;
      _setLevel(_Level.people);
    }
    return [
      // Same height for all three, also with "ggü. davor" under the Ø.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RdStatsFigure(
                label: l10n.redesignStatsAvg,
                value: rdPercent(result.average),
                delta: previous == null ? null : result.average - previous.average,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: RdStatsFigure(label: l10n.redesignStatsEvents, value: '${result.events.length}')),
            const SizedBox(width: 8),
            Expanded(child: RdStatsFigure(label: l10n.redesignStatsMembers, value: '$active')),
          ],
        ),
      ),
      const SizedBox(height: 12),
      RdCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.redesignStatsPerEvent, style: RdType.section(p))),
                RdTextLink(label: l10n.redesignTodayAllEvents, onTap: () => _setLevel(_Level.events)),
              ],
            ),
            Text(l10n.rdStatsBarsHint(bars.length), style: RdType.meta(p, size: 13)),
            const SizedBox(height: 14),
            RdStatsBars(events: bars, onTap: (e) => showRdStatsEventSheet(context, e, groups)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      RdStatsNotable(result: result, previous: previous, groups: groups, onGroup: onGroup, onLow: onLow),
      if (result.counts.total > 0) ...[const SizedBox(height: 12), RdStatsSplitCard(counts: result.counts)],
      if (byType.length > 1) ...[
        const SizedBox(height: 12),
        RdCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.rdStatsByType, style: RdType.section(p)),
              Text(l10n.rdStatsByTypeHint, style: RdType.meta(p, size: 13)),
              const SizedBox(height: 10),
              for (final t in byType)
                RdStatsGroupRow(
                  name: t.type.name,
                  meta: l10n.rdStatsEvents(t.events),
                  percent: t.average,
                  onTap: () => _setFilter(rdStatsFilterWithTypes(filter, {t.type.id!}, types)),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  /// Termine: every Termin of the period in the chosen order; by date with
  /// month headings.
  List<Widget> _events(BuildContext context, RdStatsResult result, List<Group> groups) {
    final p = context.rd;
    final l10n = context.l10n;
    final sort = ref.watch(rdStatsEventSortProvider);
    final events = rdSortStatsEvents(result.events, sort);
    final byDate = sort == RdStatsEventSort.newest || sort == RdStatsEventSort.oldest;
    Widget row(RdStatsEvent e) => RdStatsEventRow(
      key: ValueKey('rd-stats-event-${e.attendance.id}'),
      event: e,
      withDate: !byDate,
      onTap: () => showRdStatsEventSheet(context, e, groups),
    );
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          '${l10n.rdStatsEvents(events.length)} · ${rdStatsSortLabel(l10n, sort)}',
          style: RdType.meta(p, size: 13),
        ),
      ),
    ];
    List<Widget> list() {
      if (!byDate) return [RdGroupedList(children: [for (final e in events) row(e)])];
      final now = DateTime.now();
      final months = <DateTime, List<RdStatsEvent>>{};
      for (final e in events) {
        months.putIfAbsent(DateTime(e.date.year, e.date.month), () => []).add(e);
      }
      return [
        for (final (i, entry) in months.entries.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          RdGroupLabel(
            DateFormat(entry.key.year == now.year ? 'MMMM' : 'MMMM y', currentIntlLocale()).format(entry.key),
          ),
          RdGroupedList(children: [for (final e in entry.value) row(e)]),
        ],
      ];
    }

    children.add(
      _ByWidth(
        wide: () => RdStatsEventsTable(
          events: events,
          groups: groups,
          sort: sort,
          onSort: (s) => ref.read(rdStatsEventSortProvider.notifier).state = s,
        ),
        narrow: list,
      ),
    );
    return children;
  }

  /// Register: each Register with people, curve per month and quote; a
  /// tap shows its people.
  List<Widget> _register(BuildContext context, RdStatsResult result, RdStatsFilter filter) {
    final p = context.rd;
    final l10n = context.l10n;
    if (result.groups.isEmpty) return [RdCard(child: Text(l10n.redesignStatsEmpty, style: RdType.body(p)))];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(l10n.rdStatsGroupHint(ref.watch(rdGroupKindProvider)), style: RdType.meta(p, size: 13)),
      ),
      RdGroupedList(
        children: [
          for (final g in result.groups)
            RdStatsRegisterRow(
              key: ValueKey('rd-stats-register-${g.group.id}'),
              group: g,
              onTap: () {
                _setFilter(filter.withGroups({g.group.id!}));
                _setLevel(_Level.people);
              },
            ),
        ],
      ),
    ];
  }

  /// Personen: every active person with counted Termine in the chosen
  /// order; a tap opens the person sheet.
  List<Widget> _people(BuildContext context, RdStatsResult result, List<Group> groups) {
    final p = context.rd;
    final l10n = context.l10n;
    final sort = ref.watch(rdStatsPersonSortProvider);
    final people = rdSortStatsPeople(result.people, sort);
    final groupName = {for (final g in groups) if (g.id != null) g.id!: g.name};
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          '${l10n.commonPersons(people.length)} · ${rdStatsPersonSortLabel(l10n, sort)}',
          style: RdType.meta(p, size: 13),
        ),
      ),
      _ByWidth(
        wide: () => RdStatsPeopleTable(
          result: result,
          people: people,
          groups: groups,
          sort: sort,
          onSort: (s) => ref.read(rdStatsPersonSortProvider.notifier).state = s,
        ),
        narrow: () => [
          RdGroupedList(
            children: [
              for (final person in people)
                RdStatsPersonRow(
                  key: ValueKey('rd-stats-person-${person.person.id}'),
                  person: person,
                  groupName: groupName,
                  onTap: () => showRdStatsPersonSheet(context, result, person, groups),
                ),
            ],
          ),
        ],
      ),
    ];
  }
}

/// The table when the content is wide enough for it (Mac, tablet), else the
/// list. The width the page really has counts, after the sidebar and the
/// padding.
class _ByWidth extends StatelessWidget {
  const _ByWidth({required this.wide, required this.narrow});

  final Widget Function() wide;
  final List<Widget> Function() narrow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth >= rdStatsTableWidth
            ? wide()
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: narrow()),
      );
}

/// Active filters as removable chips.
class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter, required this.types, required this.groups});

  final RdStatsFilter filter;
  final List<AttendanceType> types;
  final List<Group> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    void set(RdStatsFilter next) => ref.read(rdStatsFilterProvider.notifier).state = next;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (filter.typeIds != null)
          _chip(
            l10n,
            [
              for (final t in types)
                if (filter.typeIds!.contains(t.id)) t.name,
            ].join(', '),
            () => set(filter.withTypes(null)),
          ),
        for (final g in groups)
          if (filter.groupIds.contains(g.id)) _chip(l10n, g.name, () => set(filter.toggleGroup(g.id!))),
      ],
    );
  }

  Widget _chip(AppLocalizations l10n, String label, VoidCallback onRemove) => RdRemovableChip(
    label: label.isEmpty ? l10n.rdStatsFilterTypes : label,
    semanticLabel: l10n.rdStatsFilterRemove(label.isEmpty ? l10n.rdStatsFilterTypes : label),
    onRemove: onRemove,
  );
}
