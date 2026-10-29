// PUSH: where a tapped push leads (Ionic PushService.navigateFromData /
// navigateToAttendance). Pure functions, unit tested.

import 'package:flutter/foundation.dart';

import '../../constants/enums.dart';
import '../../router/legacy_routes.dart';

/// Push types that open a Termin (Ionic navigateFromData switch).
const Set<String> kAttendancePushTypes = {
  'attendance',
  'reminder',
  'checklist',
  'duty',
  'duty_reminder',
  'duty_understaffed',
  'duty_urgent',
  'duty_filled',
};

/// Resolved navigation of a push tap.
@immutable
class PushTarget {
  const PushTarget({
    this.location,
    this.pendingAttendanceId,
    this.markReadType,
    this.markReadAttendanceId,
  });

  /// Flutter location to open; `null` = stay where you are.
  final String? location;

  /// Termin the destination page (Meine Termine / Elternportal) opens in its
  /// action sheet (Ionic `pendingAttendanceId`).
  final int? pendingAttendanceId;

  /// Mark matching notification-center entries read (Ionic
  /// `markMatchingNotificationsRead(type, attendanceId)`); `null` = don't.
  final String? markReadType;
  final String? markReadAttendanceId;

  @override
  String toString() =>
      'PushTarget($location, pending: $pendingAttendanceId, read: $markReadType/$markReadAttendanceId)';
}

/// Live plan updates are silent data pushes handled natively, never an alert.
bool isSilentPush(Map<String, dynamic> data) => data['type'] == 'live_plan';

/// The tenant a push belongs to (`data.tenantId`), if any.
int? pushTenantId(Map<String, dynamic> data) =>
    int.tryParse('${data['tenantId'] ?? ''}');

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

/// Ionic URL (`/tabs/...`) → Flutter location (query params are kept).
String flutterLocationForIonicUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return legacyRouteRedirect(uri) ?? url;
}

/// Ionic navigateToAttendance: conductors/helpers open the Termin detail,
/// parents their portal, everybody else "Meine Termine" – both of the latter
/// open the Termin via the pending attendance id.
PushTarget attendancePushTarget(int attendanceId, Role role,
    {String? markReadType, String? markReadAttendanceId}) {
  if (role.canAddAttendance) {
    return PushTarget(
      location: '/attendance/$attendanceId',
      markReadType: markReadType,
      markReadAttendanceId: markReadAttendanceId,
    );
  }
  return PushTarget(
    location: role.isParent ? '/parents' : '/signout',
    pendingAttendanceId: attendanceId,
    markReadType: markReadType,
    markReadAttendanceId: markReadAttendanceId,
  );
}

/// Ionic PushService.navigateFromData (after the tenant switch).
PushTarget resolvePushTarget(Map<String, dynamic> data, Role role) {
  final type = _str(data['type']);

  // Mitteilungen: the message page marks the message read itself.
  final messageId = _str(data['messageId']);
  if (type == 'message' && messageId != null) {
    return PushTarget(location: '/messages/$messageId');
  }

  // Opening a push marks the matching feed entries read (best-effort).
  final readType = type;
  final readAttendanceId = type == null ? null : _str(data['attendanceId']);

  PushTarget go(String? ionicUrl) => PushTarget(
        location: ionicUrl == null ? null : flutterLocationForIonicUrl(ionicUrl),
        markReadType: readType,
        markReadAttendanceId: readAttendanceId,
      );

  final route = _str(data['route']);
  if (route != null) return go(route);

  switch (type) {
    case 'task':
      final taskId = _str(data['taskId']);
      return go(taskId != null
          ? '/tabs/settings/tasks/$taskId'
          : '/tabs/settings/team-organization?tab=tasks');
    case 'protocol':
      final attId = _str(data['attendanceId']);
      return go(attId != null
          ? '/tabs/attendance/$attId/protocol'
          : '/tabs/settings/team-organization?tab=protocols');
    case 'proposal':
      return go('/tabs/settings/team-organization?tab=topics');
    case 'birthday':
      // Only roles with the people list navigate; others just see the push.
      if (role.isAdmin || role.isResponsible || role.isViewer) {
        return go('/tabs/player');
      }
      return go(null);
    case 'criticals':
      return go('/tabs/player');
  }

  if (type != null && kAttendancePushTypes.contains(type)) {
    final attendanceId = int.tryParse('${data['attendanceId'] ?? ''}');
    if (attendanceId != null) {
      return attendancePushTarget(attendanceId, role,
          markReadType: readType, markReadAttendanceId: readAttendanceId);
    }
    return go('/tabs/attendance');
  }

  return go('/tabs/player');
}
