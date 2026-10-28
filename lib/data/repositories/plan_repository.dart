import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan/plan.dart';
import 'base_repository.dart';

/// Provider for PlanRepository (without tenant; use planRepositoryWithTenantProvider)
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref);
});

/// Columns of `attendance` needed for the plan editor / viewer.
const String planAttendanceColumns =
    'id, tenantId, date, duration_days, plan, extra_plans, type_id, typeInfo, type, '
    'start_time, notes, share_plan, is_org_plan, share_key, share_edit_key';

/// Repository for Ablaufpläne of the current instance (ORG_PLANS package).
///
/// Tables:
/// - attendance (`tenantId`): plan, extra_plans, share flags
/// - attendance_types (`tenant_id`): default_plan, is_default_org_plan
/// - tenants (`id` = tenant): plan_block_templates
/// - shared_plans: ad-hoc plans, owned by `creator_user_id` (no tenant column)
class PlanRepository extends BaseRepository with TenantAwareRepository {
  PlanRepository(super.ref);

  /// Columns that may be changed through [updateAttendancePlanFields].
  static const Set<String> _allowedAttendanceKeys = {
    'plan',
    'extra_plans',
    'share_plan',
    'is_org_plan',
    'share_key',
    'share_edit_key',
  };

  // ---------------------------------------------------------------------------
  // Attendance plans
  // ---------------------------------------------------------------------------

  /// Termine of the instance since [since] (newest first), like Ionic
  /// `db.getAttendance()` (`gt('date', getCurrentAttDate())`: season start,
  /// fallback 2023-01-01).
  Future<List<PlanAttendance>> getPlanAttendances({required String since}) async {
    try {
      final response = await supabase
          .from('attendance')
          .select(planAttendanceColumns)
          .eq('tenantId', currentTenantId)
          .gt('date', since)
          .order('date', ascending: false);

      return (response as List)
          .map((e) => PlanAttendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlanAttendances');
      rethrow;
    }
  }

  /// One Termin with its plans.
  Future<PlanAttendance?> getPlanAttendanceById(int id) async {
    try {
      final response = await supabase
          .from('attendance')
          .select(planAttendanceColumns)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return PlanAttendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getPlanAttendanceById');
      rethrow;
    }
  }

  /// Updates plan related columns of a Termin (plan, extra_plans, share flags).
  Future<PlanAttendance> updateAttendancePlanFields(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateAttendancePlanFields'); // DEMO_GUARD
    try {
      final data = Map<String, dynamic>.fromEntries(
        updates.entries.where((e) => _allowedAttendanceKeys.contains(e.key)),
      );
      if (data.isEmpty) {
        throw const RepositoryException(
          message: 'No plan fields to update',
          operation: 'updateAttendancePlanFields',
        );
      }

      final response = await supabase
          .from('attendance')
          .update(data)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .select(planAttendanceColumns)
          .maybeSingle();

      if (response == null) {
        throw const RepositoryException(
          message: 'Attendance not found or belongs to different tenant',
          operation: 'updateAttendancePlanFields',
        );
      }
      return PlanAttendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateAttendancePlanFields');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Attendance types (planning settings)
  // ---------------------------------------------------------------------------

  Future<List<PlanAttendanceType>> getPlanAttendanceTypes() async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select('*')
          .eq('tenant_id', currentTenantId)
          .order('index');

      return (response as List)
          .map((e) => PlanAttendanceType.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlanAttendanceTypes');
      rethrow;
    }
  }

  /// Sets `attendance_types.is_default_org_plan`.
  Future<void> setTypeDefaultOrgPlan(String typeId, bool value) async {
    ensureNotDemo('setTypeDefaultOrgPlan'); // DEMO_GUARD
    try {
      await supabase
          .from('attendance_types')
          .update({'is_default_org_plan': value})
          .eq('id', typeId)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'setTypeDefaultOrgPlan');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Plan block templates (tenants.plan_block_templates)
  // ---------------------------------------------------------------------------

  /// The `tenants` table has no tenantId column; the row id IS the tenant id.
  Future<List<PlanBlockTemplate>> getBlockTemplates() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('plan_block_templates')
          .eq('id', currentTenantId)
          .maybeSingle();

      final raw = response?['plan_block_templates'];
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PlanBlockTemplate.fromJson)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getBlockTemplates');
      rethrow;
    }
  }

  /// Saves all block templates (admins only, enforced by RLS `admins_update_tenants`).
  Future<void> saveBlockTemplates(List<PlanBlockTemplate> templates) async {
    ensureNotDemo('saveBlockTemplates'); // DEMO_GUARD
    try {
      // tenants: filter by its own id (= currentTenantId)
      await supabase
          .from('tenants')
          .update({'plan_block_templates': templates.map((t) => t.toJson()).toList()})
          .eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'saveBlockTemplates');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Ad-hoc plans of the current user (shared_plans)
  // ---------------------------------------------------------------------------

  /// shared_plans has no tenant column; plans are owned by `creator_user_id`.
  Future<List<SharedPlan>> getMySharedPlans() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final response = await supabase
          .from('shared_plans')
          .select('*')
          .eq('creator_user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => SharedPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getMySharedPlans');
      rethrow;
    }
  }

  /// Creates or updates an ad-hoc plan owned by the current user.
  Future<void> upsertMySharedPlan(SharedPlan plan) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw const RepositoryException(message: 'User not authenticated', operation: 'upsertMySharedPlan');
      }
      final data = plan.copyWith(creatorUserId: userId).toJson()
        ..remove('created_at')
        ..remove('org_id');
      await supabase.from('shared_plans').upsert(data, onConflict: 'id');
    } catch (e, stack) {
      handleError(e, stack, 'upsertMySharedPlan');
      rethrow;
    }
  }

  /// Deletes an ad-hoc plan of the current user.
  Future<void> deleteMySharedPlan(String id) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('shared_plans')
          .delete()
          .eq('id', id)
          .eq('creator_user_id', userId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteMySharedPlan');
      rethrow;
    }
  }

  /// Adds an ad-hoc plan of the current user to an organisation (or removes it with null).
  Future<void> setMySharedPlanOrg(String id, int? orgId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('shared_plans')
          .update({'org_id': orgId})
          .eq('id', id)
          .eq('creator_user_id', userId);
    } catch (e, stack) {
      handleError(e, stack, 'setMySharedPlanOrg');
      rethrow;
    }
  }
}
