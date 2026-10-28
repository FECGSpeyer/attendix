import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_repository.dart';

/// Provider for NotificationSettingsRepository
final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
  return NotificationSettingsRepository(ref);
});

/// Tenant-dependent lookups for the notification settings page.
///
/// The per-user `notifications` config itself has no tenantId (one row per
/// user, keyed by the auth user id) and is handled by TelegramService.
class NotificationSettingsRepository extends BaseRepository
    with TenantAwareRepository {
  NotificationSettingsRepository(super.ref);

  /// Whether the current tenant uses the Dienstplan (any attendance type with
  /// duty_mode). Ionic shows the "Dienste" toggle only then.
  Future<bool> hasDutyTypes() async {
    try {
      final response = await supabase
          .from('attendance_types')
          .select('id')
          .eq('tenant_id', currentTenantId)
          .eq('duty_mode', true)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e, stack) {
      handleError(e, stack, 'hasDutyTypes');
      rethrow;
    }
  }
}
