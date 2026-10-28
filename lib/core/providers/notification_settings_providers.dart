import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../../data/repositories/notification_settings_repository.dart';
import 'tenant_providers.dart';

/// Notification settings repository with tenant context
final notificationSettingsRepositoryWithTenantProvider = Provider<NotificationSettingsRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(notificationSettingsRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [NotificationSettingsRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final notificationSettingsRepositoryForTenantProvider =
    Provider.family<NotificationSettingsRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _notificationSettingsRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _notificationSettingsRepositoryForAccountProvider =
    Provider.family<NotificationSettingsRepository, AccountScopeKey>((ref, key) {
  final repo = NotificationSettingsRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Whether the current tenant has duty (Dienstplan) attendance types
final tenantHasDutyTypesProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(notificationSettingsRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return false;
  try {
    return await repo.hasDutyTypes();
  } catch (_) {
    // duty_mode column may not exist on older schemas
    return false;
  }
});
