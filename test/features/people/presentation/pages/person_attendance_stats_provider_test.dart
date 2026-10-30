import 'dart:io';

import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/people/person_stats.dart';
import 'package:attendix/features/people/presentation/widgets/person_detail/late_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P10_PEOPLE: person page statistics follow Ionic person.page
/// getHistoryInfo (average over include_in_average types, late counts since
/// lastSolve, lateThreshold from the first rule containing "Verspätet").
void main() {
  final now = DateTime(2026, 6, 1, 12);
  final windowStart = DateTime(2025, 9, 1);

  Map<String, dynamic> row(
    String date,
    int status, {
    bool include = true,
    bool dutyMode = false,
    String? dutyState,
    String? notes,
  }) =>
      {
        'status': status,
        'notes': notes,
        'duty_state': dutyState,
        'attendance': {
          'date': date,
          'attType': {'include_in_average': include, 'duty_mode': dutyMode},
        },
      };

  group('computePersonAttendanceStats', () {
    test('averages only include_in_average types of the window', () {
      final stats = computePersonAttendanceStats(
        [
          row('2026-01-10', 1), // present
          row('2026-01-17', 4), // absent
          row('2026-01-24', 1, include: false), // not counted
          row('2025-05-01', 4), // before season start
          row('2026-07-01', 4), // future
          row('2026-02-01', 1, dutyMode: true), // duty, not assigned
          row('2026-02-08', 1, dutyMode: true, dutyState: 'assigned'),
        ],
        now: now,
        windowStart: windowStart,
      );
      expect(stats['counted'], 3);
      expect(stats['attended'], 2);
      expect(stats['percentage'], 67);
    });

    test('counts late (3) and late excused (5) only after lastSolve', () {
      final stats = computePersonAttendanceStats(
        [
          row('2026-01-10', 3),
          row('2026-03-10', 3),
          row('2026-03-17', 3),
          row('2026-03-24', 5),
        ],
        now: now,
        windowStart: windowStart,
        lastSolve: '2026-02-01T10:00:00Z',
      );
      expect(stats['lateCount'], 2);
      expect(stats['lateCountExcused'], 1);
    });

    test('no counted attendances → 0 %', () {
      final stats = computePersonAttendanceStats(const [],
          now: now, windowStart: windowStart);
      expect(stats['percentage'], 0);
    });
  });

  group('personAttendanceWindowStart', () {
    test('season start, fallback 2023-01-01, archived since 2020', () {
      expect(personAttendanceWindowStart(seasonStart: '2025-09-01'),
          DateTime(2025, 9, 1));
      expect(personAttendanceWindowStart(), DateTime(2023, 1, 1));
      expect(
          personAttendanceWindowStart(seasonStart: '2025-09-01', hasLeft: true),
          DateTime(2020, 1, 1));
    });
  });

  group('lateWarningThreshold', () {
    CriticalRule rule(List<int> statuses, int value) => CriticalRule.fromJson({
          'id': 'r$value',
          'attendance_type_ids': <String>[],
          'operator': 'OR',
          'statuses': statuses,
          'threshold_type': 'count',
          'threshold_value': value,
        });

    test('first rule with "Verspätet" wins, otherwise 999', () {
      expect(lateWarningThreshold(null), 999);
      expect(lateWarningThreshold([rule([4], 2)]), 999);
      expect(lateWarningThreshold([rule([4], 2), rule([3, 5], 4)]), 4);
    });
  });

  test('htmlStrongToSpan renders <strong> parts bold', () {
    final span = htmlStrongToSpan('Diese Person ist <strong>3x</strong> zu spät.');
    final children = span.children!.cast<TextSpan>();
    expect(children.map((c) => c.text).join(), 'Diese Person ist 3x zu spät.');
    expect(children[1].style?.fontWeight, FontWeight.bold);
  });

  test('history for non-admins: group changes and pauses only', () {
    expect(visibleHistoryTypesForMembers, {7, 1, 6});
    final source = File(
            'lib/features/people/presentation/pages/person_detail_page.dart')
        .readAsStringSync();
    expect(source, contains('visibleHistoryTypesForMembers.contains(h.type)'));
    expect(source, isNot(contains('allHistory.take(')));
  });

  test('person page is read-only for non-admins and archived persons', () {
    final source = File(
            'lib/features/people/presentation/pages/person_detail_page.dart')
        .readAsStringSync();
    expect(source, contains('final canEdit = isAdmin && !hasLeft;'));
    expect(source, contains('onPressed: _activatePerson'));
    // Stats query (now in PlayerRepository) stays tenant-bound via the
    // inner-joined attendance.
    expect(source, contains('repo.getPersonAttendanceStatsRows(personId)'));
    final repo = File('lib/data/repositories/player_repository.dart').readAsStringSync();
    final body = repo.substring(repo.indexOf('getPersonAttendanceStatsRows(int personId)'));
    expect(body.substring(0, body.indexOf('catch (e')), contains(".eq('attendance.tenantId', currentTenantId)"));
  });
}
