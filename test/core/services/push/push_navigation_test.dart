import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/services/push/push_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

/// PUSH: Ionic PushService.navigateFromData / navigateToAttendance.
void main() {
  group('resolvePushTarget', () {
    test('message opens the Mitteilung and marks nothing itself', () {
      final t = resolvePushTarget(
          {'type': 'message', 'messageId': 'abc', 'tenantId': '3'}, Role.player);
      expect(t.location, '/messages/abc');
      expect(t.markReadType, isNull);
    });

    test('explicit route is translated from the Ionic URL', () {
      final t = resolvePushTarget(
          {'type': 'criticals', 'route': '/tabs/list?tenantId=4'}, Role.admin);
      expect(t.location, '/attendance?tenantId=4');
      expect(t.markReadType, 'criticals');
    });

    test('task with and without id', () {
      expect(resolvePushTarget({'type': 'task', 'taskId': '12'}, Role.admin).location,
          '/settings/tasks/12');
      final list = Uri.parse(
          resolvePushTarget({'type': 'task'}, Role.admin).location!);
      expect(list.path, '/settings/team-organization');
      expect(list.queryParameters['tab'], 'tasks');
    });

    test('protocol with and without attendance', () {
      final t = resolvePushTarget(
          {'type': 'protocol', 'attendanceId': '7'}, Role.responsible);
      expect(t.location, '/settings/protocol/7');
      expect(t.markReadType, 'protocol');
      expect(t.markReadAttendanceId, '7');
      final list =
          Uri.parse(resolvePushTarget({'type': 'protocol'}, Role.admin).location!);
      expect(list.queryParameters['tab'], 'protocols');
    });

    test('proposal opens the topics tab', () {
      final uri = Uri.parse(
          resolvePushTarget({'type': 'proposal'}, Role.admin).location!);
      expect(uri.path, '/settings/team-organization');
      expect(uri.queryParameters['tab'], 'topics');
    });

    test('attendance types: conductors/helpers open the Termin detail', () {
      for (final role in [
        Role.admin,
        Role.responsible,
        Role.helper,
        Role.voiceLeaderHelper,
      ]) {
        for (final type in kAttendancePushTypes) {
          final t = resolvePushTarget({'type': type, 'attendanceId': '42'}, role);
          expect(t.location, '/attendance/42', reason: '$role $type');
          expect(t.pendingAttendanceId, isNull);
          expect(t.markReadType, type);
          expect(t.markReadAttendanceId, '42');
        }
      }
    });

    test('attendance types: parents → portal, others → Meine Termine', () {
      final parent = resolvePushTarget(
          {'type': 'reminder', 'attendanceId': 5}, Role.parent);
      expect(parent.location, '/parents');
      expect(parent.pendingAttendanceId, 5);

      for (final role in [Role.player, Role.viewer, Role.voiceLeader]) {
        final t = resolvePushTarget({'type': 'duty', 'attendanceId': '5'}, role);
        expect(t.location, '/signout', reason: '$role');
        expect(t.pendingAttendanceId, 5);
      }
    });

    test('attendance type without id opens the list', () {
      expect(resolvePushTarget({'type': 'checklist'}, Role.admin).location,
          '/attendance');
    });

    test('birthday only navigates for admin/responsible/viewer', () {
      expect(resolvePushTarget({'type': 'birthday'}, Role.viewer).location,
          '/people');
      final player = resolvePushTarget({'type': 'birthday'}, Role.player);
      expect(player.location, isNull);
      expect(player.markReadType, 'birthday');
    });

    test('criticals and unknown types open the people list', () {
      expect(resolvePushTarget({'type': 'criticals'}, Role.admin).location,
          '/people');
      expect(resolvePushTarget({'type': 'whatever'}, Role.admin).location,
          '/people');
      final noType = resolvePushTarget({}, Role.admin);
      expect(noType.location, '/people');
      expect(noType.markReadType, isNull);
    });
  });

  test('live_plan pushes are silent', () {
    expect(isSilentPush({'type': 'live_plan'}), isTrue);
    expect(isSilentPush({'type': 'attendance'}), isFalse);
  });

  test('pushTenantId parses string and int ids', () {
    expect(pushTenantId({'tenantId': '9'}), 9);
    expect(pushTenantId({'tenantId': 9}), 9);
    expect(pushTenantId({}), isNull);
  });
}
