import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/constants/enums.dart';
import '../../core/utils/archived_attendance.dart';
import '../../core/utils/duty_utils.dart';
import '../../core/utils/paged_query.dart';
import '../../core/utils/shift_utils.dart';
import '../models/attendance/attendance.dart';
import '../models/shift/shift_plan.dart';
import '../../core/config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;
import 'base_repository.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/status_utils.dart';

part 'attendance_repository_extras.dart';
part 'attendance_repository_records.dart';

/// Provider for AttendanceRepository
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref);
});

/// SOL_FIX1: one immutable repository instance per tenant (see
/// playerRepositoryForTenantProvider).
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final attendanceRepositoryForTenantProvider =
    Provider.family<AttendanceRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _attendanceRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _attendanceRepositoryForAccountProvider =
    Provider.family<AttendanceRepository, AccountScopeKey>((ref, key) {
  final repo = AttendanceRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// SOL_FIX11: thrown by a guarded (offline queue) write when the auth
/// session changed before the mutation; nothing was written.
class OfflineSessionChangedException implements Exception {
  const OfflineSessionChangedException();

  @override
  String toString() => 'OfflineSessionChangedException: auth session changed';
}

/// Thrown by [AttendanceRepository.updatePersonAttendance] with
/// `onlyIfStatus` when the row no longer has that status: nothing was
/// written (somebody changed it meanwhile).
class PersonAttendanceStatusChangedException implements Exception {
  const PersonAttendanceStatusChangedException();

  @override
  String toString() => 'PersonAttendanceStatusChangedException';
}

/// Repository for attendance operations
class AttendanceRepository extends _AttendanceRepositoryCore
    with _AttendanceRecordsMixin, _AttendanceExtrasMixin {
  AttendanceRepository(super.ref);

  /// Ionic `getCurrentAttDate()`: the tenant's season start, fallback
  /// 2023-01-01 (lower bound of `getAttendance(false, ...)`).
  static DateTime currentAttDate(String? seasonStart) =>
      (seasonStart != null ? DateTime.tryParse(seasonStart) : null) ??
      DateTime(2023, 1, 1);


  /// DB_FIX: `attendance` columns an insert may set. Attendance.toJson also
  /// holds client-only keys (percentage, lateExcused — no `attendance`
  /// columns → PGRST204), id and created_at.
  static const Set<String> insertColumns = {
    'created_by',
    'date',
    'type',
    'type_id',
    'save_in_history',
    'excused',
    'typeInfo',
    'notes',
    'img',
    'plan',
    'songs',
    'criticalPlayers',
    'playerNotes',
    'start_time',
    'end_time',
    'deadline',
    'duration_days',
    'checklist',
    'conductors',
    'players',
    'share_plan',
    'place',
    'files_folder',
    'description',
    'attachment_url',
    'attachment_name',
    'duty_required',
  };

  /// DB_FIX: insert payload of [createAttendance] (without tenantId): only
  /// [insertColumns]; null values are not sent so DB defaults apply (Ionic
  /// inserts only the keys it set).
  static Map<String, dynamic> buildInsertData(Attendance attendance) => {
        for (final e in attendance.toJson().entries)
          if (insertColumns.contains(e.key) && e.value != null) e.key: e.value,
      };


  /// Storage path of the description attachment (Ionic onAttachmentSelect).
  static String attachmentPath(int attendanceId, String fileName) {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$attendanceId/attachment/$safeName';
  }

  // DB_REVIEW_REST (H4): Termin-Foto like Ionic image.service
  // updateAttendanceImage: bucket `attendances`, key `<attendanceId>`, upsert.
  static String attendanceImagePath(int attendanceId) => '$attendanceId';
}

abstract class _AttendanceRepositoryCore extends BaseRepository with TenantAwareRepository {
  _AttendanceRepositoryCore(super.ref);

  /// Ionic `getAttendance(all, withPersonAttendance)`: all attendances of the
  /// current tenant after [since] (default 2020-01-01 = Ionic `all`), newest
  /// first, without a row limit.
  ///
  /// PARITY_A (R1): no default limit / 180-day window any more; all pages are
  /// loaded (PostgREST max-rows). [limit] is only applied when given.
  Future<List<Attendance>> getAttendances({
    DateTime? since,
    bool withPersonAttendances = false,
    int? limit,
  }) async {
    try {
      final sinceDate = since ?? DateTime(2020, 1, 1);

      String selectQuery = '*';
      if (withPersonAttendances) {
        selectQuery = '''*, persons:person_attendances(
          *, person:person_id(
            firstName, lastName, img, instrument(id, name), joined
          )
        )''';
      }

      final List<Map<String, dynamic>> rows;
      if (limit != null) {
        final response = await supabase
            .from('attendance')
            .select(selectQuery)
            .eq('tenantId', currentTenantId)
            .gt('date', sinceDate.toIso8601String())
            .order('date', ascending: false)
            .limit(limit);
        rows = (response as List).cast<Map<String, dynamic>>();
      } else {
        rows = await fetchAllPages<Map<String, dynamic>>((from, to) async {
          final page = await supabase
              .from('attendance')
              .select(selectQuery)
              .eq('tenantId', currentTenantId)
              .gt('date', sinceDate.toIso8601String())
              .order('date', ascending: false)
              .order('id', ascending: true)
              .range(from, to);
          return (page as List).cast<Map<String, dynamic>>();
        });
      }

      // Ionic 4.17.24 `filterArchivedForRole`.
      return filterArchivedForRole(
        rows.map((e) => _parseAttendance(e, withPersonAttendances)).toList(),
        currentUserRole,
        (a) => a.archived,
      );
    } catch (e, stack) {
      handleError(e, stack, 'getAttendances');
      rethrow;
    }
  }

  /// Get upcoming attendances (future dates)
  ///
  /// Optionally limit the number of results returned.
  Future<List<Attendance>> getUpcomingAttendances({int? limit}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final ordered = supabase
          .from('attendance')
          .select('*')
          .eq('tenantId', currentTenantId)
          .gte('date', startOfDay.toIso8601String())
          .order('date', ascending: true);

      final response = limit != null ? await ordered.limit(limit) : await ordered;

      return (response as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getUpcomingAttendances');
      rethrow;
    }
  }

  /// Get a single attendance by ID with person attendances
  Future<Attendance?> getAttendanceById(int id) async {
    try {
      final response = await supabase
          .from('attendance')
          .select('''*, persons:person_attendances(
            *, person:person_id(
              firstName, lastName, img, instrument(id, name), joined, appId, additional_fields
            )
          )''')
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return _parseAttendance(response, true);
    } catch (e, stack) {
      handleError(e, stack, 'getAttendanceById');
      rethrow;
    }
  }

  /// LINK_TERMIN: group of a Termin opened by a link without `tenantId`.
  /// Only the user's own groups ([tenantIds]) are searched; null when the
  /// Termin belongs to none of them.
  Future<int?> findTenantIdOfAttendance(int id, List<int> tenantIds) async {
    if (tenantIds.isEmpty) return null;
    try {
      final response = await supabase
          .from('attendance')
          .select('tenantId')
          .eq('id', id)
          .inFilter('tenantId', tenantIds)
          .maybeSingle();
      return (response?['tenantId'] as num?)?.toInt();
    } catch (e, stack) {
      handleError(e, stack, 'findTenantIdOfAttendance');
      rethrow;
    }
  }

  /// REDESIGN (bell): date and name of the given Termine of this tenant –
  /// `typeInfo`, else the type name unless it is hidden (Ionic
  /// Utils.getTypeTitle). Ids of other tenants are simply not returned.
  Future<Map<int, ({DateTime? date, String? name})>> getEventLabels(List<int> ids) async {
    if (ids.isEmpty) return {};
    try {
      final response = await supabase
          .from('attendance')
          .select('id, date, typeInfo, attType:type_id(name, hide_name)')
          .eq('tenantId', currentTenantId)
          .inFilter('id', ids);
      final result = <int, ({DateTime? date, String? name})>{};
      for (final row in response as List) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as int?;
        if (id == null) continue;
        final info = (map['typeInfo'] as String? ?? '').trim();
        final type = map['attType'] as Map<String, dynamic>?;
        final typeName = type == null || type['hide_name'] == true ? '' : (type['name'] as String? ?? '').trim();
        final name = info.isNotEmpty ? info : typeName;
        result[id] = (
          date: DateTime.tryParse('${map['date'] ?? ''}'),
          name: name.isEmpty ? null : name,
        );
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getEventLabels');
      rethrow;
    }
  }

  /// Create a new attendance
  /// BL-002: Checks for duplicate attendances on the same date
  Future<Attendance> createAttendance(Attendance attendance) async {
    ensureNotDemo('createAttendance'); // DEMO_GUARD
    try {
      // BL-002: Check for existing attendance on the same date
      final existing = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId)
          .eq('date', attendance.date)
          .maybeSingle();

      if (existing != null) {
        throw DuplicateAttendanceException(
          message: l10nWithoutContext.coreFlutterRepoEventExistsOnDate,
          existingId: existing['id'] as int,
          date: attendance.date,
        );
      }

      final data = AttendanceRepository.buildInsertData(attendance);
      data['tenantId'] = currentTenantId;

      final response = await supabase
          .from('attendance')
          .insert(data)
          .select()
          .single();

      return Attendance.fromJson(response);
    } catch (e, stack) {
      // BL-002: Don't wrap DuplicateAttendanceException
      if (e is DuplicateAttendanceException) rethrow;
      handleError(e, stack, 'createAttendance');
      rethrow;
    }
  }

  /// Update an existing attendance
  Future<Attendance> updateAttendance(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateAttendance'); // DEMO_GUARD
    // Ionic 4.17.24: only admins/responsible archive or restore Termine
    // (also checked here, not only in the menu).
    if ((updates.containsKey('archived') ||
            updates.containsKey('archived_at') ||
            updates.containsKey('archived_by')) &&
        !canSeeArchivedAttendances(currentUserRole)) {
      throw RepositoryException(
        message: 'Archiving Termine needs the admin or responsible role',
        operation: 'updateAttendance',
      );
    }
    try {
      // Remove read-only fields
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('tenantId');
      updates.remove('persons');

      final response = await supabase
          .from('attendance')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .select()
          .maybeSingle();

      // RT-008: Handle case where attendance was not found
      if (response == null) {
        throw RepositoryException(
          message: 'Attendance not found or belongs to different tenant',
          operation: 'updateAttendance',
        );
      }

      return Attendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateAttendance');
      rethrow;
    }
  }

  /// Delete an attendance
  Future<void> deleteAttendance(int id) async {
    ensureNotDemo('deleteAttendance'); // DEMO_GUARD
    try {
      await supabase
          .from('attendance')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteAttendance');
      rethrow;
    }
  }

  /// Get attendances for a specific date
  Future<List<Attendance>> getAttendancesByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await supabase
          .from('attendance')
          .select('*')
          .eq('tenantId', currentTenantId)
          .gte('date', startOfDay.toIso8601String())
          .lt('date', endOfDay.toIso8601String())
          .order('date', ascending: true);

      return (response as List)
          .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAttendancesByDate');
      rethrow;
    }
  }

  Attendance _parseAttendance(Map<String, dynamic> data, bool withPersons) {
    // RT-020: Removed unused persons parsing - the Attendance model
    // doesn't have a persons field yet. When needed, add the field to
    // the Attendance model and uncomment the parsing logic.
    return Attendance.fromJson(data);
  }

  /// Throws when [attendanceId] does not belong to the current tenant.
  Future<void> _assertAttendanceInTenant(int attendanceId, String operation) async {
    final check = await supabase
        .from('attendance')
        .select('id')
        .eq('id', attendanceId)
        .eq('tenantId', currentTenantId)
        .maybeSingle();
    if (check == null) {
      throw RepositoryException(
        message: 'Attendance not found or belongs to different tenant',
        operation: operation,
      );
    }
  }
}
