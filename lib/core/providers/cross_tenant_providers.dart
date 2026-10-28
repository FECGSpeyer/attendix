import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cross_tenant/cross_tenant_attendance.dart';
import '../config/supabase_config.dart';
import '../services/cross_tenant_service.dart';
import 'tenant_providers.dart';

/// Provider for CrossTenantService
final crossTenantServiceProvider = Provider<CrossTenantService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CrossTenantService(supabase);
});

/// Provider for aggregated attendances across all user's tenants
/// Returns attendances from the last 30 days and upcoming ones
final crossTenantAttendancesProvider =
    FutureProvider<List<CrossTenantPersonAttendance>>((ref) async {
  final service = ref.watch(crossTenantServiceProvider);
  // SOL_FIX14: per-user data – reload when the account changes.
  final userId = ref.watch(currentAuthUserIdProvider);
  final tenants = await ref.watch(userTenantsProvider.future);

  if (userId == null || tenants.isEmpty) return [];

  // Start date: 30 days ago (to show recent past attendances)
  final startDate = DateTime.now().subtract(const Duration(days: 30));
  final startDateStr = startDate.toIso8601String().split('T').first;

  return service.loadAllPersonAttendancesAcrossTenants(
    userId,
    tenants,
    startDateStr,
  );
});

/// Provider for upcoming cross-tenant attendances (today and future)
final upcomingCrossTenantAttendancesProvider =
    Provider<List<CrossTenantPersonAttendance>>((ref) {
  final allAttendances = ref.watch(crossTenantAttendancesProvider).valueOrNull ?? [];
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);

  return allAttendances.where((att) {
    final date = att.dateTime;
    if (date == null) return false;
    return !date.isBefore(todayOnly);
  }).toList();
});

/// Provider for past cross-tenant attendances (before today)
final pastCrossTenantAttendancesProvider =
    Provider<List<CrossTenantPersonAttendance>>((ref) {
  final allAttendances = ref.watch(crossTenantAttendancesProvider).valueOrNull ?? [];
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);

  return allAttendances.where((att) {
    final date = att.dateTime;
    if (date == null) return false;
    return date.isBefore(todayOnly);
  }).toList();
});

/// Provider for today's cross-tenant attendances
final todayCrossTenantAttendancesProvider =
    Provider<List<CrossTenantPersonAttendance>>((ref) {
  final allAttendances = ref.watch(crossTenantAttendancesProvider).valueOrNull ?? [];

  return allAttendances.where((att) => att.isToday).toList();
});
