import 'package:attendix/core/utils/field_stats.dart';
import 'package:attendix/data/models/church/church.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ionic 4.17.17 stats.page.spec "additional field statistics".
void main() {
  const labels =
      FieldStatsLabels(yes: 'Ja', no: 'Nein', noValue: 'Keine Angabe');
  const shirt = ExtraField(
    id: 'shirt',
    name: 'T-Shirt',
    type: 'select',
    defaultValue: 'M',
    options: ['S', 'M', 'L'],
  );
  const groups = [Group(id: 1, name: 'Sopran'), Group(id: 2, name: 'Alt')];

  Person person(int id, int instrument, Object? value,
          {bool paused = false, String? left, String field = 'shirt'}) =>
      Person(
        id: id,
        firstName: 'P',
        lastName: '$id',
        instrument: instrument,
        paused: paused,
        left: left,
        additionalFields: value == null ? {} : {field: value},
      );

  final players = [
    person(1, 1, 'S'),
    person(2, 1, 'M'),
    person(3, 2, null),
    person(4, 2, 'XL'),
    person(5, 2, 'L', paused: true),
    person(6, 1, 'L', left: '2025-01-01'),
  ];

  List<List<Object>> rowsOf(FieldStats s) =>
      [for (final r in s.rows) [r.label, r.count, r.perc]];

  test('counts active people per option, uses the default for missing '
      'values and keeps unknown values', () {
    final s = computeFieldStats(
        field: shirt, persons: players, groups: groups, labels: labels);
    expect(s.total, 4);
    expect(rowsOf(s), [
      ['S', 1, 25],
      ['M', 2, 50],
      ['L', 0, 0],
      ['XL', 1, 25],
    ]);
    expect(s.groupBars.map((b) => b.name), ['Sopran (2)', 'Alt (2)']);
    expect(s.groupBars.first.percByLabel, {'S': 50, 'M': 50, 'XL': 0});
    expect(s.shownRows.map((r) => r.label), ['S', 'M', 'XL']);
    // Colors follow the option order.
    expect(s.rows[1].color, fieldStatsColors[1]);
  });

  test('can include paused people and filter by group', () {
    final s = computeFieldStats(
      field: shirt,
      persons: players,
      groups: groups,
      labels: labels,
      includePaused: true,
      groupId: 2,
    );
    expect(s.total, 3);
    expect(s.rows.firstWhere((r) => r.label == 'L').count, 1);
    expect(s.groupBars, isEmpty);
    expect(s.groupId, 2);
  });

  test('resets a group filter without counted people to all groups', () {
    final s = computeFieldStats(
      field: shirt,
      persons: [person(1, 1, 'S')],
      groups: groups,
      labels: labels,
      groupId: 2,
    );
    expect(s.groupId, 0);
    expect(s.groups.map((g) => g.id), [1]);
  });

  test('boolean fields: Ja / Nein, missing values default to Ja', () {
    const field = ExtraField(id: 'b', name: 'Auto', type: 'boolean');
    final s = computeFieldStats(
      field: field,
      persons: [
        person(1, 1, true, field: 'b'),
        person(2, 1, 'false', field: 'b'),
        person(3, 1, null, field: 'b'),
      ],
      groups: groups,
      labels: labels,
    );
    expect(rowsOf(s), [
      ['Ja', 2, 67],
      ['Nein', 1, 33],
    ]);
  });

  test('church fields show the church name, empty values as "Keine Angabe"',
      () {
    const field = ExtraField(
        id: 'c', name: 'Gemeinde', type: 'bfecg_church', defaultValue: '');
    final s = computeFieldStats(
      field: field,
      persons: [
        person(1, 1, 'c1', field: 'c'),
        person(2, 1, 'unknown', field: 'c'),
        person(3, 1, null, field: 'c'),
      ],
      groups: groups,
      labels: labels,
      churches: const [Church(id: 'c1', name: 'Speyer')],
    );
    expect(s.rows.map((r) => r.label), ['Speyer', 'unknown', 'Keine Angabe']);
  });

  test('distributionFields keeps only select, boolean and church fields', () {
    const fields = [
      ExtraField(id: 'a', name: 'A', type: 'text'),
      ExtraField(id: 'b', name: 'B', type: 'select'),
      ExtraField(id: 'c', name: 'C', type: 'boolean'),
      ExtraField(id: 'd', name: 'D', type: 'bfecg_church'),
      ExtraField(id: 'e', name: 'E', type: 'number'),
    ];
    expect(distributionFields(fields).map((f) => f.id), ['b', 'c', 'd']);
  });

  test('no field: empty stats', () {
    final s = computeFieldStats(
        field: null, persons: players, groups: groups, labels: labels);
    expect(s.total, 0);
    expect(s.rows, isEmpty);
  });
}
