import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart' show currentAuthUserIdProvider;
import '../../core/constants/enums.dart';
import '../../core/utils/archived_attendance.dart';
import '../../core/utils/paged_query.dart';
import '../../features/assistant/data/assistant_command.dart';
import '../../features/assistant/data/assistant_logic.dart';
import 'base_repository.dart';

/// Why the assistant could not understand a message.
enum AssistantFailure {
  /// The admin has not switched the assistant on for this tenant.
  disabled,

  /// Daily limit of the account or the tenant reached.
  limit,

  /// Text longer than [assistantMaxTextLength].
  tooLong,

  /// Network, server or model error.
  failed,
}

class AssistantException implements Exception {
  const AssistantException(this.failure);
  final AssistantFailure failure;

  @override
  String toString() => 'AssistantException(${failure.name})';
}

/// Chat assistant (Edge Function `ai-assistant`) and the reads its answers
/// need that the app does not load elsewhere.
///
/// Multi-tenant: every read joins `attendance!inner` and filters
/// `attendance.tenantId = currentTenantId` (person_attendances has no
/// tenantId column); the Edge Function checks the membership itself.
/// Reads only: changes of package 2 (status, absence) go through the
/// existing write paths (AttendanceRepository, SignInOutRepository,
/// PlayerAbsenceRepository) after the person confirmed the preview.
class AssistantRepository extends BaseRepository with TenantAwareRepository {
  AssistantRepository(super.ref);

  /// Sends one message and returns the checked command. Only the text, the
  /// date and the language leave the app.
  Future<AssistantCommand> ask({
    required String text,
    required DateTime today,
    required String language,
  }) async {
    final clean = text.trim();
    if (clean.length > assistantMaxTextLength) {
      throw const AssistantException(AssistantFailure.tooLong);
    }
    Object? data;
    try {
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'tenantId': currentTenantId,
        'text': clean,
        'today': _isoDay(today),
        'language': language,
      }).timeout(const Duration(seconds: 30));
      data = response.data;
      if (data is String) data = jsonDecode(data);
    } on FunctionException catch (e) {
      throw AssistantException(switch (e.status) {
        403 when _reason(e.details) == 'disabled' => AssistantFailure.disabled,
        429 => AssistantFailure.limit,
        413 => AssistantFailure.tooLong,
        _ => AssistantFailure.failed,
      });
    } catch (e, stack) {
      if (e is AssistantException) rethrow;
      try {
        handleError(e, stack, 'ask');
      } catch (_) {}
      throw const AssistantException(AssistantFailure.failed);
    }
    return AssistantCommand.fromJson(data is Map ? data['command'] : null);
  }

  static String? _reason(Object? details) {
    var d = details;
    if (d is String) {
      try {
        d = jsonDecode(d);
      } catch (_) {
        return null;
      }
    }
    return d is Map ? d['reason'] as String? : null;
  }

  /// person_attendances of [personIds] with Termine in [range], for the
  /// attendance rate. Archived Termine only for roles that see them.
  Future<List<RateRow>> getRateRows({
    required List<int> personIds,
    required DayRange range,
  }) async {
    if (personIds.isEmpty) return const [];
    try {
      final from = _isoDay(range.from);
      // Termine are stored at 12:00; the day after the range end is excluded.
      final until = _isoDay(range.to.add(const Duration(days: 1)));
      final rows = <Map<String, dynamic>>[];
      // Large groups: at most 200 ids per request (URL length).
      for (var i = 0; i < personIds.length; i += 200) {
        final chunk = personIds.sublist(i, i + 200 > personIds.length ? personIds.length : i + 200);
        rows.addAll(await fetchAllPages<Map<String, dynamic>>((a, b) async {
          final page = await supabase
              .from('person_attendances')
              .select('id, person_id, status, notes, duty_state, '
                  'attendance:attendance_id!inner(date, tenantId, type_id, archived)')
              .eq('attendance.tenantId', currentTenantId)
              .inFilter('person_id', chunk)
              .gte('attendance.date', from)
              .lt('attendance.date', until)
              .order('id', ascending: true)
              .range(a, b);
          return (page as List).cast<Map<String, dynamic>>();
        }));
      }
      final showArchived = canSeeArchivedAttendances(currentUserRole);
      final result = <RateRow>[];
      for (final r in rows) {
        final att = (r['attendance'] as Map?)?.cast<String, dynamic>();
        final personId = r['person_id'] as int?;
        final date = DateTime.tryParse('${att?['date']}');
        if (att == null || personId == null || date == null) continue;
        if (!showArchived && isArchivedRow(att)) continue;
        result.add((
          personId: personId,
          date: date.toLocal(),
          typeId: att['type_id']?.toString(),
          status: AttendanceStatus.fromValue(r['status'] as int? ?? 0),
          notes: r['notes'] as String?,
          dutyState: r['duty_state'] as String?,
        ));
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getRateRows');
      rethrow;
    }
  }

  /// Status rows (person, status) of one Termin, for "Wer kommt?".
  Future<List<({int personId, AttendanceStatus status})>> getEventStatuses(int attendanceId) async {
    try {
      final response = await supabase
          .from('person_attendances')
          .select('person_id, status, attendance:attendance_id!inner(id, tenantId)')
          .eq('attendance_id', attendanceId)
          .eq('attendance.tenantId', currentTenantId);
      return [
        for (final r in (response as List).cast<Map<String, dynamic>>())
          if (r['person_id'] is int)
            (personId: r['person_id'] as int, status: AttendanceStatus.fromValue(r['status'] as int? ?? 0)),
      ];
    } catch (e, stack) {
      handleError(e, stack, 'getEventStatuses');
      rethrow;
    }
  }

  /// Rows a status change would touch: person_attendances of [personIds]
  /// either of Termin [attendanceId] or of Termine in [range]. Archived
  /// Termine are left out (they are not changed by the chat).
  Future<List<StatusRow>> getStatusRows({
    required List<int> personIds,
    int? attendanceId,
    DayRange? range,
  }) async {
    if (personIds.isEmpty || (attendanceId == null && range == null)) return const [];
    try {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < personIds.length; i += 200) {
        final chunk = personIds.sublist(i, i + 200 > personIds.length ? personIds.length : i + 200);
        rows.addAll(await fetchAllPages<Map<String, dynamic>>((a, b) async {
          var q = supabase
              .from('person_attendances')
              .select('id, person_id, status, notes, '
                  'attendance:attendance_id!inner(id, date, tenantId, type_id, typeInfo, start_time, archived)')
              .eq('attendance.tenantId', currentTenantId)
              .inFilter('person_id', chunk);
          if (attendanceId != null) {
            q = q.eq('attendance_id', attendanceId);
          } else {
            q = q
                .gte('attendance.date', _isoDay(range!.from))
                .lt('attendance.date', _isoDay(range.to.add(const Duration(days: 1))));
          }
          final page = await q.order('id', ascending: true).range(a, b);
          return (page as List).cast<Map<String, dynamic>>();
        }));
      }
      final result = <StatusRow>[];
      for (final r in rows) {
        final att = (r['attendance'] as Map?)?.cast<String, dynamic>();
        final personId = r['person_id'] as int?;
        final attId = att?['id'] as int?;
        final date = DateTime.tryParse('${att?['date']}');
        if (att == null || personId == null || attId == null || date == null || r['id'] == null) continue;
        if (isArchivedRow(att)) continue;
        result.add((
          id: r['id'].toString(),
          personId: personId,
          attendanceId: attId,
          date: date.toLocal(),
          typeId: att['type_id']?.toString(),
          typeInfo: att['typeInfo'] as String?,
          startTime: att['start_time'] as String?,
          status: AttendanceStatus.fromValue(r['status'] as int? ?? 0),
          notes: r['notes'] as String?,
        ));
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getStatusRows');
      rethrow;
    }
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// SOL_FIX1: one instance per tenant and account, bound to its tenant.
final assistantRepositoryForTenantProvider = Provider.family<AssistantRepository, int?>((ref, tenantId) {
  ref.watch(currentAuthUserIdProvider);
  final repo = AssistantRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});
