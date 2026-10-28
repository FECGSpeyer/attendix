import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/church/church.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/data/repositories/profile_repository.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/ad_hoc_reminder_sheet.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_view_options.dart';
import 'package:attendix/shared/widgets/sheets/church_overview_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

Person _p(int id, String first, String last,
        {int? instrument, Map<String, dynamic>? fields, bool paused = false, String? left}) =>
    Person(
      id: id,
      firstName: first,
      lastName: last,
      instrument: instrument,
      additionalFields: fields,
      paused: paused,
      left: left,
    );

void main() {
  group('status filter', () {
    final persons = [_p(1, 'A', 'A'), _p(2, 'B', 'B'), _p(3, 'C', 'C')];
    final statuses = {1: AttendanceStatus.present, 2: AttendanceStatus.absent};

    test('empty filter returns all persons', () {
      expect(filterPersonsByStatus(persons, statuses, {}), persons);
    });

    test('filters by status, missing status counts as neutral', () {
      final result = filterPersonsByStatus(
          persons, statuses, {AttendanceStatus.present, AttendanceStatus.neutral});
      expect(result.map((p) => p.id), [1, 3]);
    });
  });

  group('extra field sort', () {
    final fields = sortableFields(
      const [
        ProfileExtraField(id: 'age', name: 'Alter', type: 'number'),
        ProfileExtraField(id: 'note', name: 'Notiz', type: 'textarea'),
        ProfileExtraField(id: 'bfecg_church', name: 'Gemeinde', type: 'bfecg_church'),
      ],
      const [RegistrationField(id: 'r1', label: 'Essen', type: 'text')],
    );

    test('textarea fields are not sortable, registration fields are', () {
      expect(fields.map((f) => f.id), ['age', 'bfecg_church', 'r1']);
      expect(fields.last.level, SortFieldLevel.registration);
    });

    test('sorts numerically ascending and descending', () {
      final persons = [
        _p(1, 'A', 'A', fields: {'age': '10'}),
        _p(2, 'B', 'B', fields: {'age': '9'}),
        _p(3, 'C', 'C', fields: {'age': '100'}),
      ];
      const asc = AttendanceSort(fieldId: 'age', level: SortFieldLevel.person);
      expect(sortPersonsByField(persons, asc, fields.first, const {}, const []).map((p) => p.id),
          [2, 1, 3]);
      const desc = AttendanceSort(fieldId: 'age', level: SortFieldLevel.person, ascending: false);
      expect(sortPersonsByField(persons, desc, fields.first, const {}, const []).map((p) => p.id),
          [3, 1, 2]);
    });

    test('display value resolves church names, booleans and missing values', () {
      final church = fields[1];
      const sort = AttendanceSort(fieldId: 'bfecg_church', level: SortFieldLevel.person);
      final churches = [const Church(id: 'c1', name: 'Speyer')];
      expect(
          sortDisplayValueOf(_p(1, 'A', 'A', fields: {'bfecg_church': 'c1'}), sort, church, const {},
              churches),
          'Speyer');
      expect(sortDisplayValueOf(_p(2, 'B', 'B'), sort, church, const {}, churches), '–');
      const regSort = AttendanceSort(fieldId: 'r1', level: SortFieldLevel.registration);
      expect(
          sortDisplayValueOf(_p(3, 'C', 'C'), regSort, fields.last, {
            3: {'r1': true}
          }, const []),
          'Ja');
    });
  });

  group('church overview', () {
    test('counts per church, sorted by count, with persons without church', () {
      final data = computeChurchOverview(
        ['a', 'b', 'b', null, '', 'x'],
        const [Church(id: 'a', name: 'Alpha'), Church(id: 'b', name: 'Beta')],
      );
      expect(data.total, 6);
      expect(data.withoutChurch, 2);
      expect(data.churchCounts.map((c) => '${c.name}:${c.count}'),
          ['Beta:2', 'Alpha:1', 'Unbekannte Gemeinde:1']);
    });

    test('churchIdOf reads the extra field', () {
      expect(churchIdOf({'bfecg_church': 'a'}, 'bfecg_church'), 'a');
      expect(churchIdOf({'bfecg_church': ''}, 'bfecg_church'), isNull);
      expect(churchIdOf(null, 'bfecg_church'), isNull);
    });
  });

  group('add person candidates', () {
    test('splits matching and other persons, skips paused/left/in-Termin', () {
      final persons = [
        _p(1, 'Anna', 'Zeh', instrument: 1),
        _p(2, 'Bert', 'Alt', instrument: 2),
        _p(3, 'Carl', 'Bau', instrument: 1, paused: true),
        _p(4, 'Dora', 'Cox', instrument: 1),
        _p(5, 'Emil', 'Dorn', instrument: 1, left: '2024-01-01'),
        _p(6, 'Fritz', 'Abel', instrument: 1),
      ];
      final result = computeAddPersonCandidates(
        allPersons: persons,
        currentPersonIds: {4},
        type: const AttendanceType(id: 't', name: 'Probe', relevantGroups: [1]),
        groups: const [Group(id: 1, name: 'Sopran', sortOrder: 1), Group(id: 2, name: 'Alt', sortOrder: 2)],
      );
      expect(result.matching.map((p) => p.id), [6, 1]);
      expect(result.others.map((p) => p.id), [2]);
    });
  });

  group('ad-hoc reminder defaults', () {
    test('builds Ionic subject and message', () {
      final d = adHocReminderDefaults(
        typeName: 'Probe',
        date: '2026-09-01',
        startTime: '19:00:00',
        typeInfo: 'Generalprobe',
        tenantLongName: 'Jugendorchester',
      );
      expect(d.title, '🔔 Erinnerung: Probe am 01.09.2026 um 19:00 Uhr (Generalprobe)');
      expect(d.message, 'Jugendorchester\nProbe am 01.09.2026 um 19:00 Uhr (Generalprobe)');
    });

    test('link points to open-attendance', () {
      expect(adHocReminderLink(5, 7), 'https://attendix.de/open-attendance?id=5&tenantId=7');
    });
  });

  group('list helpers', () {
    test('status counts follow Ionic getStatusCounts', () {
      final c = AttendanceStatusCounts.fromStatuses([
        AttendanceStatus.present,
        AttendanceStatus.late,
        AttendanceStatus.excused,
        AttendanceStatus.lateExcused,
        AttendanceStatus.absent,
        AttendanceStatus.neutral,
      ]);
      expect([c.present, c.excused, c.absent], [2, 2, 1]);
    });

    test('attachment path sanitises the file name', () {
      expect(AttendanceRepository.attachmentPath(3, 'Noten (neu).pdf'),
          '3/attachment/Noten__neu_.pdf');
    });
  });
}
