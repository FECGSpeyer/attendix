import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/church/church.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/add_persons_sheet.dart';
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
