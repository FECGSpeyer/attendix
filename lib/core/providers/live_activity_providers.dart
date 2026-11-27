import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../../data/repositories/live_activity_repository.dart';
import '../services/live_activity_service.dart' show liveActivityServiceProvider;
import 'tenant_providers.dart';

// LIVE_ACTIVITY: the service itself lives in
// core/services/live_activity_service.dart (liveActivityServiceProvider).

/// Device-local preference controlling whether ORG-Pläne of other groups and
/// ad-hoc ORG-Pläne trigger Live Activities for leads (default: true).
const liveActivityOrgPlansStorageKey = 'live_activity.org_plans';

Future<bool> loadLiveActivityOrgPlansEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(liveActivityOrgPlansStorageKey) ?? true;
  } catch (_) {
    return true;
  }
}

class LiveActivityOrgPlansNotifier extends Notifier<bool> {
  bool _userChanged = false;

  @override
  bool build() {
    unawaited(_hydrate());
    return true;
  }

  Future<void> _hydrate() async {
    final stored = await loadLiveActivityOrgPlansEnabled();
    if (!_userChanged && state != stored) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _userChanged = true;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(liveActivityOrgPlansStorageKey, enabled);
    } catch (_) {
      // Storage unavailable (private mode): choice still applies in-memory.
    }
    try {
      await ref.read(liveActivityServiceProvider).setOrgPlansEnabled(enabled);
    } catch (_) {}
  }
}

/// Toggle for showing ORG-Pläne of other groups / ad-hoc ORG-Pläne as Live
/// Activities on this device.
final liveActivityOrgPlansEnabledProvider =
    NotifierProvider<LiveActivityOrgPlansNotifier, bool>(
  LiveActivityOrgPlansNotifier.new,
);

/// LiveActivityRepository with tenant set
final liveActivityRepositoryWithTenantProvider = Provider<LiveActivityRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(liveActivityRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [LiveActivityRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final liveActivityRepositoryForTenantProvider =
    Provider.family<LiveActivityRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _liveActivityRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _liveActivityRepositoryForAccountProvider =
    Provider.family<LiveActivityRepository, AccountScopeKey>((ref, key) {
  final repo = LiveActivityRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});
