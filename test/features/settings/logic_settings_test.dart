import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/statistics_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/attendance_type_repository.dart';
import 'package:attendix/features/settings/presentation/pages/attendance_type_edit_page.dart';
import 'package:attendix/features/settings/presentation/pages/attendance_types_page.dart';
import 'package:attendix/features/settings/presentation/pages/general_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

/// LOGIC_SETTINGS (wave 7): Ionic parity for settings and statistics.
void main() {
  group('attendance type create payload (CRITICAL)', () {
    test('statuses are written as numbers, not enum names', () {
      final data = AttendanceTypeRepository.buildInsertData(
        buildNewAttendanceType('Probe'),
        42,
      );
      expect(data['tenant_id'], 42);
      expect(data['default_status'], AttendanceStatus.present.value);
      expect(data['default_status'], isA<int>());
      expect(data['available_statuses'], [
        AttendanceStatus.neutral.value,
        AttendanceStatus.present.value,
        AttendanceStatus.absent.value,
        AttendanceStatus.excused.value,
        AttendanceStatus.late.value,
      ]);
      expect(
        (data['available_statuses'] as List).every((s) => s is int),
        isTrue,
      );
    });

    test('Ionic defaults: index 999, relevant_groups [], default_plan set', () {
      final data = AttendanceTypeRepository.buildInsertData(
        const AttendanceType(name: 'X'),
        1,
      );
      expect(data['index'], 999);
      expect(data['relevant_groups'], isEmpty);
      expect(data['relevant_groups'], isNotNull);
      expect(data['default_plan'], {'time': '', 'end': '', 'fields': []});
      expect(data['reminders'], isEmpty);
    });

    test('new type uses Ionic TypePage defaults', () {
      final t = buildNewAttendanceType('  Probe ');
      expect(t.name, 'Probe');
      expect(t.index, 999);
      expect(t.startTime, '19:00');
      expect(t.endTime, '20:30');
      expect(t.availableStatuses, hasLength(5));
    });
  });

  group('attendance type update payload', () {
    test('default_plan is never null and keeps time/end', () {
      expect(buildDefaultPlanUpdate(null, const []),
          {'time': '', 'end': '', 'fields': []});
      final plan = buildDefaultPlanUpdate(
        {'time': '18:00', 'end': '20:00', 'fields': []},
        [
          {'id': 'a', 'name': 'A', 'time': '20'},
        ],
      );
      expect(plan['time'], '18:00');
      expect(plan['end'], '20:00');
      expect(plan['fields'], hasLength(1));
    });

    test('edit page writes relevant_groups without null fallback', () {
      final src = File(
        'lib/features/settings/presentation/pages/attendance_type_edit_page.dart',
      ).readAsStringSync();
      expect(src, isNot(contains("_relevantGroups.isNotEmpty ? _relevantGroups : null")));
      expect(src, contains("'relevant_groups': _relevantGroups,"));
      // save must check the update result (Ionic shows updateFailed)
      expect(src, contains('if (updated == null)'));
    });
  });

  group('general settings normalisation', () {
    test('reasons: blanks filtered, empty -> null', () {
      expect(normalizeReasons(['', '  ']), isNull);
      expect(normalizeReasons(['Krank', ' ', 'Urlaub']), ['Krank', 'Urlaub']);
    });

    test('show-all info text: null when off, default when blank', () {
      expect(
        normalizeShowAllInfoText(enabled: false, text: 'x', defaultText: 'd'),
        isNull,
      );
      expect(
        normalizeShowAllInfoText(enabled: true, text: '  ', defaultText: 'd'),
        'd',
      );
      expect(
        normalizeShowAllInfoText(enabled: true, text: ' Hi ', defaultText: 'd'),
        'Hi',
      );
    });
  });

  group('group deletion', () {
    test('deleteGroup counts archived people too', () {
      final src =
          File('lib/data/repositories/group_repository.dart').readAsStringSync();
      expect(src, contains('getPlayerCountInGroup(id, includeArchived: true)'));
    });
  });

  group('statistics (Ionic stats.page.ts)', () {
    final types = [
      const AttendanceType(id: 't1', name: 'Probe'),
      const AttendanceType(id: 'duty', name: 'Dienst', dutyMode: true),
    ];

    test('percentage is recomputed from person attendances', () {
      final atts = [
        TestFactories.createAttendance(
            id: 1, date: '2026-01-01', typeId: 't1', percentage: 0),
        TestFactories.createAttendance(
            id: 2, date: '2026-01-02', typeId: 'duty', percentage: 0),
      ];
      final pas = [
        const PersonAttendance(
            attendanceId: 1, personId: 1, status: AttendanceStatus.present),
        const PersonAttendance(
            attendanceId: 1, personId: 2, status: AttendanceStatus.late),
        const PersonAttendance(
            attendanceId: 1, personId: 3, status: AttendanceStatus.absent),
        const PersonAttendance(
            attendanceId: 1,
            personId: 4,
            status: AttendanceStatus.excused,
            notes: 'Schichtbedingt'),
        // duty: only assigned persons (duty_state set) count
        const PersonAttendance(
            attendanceId: 2,
            personId: 1,
            status: AttendanceStatus.present,
            dutyState: 'confirmed'),
        const PersonAttendance(
            attendanceId: 2, personId: 2, status: AttendanceStatus.absent),
      ];

      final result = recomputeAttendancePercentages(atts, pas, types);
      expect(result[0].percentage, 50); // 2 of 4
      expect(result[1].percentage, 100); // 1 of 1 assigned

      final withShift = recomputeAttendancePercentages(
        atts,
        pas,
        types,
        shiftExcusedAsPresent: true,
      );
      expect(withShift[0].percentage, 75);
    });

    test('group chart uses player.instrument and only active people', () {
      final groups = [
        TestFactories.createGroup(id: 10, name: 'Geige'),
        TestFactories.createGroup(id: 20, name: 'Cello'),
      ];
      final active = [
        TestFactories.createPerson(id: 1, instrument: 10),
        TestFactories.createPerson(id: 2, instrument: 20),
      ];
      final pas = [
        const PersonAttendance(
            attendanceId: 1, personId: 1, status: AttendanceStatus.present),
        const PersonAttendance(
            attendanceId: 1, personId: 2, status: AttendanceStatus.absent),
        // person 3 left/paused -> not in active list -> ignored
        const PersonAttendance(
            attendanceId: 1, personId: 3, status: AttendanceStatus.present),
      ];
      final result = computeGroupAttendanceRates(pas, active, groups);
      expect(result.map((g) => g.name), ['Geige', 'Cello']);
      expect(result.first.percentage, 100);
      expect(result.last.percentage, 0);
      expect(result.fold<int>(0, (s, g) => s + g.total), 2);
    });

    test('average age per group via player.instrument', () {
      final groups = [TestFactories.createGroup(id: 10, name: 'Geige')];
      final active = [
        TestFactories.createPerson(id: 1, instrument: 10, birthday: '2000-01-01'),
        TestFactories.createPerson(id: 2, instrument: 10, birthday: '2010-01-01'),
        TestFactories.createPerson(id: 3, instrument: 99, birthday: '1990-01-01'),
      ];
      final result = computeAverageAgePerGroup(
        active,
        groups,
        now: DateTime(2026, 6, 1),
      );
      expect(result, hasLength(1));
      expect(result.single.name, 'Geige');
      expect(result.single.count, 2);
      expect(result.single.avgAge, 21); // (26 + 16) / 2
    });
  });
}
