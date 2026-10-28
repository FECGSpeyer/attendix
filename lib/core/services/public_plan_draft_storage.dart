import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOL_FIX12: local drafts of the ad-hoc Ablaufplanung (Ionic stores one
/// global `attendix-public-plan` entry).
///
/// A draft holds the plan content AND the plan id + edit key of the shared
/// plan, so it must never reach another account: signed-in drafts are stored
/// per auth user, the anonymous (`/planung` without login) draft separately.
/// The legacy global entry (written by older versions for every account,
/// owner unknown) is never read and is removed ([dropLegacy]). On sign-out /
/// account switch the previous user's draft is removed
/// ([clearPublicPlanDrafts]); the anonymous draft was never written by a
/// signed-in account and stays.
class PublicPlanDraftStorage {
  const PublicPlanDraftStorage._();

  /// Global key of older versions (Ionic) — owner unknown, never restored.
  static const String legacyKey = 'attendix-public-plan';

  /// Anonymous draft (`/planung` without login).
  static const String anonymousKey = 'attendix-public-plan-anon';

  /// Prefix of the per-user draft keys.
  static const String userKeyPrefix = 'attendix-public-plan-user:';

  /// Storage key of the draft of [userId] (anonymous draft without user).
  static String keyFor(String? userId) =>
      userId == null || userId.isEmpty ? anonymousKey : '$userKeyPrefix$userId';

  /// Removes the legacy global draft. Never throws.
  static Future<void> dropLegacy(SharedPreferences prefs) async {
    try {
      await prefs.remove(legacyKey);
    } catch (e) {
      debugPrint('[PublicPlanDraft] legacy cleanup failed: $e');
    }
  }
}

/// SOL_FIX12: removes the draft of [previousUserId] and the legacy global
/// draft (which may still hold a signed-in user's plan id
/// and edit key written by an older app version). Called on sign-out and
/// account switch. Never throws.
Future<void> clearPublicPlanDrafts(String? previousUserId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (previousUserId != null && previousUserId.isNotEmpty) {
      await prefs.remove(PublicPlanDraftStorage.keyFor(previousUserId));
    }
    await prefs.remove(PublicPlanDraftStorage.legacyKey);
  } catch (e) {
    debugPrint('[PublicPlanDraft] clear failed: $e');
  }
}
