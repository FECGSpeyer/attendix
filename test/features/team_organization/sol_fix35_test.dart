import 'dart:io';

import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('SOL_FIX35 calendar day shift', () {
    test('counts calendar days, not 24h blocks', () {
      expect(calendarDayDifference(DateTime(2026, 3, 29, 12), DateTime(2026, 3, 30, 12)), 1);
      expect(calendarDayDifference(DateTime(2026, 3, 29, 23, 30), DateTime(2026, 3, 30, 0, 30)), 1);
      expect(calendarDayDifference(DateTime(2026, 10, 25, 12), DateTime(2026, 10, 24, 12)), -1);
      expect(calendarDayDifference(DateTime(2026, 6, 1), DateTime(2026, 6, 1, 23)), 0);
    });

    test('shift keeps the local wall time and the UTC flag', () {
      final local = DateTime(2026, 3, 28, 18, 0);
      final moved = shiftByCalendarDays(local, 2);
      expect([moved.year, moved.month, moved.day, moved.hour, moved.minute], [2026, 3, 30, 18, 0]);
      expect(moved.isUtc, isFalse);

      final utc = DateTime(2026, 3, 28, 18, 0).toUtc();
      final movedUtc = shiftByCalendarDays(utc, 2);
      expect(movedUtc.isUtc, isTrue);
      final back = movedUtc.toLocal();
      expect([back.day, back.hour, back.minute], [30, 18, 0]);
    });
  });

  group('SOL_FIX35 source checks', () {
    test('spontaneous topic uses the bound repository and aborts on a missing Termin', () {
      final s = _src('lib/features/team_organization/presentation/pages/protocol_page.dart');
      final start = s.indexOf('Future<void> _addSpontaneousTopic()');
      final body = s.substring(start, s.indexOf('// ── Display helpers', start));
      expect(body, contains('_agendaRepo.createAgendaItem('));
      expect(body, isNot(contains('agendaItemNotifierProvider')));
      expect(body.indexOf("throw StateError('attendance"), lessThan(body.indexOf('_agendaRepo.createAgendaItem(')));
      expect(body, isNot(contains('} catch (_) {}')));
    });

    test('removing a topic refreshes plan and organisation caches', () {
      final s = _src('lib/features/team_organization/presentation/widgets/topics_tab.dart');
      final start = s.indexOf("action == 'remove'");
      final block = s.substring(start, s.indexOf('Future<void> _accept', start));
      expect(block.indexOf('ProviderScope.containerOf'), lessThan(block.indexOf('await addTopicsToAttendance')));
      for (final p in ['upcomingProtocolAttendancesProvider', 'planAttendancesProvider', 'orgPlansProvider']) {
        expect(block, contains('container.invalidate($p)'));
      }
    });

    test('duty and sign-out mutations refresh each other', () {
      final duty = _src('lib/core/providers/duty_providers.dart');
      final dutyInv = duty.substring(duty.indexOf('void _invalidate('), duty.indexOf('Future<bool> _run('));
      expect(dutyInv, contains('ref.invalidate(signoutDataProvider)'));
      final signout = _src('lib/core/providers/signout_providers.dart');
      final refresh = signout.substring(signout.indexOf('void _refresh()'), signout.indexOf('Future<bool> _run('));
      for (final p in ['upcomingDutyTermineProvider', 'dutyTermineByIdProvider', 'myDutyOverviewProvider']) {
        expect(refresh, contains('ref.invalidate($p)'));
      }
    });

    test('duty confirmation via Zusagen reports its own result only', () {
      final s = _src('lib/features/self_service/presentation/pages/signout_page.dart');
      final i = s.indexOf('await confirmDutyAction(');
      expect(s.substring(i, i + 120), contains('return null;'));
      expect(_src('lib/features/duty/presentation/widgets/duty_actions.dart'), contains('Future<bool> confirmDutyAction('));
    });
  });
}
