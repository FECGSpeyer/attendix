import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/features/assistant/data/assistant_command.dart';
import 'package:attendix/features/assistant/data/assistant_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 11, 17, 30); // Wednesday
  final season = DateTime(2026, 9, 1);

  group('resolvePeriod', () {
    test('last 3 months up to today', () {
      final r = resolvePeriod(const LastPeriod(PeriodUnit.month, 3), today, season);
      expect(r.from, DateTime(2026, 8, 11));
      expect(r.to, DateTime(2026, 11, 11));
    });

    test('this and previous month, week, year', () {
      expect(resolvePeriod(const ThisPeriod(PeriodUnit.month), today, season), (from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30)));
      expect(resolvePeriod(const PreviousPeriod(PeriodUnit.month), today, season), (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)));
      expect(resolvePeriod(const ThisPeriod(PeriodUnit.week), today, season), (from: DateTime(2026, 11, 9), to: DateTime(2026, 11, 15)));
      expect(resolvePeriod(const PreviousPeriod(PeriodUnit.year), today, season), (from: DateTime(2025, 1, 1), to: DateTime(2025, 12, 31)));
    });

    test('month ends and season', () {
      final r = resolvePeriod(const LastPeriod(PeriodUnit.month, 1), DateTime(2026, 3, 31), season);
      expect(r.from, DateTime(2026, 2, 28));
      expect(resolvePeriod(const SeasonPeriod(), today, season), (from: DateTime(2026, 9, 1), to: DateTime(2026, 11, 11)));
      expect(resolvePeriod(const NextPeriod(PeriodUnit.day, 30), today, season).to, DateTime(2026, 12, 11));
    });
  });

  test('resolveEventDay: weekday is the next such day, today included', () {
    expect(resolveEventDay(const WeekdayEventRef(AssistantWeekday.sun), today), DateTime(2026, 11, 15));
    expect(resolveEventDay(const WeekdayEventRef(AssistantWeekday.wed), today), DateTime(2026, 11, 11));
    expect(resolveEventDay(const WeekdayEventRef(AssistantWeekday.tue), today), DateTime(2026, 11, 17));
    expect(resolveEventDay(const TomorrowEventRef(), today), DateTime(2026, 11, 12));
    expect(resolveEventDay(const NextEventRef(), today), isNull);
  });

  group('names', () {
    final people = [
      (id: 1, first: 'Jonas', last: 'Müller'),
      (id: 2, first: 'Jonas', last: 'Klein'),
      (id: 3, first: 'Marie', last: 'Schmidt'),
    ];
    Iterable<String> names(({int id, String first, String last}) p) => personNames(p.first, p.last);

    test('same first name is ambiguous, full name or last name is not', () {
      expect(bestMatches('Jonas', people, names).map((p) => p.id), [1, 2]);
      expect(bestMatches('Jonas Mueller', people, names).map((p) => p.id), [1]);
      expect(bestMatches('Klein', people, names).map((p) => p.id), [2]);
    });

    test('small typos and prefixes, nothing for strangers', () {
      expect(bestMatches('Mari', people, names).map((p) => p.id), [3]);
      expect(bestMatches('Shmidt', people, names).map((p) => p.id), [3]);
      expect(bestMatches('Peter', people, names), isEmpty);
      expect(bestMatches('', people, names), isEmpty);
    });
  });

  group('computeRate', () {
    RateRow row(int day, AttendanceStatus s, {String type = 'p', String? duty, int month = 11}) =>
        (personId: 1, date: DateTime(2026, month, day, 12), typeId: type, status: s, notes: null, dutyState: duty);

    test('counts only past Termine of counted types in the range', () {
      final r = computeRate(
        [
          row(2, AttendanceStatus.present),
          row(4, AttendanceStatus.late),
          row(6, AttendanceStatus.absent),
          row(8, AttendanceStatus.excused),
          row(9, AttendanceStatus.present, type: 'not-counted'),
          row(20, AttendanceStatus.neutral), // future
          row(1, AttendanceStatus.present, month: 7), // before the range
        ],
        range: (from: DateTime(2026, 8, 11), to: DateTime(2026, 11, 30)),
        today: today,
        countedTypeIds: {'p'},
        dutyTypeIds: const {},
      );
      expect(r.total, 4);
      expect(r.attended, 2);
      expect(r.percent, 50);
    });

    test('duty Termine only where assigned; empty → no percent', () {
      final r = computeRate(
        [row(2, AttendanceStatus.present, type: 'd'), row(3, AttendanceStatus.present, type: 'd', duty: 'assigned')],
        range: (from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 11)),
        today: today,
        countedTypeIds: {'d'},
        dutyTypeIds: {'d'},
      );
      expect(r.total, 1);
      expect(computeRate(const [], range: (from: today, to: today), today: today, countedTypeIds: const {}, dutyTypeIds: const {}).percent,
          isNull);
    });
  });

  test('birthdays in a range, across the year end and on 29.2.', () {
    final dec = (from: DateTime(2026, 12, 20), to: DateTime(2027, 1, 10));
    expect(birthdayIn('2008-01-03', dec), DateTime(2027, 1, 3));
    expect(birthdayIn('2008-06-03', dec), isNull);
    expect(birthdayIn('2008-02-29', (from: DateTime(2027, 2, 1), to: DateTime(2027, 2, 28))), DateTime(2027, 2, 28));
    expect(ageOn('2008-01-03', DateTime(2027, 1, 3)), 19);
    expect(birthdayIn(null, dec), isNull);
  });

  group('AssistantAccess', () {
    const rate = AttendanceRateCommand(subject: PersonSubject('Jonas'), period: SeasonPeriod());
    const own = AttendanceRateCommand(subject: MeSubject(), period: SeasonPeriod());
    const who = EventOverviewCommand(event: NextEventRef());
    const next = NextEventCommand();

    test('members ask about themselves, not about others', () {
      const a = AssistantAccess(role: Role.player, hasOwnPerson: true);
      expect(a.allows(own), isTrue);
      expect(a.allows(next), isTrue);
      expect(a.allows(rate), isFalse);
      expect(a.allows(who), isFalse);
      expect(a.allows(const BirthdaysCommand(ThisPeriod(PeriodUnit.month))), isFalse);
    });

    test('leaders and helpers see others', () {
      for (final role in [Role.admin, Role.responsible, Role.viewer, Role.helper, Role.voiceLeaderHelper]) {
        final a = AssistantAccess(role: role, hasOwnPerson: false);
        expect(a.allows(rate), isTrue, reason: '$role');
        expect(a.allows(who), isTrue, reason: '$role');
        expect(a.allows(own), isFalse, reason: 'no own person');
      }
    });

    test('applicants and unknown roles get nothing', () {
      for (final role in [Role.applicant, Role.none]) {
        final a = AssistantAccess(role: role, hasOwnPerson: true);
        expect(a.allows(next), isFalse);
        expect(a.allows(const HelpCommand('abmelden')), isFalse);
      }
    });
  });

  group('package 2 limits and rights', () {
    test('past weekday and yesterday', () {
      expect(resolveEventDay(const PastWeekdayEventRef(AssistantWeekday.sun), today), DateTime(2026, 11, 8));
      expect(resolveEventDay(const PastWeekdayEventRef(AssistantWeekday.wed), today), DateTime(2026, 11, 4));
      expect(resolveEventDay(const YesterdayEventRef(), today), DateTime(2026, 11, 10));
    });

    test('members only sign in, sign out or report being late', () {
      expect(targetStatus(AssistantStatus.late, self: true), AttendanceStatus.lateExcused);
      expect(targetStatus(AssistantStatus.absent, self: true), isNull);
      expect(targetStatus(AssistantStatus.neutral, self: true), isNull);
      expect(targetStatus(AssistantStatus.absent, self: false), AttendanceStatus.absent);
    });

    test('change window: 14 days back, 6 months ahead', () {
      expect(inChangeWindow(DateTime(2026, 10, 28), today), isTrue);
      expect(inChangeWindow(DateTime(2026, 10, 27), today), isFalse);
      expect(inChangeWindow(DateTime(2027, 5, 13), today), isTrue);
      expect(inChangeWindow(DateTime(2027, 5, 14), today), isFalse);
    });

    test('own rows follow the buttons of Meine Termine', () {
      StatusSkip? skip(AttendanceStatus current, AttendanceStatus target,
              {bool open = true, bool fields = false, bool allows = true}) =>
          selfStatusSkip(
            current: current,
            target: target,
            signinOpen: open,
            hasRegistrationFields: fields,
            typeAllowsTarget: allows,
          );
      expect(skip(AttendanceStatus.neutral, AttendanceStatus.excused), isNull);
      expect(skip(AttendanceStatus.excused, AttendanceStatus.excused), StatusSkip.same);
      expect(skip(AttendanceStatus.absent, AttendanceStatus.excused), StatusSkip.locked);
      expect(skip(AttendanceStatus.excused, AttendanceStatus.lateExcused), StatusSkip.locked);
      expect(skip(AttendanceStatus.neutral, AttendanceStatus.excused, allows: false), StatusSkip.locked);
      expect(skip(AttendanceStatus.excused, AttendanceStatus.present), isNull);
      expect(skip(AttendanceStatus.neutral, AttendanceStatus.present, open: false), StatusSkip.locked);
      expect(skip(AttendanceStatus.neutral, AttendanceStatus.present, fields: true), StatusSkip.locked);
    });

    test('absence from today up to 6 months', () {
      expect(absenceInWindow(DateTime(2026, 11, 11), DateTime(2027, 1, 31), today), isTrue);
      expect(absenceInWindow(DateTime(2026, 11, 10), DateTime(2026, 11, 20), today), isFalse);
      expect(absenceInWindow(DateTime(2026, 11, 12), DateTime(2027, 6, 1), today), isFalse);
    });

    test('rights per role', () {
      final me = SetStatusCommand(who: const [MeSubject()], status: AssistantStatus.excused, event: const NextEventRef());
      final jonas = SetStatusCommand(who: const [PersonSubject('Jonas')], status: AssistantStatus.excused, event: const NextEventRef());
      final ownAbsence = PlannedAbsenceCommand(who: const MeSubject(), from: DateTime(2026, 12, 1), to: DateTime(2026, 12, 5));
      final otherAbsence = PlannedAbsenceCommand(who: const PersonSubject('Lena'), from: DateTime(2026, 12, 1), to: DateTime(2026, 12, 5));

      const player = AssistantAccess(role: Role.player, hasOwnPerson: true);
      expect(player.allows(me), isTrue);
      expect(player.allows(jonas), isFalse);
      expect(player.allows(ownAbsence), isFalse);
      const playerMayReport = AssistantAccess(role: Role.player, hasOwnPerson: true, canSelfReportAbsence: true);
      expect(playerMayReport.allows(ownAbsence), isTrue);
      expect(playerMayReport.allows(otherAbsence), isFalse);

      const viewer = AssistantAccess(role: Role.viewer, hasOwnPerson: false);
      expect(viewer.allows(jonas), isFalse);
      // Own sign-out works across groups (rows are checked by account).
      expect(viewer.allows(me), isTrue);

      for (final role in [Role.admin, Role.responsible, Role.helper, Role.voiceLeaderHelper]) {
        final a = AssistantAccess(role: role, hasOwnPerson: false, canManageAbsences: role == Role.admin);
        expect(a.allows(jonas), isTrue, reason: role.name);
        expect(a.allows(otherAbsence), role == Role.admin, reason: role.name);
      }
      const applicant = AssistantAccess(role: Role.applicant, hasOwnPerson: true, canSelfReportAbsence: true);
      expect(applicant.allows(me), isFalse);
      expect(applicant.allows(ownAbsence), isFalse);
    });
  });

  group('package 3 limits and rights', () {
    const create = CreateEventsCommand(dates: []);
    const move = MoveEventCommand(event: NextEventRef(), startTime: '10:00');
    const songs = SetSongsCommand(event: NextEventRef(), titles: ['A']);
    const cancel = CancelEventCommand(event: NextEventRef(), reason: 'Saal');

    test('creating needs the confirmed create permission', () {
      expect(const AssistantAccess(role: Role.admin, hasOwnPerson: true).allows(create), isFalse);
      expect(const AssistantAccess(role: Role.helper, hasOwnPerson: true, canCreateEvents: true).allows(create), isTrue);
    });

    test('moving and Werke: roles that edit Termine; cancel: roles that record attendance', () {
      for (final role in [Role.admin, Role.responsible, Role.helper, Role.voiceLeaderHelper]) {
        final a = AssistantAccess(role: role, hasOwnPerson: false);
        expect(a.allows(move), isTrue, reason: '$role');
        expect(a.allows(songs), isTrue, reason: '$role');
      }
      for (final role in [Role.viewer, Role.player, Role.voiceLeader, Role.parent]) {
        final a = AssistantAccess(role: role, hasOwnPerson: true);
        expect(a.allows(move), isFalse, reason: '$role');
        expect(a.allows(songs), isFalse, reason: '$role');
        expect(a.allows(cancel), isFalse, reason: '$role');
      }
      expect(const AssistantAccess(role: Role.admin, hasOwnPerson: false).allows(cancel), isTrue);
    });

    test('future window and moved end time', () {
      expect(inFutureWindow(DateTime(2026, 11, 11), today), isTrue);
      expect(inFutureWindow(DateTime(2026, 11, 10), today), isFalse);
      expect(inFutureWindow(DateTime(2027, 5, 13), today), isTrue);
      expect(inFutureWindow(DateTime(2027, 5, 14), today), isFalse);
      expect(shiftedEndTime('19:00', '21:00', '20:00'), '22:00');
      expect(shiftedEndTime('22:00', '23:30', '23:00'), '00:30');
      expect(shiftedEndTime('19:00', null, '20:00'), isNull);
    });
  });
}
