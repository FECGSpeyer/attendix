import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/attendance_logic_utils.dart';
import 'package:attendix/data/models/player_absence/player_absence.dart';
import 'package:flutter_test/flutter_test.dart';

/// WAVE 7 LOGIC_ATT: Termin creation/detail logic parity with Ionic.
void main() {
  const n = AttendanceStatus.neutral;
  const e = AttendanceStatus.excused;
  const p = AttendanceStatus.present;

  const absences = [
    PlayerAbsence(personId: 1, fromDate: '2026-03-10', untilDate: '2026-03-12', reason: 'Urlaub'),
    PlayerAbsence(personId: 2, fromDate: '2026-03-01', untilDate: '2026-03-01', reason: 'Krank'),
  ];

  group('absenceOnDay (Ionic attendance-create)', () {
    test('covers from..until inclusive on the local day', () {
      expect(absenceOnDay(absences, 1, DateTime(2026, 3, 10, 12))?.reason, 'Urlaub');
      expect(absenceOnDay(absences, 1, DateTime(2026, 3, 12, 12))?.reason, 'Urlaub');
      expect(absenceOnDay(absences, 1, DateTime(2026, 3, 13, 12)), isNull);
      expect(absenceOnDay(absences, 2, DateTime(2026, 3, 10, 12)), isNull);
      // ISO noon stored as UTC still maps to the local day
      expect(absenceOnDay(absences, 1, DateTime(2026, 3, 11, 12).toUtc())?.reason, 'Urlaub');
    });
  });

  group('dateChangeStatusUpdates (Ionic changeAttendanceDate)', () {
    final rows = <PersonStatusRow>[
      (id: 'a', personId: 1, status: n, notes: null),
      (id: 'b', personId: 1, status: p, notes: null),
      (id: 'c', personId: 3, status: p, notes: null),
      (id: 'd', personId: 3, status: n, notes: 'x'),
    ];

    test('keep statuses: only default rows with an absence are excused', () {
      final u = dateChangeStatusUpdates(
        rows: rows,
        absences: absences,
        newDay: DateTime(2026, 3, 11, 12),
        defaultStatus: n,
        resetStatuses: false,
      );
      expect(u.map((x) => (x.id, x.status, x.notes)), [('a', e, 'Urlaub')]);
    });

    test('reset: absences win, everything else back to default', () {
      final u = dateChangeStatusUpdates(
        rows: rows,
        absences: absences,
        newDay: DateTime(2026, 3, 11, 12),
        defaultStatus: n,
        resetStatuses: true,
      );
      expect(u.map((x) => (x.id, x.status, x.notes)), [
        ('a', e, 'Urlaub'),
        ('b', e, 'Urlaub'),
        ('c', n, ''),
        ('d', n, ''),
      ]);
    });
  });

  group('defaultDeadline (Ionic onDeadlineToggleChanged)', () {
    test('day before at type start hour + 2', () {
      final d = defaultDeadline(DateTime(2026, 5, 10, 12), '18:30', now: DateTime(2026, 5, 1));
      expect(d, DateTime(2026, 5, 9, 20));
    });

    test('19:00 without start time; Termin day when the day before is past', () {
      expect(defaultDeadline(DateTime(2026, 5, 10, 12), null, now: DateTime(2026, 5, 1)),
          DateTime(2026, 5, 9, 19));
      expect(defaultDeadline(DateTime(2026, 5, 10, 12), '18:00', now: DateTime(2026, 5, 9, 21)),
          DateTime(2026, 5, 10, 20));
    });
  });

  group('planHistorySync (no delete + re-insert)', () {
    test('keeps unchanged rows, updates conductor, inserts and deletes the rest', () {
      final plan = planHistorySync(
        [
          (id: 1, songId: 10, personId: 5, otherConductor: null),
          (id: 2, songId: 11, personId: 5, otherConductor: null),
          (id: 3, songId: 12, personId: 5, otherConductor: null),
        ],
        [
          (songId: 10, personId: 5, otherConductor: null), // unchanged
          (songId: 11, personId: null, otherConductor: 'Gast'), // conductor change
          (songId: 13, personId: 5, otherConductor: null), // new
        ],
      );
      expect(plan.delete, [3]);
      expect(plan.update.map((u) => (u.id, u.entry.otherConductor)), [(2, 'Gast')]);
      expect(plan.insert.map((x) => x.songId), [13]);
    });

    test('nothing to do for identical lists', () {
      final plan = planHistorySync(
        [(id: 1, songId: 10, personId: 5, otherConductor: '')],
        [(songId: 10, personId: 5, otherConductor: null)],
      );
      expect(plan.delete, isEmpty);
      expect(plan.update, isEmpty);
      expect(plan.insert, isEmpty);
    });
  });

  group('source parity', () {
    // REDESIGN: the create writes are shared with the new design
    // (attendance_create_writes.dart).
    final create = File('lib/features/attendance/presentation/pages/attendance_create_page.dart')
            .readAsStringSync() +
        File('lib/features/attendance/presentation/attendance_create_writes.dart')
            .readAsStringSync();
    // ASTRA_SIGNOUT_TOPICS: the date change of the Termin page is shared
    // with the Teamorganisation (attendance_date_change.dart).
    final detail = File('lib/features/attendance/presentation/pages/attendance_detail_page.dart')
            .readAsStringSync() +
        File('lib/features/attendance/presentation/widgets/attendance_date_change.dart')
            .readAsStringSync();
    final repo = File('lib/data/repositories/attendance_repository.dart').readAsStringSync();

    test('create: paused NULL counts as not paused, absences + shifts applied', () {
      expect(create, isNot(contains(".eq('paused', false)")));
      expect(create, contains("p['paused'] != true"));
      expect(create, contains('absenceOnDay(_absences'));
      expect(create, contains('ShiftUtils.statusByShiftOrDefault('));
      expect(create, contains('personExtraFieldsProvider'));
    });

    test('create: Ionic columns (local noon ISO, no legacy type, duration 1)', () {
      expect(create, contains('normalizedDate.toUtc().toIso8601String()'));
      expect(create, isNot(contains("'type': type.name")));
      expect(create, contains("'duration_days': type.allDay == true ? input.durationDays : 1"));
      expect(create, contains("dueDate?.toUtc().toIso8601String()"));
      expect(create, isNot(contains('practiceStart')));
    });

    test('detail: no auto-fill, no legacy song columns, shift recompute', () {
      expect(detail, isNot(contains('ensurePersonAttendances')));
      expect(detail, isNot(contains("'songs': songIds")));
      expect(detail, isNot(contains("from('history')")));
      expect(detail, contains('updateShiftAssignmentsForAttendance'));
      expect(detail, contains('dateChangeStatusUpdates('));
      expect(detail, contains('PostgresChangeEvent.update'));
      expect(detail, isNot(contains('recalculatePercentage')));
    });

    String body(String name) {
      final start = repo.indexOf('Future<void> $name(');
      expect(start, greaterThanOrEqualTo(0), reason: '$name should exist');
      final next = repo.indexOf('\n  Future<', start + 10);
      return repo.substring(start, next < 0 ? repo.length : next);
    }

    test('repository: new history/shift methods filter the tenant', () {
      for (final m in ['updateHistoryEntry', 'deleteHistoryEntry']) {
        expect(body(m), contains(".eq('tenantId', currentTenantId)"), reason: m);
        expect(body(m), contains(".eq('id', id)"), reason: m);
      }
      expect(body('addHistoryEntries'), contains("'tenantId': currentTenantId"));
      final shift = body('updateShiftAssignmentsForAttendance');
      expect(shift, contains(".eq('tenantId', currentTenantId)"));
      expect(shift, contains(".eq('tenant_id', currentTenantId)"));
      expect(shift, contains('ShiftUtils.shiftUpdatesForAttendance('));
    });

    test('changed_at is written as UTC', () {
      expect(repo, isNot(contains("'changed_at': DateTime.now().toIso8601String()")));
      expect(repo, isNot(contains("['changed_at'] = DateTime.now().toIso8601String()")));
    });
  });
}
