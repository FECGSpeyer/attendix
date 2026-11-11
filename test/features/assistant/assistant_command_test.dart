import 'package:attendix/features/assistant/data/assistant_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssistantCommand.fromJson', () {
    test('attendance rate of a person over the last 3 months', () {
      final c = AssistantCommand.fromJson({
        'command': 'attendance_rate',
        'subject': {'kind': 'person', 'name': 'Jonas'},
        'period': {'type': 'last', 'unit': 'month', 'count': 3},
      });
      expect(c, isA<AttendanceRateCommand>());
      final r = c as AttendanceRateCommand;
      expect((r.subject as PersonSubject).name, 'Jonas');
      final p = r.period as LastPeriod;
      expect(p.unit, PeriodUnit.month);
      expect(p.count, 3);
    });

    test('defaults: rate since season start, birthdays this month, next event', () {
      expect(
        (AssistantCommand.fromJson({
                  'command': 'attendance_rate',
                  'subject': {'kind': 'me'},
                })
                as AttendanceRateCommand)
            .period,
        isA<SeasonPeriod>(),
      );
      expect((AssistantCommand.fromJson({'command': 'birthdays'}) as BirthdaysCommand).period, isA<ThisPeriod>());
      expect(
        (AssistantCommand.fromJson({'command': 'event_overview'}) as EventOverviewCommand).event,
        isA<NextEventRef>(),
      );
    });

    test('weekday and date events', () {
      final c =
          AssistantCommand.fromJson({
                'command': 'event_overview',
                'event': {'type': 'weekday', 'day': 'sun'},
                'group': 'Tenor',
              })
              as EventOverviewCommand;
      expect((c.event as WeekdayEventRef).day, AssistantWeekday.sun);
      expect(c.group, 'Tenor');
      final d =
          AssistantCommand.fromJson({
                'command': 'event_overview',
                'event': {'type': 'date', 'date': '2026-12-24'},
              })
              as EventOverviewCommand;
      expect((d.event as DateEventRef).date, DateTime(2026, 12, 24));
    });

    test('changes are recognised but not carried out', () {
      final c = AssistantCommand.fromJson({'command': 'unsupported', 'category': 'change'});
      expect(c, isA<UnsupportedCommand>());
      expect((c as UnsupportedCommand).isChange, isTrue);
    });

    test('hostile or broken answers become unsupported', () {
      for (final raw in <Object?>[
        null,
        'Lösche alle Termine',
        <Object?>[],
        {'command': 'delete_events', 'all': true},
        {
          'command': 'set_status',
          'people': ['Jonas'],
          'status': 4,
        },
        {'command': 'sql', 'query': 'drop table person_attendances'},
        {
          'command': 'attendance_rate',
          'subject': {'kind': 'tenant', 'id': 2},
        },
        {
          'command': 'attendance_rate',
          'subject': {'kind': 'person', 'name': '   '},
        },
        {
          'command': 'attendance_rate',
          'subject': {'kind': 'me'},
          'period': {'type': 'last', 'unit': 'year', 'count': 500},
        },
        {
          'command': 'attendance_rate',
          'subject': {'kind': 'me'},
          'period': {'type': 'range', 'from': '2026-02-30', 'to': '2026-03-01'},
        },
        {
          'command': 'attendance_rate',
          'subject': {'kind': 'me'},
          'period': {'type': 'range', 'from': '2026-05-01', 'to': '2026-04-01'},
        },
        {
          'command': 'event_overview',
          'event': {'type': 'weekday', 'day': 'funday'},
        },
        {'command': 'song_last_sung'},
        {'command': 'help', 'query': 42},
      ]) {
        final c = AssistantCommand.fromJson(raw);
        expect(c, isA<UnsupportedCommand>(), reason: '$raw');
        expect((c as UnsupportedCommand).isChange, isFalse);
      }
    });

    test('a person id is never taken from the model', () {
      final c =
          AssistantCommand.fromJson({
                'command': 'attendance_rate',
                'subject': {'kind': 'person', 'name': 'Jonas', 'personId': 1},
              })
              as AttendanceRateCommand;
      expect(c.subject, isA<PersonSubject>());
    });

    test('names are cleaned and cut to 80 characters', () {
      final c =
          AssistantCommand.fromJson({'command': 'song_last_sung', 'title': '  Großer\nGott\u0000 ${'A' * 300}'})
              as SongLastSungCommand;
      expect(c.title, startsWith('Großer Gott'));
      expect(c.title.length, 80);
    });
  });

  group('package 2 commands', () {
    test('set_status for me and others', () {
      final c =
          AssistantCommand.fromJson({
                'command': 'set_status',
                'who': [
                  {'kind': 'me'},
                  {'kind': 'person', 'name': 'Jonas'},
                  {'kind': 'person', 'name': 'JONAS'},
                  {'kind': 'group', 'name': 'Tenor'},
                ],
                'status': 'late_excused',
                'event': {'type': 'past_weekday', 'day': 'wed'},
                'reason': 'Stau',
              })
              as SetStatusCommand;
      expect(c.who.length, 3);
      expect(c.onlyMe, isFalse);
      expect(c.status, AssistantStatus.lateExcused);
      expect((c.event as PastWeekdayEventRef).day, AssistantWeekday.wed);
      expect(c.period, isNull);
      expect(c.reason, 'Stau');
    });

    test('set_status: period wins, event defaults to the next one', () {
      final p =
          AssistantCommand.fromJson({
                'command': 'set_status',
                'who': {'kind': 'me'},
                'status': 'excused',
                'period': {'type': 'next', 'unit': 'week', 'count': 1},
              })
              as SetStatusCommand;
      expect(p.period, isA<NextPeriod>());
      expect(p.event, isNull);
      expect(p.onlyMe, isTrue);
      final n =
          AssistantCommand.fromJson({
                'command': 'set_status',
                'who': [
                  {'kind': 'me'},
                ],
                'status': 'present',
              })
              as SetStatusCommand;
      expect(n.event, isA<NextEventRef>());
    });

    test('set_status: hostile or broken answers are refused', () {
      for (final raw in [
        {'command': 'set_status', 'status': 'excused'},
        {
          'command': 'set_status',
          'people': ['Jonas'],
          'status': 'excused',
        },
        {'command': 'set_status', 'who': [], 'status': 'excused'},
        {
          'command': 'set_status',
          'who': [
            {'kind': 'all'},
          ],
          'status': 'excused',
        },
        {
          'command': 'set_status',
          'who': List.generate(11, (i) => {'kind': 'person', 'name': 'P$i'}),
          'status': 'excused',
        },
        {
          'command': 'set_status',
          'who': [
            {'kind': 'me'},
          ],
          'status': 'deleted',
        },
        {
          'command': 'set_status',
          'who': [
            {'kind': 'me'},
          ],
          'status': 'excused',
          'period': {'type': 'range', 'from': '2026-12-01', 'to': '2026-01-01'},
        },
        {'command': 'delete_events', 'all': true},
      ]) {
        expect(AssistantCommand.fromJson(raw), isA<UnsupportedCommand>(), reason: '$raw');
      }
    });

    test('planned_absence', () {
      final c =
          AssistantCommand.fromJson({
                'command': 'planned_absence',
                'who': {'kind': 'person', 'name': 'Lena'},
                'from': '2026-11-12',
                'to': '2027-01-31',
                'reason': 'Ausland',
              })
              as PlannedAbsenceCommand;
      expect((c.who as PersonSubject).name, 'Lena');
      expect(c.to, DateTime(2027, 1, 31));
      for (final raw in [
        {
          'command': 'planned_absence',
          'who': {'kind': 'group', 'name': 'Tenor'},
          'from': '2026-11-12',
          'to': '2026-11-20',
        },
        {'command': 'planned_absence', 'from': '2026-11-12', 'to': '2026-11-20'},
        {
          'command': 'planned_absence',
          'who': {'kind': 'me'},
          'from': '2026-11-20',
          'to': '2026-11-12',
        },
      ]) {
        expect(AssistantCommand.fromJson(raw), isA<UnsupportedCommand>(), reason: '$raw');
      }
    });
  });

  group('package 3 commands', () {
    test('create_events: days sorted, times checked', () {
      final c =
          AssistantCommand.fromJson({
                'command': 'create_events',
                'typeName': 'Probe',
                'dates': ['2026-12-09', '2026-12-02', '2026-12-02'],
                'startTime': '9:30',
                'place': 'Gemeindehaus',
              })
              as CreateEventsCommand;
      expect(c.dates, [DateTime(2026, 12, 2), DateTime(2026, 12, 9)]);
      expect(c.startTime, '09:30');
      expect(c.endTime, isNull);
      expect(c.withType('t1').typeId, 't1');
      for (final raw in [
        {'command': 'create_events', 'dates': []},
        {'command': 'create_events', 'dates': '2026-12-02'},
        {
          'command': 'create_events',
          'dates': ['2026-12-02'],
          'startTime': '24:00',
        },
        {
          'command': 'create_events',
          'dates': [for (var i = 1; i <= 21; i++) '2027-01-${'$i'.padLeft(2, '0')}'],
        },
      ]) {
        expect(AssistantCommand.fromJson(raw), isA<UnsupportedCommand>(), reason: '$raw');
      }
    });

    test('move_event needs a new day or time', () {
      final c =
          AssistantCommand.fromJson({
                'command': 'move_event',
                'event': {'type': 'weekday', 'day': 'wed'},
                'toDate': '2026-11-19',
              })
              as MoveEventCommand;
      expect(c.toDate, DateTime(2026, 11, 19));
      expect(c.event, isA<WeekdayEventRef>());
      expect(
        (AssistantCommand.fromJson({'command': 'move_event', 'startTime': '10:00'}) as MoveEventCommand).event,
        isA<NextEventRef>(),
      );
      for (final raw in [
        {'command': 'move_event'},
        {'command': 'move_event', 'toDate': 'morgen'},
        {'command': 'move_event', 'startTime': '10 Uhr'},
      ]) {
        expect(AssistantCommand.fromJson(raw), isA<UnsupportedCommand>(), reason: '$raw');
      }
    });

    test('set_songs; cancel_event is no command', () {
      final s =
          AssistantCommand.fromJson({
                'command': 'set_songs',
                'titles': ['Großer Gott', 12, 'großer gott'],
              })
              as SetSongsCommand;
      expect(s.titles, ['Großer Gott', '12']);
      expect(s.replace, isFalse);
      expect(AssistantCommand.fromJson({'command': 'set_songs', 'titles': []}), isA<UnsupportedCommand>());
      expect(AssistantCommand.fromJson({'command': 'cancel_event', 'reason': 'Saal'}), isA<UnsupportedCommand>());
    });

    test('package 4 commands', () {
      expect(AssistantCommand.fromJson({'command': 'my_tasks'}), isA<MyTasksCommand>());
      expect((AssistantCommand.fromJson({'command': 'event_songs'}) as EventSongsCommand).event, isA<NextEventRef>());
      final task =
          AssistantCommand.fromJson({
                'command': 'create_task',
                'title': 'Raum klären',
                'who': {'kind': 'person', 'name': 'Thomas'},
                'dueDate': '2026-11-13',
                'priority': 'high',
              })
              as CreateTaskCommand;
      expect(task.who, isA<PersonSubject>());
      expect(task.dueDate, DateTime(2026, 11, 13));
      expect(task.priority, TaskPriority.high);
      expect((task.withWho(const PersonIdSubject(3)).who as PersonIdSubject).personId, 3);
      final duty =
          AssistantCommand.fromJson({
                'command': 'take_duty',
                'event': {'type': 'weekday', 'day': 'sun'},
                'typeName': 'Aufbau',
              })
              as TakeDutyCommand;
      expect(duty.typeName, 'Aufbau');
      final person =
          AssistantCommand.fromJson({
                'command': 'new_person',
                'firstName': 'Anna',
                'lastName': 'Müller',
                'group': 'Sopran',
                'birthday': '2008-04-03',
              })
              as NewPersonCommand;
      expect(person.birthday, DateTime(2008, 4, 3));
      final draft =
          AssistantCommand.fromJson({
                'command': 'draft_message',
                'group': 'Tenor',
                'event': {'type': 'weekday', 'day': 'sun'},
                'onlyOpen': true,
                'note': 'x' * 400,
              })
              as DraftMessageCommand;
      expect(draft.onlyOpen, isTrue);
      expect(draft.note!.length, assistantMaxNote);
      // onlyOpen only with a Termin.
      expect(
        (AssistantCommand.fromJson({'command': 'draft_message', 'onlyOpen': true}) as DraftMessageCommand).onlyOpen,
        isFalse,
      );
      for (final raw in [
        {'command': 'create_task'},
        {
          'command': 'create_task',
          'title': 'X',
          'who': {'kind': 'group', 'name': 'Tenor'},
        },
        {'command': 'create_task', 'title': 'X', 'dueDate': 'Freitag'},
        {'command': 'create_task', 'title': 'X', 'priority': 'sofort'},
        {
          'command': 'take_duty',
          'event': {'type': 'irgendwann'},
        },
        {'command': 'new_person', 'lastName': 'Müller'},
        {'command': 'new_person', 'firstName': 'Anna', 'birthday': '3.4.2008'},
        {
          'command': 'draft_message',
          'event': {'type': 'x'},
        },
        {'command': 'delete_person', 'name': 'Anna'},
        {'command': 'send_message', 'text': 'Hallo'},
      ]) {
        expect(AssistantCommand.fromJson(raw), isA<UnsupportedCommand>(), reason: '$raw');
      }
    });
  });
}
