import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../core/config/supabase_config.dart';
import '../../data/models/tenant/tenant.dart';
import '../constants/enums.dart';
import '../services/native/ionic_session_takeover.dart'
    show ionicTakeoverTenantKey;
import 'user_preferences_provider.dart';
import '../utils/demo_guard.dart';
import '../../l10n/l10n.dart';

const _tenantIdKey = 'current_tenant_id';

/// IONIC_SESSION: group of the Ionic app still waiting to be restored after
/// the store update (null otherwise). The automatic tenant choice on
/// `/tenants` prefers it, like `CurrentTenantNotifier` does.
Future<int?> pendingIonicTenantId() async {
  try {
    return (await SharedPreferences.getInstance()).getInt(ionicTakeoverTenantKey);
  } catch (_) {
    return null;
  }
}

/// Provider for current selected tenant
final currentTenantProvider =
    StateNotifierProvider<CurrentTenantNotifier, Tenant?>((ref) {
  return CurrentTenantNotifier(ref);
});

/// Convenience provider for just the tenant ID
final currentTenantIdProvider = Provider<int?>((ref) {
  return ref.watch(currentTenantProvider)?.id;
});

/// Ionic `setTenant`: the instance stored on this device (localStorage)
/// wins over `user_metadata.currentTenantId` ([serverTenantId]). Used by the
/// login / instance selection so they pick the same instance as the
/// background restore of [CurrentTenantNotifier]. Returns the ids in order
/// of preference (without duplicates); callers take the first accessible one.
Future<List<int>> preferredTenantIds(int? serverTenantId) async {
  int? ionic;
  int? cached;
  try {
    final prefs = await SharedPreferences.getInstance();
    ionic = prefs.getInt(ionicTakeoverTenantKey);
    cached = prefs.getInt(_tenantIdKey);
  } catch (_) {}
  // IONIC_SESSION: a pending Ionic group wins once, like the restore.
  return {
    if (ionic != null) ionic,
    if (cached != null) cached,
    if (serverTenantId != null) serverTenantId,
  }.toList();
}

/// Notifier for current tenant
/// Uses dual-storage strategy:
/// - SharedPreferences for fast local cache
/// - Supabase user_metadata for cross-device sync
class CurrentTenantNotifier extends StateNotifier<Tenant?> {
  CurrentTenantNotifier(this.ref) : super(null) {
    _initializeTenant();
  }

  final Ref ref;

  /// LINKS_STARTUP: set once a tenant was chosen explicitly (selection,
  /// deep link). The async restore below must not override that choice.
  bool _explicitlySet = false;

  /// Initialize tenant from local cache and sync with server
  Future<void> _initializeTenant() async {
    // Step 1: Load from SharedPreferences (fast, instant)
    final prefs = await SharedPreferences.getInstance();
    final cachedTenantId = prefs.getInt(_tenantIdKey);

    // Step 2: Get authoritative value from user_metadata
    final auth = ref.read(supabaseAuthProvider);
    final userMetadata = auth.currentUser?.userMetadata;
    final serverTenantId = userMetadata?['currentTenantId'] as int?;

    // IONIC_SESSION: after the store update the group of the Ionic app wins
    // once (Ionic preferred its local value over user_metadata).
    final ionicTenantId = prefs.getInt(ionicTakeoverTenantKey);
    if (ionicTenantId != null && await _restoreIonicTenant(ionicTenantId)) {
      return;
    }

    // Step 3: Ionic setTenant – the same-device value (localStorage) wins
    // over user_metadata.currentTenantId when they disagree (a switch via
    // setTenantLocal does not write the metadata); metadata is the
    // cross-device fallback.
    final tenantIdToLoad = cachedTenantId ?? serverTenantId;

    if (tenantIdToLoad != null) {
      // A cached id that differs from the account's metadata may belong to
      // another account of this device: if it is not accessible, drop only
      // the local cache and fall back to the metadata – never clear the
      // metadata of the signed-in account because of a foreign cache entry.
      final fallback = cachedTenantId != null &&
              serverTenantId != null &&
              serverTenantId != cachedTenantId
          ? serverTenantId
          : null;
      final loaded = await _loadAndValidateTenant(
        tenantIdToLoad,
        localOnly: fallback != null,
      );

      if (loaded == false && fallback != null && !_explicitlySet) {
        if (await _loadAndValidateTenant(fallback) == true && !_explicitlySet) {
          await prefs.setInt(_tenantIdKey, fallback);
        }
      }

      // Fill the cache from the server value on a new device.
      if (cachedTenantId == null && serverTenantId != null) {
        await prefs.setInt(_tenantIdKey, serverTenantId);
      }
    }
  }

  /// IONIC_SESSION: loads the Ionic group if the user still belongs to it
  /// and syncs it to user_metadata. The pending key is removed once the
  /// outcome is final; network errors keep it for the next start.
  Future<bool> _restoreIonicTenant(int tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;
      final member = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('tenantId', tenantId)
          .eq('userId', userId)
          .maybeSingle();
      final response = member == null
          ? null
          : await supabase
              .from('tenants')
              .select('*')
              .eq('id', tenantId)
              .maybeSingle();
      if (response == null) {
        await prefs.remove(ionicTakeoverTenantKey);
        return false;
      }
      if (_explicitlySet) return true;
      state = Tenant.fromJson(response);
      await prefs.setInt(_tenantIdKey, tenantId);
      final metadata = supabase.auth.currentUser?.userMetadata;
      if (metadata?['currentTenantId'] != tenantId) {
        await supabase.auth.updateUser(UserAttributes(
          data: {...?metadata, 'currentTenantId': tenantId},
        ));
      }
      await prefs.remove(ionicTakeoverTenantKey);
      return true;
    } catch (e) {
      debugPrint('Ionic group not restored yet: $e');
      return state?.id == tenantId;
    }
  }

  /// Load tenant by ID and validate user still has access.
  /// Returns true when loaded, false when the tenant is not accessible (or
  /// gone; storage was cleared – only the local cache with [localOnly]) and
  /// null when nothing was decided (no user, explicit choice, error).
  Future<bool?> _loadAndValidateTenant(int tenantId, {bool localOnly = false}) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return null;

      // Verify user still has access to this tenant
      final tenantUserResponse = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('tenantId', tenantId)
          .eq('userId', userId)
          .maybeSingle();

      if (_explicitlySet) return null;
      // User no longer has access to this tenant
      if (tenantUserResponse == null) {
        debugPrint('User no longer has access to tenant $tenantId');
        await _clearStorage(localOnly: localOnly);
        return false;
      }

      // Load the tenant data
      final response = await supabase
          .from('tenants')
          .select('*')
          .eq('id', tenantId)
          .maybeSingle();

      if (_explicitlySet) return null;
      if (response != null) {
        state = Tenant.fromJson(response);
        return true;
      }
      // Tenant doesn't exist anymore
      await _clearStorage(localOnly: localOnly);
      return false;
    } catch (e, stack) {
      debugPrint('Failed to load saved tenant: $e');
      // SEC-008: Only log stack trace in debug mode
      if (kDebugMode) {
        debugPrint('$stack');
      }
      return null;
    }
  }

  Future<void> _clearStorage({required bool localOnly}) async {
    if (!localOnly) return _clearAllStorage();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantIdKey);
  }

  /// Set the current tenant locally without triggering auth sync.
  /// Use this for navigation scenarios where auth events would interrupt navigation.
  /// After navigation completes, call updateCurrentTenantId separately.
  Future<void> setTenantLocal(Tenant? tenant) async {
    _explicitlySet = true;
    state = tenant;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ionicTakeoverTenantKey);
    final tenantId = tenant?.id;
    if (tenantId != null) {
      await prefs.setInt(_tenantIdKey, tenantId);
    } else {
      await prefs.remove(_tenantIdKey);
    }
    // NOTE: Does NOT call updateCurrentTenantId to avoid auth events
  }

  /// SOL_FIX19: applies a setting that was just saved for [tenantId] to the
  /// local tenant state – only while [tenantId] is still the current
  /// tenant. A save that finishes after a switch to another tenant must not
  /// copy its value into that tenant (or switch back). [update] gets the
  /// CURRENT state, not a copy taken before the save. Returns whether the
  /// state was updated.
  Future<bool> updateTenantLocalIfCurrent(
    int? tenantId,
    Tenant Function(Tenant current) update,
  ) async {
    final current = state;
    if (tenantId == null || current == null || current.id != tenantId) {
      return false;
    }
    await setTenantLocal(update(current));
    return true;
  }

  /// Set the current tenant and persist to both storages
  Future<void> setTenant(Tenant? tenant) async {
    await setTenantLocal(tenant);

    // Update user_metadata asynchronously (fire and forget for cross-device sync)
    final tenantId = tenant?.id;
    if (tenantId != null) {
      ref
          .read(userPreferencesNotifierProvider.notifier)
          .updateCurrentTenantId(tenantId);
    }
  }

  /// Clear tenant from state and all storage
  Future<void> clearTenant() async {
    state = null;
    await _clearAllStorage();
  }

  /// Clear tenant from both SharedPreferences and user_metadata
  Future<void> _clearAllStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tenantIdKey);
    await prefs.remove(ionicTakeoverTenantKey);

    // Also clear from user_metadata
    ref.read(userPreferencesNotifierProvider.notifier).clearCurrentTenantId();
  }
}

/// Signs out and always clears the selected group afterwards (#384).
///
/// Offline, `auth.signOut()` removes the local session first and then fails
/// on the server request. The group still has to be cleared: otherwise it
/// stays selected, and after the next sign-in the group selection finds a
/// group already set and shows the list instead of opening the group
/// (Ionic setTenant opens the stored or first group).
Future<void> signOutAndClearTenant({
  required Future<void> Function() signOut,
  required Future<void> Function() clearTenant,
}) async {
  try {
    await signOut();
  } catch (e) {
    debugPrint('Sign-out request failed: $e');
  }
  await clearTenant();
}

/// Provider for user's tenants list (sorted: favorites first)
final userTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  // SOL_FIX14: per-user data – reload when the account changes.
  final userId = ref.watch(currentAuthUserIdProvider);

  if (userId == null) return [];

  // Get tenant user records including favorite flag
  final tenantUsersResponse = await supabase
      .from('tenantUsers')
      .select('tenantId, favorite, role')
      .eq('userId', userId);

  if ((tenantUsersResponse as List).isEmpty) return [];

  // Build favorite and role maps
  final favoriteMap = <int, bool>{};
  final roleMap = <int, int>{};
  final tenantIds = <int>[];
  for (final item in tenantUsersResponse as List) {
    final tenantId = item['tenantId'] as int;
    tenantIds.add(tenantId);
    favoriteMap[tenantId] = item['favorite'] as bool? ?? false;
    roleMap[tenantId] = item['role'] as int? ?? 99;
  }

  // Then get the tenants
  final tenantsResponse = await supabase
      .from('tenants')
      .select('*')
      .inFilter('id', tenantIds);

  final List<Tenant> tenants = [];
  for (final item in tenantsResponse as List) {
    final tenant = Tenant.fromJson(item as Map<String, dynamic>);
    // Merge favorite and role from tenantUsers into Tenant model
    final isFavorite = favoriteMap[tenant.id] ?? false;
    final userRole = roleMap[tenant.id] ?? 99;
    tenants.add(tenant.copyWith(
      favorite: isFavorite ? true : null,
      role: userRole,
    ));
  }

  // Sort like Ionic getTenants(): `.order('longName')`, then favorites
  // first. IOS_R4: by longName (not the short name) – the order of the
  // header tenant popover and the Mehr instance list.
  tenants.sort((a, b) {
    final aFav = a.favorite == true ? 0 : 1;
    final bFav = b.favorite == true ? 0 : 1;
    if (aFav != bFav) return aFav.compareTo(bFav);
    return compareTenantLongNames(a, b);
  });

  return tenants;
});

/// Ionic orders the tenants by `longName` in Postgres (case-insensitive
/// collation); ties fall back to the code-unit order.
int compareTenantLongNames(Tenant a, Tenant b) {
  final byName = a.longName.toLowerCase().compareTo(b.longName.toLowerCase());
  return byName != 0 ? byName : a.longName.compareTo(b.longName);
}

/// Provider for current user's TenantUser record in the selected tenant
final currentTenantUserProvider = FutureProvider<TenantUser?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  // SOL_FIX14: per-user data – reload when the account changes.
  final userId = ref.watch(currentAuthUserIdProvider);

  if (tenant == null || userId == null) return null;

  final response = await supabase
      .from('tenantUsers')
      .select('*')
      .eq('tenantId', tenant.id!)
      .eq('userId', userId)
      .maybeSingle();

  if (response == null) return null;
  return TenantUser.fromJson(response);
});

/// Convenience provider for current user's role
/// SEC-008: Returns Role.none while loading, but router handles this specially
final currentRoleProvider = Provider<Role>((ref) {
  final tenantUserAsync = ref.watch(currentTenantUserProvider);
  final tenantUser = tenantUserAsync.valueOrNull;
  if (tenantUser == null) return Role.none;
  // SOL_FIX14: while reloading after an account switch the previous
  // account's row is still the AsyncValue's value – never use its role.
  if (tenantUser.userId != ref.watch(currentAuthUserIdProvider)) {
    return Role.none;
  }
  return tenantUser.roleEnum;
});

/// SEC-008: Provider that indicates if the role is still loading
final isRoleLoadingProvider = Provider<bool>((ref) {
  final tenantUserAsync = ref.watch(currentTenantUserProvider);
  return tenantUserAsync.isLoading;
});

/// Toggle favorite status for a tenant
Future<void> toggleTenantFavorite(WidgetRef ref, int tenantId, bool favorite) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  try {
    await supabase
        .from('tenantUsers')
        .update({'favorite': favorite})
        .eq('tenantId', tenantId)
        .eq('userId', userId);

    ref.invalidate(userTenantsProvider);
  } catch (e) {
    // Rethrow so caller can handle (e.g. show toast)
    rethrow;
  }
}

/// Delete a tenant (admin-only, cascading)
Future<void> deleteTenant(WidgetRef ref, int tenantId) async {
  DemoGuard.checkCurrent('deleteInstance'); // DEMO_GUARD
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw Exception(l10nWithoutContext.coreFlutterNotLoggedIn);

  // Verify user is admin of this tenant before deleting
  final tenantUser = await supabase
      .from('tenantUsers')
      .select('role')
      .eq('tenantId', tenantId)
      .eq('userId', userId)
      .maybeSingle();

  if (tenantUser == null || tenantUser['role'] != Role.admin.value) {
    throw Exception(l10nWithoutContext.svcNoDeletePermission);
  }

  // Delete the tenant — Supabase cascading handles related records
  await supabase.from('tenants').delete().eq('id', tenantId);

  // Clear current tenant if it was the deleted one
  final currentId = ref.read(currentTenantIdProvider);
  if (currentId == tenantId) {
    await ref.read(currentTenantProvider.notifier).clearTenant();
  }

  ref.invalidate(userTenantsProvider);
}

/// Provider for member count of a specific tenant
final tenantMemberCountProvider = FutureProvider.family<int, int>((ref, tenantId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase
      .from('tenantUsers')
      .select('id')
      .eq('tenantId', tenantId);

  return (response as List).length;
});
