import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/statistics_providers.dart' show activePlayersForStatsProvider;
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_palette.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/statistics_utils.dart' show computeAverageAgePerGroup;
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/rd_stats_logic.dart';
import '../../pages/rd_members_page.dart' show rdPercentColor;
import '../rd_widgets.dart';
import 'rd_stats_widgets.dart';

// REDESIGN: the levels Register and Personen of the Auswertung (canvas
// "Auswertung neu gedacht", variant B, Paket 2): Register with their curve,
// persons with their counts and the person sheet, the tables on wide
// screens, Mitglieder and Alter.

/// From this content width the Termine and the Personen are tables.
const double rdStatsTableWidth = 600;

/// Colour of one status in the Auswertung (dots, pills).
Color rdStatsStatusColor(RdPalette p, AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => p.present,
      AttendanceStatus.late || AttendanceStatus.lateExcused => p.late,
      AttendanceStatus.excused => p.excused,
      AttendanceStatus.absent => p.absent,
      _ => p.text2,
    };

RdTone? _tone(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => RdTone.present,
      AttendanceStatus.late || AttendanceStatus.lateExcused => RdTone.late,
      AttendanceStatus.excused => RdTone.excused,
      AttendanceStatus.absent => RdTone.absent,
      _ => null,
    };

String _statusLabel(AppLocalizations l10n, AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => l10n.commonStatusPresent,
      AttendanceStatus.late || AttendanceStatus.lateExcused => l10n.commonStatusLateShort,
      AttendanceStatus.excused => l10n.commonStatusExcused,
      AttendanceStatus.absent => l10n.commonStatusAbsent,
      _ => l10n.commonStatusNeutral,
    };

/// Percentage in its colour with a fixed width, so the bars and dots of a
/// list end at the same place.
class RdStatsPercent extends StatelessWidget {
  const RdStatsPercent(this.percent, {super.key, this.width = 56});

  final int percent;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          rdPercent(percent),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: rdPercentColor(p, percent),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Small curve of a Register: its quote per month, the last month as dot.
class RdStatsSpark extends StatelessWidget {
  const RdStatsSpark({super.key, required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox(width: 56);
    return ExcludeSemantics(
      child: CustomPaint(size: const Size(56, 20), painter: _SparkPainter(values, context.rd.primary)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce((a, b) => a < b ? a : b) - 4;
    final hi = values.reduce((a, b) => a > b ? a : b) + 4;
    Offset at(int i) => Offset(
          2 + i * (size.width - 4) / (values.length - 1),
          size.height - 2 - (values[i] - lo) / (hi - lo) * (size.height - 4),
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color || !_same(old.values, values);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One Register of the Register level: name, people, curve and quote.
class RdStatsRegisterRow extends StatelessWidget {
  const RdStatsRegisterRow({super.key, required this.group, required this.onTap});

  final RdStatsGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RdListRow(
      title: group.group.name,
      subtitle: context.l10n.commonPersons(group.people),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RdStatsSpark(values: [for (final (_, v) in group.months) v]),
          const SizedBox(width: 8),
          RdStatsPercent(group.percent),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// "Viola · 2 abwesend, 1 verspätet" of a person (like the Termine).
String rdStatsPersonLine(AppLocalizations l10n, RdStatsPerson person, Map<int, String> groupName) {
  final c = person.counts;
  final missing = [
    if (c.absent > 0) l10n.rdStatsCountAbsent(c.absent),
    if (c.excused > 0) l10n.rdStatsCountExcused(c.excused),
    if (c.late > 0) l10n.rdStatsCountLate(c.late),
    if (c.open > 0) l10n.rdStatsCountOpen(c.open),
  ];
  return [
    if (groupName[person.person.instrument] case final g?) g,
    missing.isEmpty ? l10n.rdStatsEvents(c.total) : missing.join(', '),
  ].join(' · ');
}

/// One person of the Personen level.
class RdStatsPersonRow extends StatelessWidget {
  const RdStatsPersonRow({super.key, required this.person, required this.groupName, required this.onTap});

  final RdStatsPerson person;
  final Map<int, String> groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RdListRow(
      title: rdPersonName(person.person),
      subtitle: rdStatsPersonLine(context.l10n, person, groupName),
      trailing: RdStatsPercent(person.percent),
      onTap: onTap,
    );
  }
}

/// Every counted Termin of a person as a dot, oldest first. [max] keeps
/// only the newest ones (table column).
class RdStatsDots extends StatelessWidget {
  const RdStatsDots({super.key, required this.statuses, this.size = 10, this.max});

  final List<AttendanceStatus> statuses;
  final double size;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final shown = max != null && statuses.length > max! ? statuses.sublist(statuses.length - max!) : statuses;
    return Wrap(
      spacing: size * 0.35,
      runSpacing: size * 0.35,
      children: [
        for (final s in shown)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: rdStatsStatusColor(p, s), shape: BoxShape.circle),
          ),
      ],
    );
  }
}

/// Sheet of one person: quote, every Termin as a dot, the counts and the
/// Termine missed or late with the reason. One action: "Person öffnen".
Future<void> showRdStatsPersonSheet(BuildContext context, RdStatsResult result, RdStatsPerson person, List<Group> groups) {
  final router = GoRouter.of(context);
  return showRdSheet<void>(context, _PersonSheet(result: result, person: person, groups: groups, router: router));
}

class _PersonSheet extends StatelessWidget {
  const _PersonSheet({required this.result, required this.person, required this.groups, required this.router});

  final RdStatsResult result;
  final RdStatsPerson person;
  final List<Group> groups;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final id = person.person.id;
    final entries = id == null ? const <(RdStatsEvent, PersonAttendance)>[] : rdStatsPersonEntries(result, id);
    final group = [for (final g in groups) if (g.id == person.person.instrument) g.name].firstOrNull ?? '';
    final c = person.counts;
    final missed = [
      for (final (e, pa) in entries.reversed)
        if (pa.status == AttendanceStatus.absent || pa.status == AttendanceStatus.excused || pa.status == AttendanceStatus.neutral)
          (e, pa),
    ];
    final late = [
      for (final (e, pa) in entries.reversed)
        if (pa.status == AttendanceStatus.late || pa.status == AttendanceStatus.lateExcused) (e, pa),
    ];
    Widget row((RdStatsEvent, PersonAttendance) entry) {
      final (e, pa) = entry;
      final note = (pa.notes ?? '').trim();
      return RdListRow(
        title: '${rdStatsEventTitle(e)} · ${rdStatsDay(e.date)}',
        subtitle: note.isEmpty ? null : note,
        trailing: RdPill(_statusLabel(l10n, pa.status), tone: _tone(pa.status)),
      );
    }

    Widget figure(String label, int value, Color color) => Expanded(
          child: Semantics(
            label: '$label: $value',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: RdType.meta(p, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Semantics(header: true, child: Text(rdPersonName(person.person), style: RdType.cardTitle(p))),
        const SizedBox(height: 2),
        Text(
          l10n.rdStatsPersonSub(group, rdPercent(person.percent), c.attended, c.total).replaceFirst(RegExp(r'^ · '), ''),
          style: RdType.meta(p, size: 14),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: l10n.rdStatsPersonDots(entries.length),
          child: RdStatsDots(statuses: [for (final (_, pa) in entries) pa.status], size: 12),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            figure(l10n.commonStatusPresent, c.present, p.present),
            figure(l10n.commonStatusLateShort, c.late, p.late),
            figure(l10n.commonStatusExcused, c.excused, p.excused),
            figure(l10n.commonStatusAbsent, c.absent, p.absent),
            if (c.open > 0) figure(l10n.commonStatusNeutral, c.open, p.text2),
          ],
        ),
        if (missed.isEmpty && late.isEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.rdStatsPersonAllThere, style: RdType.body(p)),
        ],
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.rdStatsPersonMissed(missed.length)),
          RdGroupedList(children: [for (final m in missed) row(m)]),
        ],
        if (late.isNotEmpty) ...[
          const SizedBox(height: 16),
          RdGroupLabel(l10n.rdStatsPersonLate(late.length)),
          RdGroupedList(children: [for (final m in late) row(m)]),
        ],
        if (id != null) ...[
          const SizedBox(height: 20),
          RdPrimaryButton(
            label: l10n.rdStatsPersonOpen,
            onPressed: () {
              Navigator.of(context).pop();
              router.push(RedesignRoutes.person(id));
            },
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tables (wide screens)
// -----------------------------------------------------------------------------

/// One column of an Auswertung table.
class _Col {
  const _Col(this.label, {this.width, this.flex = 0, this.end = false, this.onSort, this.sorted = false});

  final String label;
  final double? width;
  final int flex;
  final bool end;
  final VoidCallback? onSort;
  final bool sorted;
}

/// A card with a header row (tap sorts) and one row per entry.
class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows});

  final List<_Col> columns;
  final List<(List<Widget>, VoidCallback, String)> rows;

  Widget _cell(_Col c, Widget child) {
    final aligned = Align(alignment: c.end ? Alignment.centerRight : Alignment.centerLeft, child: child);
    if (c.flex > 0) return Expanded(flex: c.flex, child: aligned);
    return SizedBox(width: c.width, child: aligned);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final head = RdType.meta(p, size: 12).copyWith(fontWeight: FontWeight.w600);
    return RdCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                for (final c in columns)
                  _cell(
                    c,
                    c.onSort == null
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(c.label, style: head))
                        : Semantics(
                            button: true,
                            selected: c.sorted,
                            label: l10n.rdStatsSortBy(c.label),
                            excludeSemantics: true,
                            child: InkWell(
                              onTap: c.onSort,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c.label, style: head.copyWith(color: c.sorted ? p.link : null)),
                                    if (c.sorted) Icon(Icons.arrow_drop_down, size: 16, color: p.link),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          for (final (cells, onTap, label) in rows) ...[
            Divider(height: 1, thickness: 1, color: p.line),
            Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [for (var i = 0; i < columns.length; i++) _cell(columns[i], cells[i])]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _num(BuildContext context, int value) => Text(
      '$value',
      style: RdType.body(context.rd).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );

/// Personen as a table: name, Register, quote, counts and the dots of the
/// newest Termine. The headers sort (also in the filter sheet).
class RdStatsPeopleTable extends ConsumerWidget {
  const RdStatsPeopleTable({
    super.key,
    required this.result,
    required this.people,
    required this.groups,
    required this.sort,
    required this.onSort,
  });

  final RdStatsResult result;
  final List<RdStatsPerson> people;
  final List<Group> groups;
  final RdStatsPersonSort sort;
  final ValueChanged<RdStatsPersonSort> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final groupName = {for (final g in groups) if (g.id != null) g.id!: g.name};
    final statuses = <int, List<AttendanceStatus>>{};
    for (final e in result.events) {
      for (final pa in e.rows) {
        if (pa.personId != null) statuses.putIfAbsent(pa.personId!, () => []).add(pa.status);
      }
    }
    final columns = [
      _Col(l10n.rdStatsColName, flex: 3, onSort: () => onSort(RdStatsPersonSort.name), sorted: sort == RdStatsPersonSort.name),
      _Col(l10n.rdStatsColRegister, flex: 2),
      _Col(
        l10n.rdStatsColQuote,
        width: 72,
        end: true,
        onSort: () => onSort(sort == RdStatsPersonSort.fewest ? RdStatsPersonSort.most : RdStatsPersonSort.fewest),
        sorted: sort == RdStatsPersonSort.fewest || sort == RdStatsPersonSort.most,
      ),
      _Col(l10n.rdStatsColPresent, width: 56, end: true),
      _Col(l10n.rdStatsColLate, width: 64, end: true, onSort: () => onSort(RdStatsPersonSort.late), sorted: sort == RdStatsPersonSort.late),
      _Col(l10n.rdStatsColExcused, width: 64, end: true),
      _Col(l10n.rdStatsColAbsent, width: 56, end: true, onSort: () => onSort(RdStatsPersonSort.absent), sorted: sort == RdStatsPersonSort.absent),
      const _Col('', width: 16),
      _Col(l10n.rdStatsColEvents, flex: 3),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Room of the dots column: 3 of 8 flex parts of what the fixed
        // columns leave.
        final dotsWidth = ((constraints.maxWidth - 28 - 72 - 56 - 64 - 64 - 56 - 16) * 3 / 8).clamp(0.0, 600.0);
        final maxDots = (dotsWidth / 11.5).floor().clamp(1, 200);
        return _Table(
          columns: columns,
          rows: [
            for (final person in people)
              (
                [
                  Text(rdPersonName(person.person), style: RdType.body(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(groupName[person.person.instrument] ?? '', style: RdType.meta(p, size: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  RdStatsPercent(person.percent, width: 64),
                  _num(context, person.counts.present),
                  _num(context, person.counts.late),
                  _num(context, person.counts.excused),
                  _num(context, person.counts.absent),
                  const SizedBox.shrink(),
                  RdStatsDots(statuses: statuses[person.person.id] ?? const [], size: 8, max: maxDots),
                ],
                () => showRdStatsPersonSheet(context, result, person, groups),
                '${rdPersonName(person.person)}, ${rdStatsPersonLine(l10n, person, groupName)}, ${rdPercent(person.percent)}',
              ),
          ],
        );
      },
    );
  }
}

/// Termine as a table: date, Termin, quote, counts and the split bar. The
/// headers sort (also in the filter sheet).
class RdStatsEventsTable extends StatelessWidget {
  const RdStatsEventsTable({
    super.key,
    required this.events,
    required this.groups,
    required this.sort,
    required this.onSort,
  });

  final List<RdStatsEvent> events;
  final List<Group> groups;
  final RdStatsEventSort sort;
  final ValueChanged<RdStatsEventSort> onSort;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final byDate = sort == RdStatsEventSort.newest || sort == RdStatsEventSort.oldest;
    final columns = [
      _Col(
        l10n.rdStatsColDate,
        width: 104,
        onSort: () => onSort(sort == RdStatsEventSort.newest ? RdStatsEventSort.oldest : RdStatsEventSort.newest),
        sorted: byDate,
      ),
      _Col(l10n.rdStatsColEvent, flex: 3),
      _Col(
        l10n.rdStatsColQuote,
        width: 72,
        end: true,
        onSort: () => onSort(sort == RdStatsEventSort.weakest ? RdStatsEventSort.best : RdStatsEventSort.weakest),
        sorted: !byDate,
      ),
      _Col(l10n.rdStatsColPresent, width: 56, end: true),
      _Col(l10n.rdStatsColLate, width: 64, end: true),
      _Col(l10n.rdStatsColExcused, width: 64, end: true),
      _Col(l10n.rdStatsColAbsent, width: 56, end: true),
      const _Col('', width: 16),
      _Col(l10n.rdStatsSplit, flex: 2),
    ];
    final date = DateFormat(dateFmt(DateFmtKind.short));
    return _Table(
      columns: columns,
      rows: [
        for (final e in events)
          (
            [
              Text('${rdStatsDay(e.date).split(' ').first} ${date.format(e.date)}',
                  style: RdType.meta(p, size: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(rdStatsEventTitle(e), style: RdType.body(p), maxLines: 1, overflow: TextOverflow.ellipsis),
              RdStatsPercent(e.percent, width: 64),
              _num(context, e.counts.present),
              _num(context, e.counts.late),
              _num(context, e.counts.excused),
              _num(context, e.counts.absent),
              const SizedBox.shrink(),
              e.counts.total > 0 ? RdStatsSplitBar(counts: e.counts) : const SizedBox.shrink(),
            ],
            () => showRdStatsEventSheet(context, e, groups),
            '${rdStatsDay(e.date)}, ${rdStatsEventTitle(e)}, ${rdPercent(e.percent)}',
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Mitglieder and Alter (Ionic stats)
// -----------------------------------------------------------------------------

/// "Mitglieder": active, paused, left and total (Ionic stats, all
/// Register).
class RdStatsMembersCard extends ConsumerWidget {
  const RdStatsMembersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.rd;
    final current = [
      for (final person in ref.watch(playersProvider).valueOrNull ?? const <Person>[])
        if (person.left == null || person.left!.isEmpty) person,
    ];
    final left = ref.watch(archivedPlayersProvider).valueOrNull ?? const <Person>[];
    final active = current.where((x) => !x.paused).length;
    final paused = current.length - active;
    Widget value(int v, Color color) => Text(
          '$v',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.rdStatsMembers),
        RdGroupedList(
          children: [
            RdListRow(title: l10n.rdStatsMembersActive, trailing: value(active, p.present)),
            RdListRow(title: l10n.rdStatsMembersPaused, trailing: value(paused, p.late)),
            RdListRow(title: l10n.rdStatsMembersLeft, trailing: value(left.length, p.text2)),
            RdListRow(title: l10n.rdStatsMembersTotal, trailing: value(current.length + left.length, p.text)),
          ],
        ),
      ],
    );
  }
}

/// "Alter": active members per decade of age and Ø age per Register
/// (Ionic stats; decades instead of Ionic's three-year steps keep the
/// list short).
class RdStatsAgeCard extends ConsumerWidget {
  const RdStatsAgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final players = ref.watch(activePlayersForStatsProvider).valueOrNull ?? const <Person>[];
    final groups = rdStatsGroups(ref.watch(groupsProvider).valueOrNull ?? const <Group>[]);
    final decades = rdStatsAgeDecades(players, DateTime.now());
    final perGroup = computeAverageAgePerGroup(players, groups);
    if (decades.isEmpty) {
      return RdCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.rdStatsAge, style: RdType.section(p)),
            const SizedBox(height: 6),
            Text(l10n.rdStatsAgeNone, style: RdType.meta(p, size: 14)),
          ],
        ),
      );
    }
    final most = decades.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
    final oldest = perGroup.fold<int>(1, (m, g) => g.avgAge > m ? g.avgAge : m);
    return RdCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rdStatsAge, style: RdType.section(p)),
          Text(l10n.rdStatsAgeHint, style: RdType.meta(p, size: 13)),
          const SizedBox(height: 10),
          for (final (from, count) in decades)
            RdStatsGroupRow(
              name: l10n.rdStatsAgeBucket(from, from + 9),
              percent: (count * 100 / most).round(),
              valueText: '$count',
            ),
          if (perGroup.length > 1) ...[
            const SizedBox(height: 14),
            Text(l10n.rdStatsAgeAvgGroup, style: RdType.section(p)),
            const SizedBox(height: 10),
            for (final g in perGroup)
              RdStatsGroupRow(
                name: g.name,
                meta: l10n.commonPersons(g.count),
                percent: (g.avgAge * 100 / oldest).round(),
                valueText: l10n.rdStatsAgeYears(g.avgAge),
              ),
          ],
        ],
      ),
    );
  }
}
