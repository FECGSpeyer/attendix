// P10_ATTENDANCE: final parity sweep (Wave 10) – attendance, history, stats.
import 'dart:io';

import 'package:attendix/core/providers/statistics_providers.dart';
import 'package:attendix/core/utils/attendance_logic_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/plan_accordion.dart';
import 'package:attendix/features/history/history_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

void main() {
  group('showSongsForType (Ionic manageSongs && !isGeneral)', () {
    const withSongs = AttendanceType(name: 'Probe', manageSongs: true);
    const noSongs = AttendanceType(name: 'Sitzung');

    test('shown for song types of non-general tenants', () {
      expect(showSongsForType(withSongs, 'orchestra'), isTrue);
      expect(showSongsForType(withSongs, null), isTrue);
    });

    test('hidden for general tenants and types without songs', () {
      expect(showSongsForType(withSongs, 'general'), isFalse);
      expect(showSongsForType(noSongs, 'orchestra'), isFalse);
      expect(showSongsForType(null, 'orchestra'), isFalse);
    });
  });

  group('plan accordion helpers', () {
    const field = PlanField(id: '1', name: 'Einspielen', time: '15');

    test('hasPlanFields needs a start time and at least one field', () {
      expect(hasPlanFields(const Plan(time: '18:00', fields: [field])), isTrue);
      expect(hasPlanFields(const Plan(fields: [field])), isFalse);
      expect(hasPlanFields(const Plan(time: '18:00')), isFalse);
    });

    test("todayChipIndex marks today's plan of a multi-day Termin", () {
      const att = PlanAttendance(
        id: 1,
        date: '2026-10-10',
        durationDays: 3,
        plan: Plan(time: '10:00', fields: [field]),
        extraPlans: [Plan(time: '10:00', fields: [field], day: 1, id: 'b')],
      );
      final plans = [att.plan!, ...att.extraPlans!];
      expect(todayChipIndex(att, plans, DateTime(2026, 10, 11, 9)), 1);
      expect(todayChipIndex(att, plans, DateTime(2026, 10, 10, 9)), 0);
      expect(todayChipIndex(att, plans, DateTime(2026, 10, 20)), -1);
    });
  });

  group('history: default conductor (Ionic activeConductors[0])', () {
    test('first conductor who has not left', () {
      final conductors = [
        TestFactories.createPerson(id: 1, left: '2024-01-01'),
        TestFactories.createPerson(id: 2),
        TestFactories.createPerson(id: 3),
      ];
      expect(defaultHistoryConductorId(conductors), 2);
    });

    test('null without active conductors', () {
      expect(defaultHistoryConductorId(const []), isNull);
      expect(
        defaultHistoryConductorId(
            [TestFactories.createPerson(id: 1, left: '2024-01-01')]),
        isNull,
      );
    });
  });

  group('stats: default period (Ionic seasonStart || 2023-01-01)', () {
    test('uses the season start when set', () {
      final n = StatisticsDateRangeNotifier()
        ..resetToDefault(seasonStart: '2025-09-01');
      expect(n.state.start, DateTime(2025, 9, 1));
    });

    test('falls back to 2023-01-01 without season start', () {
      final n = StatisticsDateRangeNotifier()..resetToDefault();
      expect(n.state.start, DateTime(2023, 1, 1));
      final m = StatisticsDateRangeNotifier()
        ..resetToDefault(seasonStart: 'kein Datum');
      expect(m.state.start, DateTime(2023, 1, 1));
    });
  });

  group('source checks', () {
    final detail = File(
      'lib/features/attendance/presentation/pages/attendance_detail_page.dart',
    ).readAsStringSync();

    test('files folder actions are gated by canAccessFiles', () {
      expect(detail, contains('ref.watch(canAccessFilesProvider)'));
      for (final cb in [
        'onChooseFilesFolder',
        'onRemoveFilesFolder',
        'onOpenFilesFolder',
      ]) {
        final i = detail.indexOf('$cb:');
        expect(i, greaterThan(0), reason: cb);
        expect(detail.substring(i, i + 160), contains('canAccessFiles'),
            reason: cb);
      }
    });

    test('plan accordion opens the editor on the shown plan', () {
      expect(detail, contains('onEditPlan:'));
      expect(detail, contains('&plan='));
    });

    test('stats page always resets the period', () {
      final stats = File(
        'lib/features/statistics/presentation/pages/statistics_page.dart',
      ).readAsStringSync();
      expect(stats, contains('resetToDefault(seasonStart: tenant?.seasonStart)'));
      expect(stats, isNot(contains('if (tenant?.seasonStart != null)')));
    });
  });
}
