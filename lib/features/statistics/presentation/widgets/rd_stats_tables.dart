part of 'rd_stats_levels.dart';

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
                            // The action sits here: the excluded InkWell's is gone.
                            onTap: c.onSort,
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
              onTap: onTap,
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
      _Col(l10n.rdWordsGroup(ref.watch(rdGroupKindProvider)), flex: 2),
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
