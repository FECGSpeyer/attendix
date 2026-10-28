import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notification_settings_repository.dart';
import 'tenant_providers.dart';

/// Notification settings repository with tenant context
final notificationSettingsRepositoryWithTenantProvider =
    Provider<NotificationSettingsRepository>((ref) {
  final repo = ref.watch(notificationSettingsRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
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
