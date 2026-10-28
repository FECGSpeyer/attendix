import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/utils/dashboard_logic.dart';
import 'package:attendix/core/utils/dashboard_utils.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/church/church.dart';
import 'package:attendix/data/models/dashboard/dashboard_event.dart';
import 'package:attendix/data/models/dashboard/dashboard_models.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 28, 12);

  group('Dashboard card config (user_metadata)', () {
    test('returns defaults when nothing is stored', () {
      final cards = mergeDashboardCardConfig(null);
      expect(cards.map((c) => c.id), DashboardCardIds.all);
      expect(cards.every((c) => c.visible), isTrue);
    });

    test('keeps stored order, appends new cards and drops unknown ids', () {
      final cards = mergeDashboardCardConfig([
        {'id': 'current-plan', 'visible': false},
        {'id': 'birthdays', 'visible': true},
        {'id': 'removed-card', 'visible': true},
      ]);
      expect(cards.first, const DashboardCardConfig(id: 'current-plan', visible: false));
      expect(cards[1].id, 'birthdays');
      expect(cards.map((c) => c.id), isNot(contains('removed-card')));
      expect(cards.length, DashboardCardIds.all.length);
    });

    test('"Meine Aufgaben" is only configurable with Teamorganisation', () {
      final cards = mergeDashboardCardConfig(null);
      expect(
        configurableDashboardCards(cards, teamOrgEnabled: false).map((c) => c.id),
        isNot(contains(DashboardCardIds.myTasks)),
      );
      expect(
        configurableDashboardCards(cards, teamOrgEnabled: true).map((c) => c.id),
        contains(DashboardCardIds.myTasks),
      );
    });
  });

  group('homeRouteFor', () {
    final meta = {'showDashboardTab_42': true};

    test('admin/responsible with dashboard tab start on the dashboard', () {
      expect(homeRouteFor(Role.admin, 42, meta), '/home-dashboard');
      expect(homeRouteFor(Role.responsible, 42, meta), '/home-dashboard');
    });

    test('setting is per tenant', () {
      expect(homeRouteFor(Role.admin, 7, meta), Role.admin.defaultRoute);
    });

    test('other roles never use the dashboard', () {
      expect(homeRouteFor(Role.viewer, 42, meta), Role.viewer.defaultRoute);
      expect(homeRouteFor(Role.player, 42, meta), Role.player.defaultRoute);
    });
  });

  group('Birthdays card', () {
    Person p(int id, String birthday, {String? left, bool correct = true}) => Person(
          id: id,
          firstName: 'P$id',
          birthday: birthday,
          correctBirthday: correct,
          left: left,
        );

    test('hides archived persons and unconfirmed birthdays', () {
      final entries = DashboardUtils.birthdays([
        p(1, '2000-10-28'),
        p(2, '2000-10-28', left: '2026-01-01'),
        p(3, '2000-10-28', correct: false),
      ], now: now);
      expect(entries.map((e) => e.person.id), [1]);
      expect(entries.single.daysOffset, 0);
      expect(entries.single.age, 26);
      expect(DashboardUtils.birthdayAgeText(entries.single), 'wird heute 26');
    });

    test('window of 14 days, upcoming first then most recent past', () {
      final entries = DashboardUtils.birthdays([
        p(1, '1990-10-20'), // 8 days ago
        p(2, '1990-11-05'), // in 8 days
        p(3, '1990-10-30'), // in 2 days
        p(4, '1990-12-31'), // outside
        p(5, '1990-10-25'), // 3 days ago
      ], now: now);
      expect(entries.map((e) => e.person.id), [3, 2, 5, 1]);
      expect(entries.firstWhere((e) => e.person.id == 2).age, 36);
    });

    test('wraps around the year end', () {
      final entries = DashboardUtils.birthdays(
        [p(1, '1990-01-05')],
        now: DateTime(2026, 12, 28),
      );
      expect(entries.single.daysOffset, 8);
      expect(entries.single.date.year, 2027);
    });
  });

  group('Member changes card', () {
    test('lists joins and leaves of the last 60 days, newest first, max 5', () {
      final persons = [
        Person(id: 1, joined: '2026-10-01'),
        Person(id: 2, joined: '2026-01-01', left: '2026-10-20'),
        Person(id: 3, joined: '2025-01-01'),
      ];
      final changes = DashboardUtils.memberChanges(persons, now: now);
      expect(changes.map((c) => (c.person.id, c.joined)), [(2, false), (1, true)]);
    });
  });

  group('Termine card', () {
    DashboardEvent event(int id, String date, List<AttendanceStatus> statuses, {int? days}) =>
        DashboardEvent(
          attendance: Attendance(id: id, date: date, durationDays: days),
          persons: [
            for (var i = 0; i < statuses.length; i++)
              PersonAttendance(personId: i, status: statuses[i], lastName: 'L$i'),
          ],
        );

    test('picks last finished and next upcoming Termin with stats', () {
      final s = computeNextEventSummary([
        event(1, '2026-10-20T18:00:00', [AttendanceStatus.present, AttendanceStatus.absent]),
        event(2, '2026-10-30T18:00:00', [
          AttendanceStatus.present,
          AttendanceStatus.excused,
          AttendanceStatus.neutral,
          AttendanceStatus.late,
        ]),
        event(3, '2026-11-10T18:00:00', const []),
      ], now: now);
      expect(s.lastEvent?.attendance.id, 1);
      expect(s.lastPerc, 50);
      expect(s.nextEvent?.attendance.id, 2);
      expect(s.nextPresent, 2);
      expect(s.nextExcused, 1);
      expect(s.nextNeutral, 1);
      expect(s.nextTotal, 4);
    });

    test('a running multi-day Termin still counts as upcoming', () {
      final s = computeNextEventSummary([
        event(1, '2026-10-26T10:00:00', const [], days: 4),
      ], now: now);
      expect(s.nextEvent?.attendance.id, 1);
      expect(s.lastEvent, isNull);
    });
  });

  group('Aktueller Ablaufplan card', () {
    Map<String, dynamic> plan(int day) => {
          'time': '10:00',
          'end': '12:00',
          'day': day,
          'fields': [
            {'id': 'a', 'name': 'Start', 'time': '30'},
          ],
        };

    test('skips Termine without plan and unshared plans for non-admins', () {
      final events = [
        DashboardEvent(attendance: Attendance(id: 1, date: '2026-10-29')),
        DashboardEvent(attendance: Attendance(id: 2, date: '2026-10-30', plan: plan(0))),
        DashboardEvent(
          attendance: Attendance(id: 3, date: '2026-10-31', plan: plan(0), sharePlan: true),
        ),
      ];
      expect(selectCurrentPlan(events, isAdmin: true, now: now)?.event.attendance.id, 2);
      expect(selectCurrentPlan(events, isAdmin: false, now: now)?.event.attendance.id, 3);
    });

    test("multi-day Termin shows today's plan", () {
      final e = DashboardEvent(
        attendance: Attendance(id: 1, date: '2026-10-27', durationDays: 3, plan: plan(0)),
        extraPlans: [plan(1), plan(2)],
      );
      final data = selectCurrentPlan([e], isAdmin: true, now: now)!;
      expect(data.plan['day'], 1);
      expect(DashboardUtils.isSameDay(data.planDay, now), isTrue);
      expect(data.multiPlan, isTrue);
    });

    test('field numbers for Programmblöcke', () {
      expect(
        DashboardUtils.fieldNumbers([
          {'id': '1'},
          {'id': 'g', 'isGroup': true},
          {'id': '2', 'groupId': 'g'},
          {'id': '3', 'groupId': 'g'},
          {'id': '4'},
        ]),
        ['1', '2', '2.1', '2.2', '3'],
      );
    });
  });

  group('Aktuelle Werke card', () {
    test('one entry per song with conductor and type label', () {
      final entries = buildCurrentSongEntries([
        {
          'date': '2026-11-01T10:00:00',
          'person_id': {'firstName': 'Max', 'lastName': 'M'},
          'song': {'id': 5, 'name': 'Choral', 'number': 12, 'prefix': 'A'},
          'attendance_id': {'id': 9, 'date': '2026-11-01T10:00:00', 'type_id': 't', 'typeInfo': null},
        },
        {
          'date': '2026-11-08T10:00:00',
          'otherConductor': 'Gast',
          'song': {'id': 5, 'name': 'Choral'},
          'attendance_id': null,
        },
      ], typeName: (_) => 'Probe');
      expect(entries.length, 1);
      expect(entries.single.songId, 5);
      expect(entries.single.conductorName, 'Max M');
      expect(entries.single.typeLabel, 'Probe');
    });
  });

  group('Administration: Gemeinden duplicates', () {
    test('groups churches with the same normalised name', () {
      final groups = findChurchDuplicates(const [
        Church(id: 'a', name: 'FeG Speyer'),
        Church(id: 'b', name: 'feg-speyer'),
        Church(id: 'c', name: 'Andere'),
      ]);
      expect(groups.length, 1);
      expect(groups.single.target.id, 'a');
      expect(groups.single.duplicates.single.id, 'b');
    });
  });

  group('Date helpers', () {
    test('relative days in German', () {
      expect(DashboardUtils.relativeDays(DateTime(2026, 10, 28), now: now), 'Heute');
      expect(DashboardUtils.relativeDays(DateTime(2026, 10, 29), now: now), 'Morgen');
      expect(DashboardUtils.relativeDays(DateTime(2026, 10, 27), now: now), 'Gestern');
      expect(DashboardUtils.relativeDays(DateTime(2026, 10, 25), now: now), 'vor 3 Tagen');
      expect(DashboardUtils.relativeDays(DateTime(2026, 11, 2), now: now), 'in 5 Tagen');
    });
  });
}
