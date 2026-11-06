import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tenant/tenant.dart';
import 'base_repository.dart';

/// Provider (ohne Tenant – nutze tenantSettingsRepositoryWithTenantProvider)
final tenantSettingsRepositoryProvider = Provider<TenantSettingsRepository>((ref) {
  return TenantSettingsRepository(ref);
});

/// REDESIGN: saves single columns of the current instance (`tenants` row),
/// e.g. one switch of Verwaltung › Allgemein. The old settings page writes
/// all columns at once; the Beta page saves each change right away.
class TenantSettingsRepository extends BaseRepository with TenantAwareRepository {
  TenantSettingsRepository(super.ref);

  /// Updates [values] (column → value) of the current instance only.
  Future<void> updateSettings(Map<String, dynamic> values) async {
    ensureNotDemo('updateSettings'); // DEMO_GUARD
    if (values.isEmpty) return;
    try {
      await supabase.from('tenants').update(values).eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updateSettings');
      rethrow;
    }
  }

  /// Ionic re-evaluates the Problemfall rules after saving them.
  Future<void> evaluateCriticalRules() async {
    try {
      await supabase.functions.invoke('evaluate-critical-rules');
    } catch (_) {
      // Best effort like the old page: the nightly run catches up.
    }
  }
}

/// `tenants.critical_rules` entry like the old settings page writes it
/// (Ionic format; legacy rules without period get "days").
Map<String, dynamic> criticalRuleToJson(CriticalRule r) {
  final period = r.periodType ?? CriticalRulePeriodType.days;
  return {
    'id': r.id,
    if (r.name != null) 'name': r.name,
    'attendance_type_ids': r.attendanceTypeIds,
    'statuses': r.statuses,
    'threshold_type': r.thresholdType.name,
    'threshold_value': r.thresholdValue,
    'period_type': period == CriticalRulePeriodType.allTime ? 'all' : period.name,
    if (r.periodDays != null) 'period_days': r.periodDays,
    'operator': r.operator == CriticalRuleOperator.and ? 'AND' : 'OR',
  };
}
