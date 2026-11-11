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
      expect((AssistantCommand.fromJson({'command': 'attendance_rate', 'subject': {'kind': 'me'}}) as AttendanceRateCommand).period,
          isA<SeasonPeriod>());
      expect((AssistantCommand.fromJson({'command': 'birthdays'}) as BirthdaysCommand).period, isA<ThisPeriod>());
      expect((AssistantCommand.fromJson({'command': 'event_overview'}) as EventOverviewCommand).event, isA<NextEventRef>());
    });

    test('weekday and date events', () {
      final c = AssistantCommand.fromJson({
        'command': 'event_overview',
        'event': {'type': 'weekday', 'day': 'sun'},
        'group': 'Tenor',
      }) as EventOverviewCommand;
      expect((c.event as WeekdayEventRef).day, AssistantWeekday.sun);
      expect(c.group, 'Tenor');
      final d = AssistantCommand.fromJson({
        'command': 'event_overview',
        'event': {'type': 'date', 'date': '2026-12-24'},
      }) as EventOverviewCommand;
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
        {'command': 'set_status', 'people': ['Jonas'], 'status': 4},
        {'command': 'sql', 'query': 'drop table person_attendances'},
        {'command': 'attendance_rate', 'subject': {'kind': 'tenant', 'id': 2}},
        {'command': 'attendance_rate', 'subject': {'kind': 'person', 'name': '   '}},
        {'command': 'attendance_rate', 'subject': {'kind': 'me'}, 'period': {'type': 'last', 'unit': 'year', 'count': 500}},
        {'command': 'attendance_rate', 'subject': {'kind': 'me'}, 'period': {'type': 'range', 'from': '2026-02-30', 'to': '2026-03-01'}},
        {'command': 'attendance_rate', 'subject': {'kind': 'me'}, 'period': {'type': 'range', 'from': '2026-05-01', 'to': '2026-04-01'}},
        {'command': 'event_overview', 'event': {'type': 'weekday', 'day': 'funday'}},
        {'command': 'song_last_sung'},
        {'command': 'help', 'query': 42},
      ]) {
        final c = AssistantCommand.fromJson(raw);
        expect(c, isA<UnsupportedCommand>(), reason: '$raw');
        expect((c as UnsupportedCommand).isChange, isFalse);
      }
    });

    test('a person id is never taken from the model', () {
      final c = AssistantCommand.fromJson({
        'command': 'attendance_rate',
        'subject': {'kind': 'person', 'name': 'Jonas', 'personId': 1},
      }) as AttendanceRateCommand;
      expect(c.subject, isA<PersonSubject>());
    });

    test('names are cleaned and cut to 80 characters', () {
      final c = AssistantCommand.fromJson({'command': 'song_last_sung', 'title': '  Großer\nGott\u0000 ${'A' * 300}'})
          as SongLastSungCommand;
      expect(c.title, startsWith('Großer Gott'));
      expect(c.title.length, 80);
    });
  });
}
