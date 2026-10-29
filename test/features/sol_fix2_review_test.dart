import 'dart:io';

import 'package:attendix/core/utils/duty_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// SOL_FIX2: external review findings PR #225 (protocol publish, planning
/// fallback, duty same-day lock). Items 1–4 are covered in
/// plan_repository_test, role_permission_providers_test, leftovers_test and
/// offline_queue_service_test.
void main() {
  group('Dienste verteilen: "Nicht zweimal am selben Tag"', () {
    const fullyStaffed = DutySlot(
      attendanceId: 1,
      date: '2026-05-10T09:00:00',
      candidates: [],
      occupied: [7],
      open: 0,
    );
    const sameDayOpen = DutySlot(
      attendanceId: 2,
      date: '2026-05-10T18:00:00',
      candidates: [7, 8],
      occupied: [],
      open: 2,
    );

    test('people of a fully staffed duty are not assigned again that day', () {
      final result = distributeDuties(
        [fullyStaffed, sameDayOpen],
        const {},
        maxPerPerson: 5,
        notTwiceSameDay: true,
      );
      expect(result[2], [8]);
      expect(result.containsKey(1), isFalse, reason: 'open: 0 is never filled');
    });

    test('without the option the person may be picked', () {
      final result = distributeDuties(
        [fullyStaffed, sameDayOpen],
        const {},
        maxPerPerson: 5,
        notTwiceSameDay: false,
      );
      expect(result[2]!.toSet(), {7, 8});
    });

    test('page keeps fully staffed and other-type duties in the computation', () {
      final src = File('lib/features/duty/presentation/pages/duty_distribute_page.dart').readAsStringSync();
      expect(src, isNot(contains('t.occupied < t.required')));
      expect(src, contains('open: max(0, t.required - t.occupied)'));
      expect(src, contains('repo.getUpcomingDutyTermine(dutyTypes'));
      expect(src, contains('_otherTermine.where'));
    });
  });

  group('Protokoll veröffentlichen', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/team_organization/presentation/pages/protocol_page.dart').readAsStringSync();
    });

    String body(String signature) {
      final start = src.indexOf(signature);
      expect(start, greaterThanOrEqualTo(0), reason: signature);
      final next = src.indexOf(RegExp(r'\n  (Future<|void |bool |Widget |String )'), start + signature.length);
      return src.substring(start, next < 0 ? src.length : next);
    }

    test('_flushAll awaits in-flight saves and reports failures', () {
      final flushAll = body('Future<bool> _flushAll()');
      expect(flushAll, contains('_inFlight.values'));
      expect(flushAll, contains('results.every((ok) => ok)'));
      expect(body('Future<bool> _saveSectionNow(').contains('return false;'), isTrue);
    });

    test('publish aborts before publishing/notifying when a save failed', () {
      final publish = body('Future<void> _publish(');
      final guard = publish.indexOf('if (!await _flushAll())');
      final publishCall = publish.indexOf('_repo.publish(');
      final notify = publish.indexOf('_repo.notifyTeam(');
      expect(guard, greaterThan(0));
      expect(publishCall, greaterThan(guard));
      expect(notify, greaterThan(guard));
      expect(publish.substring(guard, publishCall), contains('return;'));
      expect(publish.substring(guard, publishCall), contains('protocolNotesSaveFailed'));
    });

    test('opening the publish sheet also requires a complete save', () {
      expect(body('Future<void> _openPublish()'), contains('if (!await _flushAll())'));
    });
  });

  group('Ablaufplan: angeforderter Termin', () {
    test('loads the requested Termin by id and never falls back', () {
      final src = File('lib/features/planning/presentation/pages/planning_page.dart').readAsStringSync();
      final start = src.indexOf('Future<void> _init(');
      final init = src.substring(start, src.indexOf('/// Ionic `Utils.getPlanningTitle`', start));
      expect(init, contains('_loadRequestedAttendance(requestedId)'));
      expect(init, contains('_requestedNotFound = true'));
      // the requested branch returns before the "first upcoming" fallback
      final requested = init.indexOf('if (requestedId != null)');
      final fallback = init.indexOf('upcoming.isNotEmpty');
      expect(init.substring(requested, fallback), contains('return;'));
      expect(src, contains('repo.getPlanAttendanceById(id)'));
    });

    test('getPlanAttendanceById is tenant filtered', () {
      final repo = File('lib/data/repositories/plan_repository.dart').readAsStringSync();
      final start = repo.indexOf('Future<PlanAttendance?> getPlanAttendanceById(');
      final method = repo.substring(start, repo.indexOf('handleError', start));
      expect(method, contains(".eq('id', id)"));
      expect(method, contains(".eq('tenantId', currentTenantId)"));
    });
  });
}
