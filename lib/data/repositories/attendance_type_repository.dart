import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance/attendance.dart';
import 'base_repository.dart';

/// Repository for AttendanceType CRUD operations
class AttendanceTypeRepository extends BaseRepository with TenantAwareRepository {
  AttendanceTypeRepository(super.ref);

  /// Get all attendance types for current tenant, ordered by index
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

  /// Create a new attendance type
  Future<AttendanceType?> createType(AttendanceType type) async {
    ensureNotDemo('createType'); // DEMO_GUARD
    try {
      // Get max index first
      final maxIndexResponse = await supabase
          .from('attendance_types')
          .select('index')
          .eq('tenant_id', currentTenantId)
          .order('index', ascending: false)
          .limit(1);

      final maxIndex = (maxIndexResponse as List).isNotEmpty
          ? (maxIndexResponse[0]['index'] as int? ?? 0)
          : 0;

      final data = {
        'name': type.name,
        'tenant_id': currentTenantId,
        'default_status': type.defaultStatus.name,
        'available_statuses': type.availableStatuses?.map((s) => s.name).toList(),
        'default_plan': type.defaultPlan,
        'relevant_groups': type.relevantGroups,
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
        'reminders': type.reminders,
        'additional_fields_filter': type.additionalFieldsFilter,
        'checklist': type.checklist?.map((c) => c.toJson()).toList(),
        'index': maxIndex + 1,
      };

      final response = await supabase
          .from('attendance_types')
          .insert(data)
          .select()
          .single();

      return AttendanceType.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createType');
      return null;
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

  /// Delete an attendance type
  /// BL-009: Checks for references before deletion
  Future<bool> deleteType(String id) async {
    ensureNotDemo('deleteType'); // DEMO_GUARD
    try {
      // BL-009: Check for attendances using this type
      final usageCount = await getAttendanceCountForType(id);
      if (usageCount > 0) {
        throw RepositoryException(
          message: 'Typ kann nicht gelöscht werden: Wird von $usageCount Anwesenheit(en) verwendet',
          operation: 'deleteType',
          code: 'FK_VIOLATION',
        );
      }

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
