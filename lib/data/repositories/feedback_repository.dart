import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import 'base_repository.dart';

/// Provider for FeedbackRepository
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref);
});

/// Repository for feedback and support question operations
///
/// This repository handles write-only operations to the `feedback`
/// and `questions` tables. No tenant filtering is needed since these
/// are INSERT-only operations.
class FeedbackRepository extends BaseRepository with TenantAwareRepository {
  FeedbackRepository(super.ref);

  /// Send a support question
  ///
  /// [message] - The question text
  /// [phone] - Optional phone number for callback
  /// [userId] - The user's auth ID (optional)
  Future<void> sendQuestion({
    required String message,
    String? phone,
    String? userId,
  }) async {
    try {
      await supabase.from(SupabaseTable.questions.tableName).insert({
        'message': message,
        'phone': phone,
        'tenant_id': hasTenantId ? currentTenantId : null,
        'user_id': userId,
      });
    } catch (e, stack) {
      handleError(e, stack, 'sendQuestion');
      rethrow;
    }
  }

  /// Send app feedback with rating
  ///
  /// [message] - The feedback text
  /// [rating] - Star rating (1-5)
  /// [anonymous] - If true, tenant and user info are not stored
  /// [phone] - Optional phone number for follow-up
  /// [userId] - The user's auth ID (optional, ignored if anonymous)
  Future<void> sendFeedback({
    required String message,
    required int rating,
    required bool anonymous,
    String? phone,
    String? userId,
  }) async {
    try {
      await supabase.from(SupabaseTable.feedback.tableName).insert({
        'message': message,
        'rating': rating,
        'anonymous': anonymous,
        // Anonymous feedback never carries a phone number.
        'phone': anonymous ? null : phone,
        'tenant_id': anonymous ? null : (hasTenantId ? currentTenantId : null),
        'user_id': anonymous ? null : userId,
      });
    } catch (e, stack) {
      handleError(e, stack, 'sendFeedback');
      rethrow;
    }
  }
}
