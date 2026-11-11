import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/type_circle.dart';
import '../models/attendance/attendance.dart';
import 'base_repository.dart';

/// Repository for AttendanceType CRUD operations
class AttendanceTypeRepository extends BaseRepository with TenantAwareRepository {
  AttendanceTypeRepository(super.ref);

  /// Single persons of each type's circle (`relevant_persons`, next to the
  /// groups in `relevant_groups`), by type id; types without any are left out.
  Future<Map<String, List<int>>> getCirclePersons() async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select('id, relevant_persons')
          .eq('tenant_id', currentTenantId);
      return {
        for (final row in response as List)
          if (typeCirclePersonsFromJson(row['relevant_persons']).isNotEmpty)
            row['id'].toString(): typeCirclePersonsFromJson(row['relevant_persons']),
      };
    } catch (e, stack) {
      handleError(e, stack, 'getCirclePersons');
      rethrow;
    }
  }

  /// Sets who belongs to a type's circle: groups and single persons (both
  /// empty = everyone).
  Future<void> updateCircle(String id, {required List<int> groups, required List<int> persons}) async {
    ensureNotDemo('updateCircle'); // DEMO_GUARD
    try {
      await supabase
          .from('attendance_types')
          .update({'relevant_groups': groups, 'relevant_persons': persons})
          .eq('id', id)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateCircle');
      rethrow;
    }
  }

  /// Raw attendance_types rows of the tenant (person history labels).
  Future<List<Map<String, dynamic>>> getTypeRows() async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select('*')
          .eq('tenant_id', currentTenantId);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e, stack) {
      handleError(e, stack, 'getTypeRows');
      rethrow;
    }
  }

  Future<List<AttendanceType>> getTypes() async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select()
          .eq('tenant_id', currentTenantId)
          .order('index', ascending: true);

      return (response as List)
          .map((json) => AttendanceType.fromJson(json))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getTypes');
      return [];
    }
  }

  /// Get a single attendance type by ID
  Future<AttendanceType?> getTypeById(String id) async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select()
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .single();

      return AttendanceType.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getTypeById');
      return null;
    }
  }

  /// LOGIC_SETTINGS: Insert payload for a new attendance type, matching
  /// Ionic `addAttendanceType` (type.page.ts isNew defaults):
  /// - `default_status` / `available_statuses` are NUMERIC (DB columns are
  ///   `number` / `number[]`), never the enum names.
  /// - `relevant_groups` is always a list (`[]`), never null.
  /// - `default_plan` is always `{time, end, fields: []}`, never null.
  /// - `reminders` defaults to `[]`, `index` to the given index (Ionic: 999).
  static Map<String, dynamic> buildInsertData(
    AttendanceType type,
    int tenantId,
  ) {
    return {
      'name': type.name,
      'planning_title': type.planningTitle ?? '',
      'tenant_id': tenantId,
      'default_status': type.defaultStatus.value,
      'available_statuses':
          (type.availableStatuses ?? const []).map((s) => s.value).toList(),
      'default_plan': type.defaultPlan ??
          <String, dynamic>{'time': '', 'end': '', 'fields': <dynamic>[]},
      'relevant_groups': type.relevantGroups ?? <int>[],
      'start_time': type.startTime,
      'end_time': type.endTime,
      'manage_songs': type.manageSongs,
      'visible': type.visible,
      'color': type.color,
      'highlight': type.highlight,
      'hide_name': type.hideName,
      'include_in_average': type.includeInAverage,
      'all_day': type.allDay,
      'duration_days': type.durationDays,
      'notification': type.notification,
      'reminders': type.reminders ?? <int>[],
      'additional_fields_filter': type.additionalFieldsFilter,
      'checklist': type.checklist?.map((c) => c.toJson()).toList(),
      'index': type.index ?? 999,
    };
  }

  /// Create a new attendance type.
  /// LOGIC_SETTINGS: errors are rethrown (Ionic throws after `svc.addTypeFailed`)
  /// so callers never report success for a failed insert.
  Future<AttendanceType> createType(AttendanceType type) async {
    ensureNotDemo('createType'); // DEMO_GUARD
    try {
      final data = buildInsertData(type, currentTenantId);

      final response = await supabase
          .from('attendance_types')
          .insert(data)
          .select()
          .single();

      return AttendanceType.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createType');
      rethrow;
    }
  }

  /// Ionic `createType` from the type page (isNew): inserts the columns as
  /// edited on the page. The tenant is set here and cannot be overridden.
  Future<AttendanceType> createTypeFromData(Map<String, dynamic> data) async {
    ensureNotDemo('createType'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('attendance_types')
          .insert({...data, 'tenant_id': currentTenantId})
          .select()
          .single();

      return AttendanceType.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createTypeFromData');
      rethrow;
    }
  }

  /// Beta "Neue Terminart › Startet wie": a new type named [name] with all
  /// columns of [templateId] (plan, checklist, reminders, duty, protocol,
  /// sign-up questions …), offered for new Termine and at the end of the
  /// list. Ort and Werke are on: the Beta offers them at every Termin.
  Future<AttendanceType> copyType(String templateId, String name) async {
    ensureNotDemo('createType'); // DEMO_GUARD
    try {
      final row = await supabase
          .from('attendance_types')
          .select('*')
          .eq('id', templateId)
          .eq('tenant_id', currentTenantId)
          .single();
      final data = Map<String, dynamic>.from(row)
        ..remove('id')
        ..remove('created_at')
        ..remove('is_default_org_plan');
      final response = await supabase
          .from('attendance_types')
          .insert({
            ...data,
            'name': name.trim(),
            'visible': true,
            'index': 999,
            'place_enabled': true,
            'manage_songs': true,
            'tenant_id': currentTenantId,
          })
          .select()
          .single();
      return AttendanceType.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'copyType');
      rethrow;
    }
  }

  /// Update an attendance type
  Future<AttendanceType?> updateType(String id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateType'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('attendance_types')
          .update(updates)
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select()
          .single();

      return AttendanceType.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateType');
      return null;
    }
  }

  /// SETTINGS2: `planning_prefix_instance_name` ("Instanz-Name vor Werken").
  /// Not part of the shared AttendanceType model, so read it directly.
  Future<bool> getPlanningPrefixInstanceName(String typeId) async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select('planning_prefix_instance_name')
          .eq('id', typeId)
          .eq('tenant_id', currentTenantId)
          .maybeSingle();
      return response?['planning_prefix_instance_name'] == true;
    } catch (e, stack) {
      handleError(e, stack, 'getPlanningPrefixInstanceName');
      return false;
    }
  }

  /// Check if attendance type is used by any attendances
  Future<int> getAttendanceCountForType(String typeId) async {
    try {
      final response = await supabase
          .from('attendance')
          .select('id')
          .eq('type_id', typeId)
          .eq('tenantId', currentTenantId);

      return (response as List).length;
    } catch (e, stack) {
      handleError(e, stack, 'getAttendanceCountForType');
      return -1;
    }
  }

  /// Delete an attendance type.
  /// Ionic attendance-type.service deleteAttendanceType deletes without a
  /// pre-check; the dialog tells that the Termine of this type go with it.
  Future<bool> deleteType(String id) async {
    ensureNotDemo('deleteType'); // DEMO_GUARD
    try {
      await supabase
          .from('attendance_types')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId);

      return true;
    } catch (e, stack) {
      handleError(e, stack, 'deleteType');
      return false;
    }
  }

  /// Reorder attendance types
  Future<bool> reorderTypes(List<String> orderedIds) async {
    ensureNotDemo('reorderTypes'); // DEMO_GUARD
    try {
      // Update each type's index based on its position in the list
      for (int i = 0; i < orderedIds.length; i++) {
        await supabase
            .from('attendance_types')
            .update({'index': i})
            .eq('id', orderedIds[i])
            .eq('tenant_id', currentTenantId);
      }
      return true;
    } catch (e, stack) {
      handleError(e, stack, 'reorderTypes');
      return false;
    }
  }
}

/// Provider for AttendanceTypeRepository
final attendanceTypeRepositoryProvider = Provider<AttendanceTypeRepository>((ref) {
  return AttendanceTypeRepository(ref);
});
