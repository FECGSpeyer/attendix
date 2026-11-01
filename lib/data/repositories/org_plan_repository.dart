import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organisation/organisation.dart';
import '../models/plan/plan.dart';
import 'base_repository.dart';

/// Provider for OrgPlanRepository
final orgPlanRepositoryProvider = Provider<OrgPlanRepository>((ref) {
  return OrgPlanRepository(ref);
});

/// An org plan Termin with the name and colour of its Termin type
/// (`attType:type_id(name, color)`), for the Live Activity.
typedef OrgLiveAttendance = ({
  PlanAttendance attendance,
  String typeName,
  String? typeColor,
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

  /// LIVE_ACTIVITY (Ionic 4.17.8 `addOrgPlans`): org plan Termine of the
  /// organisation's instances dated within [[from], [to]], with the name and
  /// colour of their Termin type.
  Future<List<OrgLiveAttendance>> getOrgLiveAttendancesBetween(
    int orgId,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final links = await supabase
          .from('tenant_group_tenants')
          .select('tenant_id')
          .eq('tenant_group', orgId);
      final tenantIds = (links as List)
          .map((l) => (l as Map)['tenant_id'])
          .whereType<int>()
          .toList();
      if (tenantIds.isEmpty) return [];

      final response = await supabase
          .from('attendance')
          .select('id, date, plan, typeInfo, attType:type_id(name, color)')
          .inFilter('tenantId', tenantIds)
          .eq('is_org_plan', true)
          .gte('date', from.toUtc().toIso8601String())
          .lte('date', to.toUtc().toIso8601String())
          .not('plan', 'is', null);

      return (response as List).map((e) {
        final row = e as Map<String, dynamic>;
        final type = row['attType'];
        return (
          attendance: PlanAttendance.fromJson(row),
          typeName: type is Map ? (type['name'] as String? ?? '') : '',
          typeColor: type is Map ? type['color'] as String? : null,
        );
      }).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getOrgLiveAttendancesBetween');
      rethrow;
    }
  }

  /// LIVE_ACTIVITY: ad-hoc plans of the organisation dated within
  /// [[fromDate], [toDate]] ("YYYY-MM-DD").
  Future<List<SharedPlan>> getAdHocOrgPlansBetween(
    int orgId,
    String fromDate,
    String toDate,
  ) async {
    try {
      final response = await supabase
          .from('shared_plans')
          .select('*')
          .eq('org_id', orgId)
          .gte('date', fromDate)
          .lte('date', toDate);

      return (response as List)
          .map((e) => SharedPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAdHocOrgPlansBetween');
      rethrow;
    }
  }

  /// One ad-hoc plan of the organisation (tap on its Live Activity).
  Future<SharedPlan?> getAdHocOrgPlan(int orgId, String planId) async {
    try {
      final response = await supabase
          .from('shared_plans')
          .select('*')
          .eq('id', planId)
          .eq('org_id', orgId)
          .maybeSingle();
      return response == null ? null : SharedPlan.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getAdHocOrgPlan');
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

  /// Gemeinde App link settings (Ionic 4.17.10 `updateOrgGemeindeApp`):
  /// `beamer_files_enabled`, `gemeinde_app_key_hash`, `gemeinde_app_key_hint`.
  /// Only these columns are accepted; scoped by the organisation id.
  Future<Organisation> updateOrgGemeindeApp(int orgId, Map<String, dynamic> updates) {
    const allowed = {'beamer_files_enabled', 'gemeinde_app_key_hash', 'gemeinde_app_key_hint'};
    return updateOrganisation(orgId, {
      for (final e in updates.entries)
        if (allowed.contains(e.key)) e.key: e.value,
    });
  }

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
