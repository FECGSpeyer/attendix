import 'package:attendix/core/constants/enums.dart' show AttendanceStatus;
import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/data/models/user_notification/user_notification.dart';
import 'package:attendix/features/messages/presentation/bell_logic.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

UserNotification _n(String id, {String type = 'attendance', int? att, int tenant = 1, String body = ''}) =>
    UserNotification(
      id: id,
      tenantId: tenant,
      type: type,
      body: body,
      data: {if (att != null) 'attendanceId': '$att'},
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('de'));
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('parseBellAttendanceBody', () {
    test('late with reason', () {
      final line = parseBellAttendanceBody('Jolina Goas kommt am 10.11.2026 zu spät. Grund: Verkehr')!;
      expect(bellLineTitle(l10n, line), 'Jolina Goas kommt zu spät');
      expect(bellLineDetail(l10n, line), 'Verkehr');
      expect(line.date, DateTime(2026, 11, 10));
      expect(line.eventInfo, isNull);
    });

    test('sign-out with event name, by parents', () {
      final line = parseBellAttendanceBody(
        'Tina Betz hat sich für den 29.11.2026 Vortrag mit EV Gruppe in SP abgemeldet. Grund: Familienbedingt\n(von Elternteil abgemeldet)',
      )!;
      expect(bellLineTitle(l10n, line), 'Tina Betz ist abgemeldet');
      expect(line.eventInfo, 'Vortrag mit EV Gruppe in SP');
      expect(bellLineDetail(l10n, line), 'Familienbedingt · von den Eltern gemeldet');
    });

    test('lecture marker, sign-in, note, unknown text', () {
      expect(parseBellAttendanceBody('Max hat sich für den 01.12.2026 (Vortrag) angemeldet.')!.eventInfo, 'Vortrag');
      expect(parseBellAttendanceBody('Max hat die Notiz für den 01.12.2026 angepasst: später')!.detail, 'später');
      expect(parseBellAttendanceBody('Neue Mitteilung: Probe fällt aus'), isNull);
      expect(parseBellAttendanceBody('Max signed out for 12/01/2026.'), isNull);
    });
  });

  test('groupBellEntries: one block per Termin at its newest entry', () {
    final items = groupBellEntries([
      _n('a', att: 5),
      _n('m', type: 'message'),
      _n('b', att: 5),
      _n('c', att: 5, tenant: 2),
      _n('r', type: 'reminder', att: 5),
    ]);
    expect(items, hasLength(4));
    expect((items[0] as BellEventGroup).entries.map((e) => e.id), ['a', 'b']);
    expect((items[1] as BellSingle).notification.id, 'm');
    expect((items[2] as BellEventGroup).tenantId, 2);
    expect(items[3], isA<BellSingle>()); // reminders stay single
  });

  test('relative times and event days', () {
    final now = DateTime(2026, 11, 10, 18);
    expect(bellRelativeTime(l10n, DateTime(2026, 11, 10, 17, 44), now: now, locale: 'de_DE'), '17:44');
    expect(bellRelativeTime(l10n, DateTime(2026, 11, 9, 9), now: now, locale: 'de_DE'), 'Gestern');
    expect(bellRelativeTime(l10n, DateTime(2026, 11, 3, 9), now: now, locale: 'de_DE'), '3.11.');
    expect(bellEventDay(l10n, DateTime(2026, 11, 10), now: now), 'Heute');
    expect(bellEventDay(l10n, DateTime(2026, 11, 11), now: now), 'Morgen');
  });

  test('a personal reminder to answer is done once the person has answered', () {
    UserNotification reminder(String id, String body, {String title = '🔔 Erinnerung: Probe'}) =>
        UserNotification(id: id, tenantId: 1, type: 'reminder', title: title, body: body, data: const {'attendanceId': '7'});
    final list = [
      reminder('ask', 'Hallo Tim,\nfür „Probe“ fehlt noch deine Antwort.'),
      // The automatic "startet in 2 Stunden" and the classic reminder stay as they are.
      reminder('auto', 'Hallo Tim, Probe startet in 2 Stunden', title: '⏰ Terminerinnerung'),
      reminder('classic', 'Chor\nProbe am 20.11.2026'),
      _n('other', type: 'attendance', att: 7, body: 'Hallo Tim, x'),
    ];
    expect(bellAnsweredReminders(list, (_, _) => null), isEmpty);
    expect(bellAnsweredReminders(list, (tenant, att) => tenant == 1 && att == 7 ? true : null), {'ask': true});
    expect(bellOwnAnswer(AttendanceStatus.neutral), isNull);
    expect(bellOwnAnswer(AttendanceStatus.lateExcused), isTrue);
    expect(bellOwnAnswer(AttendanceStatus.excused), isFalse);
  });

  test('bellEventLabelsKey is sorted per tenant', () {
    expect(bellEventLabelsKey([(2, 9), (1, 7), (1, 3), (2, 9)]), '1:3,7;2:9');
  });
}
