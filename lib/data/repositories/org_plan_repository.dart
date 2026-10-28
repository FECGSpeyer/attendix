import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organisation/organisation.dart';
import '../models/plan/plan.dart';
import 'base_repository.dart';

/// Provider for OrgPlanRepository
final orgPlanRepositoryProvider = Provider<OrgPlanRepository>((ref) {
  return OrgPlanRepository(ref);
});

/// Organisation-level planning (ORG_PLANS package).
///
/// Organisations (`tenant_groups`) span several instances, so these queries
/// are scoped by organisation id instead of a single tenantId:
/// - tenant_groups: filtered by `id` = organisation id
/// - tenant_group_tenants / shared_plans / tenant_group_person_fields: filtered
///   by the organisation id (`tenant_group` / `org_id`)
/// - attendance: filtered with `.inFilter('tenantId', <instances of the org>)`
///   and `is_org_plan = true`
/// RLS additionally restricts all of these to org admins/responsibles.
class OrgPlanRepository extends BaseRepository {
  OrgPlanRepository(super.ref);

  /// Instances of the organisation with their long names.
  Future<Map<int, String>> getOrgTenantNames(int orgId) async {
    try {
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant_id, tenant:tenant_id(longName)')
          .eq('tenant_group', orgId);

      final result = <int, String>{};
      for (final row in response as List) {
        final id = row['tenant_id'];
        if (id is int) {
          final tenant = row['tenant'];
          result[id] = tenant is Map ? (tenant['longName'] as String? ?? '') : '';
        }
      }
      return result;
    } catch (e, stack) {
      handleError(e, stack, 'getOrgTenantNames');
      rethrow;
    }
  }

  /// All Termine of the organisation's instances flagged as org plan.
  Future<List<PlanAttendance>> getOrgPlans(int orgId) async {
    try {
      final names = await getOrgTenantNames(orgId);
      final tenantIds = names.keys.toList();
      if (tenantIds.isEmpty) return [];

      final response = await supabase
          .from('attendance')
          .select('id, date, duration_days, plan, extra_plans, typeInfo, type_id, tenantId, is_org_plan')
          .inFilter('tenantId', tenantIds)
          .eq('is_org_plan', true)
          .not('plan', 'is', null)
          .order('date', ascending: true);

      return (response as List).map((e) {
        final att = PlanAttendance.fromJson(e as Map<String, dynamic>);
        return att.copyWith(tenantName: names[att.tenantId] ?? '');
      }).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getOrgPlans');
      rethrow;
    }
  }

  /// Ad-hoc plans added to the organisation.
  Future<List<SharedPlan>> getAdHocOrgPlans(int orgId) async {
    try {
      final response = await supabase
          .from('shared_plans')
          .select('*')
          .eq('org_id', orgId)
          .order('date', ascending: true);

      return (response as List)
          .map((e) => SharedPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAdHocOrgPlans');
      rethrow;
    }
  }

  /// Deletes an ad-hoc org plan.
  Future<void> deleteAdHocOrgPlan(int orgId, String planId) async {
    try {
      await supabase
          .from('shared_plans')
          .delete()
          .eq('id', planId)
          .eq('org_id', orgId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteAdHocOrgPlan');
      rethrow;
    }
  }

  /// Creates a new public link key (16 hex chars).
  Future<String> generatePublicPlanKey(int orgId, String key) async {
    try {
      await supabase
          .from('tenant_groups')
          .update({'public_plan_key': key})
          .eq('id', orgId);
      return key;
    } catch (e, stack) {
      handleError(e, stack, 'generatePublicPlanKey');
      rethrow;
    }
  }

  Future<void> revokePublicPlanKey(int orgId) async {
    try {
      await supabase
          .from('tenant_groups')
          .update({'public_plan_key': null})
          .eq('id', orgId);
    } catch (e, stack) {
      handleError(e, stack, 'revokePublicPlanKey');
      rethrow;
    }
  }

  Future<Organisation> updateOrganisation(int orgId, Map<String, dynamic> updates) async {
    ensureNotDemo('updateOrganisation'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('tenant_groups')
          .update(updates)
          .eq('id', orgId)
          .select()
          .single();
      return Organisation.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateOrganisation');
      rethrow;
    }
  }

  Future<Organisation> updatePlanningTemplates(int orgId, List<Plan> templates) =>
      updateOrganisation(orgId, {'planning_templates': templates.map((t) => t.toJson()).toList()});

  Future<Organisation> updateDefaultFields(int orgId, List<PlanField> fields) =>
      updateOrganisation(orgId, {'default_fields': fields.map((f) => f.toJson()).toList()});

  Future<Organisation> updateOrgName(int orgId, String name) =>
      updateOrganisation(orgId, {'name': name});

  Future<Organisation> updateOrgExtraFields(int orgId, List<OrgExtraField> fields) =>
      updateOrganisation(orgId, {'additional_fields': fields.map((f) => f.toJson()).toList()});

  // ---------------------------------------------------------------------------
  // Shared person field values (tenant_group_person_fields)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getPersonFieldValues(int orgId, String personKey) async {
    try {
      final response = await supabase
          .from('tenant_group_person_fields')
          .select('field_id, value')
          .eq('tenant_group', orgId)
          .eq('person_key', personKey);

      return {
        for (final row in response as List) row['field_id'] as String: row['value'],
      };
    } catch (e, stack) {
      handleError(e, stack, 'getPersonFieldValues');
      rethrow;
    }
  }

  Future<void> updatePersonFieldValues(int orgId, String personKey, Map<String, dynamic> values) async {
    if (values.isEmpty) return;
    try {
      final rows = values.entries
          .map((e) => {
                'tenant_group': orgId,
                'person_key': personKey,
                'field_id': e.key,
                'value': e.value,
              })
          .toList();
      await supabase
          .from('tenant_group_person_fields')
          .upsert(rows, onConflict: 'tenant_group,person_key,field_id');
    } catch (e, stack) {
      handleError(e, stack, 'updatePersonFieldValues');
      rethrow;
    }
  }

  Future<void> deletePersonFieldValues(int orgId, List<String> fieldIds) async {
    if (fieldIds.isEmpty) return;
    try {
      await supabase
          .from('tenant_group_person_fields')
          .delete()
          .eq('tenant_group', orgId)
          .inFilter('field_id', fieldIds);
    } catch (e, stack) {
      handleError(e, stack, 'deletePersonFieldValues');
      rethrow;
    }
  }

  /// `global:<id>` for linked persons, `app:<uuid>` for accounts (Ionic getOrganisationPersonKey).
  static String? personKey({int? globalPersonId, String? appId}) {
    if (globalPersonId != null) return 'global:$globalPersonId';
    if (appId != null && appId.isNotEmpty) return 'app:$appId';
    return null;
  }
}
