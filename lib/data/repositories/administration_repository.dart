import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard/dashboard_models.dart';
import 'base_repository.dart';

/// Provider for AdministrationRepository
final administrationRepositoryProvider =
    Provider<AdministrationRepository>((ref) {
  return AdministrationRepository(ref);
});

/// Provider for UsageDashboardRepository
final usageDashboardRepositoryProvider =
    Provider<UsageDashboardRepository>((ref) {
  return UsageDashboardRepository(ref);
});

/// Super-developer administration of the CURRENT tenant
/// (Ionic `settings/administration`): Dateiablage storage quota.
///
/// The `tenants` table has no `tenantId` column; rows are scoped by
/// `id` = current tenant id. Changing `files_max_bytes` is additionally
/// protected server-side by the `protect_tenant_files_flags` trigger
/// (only developer@attendix.de).
class AdministrationRepository extends BaseRepository
    with TenantAwareRepository {
  AdministrationRepository(super.ref);

  /// Storage limit in bytes; `null` = unlimited.
  Future<int?> getFilesMaxBytes() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('files_max_bytes')
          .eq('id', currentTenantId)
          .maybeSingle();
      final value = response?['files_max_bytes'];
      return value is num ? value.toInt() : null;
    } catch (e, stack) {
      handleError(e, stack, 'getFilesMaxBytes');
      rethrow;
    }
  }

  /// Sets the storage limit in bytes (`null` = unlimited).
  Future<void> updateFilesMaxBytes(int? bytes) async {
    try {
      await supabase
          .from('tenants')
          .update({'files_max_bytes': bytes})
          .eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateFilesMaxBytes');
      rethrow;
    }
  }

  /// Bytes currently used in the `files` bucket (RPC `files_used_bytes`).
  Future<int> getFilesUsedBytes() async {
    try {
      final result = await supabase.rpc(
        'files_used_bytes',
        params: {'p_tenant_id': currentTenantId},
      );
      if (result is num) return result.toInt();
      return int.tryParse(result?.toString() ?? '') ?? 0;
    } catch (e, stack) {
      handleError(e, stack, 'getFilesUsedBytes');
      rethrow;
    }
  }
}

/// Aggregated usage analytics for the super-developer (Ionic `dashboard/`).
///
/// NOTE: Intentionally NOT tenant-aware — the `usage_*` RPCs aggregate over
/// ALL tenants and are guarded server-side by `assert_usage_dashboard_access()`
/// (JWT email must be developer@attendix.de, see add_usage_dashboard_rpcs.sql).
class UsageDashboardRepository extends BaseRepository {
  UsageDashboardRepository(super.ref);

  /// Loads all aggregations for events since [since], restricted to the
  /// event names the app currently tracks ([events]).
  Future<UsageDashboardData> load({
    required DateTime since,
    required List<String> events,
  }) async {
    try {
      final params = {
        'p_since': since.toUtc().toIso8601String(),
        'p_events': events,
      };
      final results = await Future.wait([
        supabase.rpc('usage_kpis', params: params),
        supabase.rpc('usage_events_per_day', params: params),
        supabase.rpc('usage_events_by_name', params: params),
        supabase.rpc('usage_events_by_tenant', params: params),
        supabase.rpc('usage_events_by_device', params: params),
      ]);

      List<Map<String, dynamic>> rows(dynamic r) =>
          (r as List? ?? const []).cast<Map<String, dynamic>>();

      final kpiRows = rows(results[0]);
      final kpi = kpiRows.isNotEmpty ? kpiRows.first : const <String, dynamic>{};

      return UsageDashboardData(
        kpis: UsageKpis(
          totalEvents: _toInt(kpi['total_events']),
          distinctTenants: _toInt(kpi['distinct_tenants']),
          activeTenants7d: _toInt(kpi['active_tenants_7d']),
        ),
        perDay: rows(results[1])
            .map((r) => UsageCount(
                  label: r['day']?.toString() ?? '',
                  count: _toInt(r['count']),
                ))
            .toList(),
        byName: rows(results[2])
            .map((r) => UsageCount(
                  label: r['event_name']?.toString() ?? '',
                  count: _toInt(r['count']),
                ))
            .toList(),
        byTenant: rows(results[3])
            .map((r) => UsageCount(
                  label: r['tenant_id']?.toString() ?? '',
                  count: _toInt(r['count']),
                ))
            .toList(),
        byDevice: rows(results[4])
            .map((r) => UsageCount(
                  label: r['device_type']?.toString() ?? 'unknown',
                  count: _toInt(r['count']),
                ))
            .toList(),
      );
    } catch (e, stack) {
      handleError(e, stack, 'loadUsageDashboard');
      rethrow;
    }
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
