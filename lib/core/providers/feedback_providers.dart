import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/feedback_repository.dart';
import '../config/supabase_config.dart';
import 'tenant_providers.dart';

/// Initialized feedback repository with tenant context
final feedbackRepositoryWithTenantProvider = Provider<FeedbackRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(feedbackRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [FeedbackRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final feedbackRepositoryForTenantProvider =
    Provider.family<FeedbackRepository, int?>((ref, tenantId) {
  final repo = FeedbackRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Notifier for feedback mutations (sending questions and feedback)
class FeedbackNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  FeedbackRepository get _repo => ref.read(feedbackRepositoryWithTenantProvider);

  /// Send a support question
  Future<bool> sendQuestion({
    required String message,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.currentUser?.id;

      await _repo.sendQuestion(
        message: message,
        phone: phone,
        userId: userId,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Send app feedback with rating
  Future<bool> sendFeedback({
    required String message,
    required int rating,
    required bool anonymous,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.currentUser?.id;

      await _repo.sendFeedback(
        message: message,
        rating: rating,
        anonymous: anonymous,
        phone: phone,
        userId: userId,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final feedbackNotifierProvider =
    NotifierProvider<FeedbackNotifier, AsyncValue<void>>(
  FeedbackNotifier.new,
);
