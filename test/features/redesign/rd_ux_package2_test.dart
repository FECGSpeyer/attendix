import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/parents/data/providers/parents_providers.dart';
import 'package:attendix/features/redesign/data/providers/rd_today_providers.dart';
import 'package:attendix/features/redesign/presentation/widgets/join/rd_join_sheet.dart';
import 'package:attendix/features/redesign/presentation/widgets/members/rd_invite_sheet.dart';
import 'package:attendix/features/redesign/presentation/widgets/today/rd_parent_today.dart';
import 'package:attendix/features/redesign/presentation/widgets/today/rd_remind_open_sheet.dart';
import 'package:attendix/l10n/generated/app_localizations_de.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

/// REDESIGN: logic of the UX package 2 (E1 parents, D1 invite, D2 open
/// answers, B1/N1 join).
void main() {
  final l10n = AppLocalizationsDe();

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('de');
  });

  group('B1/N1: invitation link', () {
    const id = '7f3c2a10-9b1e-4c55-a0d2-1e2f3a4b5c6d';

    test('the id comes from a pasted link, with or without https', () {
      expect(rdRegisterIdFromLink('https://attendix.de/register/$id'), id);
      expect(rdRegisterIdFromLink('  attendix.de/register/$id?x=1 '), id);
      expect(rdRegisterIdFromLink('Melde dich an:\nhttps://attendix.de/register/$id'), id);
      expect(rdRegisterIdFromLink(id), id);
    });

    test('anything else is no invitation', () {
      expect(rdRegisterIdFromLink(''), isNull);
      expect(rdRegisterIdFromLink('hallo'), isNull);
      expect(rdRegisterIdFromLink('https://attendix.de/register/'), isNull);
    });
  });

  group('D1: invite link', () {
    test('only while registration is on', () {
      expect(rdInviteLink(TestFactories.createTenant().copyWith(registerId: 'abc')), 'https://attendix.de/register/abc');
      expect(rdInviteLink(TestFactories.createTenant().copyWith(registerId: '')), isNull);
      expect(rdInviteLink(TestFactories.createTenant()), isNull);
      expect(rdInviteLink(null), isNull);
    });
  });

  group('D2: open answers', () {
    final tim = TestFactories.createPerson(id: 1, firstName: 'Tim', lastName: 'Maurer', appId: 'a1')
        .copyWith(groupName: 'Trompete');
    final eva = TestFactories.createPerson(id: 2, firstName: 'Eva', lastName: 'Krämer').copyWith(groupName: 'Posaune');
    final jo = TestFactories.createPerson(id: 3, firstName: 'Jo', lastName: 'Bauer').copyWith(groupName: 'Posaune');

    test('only members still without a status, by register and name', () {
      const rows = [
        PersonAttendance(personId: 1, status: AttendanceStatus.neutral),
        PersonAttendance(personId: 2, status: AttendanceStatus.neutral),
        PersonAttendance(personId: 3, status: AttendanceStatus.present),
        PersonAttendance(personId: 9, status: AttendanceStatus.neutral), // not a member (any more)
      ];
      expect(rdOpenPersons(rows, [tim, eva, jo]).map((p) => p.id), [2, 1]);
    });

    test('duty Termin: stand-ins without a duty state are not reminded', () {
      const rows = [
        PersonAttendance(personId: 1, status: AttendanceStatus.neutral, dutyState: 'requested'),
        PersonAttendance(personId: 2, status: AttendanceStatus.neutral),
      ];
      expect(rdOpenPersons(rows, [tim, eva], duty: true).map((p) => p.id), [1]);
      expect(rdOpenPersons(rows, [tim, eva]).map((p) => p.id), [2, 1]);
    });

    test('each push starts with the first name', () {
      expect(rdRemindMessage(l10n, tim, ' Bitte antworten. '), 'Hallo Tim,\nBitte antworten.');
      expect(rdRemindMessage(l10n, tim.copyWith(firstName: ''), 'Bitte antworten.'), 'Bitte antworten.');
    });

    test('date of the Termin in the text', () {
      expect(rdRemindWhen(DateTime(2026, 11, 2, 10), hasTime: true), 'Mo 2.11., 10:00');
      expect(rdRemindWhen(DateTime(2026, 11, 2), hasTime: false), 'Mo 2.11.');
      expect(rdRemindWhen(null, hasTime: true), '');
    });
  });

  group('E1: children of a Termin', () {
    ParentAttendanceGroup group(List<AttendanceStatus> statuses) => ParentAttendanceGroup(
          attendanceId: 1,
          startTime: '16:30',
          endTime: '17:30',
          childAttendances: [
            for (final (i, s) in statuses.indexed)
              ChildPersonAttendance(
                id: 'pa$i',
                childId: i,
                childName: ['Mia W', 'Ben W'][i],
                childFirstName: ['Mia', 'Ben'][i],
                status: s,
              ),
          ],
        );

    test('"Mia ✓ · Ben offen" with several children, else the time', () {
      expect(rdChildrenLine(l10n, group([AttendanceStatus.present, AttendanceStatus.neutral])), 'Mia ✓ · Ben offen');
      expect(rdChildrenLine(l10n, group([AttendanceStatus.excused, AttendanceStatus.present])), 'Mia ✕ · Ben ✓');
      expect(rdChildrenLine(l10n, group([AttendanceStatus.neutral])), contains('16:30'));
    });

    test('counts children without an answer', () {
      expect(rdOpenChildren(group([AttendanceStatus.present, AttendanceStatus.neutral])), 1);
      expect(rdOpenChildren(group([AttendanceStatus.present, AttendanceStatus.excused])), 0);
    });
  });
}
