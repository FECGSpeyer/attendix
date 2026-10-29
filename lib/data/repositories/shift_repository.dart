import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../models/shift/shift_plan.dart';
import 'base_repository.dart';

/// Provider for ShiftRepository
final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(ref);
});

/// Repository for shift plan operations
class ShiftRepository extends BaseRepository with TenantAwareRepository {
  ShiftRepository(super.ref);

  /// Get all shift plans for the current tenant
  Future<List<ShiftPlan>> getShifts() async {
    try {
      final response = await supabase
          .from(SupabaseTable.shiftPlans.tableName)
          .select('*')
          .eq('tenant_id', currentTenantId)
          .order('name');

      return (response as List)
          .map((e) => ShiftPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getShifts');
      rethrow;
    }
  }

  /// Get a single shift plan by ID
  Future<ShiftPlan?> getShiftById(String id) async {
    try {
      final response = await supabase
          .from(SupabaseTable.shiftPlans.tableName)
          .select('*')
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return ShiftPlan.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getShiftById');
      rethrow;
    }
  }

  /// Create a new shift plan
  Future<ShiftPlan> createShift(ShiftPlan plan) async {
    ensureNotDemo('createShift'); // DEMO_GUARD
    try {
      final data = plan.toJson();
      // Remove read-only fields
      data.remove('id');
      data.remove('created_at');
      // Set tenant_id
      data['tenant_id'] = currentTenantId;

      final response = await supabase
          .from(SupabaseTable.shiftPlans.tableName)
          .insert(data)
          .select()
          .single();

      return ShiftPlan.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createShift');
      rethrow;
    }
  }

  /// Update a shift plan
  Future<ShiftPlan> updateShift(ShiftPlan plan) async {
    ensureNotDemo('updateShift'); // DEMO_GUARD
    try {
      if (plan.id == null) {
        throw RepositoryException(
          message: 'Shift ID is required for update',
          operation: 'updateShift',
        );
      }

      final data = plan.toJson();
      // Remove read-only fields
      data.remove('id');
      data.remove('created_at');
      data.remove('tenant_id');

      final response = await supabase
          .from(SupabaseTable.shiftPlans.tableName)
          .update(data)
          .eq('id', plan.id!)
          .eq('tenant_id', currentTenantId)
          .select()
          .single();

      return ShiftPlan.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateShift');
      rethrow;
    }
  }

  /// Delete a shift plan
  Future<void> deleteShift(String id) async {
    ensureNotDemo('deleteShift'); // DEMO_GUARD
    try {
      await supabase
          .from(SupabaseTable.shiftPlans.tableName)
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteShift');
      rethrow;
    }
  }

  /// Check if a shift plan is used by any players
  Future<bool> isShiftUsed(String id) async {
    try {
      final response = await supabase
          .from(SupabaseTable.player.tableName)
          .select('id')
          .eq('shift_id', id)
          .eq('tenantId', currentTenantId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e, stack) {
      handleError(e, stack, 'isShiftUsed');
      rethrow;
    }
  }

  /// Get count of players using a shift plan
  Future<int> getShiftUsageCount(String id) async {
    try {
      final response = await supabase
          .from(SupabaseTable.player.tableName)
          .select('id')
          .eq('shift_id', id)
          .eq('tenantId', currentTenantId);

      return (response as List).length;
    } catch (e, stack) {
      handleError(e, stack, 'getShiftUsageCount');
      rethrow;
    }
  }
}
