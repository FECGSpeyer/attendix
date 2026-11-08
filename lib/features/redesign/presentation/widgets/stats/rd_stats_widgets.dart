import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/attendance_providers.dart' show playerAttendancePercentagesProvider;
import '../../../../../core/providers/attendance_type_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../core/utils/duty_utils.dart' show weekdayShortNames;
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart'
    show AppActionSheetAction, showAppActionSheet, showAppDatePicker;
import '../../../data/providers/rd_stats_providers.dart';
import '../../../data/providers/rd_today_providers.dart' show rdEventInfo;
import '../../../data/rd_stats_logic.dart';
import '../../pages/rd_members_page.dart' show rdPercentColor;
import '../manage/rd_settings_sheets.dart' show RdListNote;
import '../rd_widgets.dart';

// REDESIGN: building blocks of the Auswertung (canvas "Auswertung neu
// gedacht"): figures, the Termin bars, the status split, the Register rows,
// the people below 50 % and the sheets behind them.

/// "73 %" with a no-break space, so the sign never wraps on its own.
String rdPercent(int value) => '$value %';

/// "Do 16.10." of a Termin.
String rdStatsDay(DateTime date) =>
    '${weekdayShortNames[date.weekday - 1]} ${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(date)}';

/// Title of a Termin in the Auswertung ("Probe" or its own title).
String rdStatsEventTitle(RdStatsEvent e) => rdEventInfo(e.attendance, e.type).title;

/// One key figure ("Ø Anwesenheit 73 %"), optionally with the change
/// against the period before ([delta] in percentage points).
class RdStatsFigure extends StatelessWidget {
  const RdStatsFigure({super.key, required this.label, required this.value, this.delta});

  final String label;
  final String value;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final d = delta;
    final deltaText = d == null
        ? null
        : (d > 0 ? l10n.rdStatsDeltaUp(d) : (d < 0 ? l10n.rdStatsDeltaDown(-d) : l10n.rdStatsDeltaSame));
    final deltaLong = d == null
        ? null
        : (d > 0 ? l10n.rdStatsDeltaUpLong(d) : (d < 0 ? l10n.rdStatsDeltaDownLong(-d) : l10n.rdStatsDeltaSameLong));
    return RdCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Semantics(
        label: ['$label: $value', if (deltaLong != null) deltaLong].join(', '),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: RdType.meta(p, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (deltaText != null)
              Text(
                deltaText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: d! > 0 ? p.present : (d < 0 ? p.absent : p.text2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Column chart, one bar per Termin (oldest left); the weakest bar is
/// darker. A bar reads its day, title and percentage and opens the Termin.
class RdStatsBars extends StatelessWidget {
  const RdStatsBars({super.key, required this.events, required this.onTap});

  final List<RdStatsEvent> events;
  final ValueChanged<RdStatsEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    var lowest = 0;
    for (var i = 1; i < events.length; i++) {
      if (events[i].percent < events[lowest].percent) lowest = i;
    }
    String label(RdStatsEvent e) => l10n.rdStatsBar(rdStatsDay(e.date), rdStatsEventTitle(e), e.percent);
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < events.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: label(events[i]),
                    excludeSemantics: true,
                    child: Tooltip(
                      message: label(events[i]),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(events[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: FractionallySizedBox(
                            heightFactor: (events[i].percent / 100).clamp(0.02, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i == lowest ? p.softText : p.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: p.line),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rdStatsDay(events.first.date), style: RdType.meta(p, size: 11)),
            Text(rdStatsDay(events.last.date), style: RdType.meta(p, size: 11)),
          ],
        ),
      ],
    );
  }
}

/// Segments of [counts] in the order Anwesend, Verspätet, Entschuldigt,
/// Abwesend, Neutral.
List<(String, int, Color)> rdStatsSplit(BuildContext context, RdStatsCounts counts) {
  final p = context.rd;
  final l10n = context.l10n;
  return [
    (l10n.commonStatusPresent, counts.present, p.present),
    (l10n.commonStatusLateShort, counts.late, p.late),
    (l10n.commonStatusExcused, counts.excused, p.excused),
    (l10n.commonStatusAbsent, counts.absent, p.absent),
    (l10n.commonStatusNeutral, counts.open, p.text2),
  ];
}

/// Thin bar with the share of each status of [counts].
class RdStatsSplitBar extends StatelessWidget {
  const RdStatsSplitBar({super.key, required this.counts});

  final RdStatsCounts counts;

  @override
  Widget build(BuildContext context) {
    final split = rdStatsSplit(context, counts);
    return RdStatusBar(
      segments: [for (final (_, n, color) in split) RdBarSegment(n, color)],
      total: counts.total,
      semanticLabel: [
        for (final (label, n, _) in split)
          if (n > 0) '$label ${rdPercent(_share(n, counts.total))}',
      ].join(', '),
    );
  }
}

int _share(int n, int total) => total == 0 ? 0 : (n * 100 / total).round();

/// "Statusverteilung": how all counted entries of the period split up.
class RdStatsSplitCard extends StatelessWidget {
  const RdStatsSplitCard({super.key, required this.counts});

  final RdStatsCounts counts;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rdStatsSplit, style: RdType.section(p)),
          const SizedBox(height: 10),
          RdStatsSplitBar(counts: counts),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (label, n, color) in rdStatsSplit(context, counts))
                  if (n > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$label ${rdPercent(_share(n, counts.total))}', style: RdType.meta(p, size: 13)),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One Register or Terminart: name (with an optional [meta] line), bar
/// and percentage (the percentage keeps one line, also "100 %"). [onTap]
/// narrows the Auswertung to it.
class RdStatsGroupRow extends StatelessWidget {
  const RdStatsGroupRow({super.key, required this.name, required this.percent, this.meta, this.onTap, this.valueText});

  final String name;
  final int percent;
  final String? meta;
  final VoidCallback? onTap;

  /// Shown instead of the percentage (bar length stays [percent]).
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: onTap == null ? 0 : 36),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: RdType.body(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (meta != null) Text(meta!, style: RdType.meta(p, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: p.primary,
                  backgroundColor: p.track,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  valueText ?? rdPercent(percent),
                  maxLines: 1,
                  softWrap: false,
                  style: RdType.body(p).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 20, color: p.text2),
          ],
        ),
      ),
    );
    return Semantics(
      label: [name, if (meta != null) meta!, valueText ?? rdPercent(percent)].join(', '),
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null
          ? row
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row),
    );
  }
}

/// Label of an order of the Termine level.
String rdStatsSortLabel(AppLocalizations l10n, RdStatsEventSort sort) => switch (sort) {
      RdStatsEventSort.newest => l10n.rdStatsSortNewest,
      RdStatsEventSort.oldest => l10n.rdStatsSortOldest,
      RdStatsEventSort.weakest => l10n.rdStatsSortWeakest,
      RdStatsEventSort.best => l10n.rdStatsSortBest,
    };

/// Label of an order of the Personen level.
String rdStatsPersonSortLabel(AppLocalizations l10n, RdStatsPersonSort sort) => switch (sort) {
      RdStatsPersonSort.fewest => l10n.rdStatsPersonSortFewest,
      RdStatsPersonSort.most => l10n.rdStatsPersonSortMost,
      RdStatsPersonSort.absent => l10n.rdStatsPersonSortAbsent,
      RdStatsPersonSort.late => l10n.rdStatsPersonSortLate,
      RdStatsPersonSort.name => l10n.rdStatsPersonSortName,
    };

/// "Fällt auf": the people below 50 %, the Register that lost most
/// against the period before (else the weakest one), the weakest and the
/// best Termin. Each row leads on: the people, the Register as filter, the
/// Termin sheet. Nothing to show: nothing at all.
class RdStatsNotable extends StatelessWidget {
  const RdStatsNotable({
    super.key,
    required this.result,
    required this.previous,
    required this.groups,
    required this.onGroup,
    required this.onLow,
  });

  final RdStatsResult result;
  final RdStatsResult? previous;
  final List<Group> groups;

  /// Narrows the Auswertung to one Register.
  final ValueChanged<Group> onGroup;

  /// Shows the people below 50 % (Personen level, weakest first).
  final VoidCallback onLow;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final low = result.low();
    final drop = rdStatsBiggestDrop(result, previous);
    final weakGroup = drop == null && result.groups.length > 1 ? result.groups.last : null;
    final byPercent = rdSortStatsEvents(result.events, RdStatsEventSort.weakest);
    final weakest = byPercent.length > 1 ? byPercent.first : null;
    final best = byPercent.length > 1 && byPercent.last.percent > byPercent.first.percent ? byPercent.last : null;
    Widget pct(int v) => Text(
          rdPercent(v),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: rdPercentColor(p, v)),
        );
    final rows = <Widget>[
      if (low.isNotEmpty)
        RdListRow(
          key: const Key('rd-stats-notable-low'),
          leading: RdRowIcon(Icons.person_outline, color: p.absent, background: p.absentSoft),
          title: l10n.redesignStatsLow(low.length),
          subtitle: [for (final e in low.take(3)) rdPersonName(e.person)].join(', ') + (low.length > 3 ? ' …' : ''),
          onTap: onLow,
        ),
      if (drop != null)
        RdListRow(
          leading: RdRowIcon(Icons.trending_down, color: p.absent, background: p.absentSoft),
          title: l10n.rdStatsNotableDrop(drop.$1.group.name),
          subtitle: l10n.rdStatsNotableDropDetail(rdPercent(drop.$1.percent), rdPercent(drop.$1.percent + drop.$2)),
          onTap: () => onGroup(drop.$1.group),
        ),
      if (weakGroup != null)
        RdListRow(
          leading: const RdRowIcon(Icons.groups_outlined),
          title: l10n.rdStatsNotableWeakGroup(weakGroup.group.name),
          trailing: pct(weakGroup.percent),
          onTap: () => onGroup(weakGroup.group),
        ),
      if (weakest != null)
        RdListRow(
          leading: const RdRowIcon(Icons.south),
          title: l10n.rdStatsNotableWeakest,
          subtitle: '${rdStatsDay(weakest.date)} · ${rdStatsEventTitle(weakest)}',
          trailing: pct(weakest.percent),
          onTap: () => showRdStatsEventSheet(context, weakest, groups),
        ),
      if (best != null)
        RdListRow(
          leading: const RdRowIcon(Icons.north),
          title: l10n.rdStatsNotableBest,
          subtitle: '${rdStatsDay(best.date)} · ${rdStatsEventTitle(best)}',
          trailing: pct(best.percent),
          onTap: () => showRdStatsEventSheet(context, best, groups),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.rdStatsNotable),
        RdGroupedList(children: rows),
      ],
    );
  }
}

/// One Termin of the Termine level: day, title, who was missing, split
/// bar and percentage. [withDate] adds the date (lists not grouped by
/// month).
class RdStatsEventRow extends StatelessWidget {
  const RdStatsEventRow({super.key, required this.event, required this.onTap, this.withDate = false});

  final RdStatsEvent event;
  final VoidCallback onTap;
  final bool withDate;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final c = event.counts;
    final missing = [
      if (c.absent > 0) l10n.rdStatsCountAbsent(c.absent),
      if (c.excused > 0) l10n.rdStatsCountExcused(c.excused),
      if (c.late > 0) l10n.rdStatsCountLate(c.late),
      if (c.open > 0) l10n.rdStatsCountOpen(c.open),
    ];
    final d = event.date;
    return RdListRow(
      leading: RdDateTile(weekday: weekdayShortNames[d.weekday - 1], day: '${d.day}'),
      title: rdStatsEventTitle(event),
      subtitle: [
        if (withDate) DateFormat(dateFmt(DateFmtKind.short)).format(d),
        if (c.total > 0) missing.isEmpty ? l10n.rdStatsAllThere : missing.join(', '),
      ].join(' · '),
      footer: c.total > 0 ? RdStatsSplitBar(counts: c) : null,
      // Fixed width: the split bars of all rows end at the same place.
      trailing: SizedBox(
        width: 56,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            rdPercent(event.percent),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: rdPercentColor(p, event.percent),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Sheet of one Termin: how the people split up and who was missing, by
/// status, with the reason. One action: "Termin öffnen".
Future<void> showRdStatsEventSheet(BuildContext context, RdStatsEvent event, List<Group> groups) {
  final router = GoRouter.of(context);
  return showRdSheet<void>(context, _EventSheet(event: event, groups: groups, router: router));
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.event, required this.groups, required this.router});

  final RdStatsEvent event;
  final List<Group> groups;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final info = rdEventInfo(event.attendance, event.type);
    final groupName = {for (final g in groups) if (g.id != null) g.id!: g.name};
    String name(PersonAttendance pa) => '${pa.firstName ?? ''} ${pa.lastName ?? ''}'.trim();
    final missing = [
      (l10n.commonStatusAbsent, [for (final pa in event.rows) if (pa.status == AttendanceStatus.absent) pa]),
      (l10n.commonStatusExcused, [for (final pa in event.rows) if (pa.status == AttendanceStatus.excused) pa]),
      (l10n.commonStatusLateShort, [
        for (final pa in event.rows)
          if (pa.status == AttendanceStatus.late || pa.status == AttendanceStatus.lateExcused) pa,
      ]),
      (l10n.commonStatusNeutral, [for (final pa in event.rows) if (pa.status == AttendanceStatus.neutral) pa]),
    ];
    for (final (_, list) in missing) {
      list.sort((a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()));
    }
    final id = event.attendance.id;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Semantics(
          header: true,
          child: Text('${info.title} · ${rdStatsDay(event.date)}', style: RdType.cardTitle(p)),
        ),
        const SizedBox(height: 2),
        Text(
          [rdPercent(event.percent), if (info.timeRange.isNotEmpty) info.timeRange].join(' · '),
          style: RdType.meta(p, size: 14),
        ),
        const SizedBox(height: 12),
        RdStatsSplitBar(counts: event.counts),
        if (missing.every((m) => m.$2.isEmpty)) ...[
          const SizedBox(height: 16),
          Text(event.rows.isEmpty ? l10n.rdStatsEventEmpty : l10n.rdStatsEventAllThere, style: RdType.body(p)),
        ],
        for (final (label, list) in missing)
          if (list.isNotEmpty) ...[
            const SizedBox(height: 16),
            RdGroupLabel(l10n.rdStatsEventGroup(label, list.length)),
            RdGroupedList(
              children: [
                for (final pa in list)
                  RdListRow(
                    title: name(pa),
                    subtitle: (pa.notes ?? '').trim().isEmpty ? null : pa.notes!.trim(),
                    value: groupName[pa.instrument],
                  ),
              ],
            ),
          ],
        if (id != null) ...[
          const SizedBox(height: 20),
          RdPrimaryButton(
            label: l10n.rdStatsEventOpen,
            onPressed: () {
              Navigator.of(context).pop();
              router.push(RedesignRoutes.event(id));
            },
          ),
        ],
      ],
    );
  }
}

/// Which list the "Sortieren" row of the filter sheet orders.
enum RdStatsSortFor { events, people }

/// "Filter" of the Auswertung: Terminarten and Register, with [sort] also
/// the order of the Termine or the Personen ("Sortieren & Filtern").
/// Changes apply at once; the button shows how many Termine are left.
Future<void> showRdStatsFilterSheet(
  BuildContext context, {
  required List<AttendanceType> types,
  required List<Group> groups,
  RdStatsSortFor? sort,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (sheet, controller) => _FilterSheet(controller: controller, types: types, groups: groups, sort: sort),
    ),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.controller, required this.types, required this.groups, required this.sort});

  final ScrollController controller;
  final List<AttendanceType> types;
  final List<Group> groups;
  final RdStatsSortFor? sort;

  Future<void> _pickSort<T>(
    BuildContext context,
    WidgetRef ref,
    StateProvider<T> provider,
    List<T> values,
    String Function(T) label,
  ) async {
    final current = ref.read(provider);
    final choice = await showAppActionSheet<T>(
      context,
      title: context.l10n.redesignWorksSort,
      actions: [
        for (final s in values)
          AppActionSheetAction(value: s, icon: s == current ? Icons.check : null, label: label(s)),
      ],
    );
    if (choice != null) ref.read(provider.notifier).state = choice;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final filter = ref.watch(rdStatsFilterProvider);
    final shown = rdStatsTypeIds(filter, types);
    final events = ref.watch(rdStatsResultProvider).events.length;
    void set(RdStatsFilter next) => ref.read(rdStatsFilterProvider.notifier).state = next;
    void toggleType(String id) =>
        set(rdStatsFilterWithTypes(filter, shown.contains(id) ? ({...shown}..remove(id)) : {...shown, id}, types));

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(sort != null ? l10n.redesignWorksFilterTitle : l10n.redesignWorksFilter, style: RdType.section(p)),
              ),
            ),
            RdTextLink(
              label: l10n.redesignWorksFilterReset,
              onTap: () {
                set(const RdStatsFilter());
                switch (sort) {
                  case RdStatsSortFor.events:
                    ref.read(rdStatsEventSortProvider.notifier).state = RdStatsEventSort.newest;
                  case RdStatsSortFor.people:
                    ref.read(rdStatsPersonSortProvider.notifier).state = RdStatsPersonSort.fewest;
                  case null:
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sort != null) ...[
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-stats-sort'),
                title: l10n.redesignWorksSort,
                value: sort == RdStatsSortFor.events
                    ? rdStatsSortLabel(l10n, ref.watch(rdStatsEventSortProvider))
                    : rdStatsPersonSortLabel(l10n, ref.watch(rdStatsPersonSortProvider)),
                onTap: () => sort == RdStatsSortFor.events
                    ? _pickSort(context, ref, rdStatsEventSortProvider, RdStatsEventSort.values,
                        (s) => rdStatsSortLabel(l10n, s))
                    : _pickSort(context, ref, rdStatsPersonSortProvider, RdStatsPersonSort.values,
                        (s) => rdStatsPersonSortLabel(l10n, s)),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        RdGroupLabel(l10n.rdStatsFilterTypes),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in types)
              if (t.id != null)
                RdChoiceChip(label: t.name, selected: shown.contains(t.id), onTap: () => toggleType(t.id!)),
          ],
        ),
        RdListNote(l10n.rdStatsFilterTypesHint),
        if (rdStatsGroups(groups).length > 1) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.rdStatsFilterGroups),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in rdStatsGroups(groups))
                RdChoiceChip(
                  label: g.name,
                  selected: filter.groupIds.contains(g.id),
                  onTap: () => set(filter.toggleGroup(g.id!)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        RdPrimaryButton(label: l10n.rdStatsFilterShow(events), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// "Eigener Zeitraum": Von and Bis. Returns the chosen range, null when
/// closed.
Future<DateTimeRange?> showRdStatsRangeSheet(BuildContext context, DateTimeRange initial) =>
    showRdSheet<DateTimeRange>(context, _RangeSheet(initial: initial));

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({required this.initial});

  final DateTimeRange initial;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late DateTime _from = widget.initial.start;
  late DateTime _to = widget.initial.end;

  Future<void> _pick({required bool from}) async {
    final today = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      // Von ≤ Bis, nothing after today (the Auswertung counts past Termine).
      firstDate: from ? DateTime(2015) : _from,
      lastDate: from ? _to : DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = DateFormat(dateFmt());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSheetTitle(l10n.rdStatsRangeTitle),
          RdGroupedList(
            children: [
              RdListRow(title: l10n.rdStatsRangeFrom, value: fmt.format(_from), onTap: () => _pick(from: true)),
              RdListRow(title: l10n.rdStatsRangeTo, value: fmt.format(_to), onTap: () => _pick(from: false)),
            ],
          ),
          const SizedBox(height: 20),
          RdPrimaryButton(
            label: l10n.rdStatsRangeShow,
            onPressed: () => Navigator.of(context).pop(DateTimeRange(start: _from, end: _to)),
          ),
        ],
      ),
    );
  }
}

/// "Zählt zur Anwesenheitsquote" below "So wird gezählt": the Terminarten
/// that count for the percentages everywhere (Mitglieder, Heute,
/// Auswertung). Same value as the switch on the Terminart.
class RdStatsCountedTypes extends ConsumerWidget {
  const RdStatsCountedTypes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final names = [for (final t in types) if (t.includeInAverage) t.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-stats-counted-types'),
              title: l10n.rdStatsCountedTypes,
              subtitle: names.isEmpty ? l10n.rdStatsCountedTypesNone : names.join(', '),
              onTap: types.isEmpty ? null : () => showRdSheet<void>(context, const _CountedTypesSheet()),
            ),
          ],
        ),
        RdListNote(l10n.rdStatsCountedTypesHint),
      ],
    );
  }
}

class _CountedTypesSheet extends ConsumerStatefulWidget {
  const _CountedTypesSheet();

  @override
  ConsumerState<_CountedTypesSheet> createState() => _CountedTypesSheetState();
}

class _CountedTypesSheetState extends ConsumerState<_CountedTypesSheet> {
  /// The type being saved; switches are disabled meanwhile.
  String? _saving;

  /// Saves for the group shown when the change started; aborts when the
  /// group changed meanwhile. Everything used after the await is bound
  /// before it.
  Future<void> _set(AttendanceType type, bool value) async {
    final id = type.id;
    final tenantId = ref.read(currentTenantIdProvider);
    if (_saving != null || id == null || tenantId == null || DemoGuard.blocked()) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(attendanceTypeNotifierProvider.notifier);
    final failed = context.l10n.rdSettingsSaveFailed;
    setState(() => _saving = id);
    try {
      final saved = await notifier.updateType(id, {'include_in_average': value});
      if (saved == null) {
        if (mounted) ToastHelper.showError(context, failed);
        return;
      }
      // The percentages of the members follow the new choice.
      if (container.read(currentTenantIdProvider) == tenantId) container.invalidate(playerAttendancePercentagesProvider);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, failed);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetTitle(l10n.rdStatsCountedTypes),
        RdGroupedList(
          children: [
            for (final t in types)
              if (t.id != null)
                RdSwitchRow(
                  key: ValueKey('rd-stats-counted-${t.id}'),
                  title: t.name,
                  value: t.includeInAverage,
                  onChanged: _saving == null ? (v) => _set(t, v) : null,
                ),
          ],
        ),
        RdListNote(l10n.rdStatsCountedTypesHint),
      ],
    );
  }
}
