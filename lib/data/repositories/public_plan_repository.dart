import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan/plan.dart';
import 'base_repository.dart';

/// Provider for PublicPlanRepository
final publicPlanRepositoryProvider = Provider<PublicPlanRepository>((ref) {
  return PublicPlanRepository(ref);
});

/// Organisation found by its public plan key.
class PublicOrg {
  const PublicOrg({required this.id, required this.name});
  final int id;
  final String name;
}

/// Public plan access without login (routes /plan, /planung, /org-plan).
///
/// There is no tenant context here. Every query is scoped by a secret key
/// instead of tenantId:
/// - attendance: `.eq('id', id).eq('share_key', key)` (edits additionally
///   require `share_edit_key`)
/// - shared_plans: the row id IS the access token; edits require `edit_key`
/// - tenant_groups: `.eq('public_plan_key', key)`; org plans are then read
///   with `.inFilter('tenantId', <instances of that org>)` + `is_org_plan`
///
/// Edit keys (`attendance.share_edit_key`, `shared_plans.edit_key`) are NEVER
/// selected in a public read path: a viewer could otherwise rebuild the edit
/// link. Edit mode is verified with [verifySharedAttendanceEditKey] /
/// [verifySharedPlanEditKey], which filter by id AND the key from the URL and
/// only return whether a row matched.
class PublicPlanRepository extends BaseRepository {
  PublicPlanRepository(super.ref);

  static const String _sharedAttendanceColumns =
      'id, date, duration_days, plan, extra_plans, type_id, typeInfo';

  /// Public columns of `shared_plans` (everything except `edit_key`).
  static const String _sharedPlanColumns =
      'id, plan_title, date, time, end_time, fields, branding_id, creator_user_id, created_at, org_id';

  /// Columns that must never reach a public viewer (realtime payloads included).
  static const Set<String> _secretColumns = {'share_key', 'share_edit_key', 'edit_key'};

  /// Removes edit/share keys from a row before it is handed to the UI.
  static Map<String, dynamic> stripSecrets(Map<String, dynamic> row) =>
      Map<String, dynamic>.fromEntries(row.entries.where((e) => !_secretColumns.contains(e.key)));

  /// `SharedPlan.editKey` is required by the model; public reads never load it.
  static SharedPlan _sharedPlanFromPublicRow(Map<String, dynamic> row) =>
      SharedPlan.fromJson({...stripSecrets(row), 'edit_key': ''});

  /// A Termin shared with `share_key`.
  Future<PlanAttendance?> getSharedAttendancePlan(int id, String key) async {
    try {
      final response = await supabase
          .from('attendance')
          .select(_sharedAttendanceColumns)
          .eq('id', id)
          .eq('share_key', key)
          .maybeSingle();
      if (response == null) return null;
      return PlanAttendance.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getSharedAttendancePlan');
      rethrow;
    }
  }

  /// Whether [editKey] is the edit key of the shared Termin [id]/[key].
  ///
  /// The key is compared server side (filter on id + share_key +
  /// share_edit_key) and never read back.
  Future<bool> verifySharedAttendanceEditKey(int id, String key, String editKey) async {
    if (editKey.isEmpty) return false;
    try {
      final response = await supabase
          .from('attendance')
          .select('id')
          .eq('id', id)
          .eq('share_key', key)
          .eq('share_edit_key', editKey)
          .maybeSingle();
      return response != null;
    } catch (e, stack) {
      handleError(e, stack, 'verifySharedAttendanceEditKey');
      rethrow;
    }
  }

  /// Saves edits of a shared Termin plan (edit link).
  Future<void> updateSharedAttendancePlan(
    int id,
    String key,
    String editKey,
    Map<String, dynamic> planColumns,
  ) async {
    try {
      final data = Map<String, dynamic>.fromEntries(
        planColumns.entries.where((e) => e.key == 'plan' || e.key == 'extra_plans'),
      );
      await supabase
          .from('attendance')
          .update(data)
          .eq('id', id)
          .eq('share_key', key)
          .eq('share_edit_key', editKey);
    } catch (e, stack) {
      handleError(e, stack, 'updateSharedAttendancePlan');
      rethrow;
    }
  }

  /// An ad-hoc plan by its id (= key).
  Future<SharedPlan?> getSharedPlan(String key) async {
    try {
      final response = await supabase
          .from('shared_plans')
          .select(_sharedPlanColumns)
          .eq('id', key)
          .maybeSingle();
      if (response == null) return null;
      return _sharedPlanFromPublicRow(response);
    } catch (e, stack) {
      handleError(e, stack, 'getSharedPlan');
      rethrow;
    }
  }

  /// Whether [editKey] is the edit key of the ad-hoc plan [key].
  ///
  /// Compared server side (filter on id + edit_key), never read back.
  Future<bool> verifySharedPlanEditKey(String key, String editKey) async {
    if (editKey.isEmpty) return false;
    try {
      final response = await supabase
          .from('shared_plans')
          .select('id')
          .eq('id', key)
          .eq('edit_key', editKey)
          .maybeSingle();
      return response != null;
    } catch (e, stack) {
      handleError(e, stack, 'verifySharedPlanEditKey');
      rethrow;
    }
  }

  /// Saves edits of an ad-hoc plan (edit link).
  Future<void> updateSharedPlan(String key, String editKey, {required List<PlanField> fields, String? title, String? time}) async {
    try {
      await supabase
          .from('shared_plans')
          .update({
            'fields': fields.map((f) => f.toJson()).toList(),
            if (title != null) 'plan_title': title,
            if (time != null) 'time': time,
          })
          .eq('id', key)
          .eq('edit_key', editKey);
    } catch (e, stack) {
      handleError(e, stack, 'updateSharedPlan');
      rethrow;
    }
  }

  /// Anonymous one-off share from /planung (no creator).
  Future<void> insertAnonymousSharedPlan(SharedPlan plan) async {
    try {
      final data = plan.toJson()
        ..remove('creator_user_id')
        ..remove('created_at')
        ..remove('org_id');
      await supabase.from('shared_plans').insert(data);
    } catch (e, stack) {
      handleError(e, stack, 'insertAnonymousSharedPlan');
      rethrow;
    }
  }

  /// Organisation with this public plan key.
  Future<PublicOrg?> getOrgByPublicKey(String key) async {
    try {
      final response = await supabase
          .from('tenant_groups')
          .select('id, name')
          .eq('public_plan_key', key)
          .maybeSingle();
      if (response == null) return null;
      return PublicOrg(id: response['id'] as int, name: response['name'] as String? ?? '');
    } catch (e, stack) {
      handleError(e, stack, 'getOrgByPublicKey');
      rethrow;
    }
  }

  /// All public plans of an organisation (Termine flagged as org plan + ad-hoc org plans).
  Future<({List<PlanAttendance> attendances, List<SharedPlan> adHoc})> getPublicOrgPlans(int orgId) async {
    try {
      final tgts = await supabase
          .from('tenant_group_tenants')
          .select('tenant_id, tenant:tenant_id(longName)')
          .eq('tenant_group', orgId);

      final names = <int, String>{};
      for (final row in tgts as List) {
        final id = row['tenant_id'];
        if (id is int) {
          final tenant = row['tenant'];
          names[id] = tenant is Map ? (tenant['longName'] as String? ?? '') : '';
        }
      }

      var attendances = <PlanAttendance>[];
      if (names.isNotEmpty) {
        final rows = await supabase
            .from('attendance')
            .select('id, date, plan, typeInfo, tenantId')
            .inFilter('tenantId', names.keys.toList())
            .eq('is_org_plan', true)
            .not('plan', 'is', null)
            .order('date', ascending: true);
        attendances = (rows as List).map((e) {
          final att = PlanAttendance.fromJson(e as Map<String, dynamic>);
          return att.copyWith(tenantName: names[att.tenantId] ?? '');
        }).toList();
      }

      final adHocRows = await supabase
          .from('shared_plans')
          .select(_sharedPlanColumns)
          .eq('org_id', orgId)
          .order('date', ascending: true);
      final adHoc = (adHocRows as List)
          .map((e) => _sharedPlanFromPublicRow(e as Map<String, dynamic>))
          .toList();

      return (attendances: attendances, adHoc: adHoc);
    } catch (e, stack) {
      handleError(e, stack, 'getPublicOrgPlans');
      rethrow;
    }
  }

  /// Live updates of a shared Termin plan (edit link).
  ///
  /// No tenant context: the channel is filtered by the attendance row id,
  /// which the caller only knows together with its share key.
  ///
  /// SOL_FIX7: a `postgres_changes` payload is the FULL row (incl.
  /// `share_key` / `share_edit_key`) — [stripSecrets] only hides them from the
  /// UI, they are still on the WebSocket. Only call this after the viewer's
  /// edit key was verified (it then only carries keys the viewer already
  /// has). Read-only public pages poll the whitelisted selects instead; see
  /// docs/security-public-plans.md.
  RealtimeChannel watchSharedAttendancePlan(int id, void Function(Map<String, dynamic> row) onUpdate) {
    return supabase
        .channel('shared-att-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'attendance',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: id),
          callback: (payload) => onUpdate(stripSecrets(payload.newRecord)),
        )
        .subscribe();
  }

  /// Live updates of an ad-hoc plan (edit link); filtered by its key (row id).
  ///
  /// SOL_FIX7: the payload contains `edit_key` — only for viewers whose edit
  /// key was verified (see [watchSharedAttendancePlan]).
  RealtimeChannel watchSharedPlan(String key, void Function(Map<String, dynamic> row) onUpdate) {
    return supabase
        .channel('shared-plan-$key')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'shared_plans',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: key),
          callback: (payload) => onUpdate(stripSecrets(payload.newRecord)),
        )
        .subscribe();
  }

  /// Stops a channel from [watchSharedAttendancePlan] / [watchSharedPlan].
  Future<void> unwatch(RealtimeChannel channel) async {
    try {
      await supabase.removeChannel(channel);
    } catch (_) {}
  }
}
