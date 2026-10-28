import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan/plan.dart';
import 'base_repository.dart';

// LIVE_ACTIVITY

/// Provider for LiveActivityRepository (without tenant; use
/// liveActivityRepositoryWithTenantProvider).
final liveActivityRepositoryProvider = Provider<LiveActivityRepository>((ref) {
  return LiveActivityRepository(ref);
});

/// Columns Ionic's LiveActivityService loads for running plans.
const String liveActivityAttendanceColumns =
    'id, date, plan, extra_plans, duration_days, share_plan, type_id, typeInfo';

/// Data access for the iOS Live Activity (Ionic `live-activity.service.ts`).
///
/// Tables:
/// - attendance (`tenantId`): Termine with a plan around now
/// - notifications (one row per user, `id` = auth uid, no tenant column):
///   `live_activity` switch
/// - live_activity_tokens (`user_id`, no tenant column; RLS owner only):
///   ActivityKit push tokens
class LiveActivityRepository extends BaseRepository with TenantAwareRepository {
  LiveActivityRepository(super.ref);

  /// Termine of the current tenant with a plan whose date lies in
  /// [[from], [to]] (Ionic `runningPlans` query).
  Future<List<PlanAttendance>> getPlanAttendancesBetween(DateTime from, DateTime to) async {
    try {
      final response = await supabase
          .from('attendance')
          .select(liveActivityAttendanceColumns)
          .eq('tenantId', currentTenantId)
          .gte('date', from.toUtc().toIso8601String())
          .lte('date', to.toUtc().toIso8601String())
          .not('plan', 'is', null);

      return (response as List)
          .map((e) => PlanAttendance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlanAttendancesBetween');
      rethrow;
    }
  }

  /// `notifications.live_activity` of the user; null/true = on.
  Future<bool> isLiveActivityEnabled(String userId) async {
    try {
      // notifications has no tenantId: one row per user (id = auth uid)
      final data = await supabase
          .from('notifications')
          .select('live_activity')
          .eq('id', userId)
          .maybeSingle();
      return data?['live_activity'] != false;
    } catch (e, stack) {
      handleError(e, stack, 'isLiveActivityEnabled');
      rethrow;
    }
  }

  /// Stores an ActivityKit token (Ionic `saveToken`).
  ///
  /// kind 'start' = push-to-start token of the device (attendance_id 0,
  /// plan_key ''); kind 'update' = token of one running Live Activity.
  Future<void> saveToken({
    required String userId,
    required String kind,
    required String token,
    required String platform,
    int attendanceId = 0,
    String planKey = '',
  }) async {
    try {
      // live_activity_tokens has no tenantId: rows belong to the user
      // (user_id, RLS `user_id = auth.uid()`), like device_tokens.
      await supabase.from('live_activity_tokens').upsert({
        'user_id': userId,
        'kind': kind,
        'attendance_id': attendanceId,
        'plan_key': planKey,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,kind,attendance_id,plan_key');
    } catch (e, stack) {
      handleError(e, stack, 'saveToken');
      rethrow;
    }
  }
}
