import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_org/team_org.dart';
import 'base_repository.dart';

/// Provider for ProtocolRepository
final protocolRepositoryProvider = Provider<ProtocolRepository>((ref) {
  return ProtocolRepository(ref);
});

/// List select with the joined attendance (Ionic PROTOCOL_LIST_SELECT).
const String protocolListSelect =
    'id, attendance_id, tenant_id, status, published_at, updated_at, created_at, outcomes, attendance:attendance!attendance_id(id, date, typeInfo, type_id)';

/// Repository for protocols of the Teamorganisation (table `protocols`) and
/// the attendance data the protocol page and topic planning need.
///
/// `protocols` and `attendance_types` use `tenant_id`, `attendance` uses
/// `tenantId`. Writing protocol sections and publishing goes through the
/// SECURITY DEFINER functions `save_protocol_section` / `publish_protocol`,
/// which derive the tenant from the attendance and check the leadership role.
class ProtocolRepository extends BaseRepository with TenantAwareRepository {
  ProtocolRepository(super.ref);

  /// Leadership: draft or published. Members: only published protocols of their circle (RLS).
  Future<Protocol?> getProtocolForAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('protocols')
          .select('*')
          .eq('attendance_id', attendanceId)
          .eq('tenant_id', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Protocol.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getProtocolForAttendance');
      rethrow;
    }
  }

  /// All protocols visible to the user, newest attendance first.
  Future<List<Protocol>> getProtocols() async {
    try {
      final response = await supabase
          .from('protocols')
          .select(protocolListSelect)
          .eq('tenant_id', currentTenantId);

      final list = (response as List)
          .map((e) => Protocol.fromJson(e as Map<String, dynamic>))
          .toList();
      DateTime dateOf(Protocol p) =>
          DateTime.tryParse(p.attendance?.date ?? p.createdAt ?? '') ?? DateTime(1970);
      list.sort((a, b) => dateOf(b).compareTo(dateOf(a)));
      return list;
    } catch (e, stack) {
      handleError(e, stack, 'getProtocols');
      rethrow;
    }
  }

  /// Saves one section (note and/or outcome) atomically on the server.
  /// [clearOutcome] removes the outcome of the section.
  Future<Protocol?> saveSection(
    int attendanceId,
    String fieldId, {
    Map<String, dynamic>? doc,
    String? outcome,
    bool clearOutcome = false,
  }) async {
    ensureNotDemo('saveSection'); // DEMO_GUARD
    try {
      await _ensureAttendanceOfTenant(attendanceId);
      final response = await supabase.rpc('save_protocol_section', params: {
        'p_attendance_id': attendanceId,
        'p_field_id': fieldId,
        'p_doc': doc,
        'p_outcome': outcome,
        'p_clear_outcome': clearOutcome,
      });
      return _parseRow(response);
    } catch (e, stack) {
      handleError(e, stack, 'saveSection');
      rethrow;
    }
  }

  Future<Protocol?> publish(int attendanceId) async {
    ensureNotDemo('publish'); // DEMO_GUARD
    try {
      await _ensureAttendanceOfTenant(attendanceId);
      final response = await supabase.rpc('publish_protocol', params: {
        'p_attendance_id': attendanceId,
      });
      return _parseRow(response);
    } catch (e, stack) {
      handleError(e, stack, 'publish');
      rethrow;
    }
  }

  Future<void> deleteProtocol(String id) async {
    ensureNotDemo('deleteProtocol'); // DEMO_GUARD
    try {
      await supabase
          .from('protocols')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteProtocol');
      rethrow;
    }
  }

  /// Uploads a protocol PDF to the public `attendances` bucket so the
  /// notification can attach it. Returns (url, path).
  Future<({String url, String path})> uploadPdf(int attendanceId, Uint8List bytes) async {
    ensureNotDemo('uploadPdf'); // DEMO_GUARD
    try {
      final path = 'protocols/${attendanceId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await supabase.storage.from('attendances').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
          );
      final url = supabase.storage.from('attendances').getPublicUrl(path);
      return (url: url, path: path);
    } catch (e, stack) {
      handleError(e, stack, 'uploadPdf');
      rethrow;
    }
  }

  Future<void> removePdf(String path) async {
    ensureNotDemo('removePdf'); // DEMO_GUARD
    try {
      await supabase.storage.from('attendances').remove([path]);
    } catch (e) {
      if (kDebugMode) debugPrint('[ProtocolRepository] removePdf failed: $e');
    }
  }

  // ── Attendance data for protocols ─────────────────────────

  /// Attendance types with the protocol columns (table uses `tenant_id`).
  Future<List<ProtocolType>> getProtocolTypes() async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select('id, name, enable_protocol, relevant_groups, agenda_default_duration, suggest_postponed, default_plan, start_time, index')
          .eq('tenant_id', currentTenantId)
          .order('index', ascending: true);

      return (response as List)
          .map((e) => ProtocolType.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getProtocolTypes');
      rethrow;
    }
  }

  /// One attendance with plan and attendees (person_attendances + names).
  Future<ProtocolAttendance?> getAttendance(int attendanceId) async {
    try {
      final response = await supabase
          .from('attendance')
          .select('id, date, type_id, typeInfo, start_time, end_time, plan, persons:person_attendances(id, person_id, status, notes, person:person_id(firstName, lastName))')
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return ProtocolAttendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getAttendance');
      rethrow;
    }
  }

  /// Attendances from today on (soonest first), without attendees.
  Future<List<ProtocolAttendance>> getUpcomingAttendances() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final response = await supabase
          .from('attendance')
          .select('id, date, type_id, typeInfo, start_time, end_time, plan')
          .eq('tenantId', currentTenantId)
          .gte('date', startOfDay.toIso8601String())
          .order('date', ascending: true);

      return (response as List)
          .map((e) => ProtocolAttendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getUpcomingAttendances');
      rethrow;
    }
  }

  /// Saves the plan (Ablaufplan) of an attendance and returns the stored plan.
  Future<Map<String, dynamic>?> updateAttendancePlan(int attendanceId, Map<String, dynamic> plan) async {
    ensureNotDemo('updateAttendancePlan'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('attendance')
          .update({'plan': plan})
          .eq('id', attendanceId)
          .eq('tenantId', currentTenantId)
          .select('plan')
          .maybeSingle();

      final stored = response?['plan'];
      return stored is Map ? Map<String, dynamic>.from(stored) : plan;
    } catch (e, stack) {
      handleError(e, stack, 'updateAttendancePlan');
      rethrow;
    }
  }

  // ── Quick-create Termin (Ionic promptCreateProtocolAttendance) ──

  /// Active persons a new Termin can be created for (not archived, pending or paused).
  Future<List<Map<String, dynamic>>> getPersonsForNewAttendance() async {
    try {
      final response = await supabase
          .from('player')
          .select('id, instrument, additional_fields')
          .eq('tenantId', currentTenantId)
          .isFilter('left', null)
          .eq('pending', false)
          .eq('paused', false);
      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonsForNewAttendance');
      rethrow;
    }
  }

  /// Creates a Termin (tenant forced to the current one) and returns its id.
  Future<int> createAttendance(Map<String, dynamic> row) async {
    ensureNotDemo('createAttendance'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('attendance')
          .insert({...row, 'tenantId': currentTenantId})
          .select('id')
          .single();
      return (response['id'] as num).toInt();
    } catch (e, stack) {
      handleError(e, stack, 'createAttendance');
      rethrow;
    }
  }

  /// Inserts the person attendances of a new Termin. `person_attendances` has
  /// no tenant column; the Termin is checked to belong to the current tenant first.
  Future<void> createPersonAttendances(int attendanceId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _ensureAttendanceOfTenant(attendanceId);
      await supabase
          .from('person_attendances')
          .insert([for (final r in rows) {...r, 'attendance_id': attendanceId}]);
    } catch (e, stack) {
      handleError(e, stack, 'createPersonAttendances');
      rethrow;
    }
  }

  /// Sends a team notification via the `team-notify` edge function
  /// (assignment, published protocol, decided suggestion). Never throws.
  Future<void> notifyTeam(Map<String, dynamic> body) async {
    try {
      await supabase.functions.invoke('team-notify', body: {
        ...body,
        'tenantId': currentTenantId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[ProtocolRepository] team-notify error: $e');
    }
  }

  /// Guards the RPCs: the attendance must belong to the current tenant.
  Future<void> _ensureAttendanceOfTenant(int attendanceId) async {
    final row = await supabase
        .from('attendance')
        .select('id')
        .eq('id', attendanceId)
        .eq('tenantId', currentTenantId)
        .maybeSingle();
    if (row == null) {
      throw const RepositoryException(
        message: 'Termin gehört nicht zur aktuellen Instanz',
        operation: 'ensureAttendanceOfTenant',
      );
    }
  }

  Protocol? _parseRow(dynamic response) {
    if (response == null) return null;
    if (response is List) {
      if (response.isEmpty) return null;
      return Protocol.fromJson(Map<String, dynamic>.from(response.first as Map));
    }
    return Protocol.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
