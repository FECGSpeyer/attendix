import 'package:attendix/core/utils/statistics_utils.dart';
import 'package:attendix/core/utils/extra_field_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/export/export_fields.dart';
import 'package:attendix/features/people/people_list_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const shoeSize = ExtraField(id: 'shoe', name: 'Schuhgröße', type: 'number');
  const club = ExtraField(id: 'club', name: 'Verein', type: 'text');
  const member = ExtraField(id: 'member', name: 'Mitglied', type: 'boolean');

  group('searchPeople', () {
    final people = [
      const Person(
        id: 1,
        firstName: 'Anna',
        lastName: 'Berg',
        groupName: 'Violine',
        additionalFields: {'club': 'TSV Nord', 'shoe': 38},
      ),
      const Person(id: 2, firstName: 'Ben', lastName: 'Clausen'),
    ];

    test('matches name, group and text/number extra fields', () {
      expect(searchPeople(people, 'berg').map((p) => p.id), [1]);
      expect(searchPeople(people, 'violine').map((p) => p.id), [1]);
      expect(
        searchPeople(people, 'tsv', extraFields: [club]).map((p) => p.id),
        [1],
      );
      expect(
        searchPeople(people, '38', extraFields: [shoeSize]).map((p) => p.id),
        [1],
      );
      expect(searchPeople(people, 'tsv'), isEmpty,
          reason: 'extra fields are only searched when passed');
      expect(searchPeople(people, '  ').length, 2);
    });
  });

  group('birthdays', () {
    test('todaysBirthdays requires a confirmed birthday', () {
      final now = DateTime(2026, 10, 28);
      final people = [
        const Person(
            id: 1,
            firstName: 'A',
            lastName: 'A',
            birthday: '2000-10-28',
            correctBirthday: true),
        const Person(
            id: 2, firstName: 'B', lastName: 'B', birthday: '2000-10-28'),
        const Person(
            id: 3,
            firstName: 'C',
            lastName: 'C',
            birthday: '2000-10-29',
            correctBirthday: true),
      ];
      expect(todaysBirthdays(people, now: now).map((p) => p.id), [1]);
      expect(ageInYears('2000-10-28', now: now), 26);
      expect(ageInYears('2000-10-29', now: now), 25);
    });
  });

  test('sortPeopleByGroup: main group first, then instrument sort_order', () {
    final groups = [
      const Group(id: 1, name: 'Dirigent', maingroup: true),
      const Group(id: 2, name: 'Bratsche', sortOrder: 2),
      const Group(id: 3, name: 'Violine', sortOrder: 1),
    ];
    final people = [
      const Person(id: 10, firstName: 'a', lastName: 'Z', instrument: 2),
      const Person(id: 11, firstName: 'b', lastName: 'Y', instrument: 3),
      const Person(id: 12, firstName: 'c', lastName: 'X', instrument: 1),
      const Person(
          id: 13, firstName: 'd', lastName: 'W', instrument: 3, sortOrder: 1),
    ];
    expect(
      sortPeopleByGroup(people, groups).map((p) => p.id),
      [12, 13, 11, 10],
    );
  });

  group('export fields', () {
    test('extra fields are selectable and sortable', () {
      expect(availableExportFields('player', [club]), contains('Verein'));
      expect(
        exportSortOptions('player', [club]).map((o) => o.value),
        contains('extra_club'),
      );
    });

    test('extra field values are formatted', () {
      const p = Person(
        firstName: 'A',
        lastName: 'B',
        additionalFields: {'member': true, 'club': 'TSV'},
      );
      expect(exportFieldValue(p, 'Mitglied', extraFields: [member]), 'Ja');
      expect(exportFieldValue(p, 'Verein', extraFields: [club]), 'TSV');
      expect(exportFieldValue(p, 'Unbekannt'), '');
      expect(exportFieldValue(p, 'Anwesenheit %', percentage: 80), '80%');
      expect(
        formatExtraFieldValue({'member': false}, member),
        'Nein',
      );
    });
  });

  group('calculateAveragePercentage (include_in_average)', () {
    test('only averages attendance types included in the average', () {
      final types = [
        const AttendanceType(id: 'probe', name: 'Probe'),
        const AttendanceType(
            id: 'fest', name: 'Fest', includeInAverage: false),
      ];
      final attendances = [
        const Attendance(date: '2026-01-01', typeId: 'probe', percentage: 80),
        const Attendance(date: '2026-01-08', typeId: 'probe', percentage: 60),
        const Attendance(date: '2026-01-15', typeId: 'fest', percentage: 0),
        const Attendance(date: '2026-01-22', percentage: 0),
      ];
      expect(calculateAveragePercentage(attendances, types), 70);
      expect(calculateAveragePercentage(const [], types), 0);
    });
  });
}
