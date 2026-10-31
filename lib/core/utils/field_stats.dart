import 'dart:ui' show Color;

import '../../data/models/church/church.dart';
import '../../data/models/instrument/instrument.dart';
import '../../data/models/person/person.dart';
import '../../data/models/tenant/tenant.dart';
import 'extra_field_utils.dart';

/// Statistics for additional fields ("🧩 Zusatzfelder", Ionic 4.17.17
/// stats.page.ts `initFieldStats` / `updateFieldStats`).

/// Field types whose values are a fixed set of options and can be shown as a
/// distribution (Ionic `DISTRIBUTION_FIELD_TYPES`).
const distributionFieldTypes = <String>{
  ExtraFieldType.select,
  ExtraFieldType.boolean,
  ExtraFieldType.bfecgChurch,
};

/// Ionic `FIELD_STATS_COLORS`.
const fieldStatsColors = <Color>[
  Color(0xFF3880FF), Color(0xFF2DD36F), Color(0xFFFFC409), Color(0xFFEB445A),
  Color(0xFF5260FF), Color(0xFF3DC2FF), Color(0xFFFF9F0A), Color(0xFFA855F7),
  Color(0xFF14B8A6), Color(0xFFF472B6), Color(0xFF84CC16), Color(0xFF92949C),
];

/// Fields that can be analysed (organisation + tenant fields, in
/// `getPersonExtraFields` order).
List<ExtraField> distributionFields(List<ExtraField> fields) =>
    fields.where((f) => distributionFieldTypes.contains(f.type)).toList();

/// Translated labels used by [computeFieldStats].
class FieldStatsLabels {
  const FieldStatsLabels({
    required this.yes,
    required this.no,
    required this.noValue,
  });

  final String yes;
  final String no;
  final String noValue;
}

/// One option of the selected field (Ionic `FieldStatsRow`).
class FieldStatsRow {
  const FieldStatsRow({
    required this.label,
    required this.count,
    required this.perc,
    required this.color,
  });

  final String label;
  final int count;
  final int perc;
  final Color color;
}

/// One bar of the 100 % per-group chart.
class FieldStatsGroupBar {
  const FieldStatsGroupBar({
    required this.name,
    required this.count,
    required this.percByLabel,
  });

  /// `"<group> (<count>)"`.
  final String name;
  final int count;

  /// Rounded percentage per option label (only the [FieldStats.shownRows]).
  final Map<String, int> percByLabel;
}

class FieldStats {
  const FieldStats({
    required this.groupId,
    required this.groups,
    required this.rows,
    required this.total,
    required this.groupBars,
  });

  static const empty = FieldStats(
    groupId: 0,
    groups: [],
    rows: [],
    total: 0,
    groupBars: [],
  );

  /// Effective group filter (0 = all groups). Reset to 0 when the selected
  /// group has no counted person any more.
  final int groupId;

  /// Groups offered in the filter: those with at least one counted person.
  final List<Group> groups;

  /// All options (defined ones first, then other values, "no value" last).
  final List<FieldStatsRow> rows;
  final int total;

  /// Per-group distribution; empty when a single group is selected.
  final List<FieldStatsGroupBar> groupBars;

  /// Rows shown in the donut chart / as bar segments.
  List<FieldStatsRow> get shownRows => rows.where((r) => r.count > 0).toList();
}

bool _counted(Person p, bool includePaused, int groupId) =>
    (p.left == null || p.left!.isEmpty) &&
    (includePaused || !p.paused) &&
    (groupId == 0 || p.instrument == groupId);

/// Display label of a person's value; missing values fall back to the
/// field's default like in the people list.
String fieldValueLabel(
  ExtraField field,
  Person person,
  FieldStatsLabels labels, {
  List<Church> churches = const [],
}) {
  dynamic value = person.additionalFields?[field.id];
  value ??= extraFieldDefaultValue(
    field,
    churchIds: [for (final c in churches) if (c.id != null) c.id!],
  );
  switch (field.type) {
    case ExtraFieldType.boolean:
      return value == true || value == 'true' ? labels.yes : labels.no;
    case ExtraFieldType.bfecgChurch:
      if (value == null || value == '') return labels.noValue;
      for (final c in churches) {
        if (c.id == value) return c.name.isEmpty ? value.toString() : c.name;
      }
      return value.toString();
    default:
      return value == null || value == '' ? labels.noValue : value.toString();
  }
}

/// Labels in a stable order: defined options first, then other values
/// found (sorted), "no value" last.
List<String> fieldValueOrder(
  ExtraField field,
  List<String> found,
  FieldStatsLabels labels,
) {
  final base = switch (field.type) {
    ExtraFieldType.boolean => [labels.yes, labels.no],
    ExtraFieldType.select => [...?field.options],
    _ => <String>[],
  };
  final extra = found
      .toSet()
      .where((l) => !base.contains(l) && l != labels.noValue)
      .toList()
    ..sort((a, b) => a.compareTo(b));
  return [
    ...base,
    ...extra,
    if (found.contains(labels.noValue)) labels.noValue,
  ];
}

int _perc(int count, int total) =>
    total == 0 ? 0 : (count / total * 100).round();

/// Ionic `updateFieldStats`.
FieldStats computeFieldStats({
  required ExtraField? field,
  required List<Person> persons,
  required List<Group> groups,
  required FieldStatsLabels labels,
  int groupId = 0,
  bool includePaused = false,
  List<Church> churches = const [],
}) {
  if (field == null) return FieldStats.empty;

  final groupIds = {
    for (final p in persons)
      if (_counted(p, includePaused, 0)) p.instrument,
  };
  final filterGroups =
      groups.where((g) => g.id != null && groupIds.contains(g.id)).toList();
  final effectiveGroupId =
      groupId != 0 && filterGroups.any((g) => g.id == groupId) ? groupId : 0;

  List<String> labelsOf(int gid) => [
        for (final p in persons)
          if (_counted(p, includePaused, gid))
            fieldValueLabel(field, p, labels, churches: churches),
      ];

  final found = labelsOf(effectiveGroupId);
  final order = fieldValueOrder(field, found, labels);
  final total = found.length;
  final rows = [
    for (var i = 0; i < order.length; i++)
      () {
        final count = found.where((l) => l == order[i]).length;
        return FieldStatsRow(
          label: order[i],
          count: count,
          perc: _perc(count, total),
          color: fieldStatsColors[i % fieldStatsColors.length],
        );
      }(),
  ];
  final shown = rows.where((r) => r.count > 0).toList();

  final groupBars = effectiveGroupId != 0
      ? const <FieldStatsGroupBar>[]
      : [
          for (final g in filterGroups)
            () {
              final gl = labelsOf(g.id!);
              return FieldStatsGroupBar(
                name: '${g.name} (${gl.length})',
                count: gl.length,
                percByLabel: {
                  for (final r in shown)
                    r.label: _perc(gl.where((l) => l == r.label).length, gl.length),
                },
              );
            }(),
        ];

  return FieldStats(
    groupId: effectiveGroupId,
    groups: filterGroups,
    rows: rows,
    total: total,
    groupBars: groupBars,
  );
}
