/// Defaults for a newly created tenant (Ionic register.page / db.service
/// createInstance / Utils.getDefaultAttendanceTypes).
library;

import '../../core/constants/enums.dart';
import '../../l10n/l10n.dart';

/// Fallback IANA timezone. The tenant creation uses the device zone
/// (Ionic `Intl.DateTimeFormat().resolvedOptions().timeZone`, see
/// `deviceTimezone()`); native platforms without it fall back to this.
const String defaultTenantTimezone = 'Europe/Berlin';

/// Ionic `SUPER_DEVELOPER_EMAIL`.
const String _superDeveloperEmail = 'developer@attendix.de';

/// Auth user id of the super developer (Ionic db.service createInstance).
const String superDeveloperUserId = '665fe2b4-d53f-4f17-a66b-46c0949af99a';

/// `tenantUsers` rows of a new tenant (Ionic createInstance `usersToAdd`):
/// the super developer is always added as ADMIN; the creator is added as
/// ADMIN too unless the creator is the super developer.
List<Map<String, dynamic>> buildNewTenantUsers({
  required int tenantId,
  required String userId,
  required String? email,
}) {
  return [
    {
      'userId': superDeveloperUserId,
      'role': Role.admin.value,
      'tenantId': tenantId,
      'email': _superDeveloperEmail,
    },
    if (email != _superDeveloperEmail)
      {
        'userId': userId,
        'role': Role.admin.value,
        'tenantId': tenantId,
        'email': email,
      },
  ];
}

/// Insert payload for `tenants` with the Ionic register defaults.
Map<String, dynamic> buildNewTenantPayload({
  required String shortName,
  required String longName,
  required String type,
  String timezone = defaultTenantTimezone,
}) {
  return {
    'shortName': shortName,
    'longName': longName,
    'type': type,
    'maintainTeachers': false,
    'withExcuses': true,
    'betaProgram': true,
    'showHolidays': false,
    'timezone': timezone,
  };
}

/// Insert payload for the main group (Ionic group.service addGroup with
/// `maingroup = true`). No `isSection` flag: the main group is not a section.
Map<String, dynamic> buildMainGroupPayload({
  required int tenantId,
  required String name,
}) {
  return {
    'name': name,
    'tuning': 'C',
    'clefs': ['g'],
    'tenantId': tenantId,
    'maingroup': true,
  };
}

/// Default attendance types for a new tenant (Ionic
/// Utils.getDefaultAttendanceTypes). Labels from de.json `defaults.types`.
List<Map<String, dynamic>> buildDefaultAttendanceTypes({
  required int tenantId,
  required String type,
}) {
  // Ionic translates the default type names in the active language.
  final l10n = l10nWithoutContext;
  final isGeneral = type == 'general';
  final p = AttendanceStatus.present.value;
  final e = AttendanceStatus.excused.value;
  final l = AttendanceStatus.late.value;
  final a = AttendanceStatus.absent.value;
  final n = AttendanceStatus.neutral.value;

  Map<String, dynamic> typeRow({
    required String name,
    required String planningTitle,
    required String color,
    required List<int> statuses,
    required int defaultStatus,
    required bool hideName,
    required bool highlight,
    required bool manageSongs,
  }) =>
      {
        'name': name,
        'planning_title': planningTitle,
        'color': color,
        'include_in_average': true,
        'available_statuses': statuses,
        'default_status': defaultStatus,
        'hide_name': hideName,
        'highlight': highlight,
        'visible': true,
        'manage_songs': manageSongs,
        'relevant_groups': <int>[],
        'tenant_id': tenantId,
        'reminders': <int>[],
      };

  return [
    typeRow(
      name: isGeneral ? l10n.defaultsTypesMeeting : l10n.defaultsTypesRehearsal,
      planningTitle:
          isGeneral ? l10n.defaultsTypesMeeting : l10n.defaultsTypesRehearsalPlan,
      color: 'primary',
      statuses: [p, e, l, a],
      defaultStatus: p,
      hideName: true,
      highlight: false,
      manageSongs: false,
    ),
    if (!isGeneral)
      typeRow(
        name: l10n.defaultsTypesPerformance,
        planningTitle: l10n.defaultsTypesPerformance,
        color: 'secondary',
        statuses: [p, e, l, a, n],
        defaultStatus: n,
        hideName: false,
        highlight: true,
        manageSongs: true,
      ),
    typeRow(
      name: l10n.commonOther,
      planningTitle: l10n.commonOther,
      color: 'tertiary',
      statuses: [p, e, l, a, n],
      defaultStatus: n,
      hideName: false,
      highlight: false,
      manageSongs: false,
    ),
  ];
}
