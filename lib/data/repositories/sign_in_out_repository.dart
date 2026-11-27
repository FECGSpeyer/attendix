import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/services/cross_tenant_service.dart' show CrossTenantService;
import '../../core/utils/archived_attendance.dart';
import '../../core/utils/event_list_utils.dart';
import '../../core/utils/paged_query.dart';
import '../models/attendance/attendance.dart';
import '../../core/utils/duty_utils.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/status_utils.dart';
import '../models/plan/plan.dart' show isPlanPublished;

part 'cross_tenant_person_attendance.dart';
part 'sign_in_out_repository_queries.dart';

/// Provider for SignInOutRepository (without tenant – use the WithTenant variant).
final signInOutRepositoryProvider = Provider<SignInOutRepository>((ref) {
  return SignInOutRepository(ref);
});

/// Columns of `attendance` needed by the Terminlisten (signout, overview, parents).
const String kSignoutAttendanceColumns =
    'id, date, type, typeInfo, songs, type_id, start_time, end_time, deadline, '
    'duration_days, plan, extra_plans, share_plan, description, attachment_url, '
    'attachment_name, files_folder, place, tenantId, archived';

/// IOS_FORMS2: `attendance` columns of the Übersicht – exactly Ionic
/// `getPersonAttendancesForTenant` (no `place`, `plan`, `share_plan`), so the
/// Übersicht shows no place / "Route" chip and no Ablaufplan action.
const String kOverviewAttendanceColumns =
    'id, date, type, typeInfo, songs, type_id, start_time, end_time, deadline, '
    'duration_days, description, attachment_url, attachment_name, '
    'files_folder, tenantId, archived';

/// Columns of `attendance_types` joined into the Terminlisten.
const String kSignoutAttendanceTypeColumns =
    'id, name, highlight, include_in_average, color, hide_name, all_day, '
    'duration_days, start_time, end_time, available_statuses, '
    'default_status, registration_fields, duty_mode';

/// Repository for self-service sign in/out operations
class SignInOutRepository extends _SignInOutRepositoryCore
    with _SignInOutQueriesMixin {
  SignInOutRepository(super.ref);

  /// Ionic `tenant?.longName || tenant?.shortName || 'Unbekannt'`.
  @visibleForTesting
  static String tenantDisplayName(String? longName, String? shortName) {
    if (longName != null && longName.isNotEmpty) return longName;
    if (shortName != null && shortName.isNotEmpty) return shortName;
    return l10nWithoutContext.commonUnknown;
  }

  /// Ionic `tenantData?.seasonStart || dayjs('2023-01-01').toISOString()`.
  @visibleForTesting
  static String overviewSeasonStart(dynamic seasonStart) {
    final value = seasonStart?.toString();
    if (value != null && value.isNotEmpty) return value;
    return DateTime(2023).toUtc().toIso8601String();
  }

  /// Ionic: flattened list sorted by date ascending.
  @visibleForTesting
  static List<CrossTenantPersonAttendance> sortCrossTenantByDate(
    List<CrossTenantPersonAttendance> list,
  ) {
    DateTime d(CrossTenantPersonAttendance a) =>
        EventListUtils.parse(a.date) ?? DateTime(1970);
    return [...list]..sort((a, b) => d(a).compareTo(d(b)));
  }
}

abstract class _SignInOutRepositoryCore extends BaseRepository with TenantAwareRepository {
  _SignInOutRepositoryCore(super.ref);

  /// Predefined distinct colors for tenant visual separation (from Ionic app)
  static const _distinctColors = [
    '#E53935', // Red
    '#1E88E5', // Blue
    '#43A047', // Green
    '#FB8C00', // Orange
    '#8E24AA', // Purple
    '#00ACC1', // Cyan
    '#F4511E', // Deep Orange
    '#3949AB', // Indigo
    '#7CB342', // Light Green
    '#C2185B', // Pink
    '#00897B', // Teal
    '#6D4C41', // Brown
    '#5E35B1', // Deep Purple
    '#039BE5', // Light Blue
    '#D81B60', // Pink Dark
  ];

  /// Get color for tenant based on index (like Ionic app)
  String _getTenantColor(int tenantId, List<dynamic> tenantIds) {
    final index = tenantIds.indexOf(tenantId);
    final colorIndex = index >= 0
        ? index % _distinctColors.length
        : tenantId.abs() % _distinctColors.length;
    return _distinctColors[colorIndex];
  }

  /// SEC: person_attendances has no tenantId column. Ownership is checked via
  /// the joined attendance (current tenant) or – for the cross-tenant
  /// overview – via the linked person's appId (= current user).
  Future<List<String>> _validatePersonAttendanceIds(
    List<String> ids,
    String operation, {
    bool ownAcrossTenants = false,
  }) async {
    if (ids.isEmpty) return [];
    if (ownAcrossTenants) {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final rows = await supabase
          .from('person_attendances')
          .select('id, person:person_id(appId)')
          .inFilter('id', ids);
      return (rows as List)
          .where((r) => r['person']?['appId'] == userId)
          .map((r) => r['id'].toString())
          .toList();
    }

    final rows = await supabase
        .from('person_attendances')
        .select('id, attendance:attendance_id(tenantId)')
        .inFilter('id', ids);
    return (rows as List)
        .where((r) => r['attendance']?['tenantId'] == currentTenantId)
        .map((r) => r['id'].toString())
        .toList();
  }

  Future<void> _updatePersonAttendances(
    List<String> ids,
    Map<String, dynamic> fields,
  ) async {
    await supabase.from('person_attendances').update({
      ...fields,
      'changed_at': DateTime.now().toUtc().toIso8601String(),
      'changed_by': supabase.auth.currentUser?.id,
    }).inFilter('id', ids);
  }

  /// Telegram/Push notification for the conductors (Ionic notifyPerTelegram).
  /// Errors are swallowed: the sign in/out itself already succeeded.
  Future<void> _notify({
    required String attId,
    required String type,
    String? reason,
    bool isParents = false,
    String notes = '',
    bool isSelf = false,
  }) async {
    try {
      await supabase.functions.invoke('quick-processor', body: {
        'attId': attId,
        'type': type,
        'reason': reason,
        'isParents': isParents,
        'notes': notes,
        'isSelf': isSelf,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[SignInOutRepository] notify failed: $e');
    }
  }

  /// DUTY: duty fields to write along with a status change (Ionic
  /// syncDutyWithStatus). The id must already be validated for the tenant.
  Future<Map<String, dynamic>> _dutyUpdateForStatus(
    String personAttendanceId,
    AttendanceStatus newStatus,
  ) async {
    final row = await supabase
        .from('person_attendances')
        .select('duty_state, attendance:attendance_id(attType:type_id(duty_mode))')
        .eq('id', personAttendanceId)
        .maybeSingle();
    if (row == null || row['attendance']?['attType']?['duty_mode'] != true) {
      return const {};
    }
    return dutySyncFieldsForStatus(
      isDutyTermin: true,
      currentDutyState: row['duty_state'] as String?,
      newStatus: newStatus,
      userId: supabase.auth.currentUser?.id,
    );
  }

  /// Sign in to an attendance (status → Anwesend, like Ionic `signin`).
  ///
  /// [type] only selects the notification text (previous status).
  Future<void> signIn(
    String personAttendanceId,
    SignInType type, {
    String notes = '',
    bool ownAcrossTenants = false,
  }) async {
    try {
      final valid = await _validatePersonAttendanceIds(
        [personAttendanceId],
        'signIn',
        ownAcrossTenants: ownAcrossTenants,
      );
      if (valid.isEmpty) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'signIn',
        );
      }

      // DUTY: keep assignment and status in sync (Ionic syncDutyWithStatus)
      final dutyUpdate =
          await _dutyUpdateForStatus(personAttendanceId, AttendanceStatus.present);

      await _updatePersonAttendances(valid, {
        'status': AttendanceStatus.present.value,
        'notes': notes,
        ...dutyUpdate,
      });

      await _notify(attId: personAttendanceId, type: type.telegramType, notes: notes);
    } catch (e, stack) {
      handleError(e, stack, 'signIn');
      rethrow;
    }
  }

  /// Sign out from attendances (Entschuldigt / Verspätung gemeldet).
  Future<void> signOut(
    List<String> personAttendanceIds,
    String reason, {
    bool isLateComing = false,
    bool isParents = false,
    bool isSelf = false,
    bool ownAcrossTenants = false,
  }) async {
    try {
      final validIds = await _validatePersonAttendanceIds(
        personAttendanceIds,
        'signOut',
        ownAcrossTenants: ownAcrossTenants,
      );

      if (validIds.isEmpty) {
        throw RepositoryException(
          message: 'No valid person attendances found for current tenant',
          operation: 'signOut',
        );
      }

      final status =
          isLateComing ? AttendanceStatus.lateExcused : AttendanceStatus.excused;

      await _updatePersonAttendances(validIds, {
        'status': status.value,
        'notes': reason,
      });

      await _notify(
        attId: validIds.first,
        type: isLateComing ? 'lateSignout' : 'signout',
        reason: reason,
        isParents: isParents,
        isSelf: isSelf,
      );
    } catch (e, stack) {
      handleError(e, stack, 'signOut');
      rethrow;
    }
  }

  /// Chat assistant "Rückgängig": puts own rows back to their previous
  /// status and note. Only rows of the signed-in person (appId), in the
  /// current tenant unless [acrossTenants] (own rows of all groups, like
  /// the Übersicht); no notification.
  Future<int> restoreOwnStatuses(
    List<({String id, AttendanceStatus status, String notes})> rows, {
    bool acrossTenants = false,
  }) async {
    if (rows.isEmpty) return 0;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;
      final check = await supabase
          .from('person_attendances')
          .select('id, person:person_id(appId), attendance:attendance_id(tenantId)')
          .inFilter('id', [for (final r in rows) r.id]);
      final valid = {
        for (final r in (check as List).cast<Map<String, dynamic>>())
          if (r['person']?['appId'] == userId &&
              (acrossTenants || r['attendance']?['tenantId'] == currentTenantId))
            r['id'].toString(),
      };
      var count = 0;
      for (final r in rows) {
        if (!valid.contains(r.id)) continue;
        final dutyUpdate = await _dutyUpdateForStatus(r.id, r.status);
        await _updatePersonAttendances([r.id], {
          'status': r.status.value,
          'notes': r.notes,
          ...dutyUpdate,
        });
        count++;
      }
      return count;
    } catch (e, stack) {
      handleError(e, stack, 'restoreOwnStatuses');
      rethrow;
    }
  }

  /// Update attendance note
  Future<void> updateAttendanceNote(
    String personAttendanceId,
    String note, {
    bool ownAcrossTenants = false,
  }) async {
    try {
      final valid = await _validatePersonAttendanceIds(
        [personAttendanceId],
        'updateAttendanceNote',
        ownAcrossTenants: ownAcrossTenants,
      );
      if (valid.isEmpty) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'updateAttendanceNote',
        );
      }

      await _updatePersonAttendances(valid, {'notes': note});
      await _notify(attId: personAttendanceId, type: 'noteUpdate', reason: note);
    } catch (e, stack) {
      handleError(e, stack, 'updateAttendanceNote');
      rethrow;
    }
  }

  /// Saves the answers to the attendance type's registration fields.
  Future<void> updateRegistrationAnswers(
    String personAttendanceId,
    Map<String, dynamic> answers,
  ) async {
    try {
      final valid = await _validatePersonAttendanceIds(
        [personAttendanceId],
        'updateRegistrationAnswers',
      );
      if (valid.isEmpty) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'updateRegistrationAnswers',
        );
      }
      await _updatePersonAttendances(valid, {'registration_answers': answers});
    } catch (e, stack) {
      handleError(e, stack, 'updateRegistrationAnswers');
      rethrow;
    }
  }

  /// Whether the Dateiablage is shared with all members of the current
  /// tenant (`tenants.files_shared`). Returns false when the column is
  /// missing (files module not migrated yet).
  Future<bool> getTenantFilesShared() async {
    try {
      final row = await supabase
          .from('tenants')
          .select('files_shared')
          .eq('id', currentTenantId)
          .maybeSingle();
      return row?['files_shared'] == true;
    } catch (_) {
      return false;
    }
  }

  /// REDESIGN: Werke (history rows with song and conductor) of one own
  /// Termin, the group of [personId] in that tenant and the tenant's type
  /// (choir, orchestra, general …). Cross-tenant by design like "Meine Termine": every query is
  /// filtered by the Termin's [tenantId] (one of the user's memberships).
  Future<({List<Map<String, dynamic>> rows, int? instrumentId, String? tenantType})> getOwnProgram({
    required int tenantId,
    required int attendanceId,
    required int? personId,
  }) async {
    try {
      final rows = await supabase
          .from('history')
          .select('id, songId, person_id, otherConductor, '
              'song:songId(id, name, number, prefix, link, instrument_ids, files), '
              'person:person_id(firstName, lastName)')
          .eq('attendance_id', attendanceId)
          .eq('tenantId', tenantId)
          .order('id', ascending: true);
      int? instrumentId;
      if (personId != null) {
        final person = await supabase
            .from('player')
            .select('instrument')
            .eq('id', personId)
            .eq('tenantId', tenantId)
            .maybeSingle();
        instrumentId = _toInt(person?['instrument']);
      }
      final tenant = await supabase.from('tenants').select('type').eq('id', tenantId).maybeSingle();
      return (
        rows: List<Map<String, dynamic>>.from(rows as List),
        instrumentId: instrumentId,
        tenantType: tenant?['type'] as String?,
      );
    } catch (e, stack) {
      handleError(e, stack, 'getOwnProgram');
      rethrow;
    }
  }

  /// REDESIGN: the Werke of the next Auftritt (hervorgehobene Terminart)
  /// after the Termin [attendanceId], for a Probe that has none of its own
  /// ("Vom nächsten Auftritt"). Null when there is none with Werke.
  ///
  /// Only a Termin whose Terminart has Werke and is no Auftritt itself
  /// follows one (not a Besprechung). Only for Termine of the current
  /// group: every query filters by [currentTenantId]. Flat queries (no
  /// embedded Termin rows).
  Future<({List<Map<String, dynamic>> rows, String name, String date})?> getNextPerformanceProgram({
    required int attendanceId,
  }) async {
    try {
      final own = await supabase
          .from('attendance')
          .select('date, start_time, type_id')
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId)
          .maybeSingle();
      final date = own?['date'] as String?;
      if (date == null || own?['type_id'] == null) return null;
      final types = ((await supabase
              .from('attendance_types')
              .select('id, name, highlight, manage_songs')
              .eq('tenant_id', currentTenantId)) as List)
          .cast<Map<String, dynamic>>();
      final ownType = types.where((t) => '${t['id']}' == '${own?['type_id']}').firstOrNull;
      if (ownType == null || ownType['manage_songs'] != true || ownType['highlight'] == true) return null;
      final typeNames = {
        for (final t in types)
          if (t['highlight'] == true) '${t['id']}': (t['name'] as String?) ?? '',
      };
      if (typeNames.isEmpty) return null;
      final next = await supabase
          .from('attendance')
          .select('id, date, start_time, typeInfo, type_id')
          .eq('tenantId', currentTenantId)
          .gte('date', date)
          .neq('id', attendanceId)
          .not('archived', 'is', true)
          .inFilter('type_id', typeNames.keys.toList())
          .order('date', ascending: true)
          .order('id', ascending: true)
          .limit(6);
      final ownStart = own?['start_time'] as String?;
      final candidates = [
        for (final a in (next as List).cast<Map<String, dynamic>>())
          // The same day: not an Auftritt that begins before this Termin.
          if (!(a['date'] == date &&
              ownStart != null &&
              a['start_time'] is String &&
              (a['start_time'] as String).compareTo(ownStart) < 0))
            a,
      ];
      if (candidates.isEmpty) return null;
      final rows = await supabase
          .from('history')
          .select('id, attendance_id, songId, person_id, otherConductor, '
              'song:songId(id, name, number, prefix, link, instrument_ids, files), '
              'person:person_id(firstName, lastName)')
          .inFilter('attendance_id', [for (final a in candidates) a['id']])
          .eq('tenantId', currentTenantId)
          .order('id', ascending: true);
      final all = List<Map<String, dynamic>>.from(rows as List);
      for (final a in candidates) {
        final mine = [for (final r in all) if (r['attendance_id'] == a['id']) r];
        if (mine.isEmpty) continue;
        final info = (a['typeInfo'] as String?)?.trim() ?? '';
        return (
          rows: mine,
          name: info.isNotEmpty ? info : (typeNames['${a['type_id']}'] ?? ''),
          date: a['date'] as String,
        );
      }
      return null;
    } catch (e, stack) {
      handleError(e, stack, 'getNextPerformanceProgram');
      rethrow;
    }
  }

  AttendanceType? _parseType(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return AttendanceType.fromJson({'name': '', ...json});
    } catch (_) {
      return null;
    }
  }
}
