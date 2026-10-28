import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_detail_providers.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_test_helpers.dart';

/// GROUP_ORDER: the Termin page of the choir tenant showed the groups as
/// "Alt, Tenor, Bass, Sopran, Dirigenten" (Flutter) instead of Ionic's
/// "Dirigenten, Alt, Bass, Sopran, Tenor".
///
/// Root cause: the persons are loaded with
/// `player.select('*, instrument:instrument(id, name)')`, so `instrument`
/// is the embedded `{id, name}` object; `Person.fromJson` turned it into
/// `instrument == null` for everybody. `sortPersonsByGroup` then saw one
/// single "group" (no main group, no group sort_order) and the list kept the
/// query order (by last name) – the headers appeared in the order of each
/// group's first last name.
void main() {
  // Realistic `player` rows as the attendance page query returns them
  // (ordered by lastName, `instrument` embedded as {id, name}).
  const groups = [
    Group(id: 10, name: 'Dirigenten', maingroup: true),
    Group(id: 11, name: 'Alt'),
    Group(id: 12, name: 'Bass'),
    Group(id: 13, name: 'Sopran'),
    Group(id: 14, name: 'Tenor'),
  ];
  final rows = <Map<String, dynamic>>[
    {'id': 1, 'firstName': 'Anna', 'lastName': 'Albers', 'tenantId': 7, 'instrument': {'id': 11, 'name': 'Alt'}},
    {'id': 2, 'firstName': 'Tom', 'lastName': 'Becker', 'tenantId': 7, 'instrument': {'id': 14, 'name': 'Tenor'}},
    {'id': 3, 'firstName': 'Ben', 'lastName': 'Fischer', 'tenantId': 7, 'instrument': {'id': 12, 'name': 'Bass'}},
    {'id': 4, 'firstName': 'Sara', 'lastName': 'Hoffmann', 'tenantId': 7, 'sort_order': 1, 'instrument': {'id': 13, 'name': 'Sopran'}},
    {'id': 5, 'firstName': 'Dora', 'lastName': 'Müller', 'tenantId': 7, 'instrument': {'id': 10, 'name': 'Dirigenten'}},
    {'id': 6, 'firstName': 'Sina', 'lastName': 'Schulz', 'tenantId': 7, 'instrument': {'id': 13, 'name': 'Sopran'}},
    {'id': 7, 'firstName': 'Alex', 'lastName': 'Adler', 'tenantId': 7, 'instrument': {'id': 13, 'name': 'Sopran'}},
  ];

  List<Person> loadAndSort(List<Group> groups) => sortPersonsByGroup(
        rows.map(personFromPlayerRowWithGroup).toList(),
        groups: groups,
        mainGroupId: mainGroupIdOf(groups),
        usePersonSortOrder: false,
      );

  group('personFromPlayerRowWithGroup', () {
    test('keeps the group id and name of the embedded instrument', () {
      final p = personFromPlayerRowWithGroup(rows.first);
      expect(p.instrument, 11);
      expect(p.groupName, 'Alt');
    });

    test('plain rows (instrument id) and persons without group', () {
      expect(personFromPlayerRowWithGroup({'id': 1, 'firstName': 'A', 'lastName': 'B', 'instrument': 3}).instrument, 3);
      final none = personFromPlayerRowWithGroup({'id': 1, 'firstName': 'A', 'lastName': 'B', 'instrument': null});
      expect(none.instrument, isNull);
      expect(none.groupName, isNull);
    });
  });

  group('Ionic group order on the Termin page', () {
    test('main group first, then groups by name (no sort_order)', () {
      final sorted = loadAndSort(groups);
      expect(sorted.map((p) => p.groupName).toSet().toList(), ['Dirigenten', 'Alt', 'Bass', 'Sopran', 'Tenor']);
      // Ionic attendanceSelect does not load player.sort_order: last name only.
      expect(sorted.where((p) => p.instrument == 13).map((p) => p.lastName), ['Adler', 'Hoffmann', 'Schulz']);
    });

    test('groups with sort_order first, by sort_order', () {
      final withOrder = [
        groups[0],
        groups[1].copyWith(sortOrder: 2),
        groups[2].copyWith(sortOrder: 4),
        groups[3].copyWith(sortOrder: 1),
        groups[4],
      ];
      final sorted = loadAndSort(withOrder);
      expect(sorted.map((p) => p.groupName).toSet().toList(), ['Dirigenten', 'Sopran', 'Alt', 'Bass', 'Tenor']);
    });
  });

  for (final size in const [Size(1440, 900), Size(390, 844)]) {
    testWidgets('rendered group headers follow Ionic order (${size.width.toInt()} px)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final persons = loadAndSort(groups);
      await tester.pumpApp(Scaffold(
        body: CustomScrollView(slivers: [
          AttendanceGrid(
            persons: persons,
            localStatuses: {for (final p in persons) p.id!: AttendanceStatus.present},
            personNotes: const {},
            availableStatuses: AttendanceStatus.values,
            onStatusChanged: (_, __) {},
            onNoteChanged: (_, __) {},
            onShowModifierInfo: (_) {},
            onRemoveFromAttendance: (_) {},
          ),
        ]),
      ));
      await tester.pump();

      final header = RegExp(r'^(\S+) \(\d+/\d+\)$');
      final headers = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .map((s) => header.firstMatch(s)?.group(1))
          .whereType<String>()
          .toList();
      expect(headers, ['Dirigenten', 'Alt', 'Bass', 'Sopran', 'Tenor']);
    });
  }
}
