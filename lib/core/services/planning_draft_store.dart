import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOL_FIX27: local drafts of the Ablaufplan editor (`PlanningPage`): an
/// edit whose write was queued when the editor went away is kept here until
/// the write is confirmed, and restored the next time the plan is opened.
///
/// - Drafts belong to one account in one tenant: the key carries the auth
///   user id ([keyFor]); without a signed-in user there is no draft. On
///   sign-out / account switch every draft is removed ([clearPlanningDrafts]).
/// - Every stored draft carries a revision ([nextRevision], strictly
///   increasing within the process). A writer removes a draft only when it
///   still holds the revision that writer stored ([removeIfRevision]), so an
///   older editor never deletes a newer draft under the same key.
class PlanningDraftStore {
  const PlanningDraftStore._();

  /// Prefix of every draft key.
  static const String prefix = 'planning_draft_';

  static int _lastRevision = 0;

  /// Key of the draft of plan [planKey] of Termin [attId] for [userId] in
  /// [tenantId]: `planning_draft_<userId>_<tenantId>_<attId>_<plan>`; null
  /// (no draft) without signed-in user or tenant.
  static String? keyFor({
    required String? userId,
    required int? tenantId,
    required int attId,
    required String planKey,
  }) {
    if (userId == null || userId.isEmpty || tenantId == null) return null;
    return '$prefix${userId}_${tenantId}_${attId}_$planKey';
  }

  /// Strictly increasing revision (microseconds, bumped on collisions).
  static int nextRevision() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _lastRevision = now > _lastRevision ? now : _lastRevision + 1;
    return _lastRevision;
  }

  /// Stores [data] under [key] with a new revision and returns it; null when
  /// nothing was stored. [allowed] is checked right before the write (e.g.
  /// the account is still signed in). Never throws.
  static Future<int?> write(
    String? key,
    Map<String, dynamic> data, {
    required bool Function() allowed,
  }) async {
    if (key == null) return null;
    // Assigned synchronously: writes to one key keep their call order.
    final rev = nextRevision();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!allowed()) return null;
      await prefs.setString(key, jsonEncode({...data, 'rev': rev}));
      return rev;
    } catch (e) {
      debugPrint('[PlanningDraft] write failed: $e');
      return null;
    }
  }

  /// The draft under [key] (`rev` = its revision) or null. Never throws.
  static Future<({int? rev, Map<String, dynamic> data})?> read(String? key) async {
    if (key == null) return null;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final rev = data.remove('rev');
      return (rev: rev is int ? rev : null, data: data);
    } catch (_) {
      return null;
    }
  }

  /// Removes the draft under [key] only while it still holds revision [rev]
  /// (a newer draft written meanwhile stays). Never throws.
  static Future<void> removeIfRevision(String? key, int? rev) async {
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return;
      Object? stored;
      try {
        stored = (jsonDecode(raw) as Map)['rev'];
      } catch (_) {
        stored = null; // unreadable draft: treated as revision-less
      }
      if (stored == rev) await prefs.remove(key);
    } catch (e) {
      debugPrint('[PlanningDraft] remove failed: $e');
    }
  }
}

/// SOL_FIX27: removes every Ablaufplan draft (all users, all tenants).
/// Called on sign-out and account switch. Never throws.
Future<void> clearPlanningDrafts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(PlanningDraftStore.prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  } catch (e) {
    debugPrint('[PlanningDraft] clear failed: $e');
  }
}
