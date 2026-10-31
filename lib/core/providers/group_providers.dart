import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../../data/models/instrument/instrument.dart';
import '../../data/repositories/repositories.dart';
import 'tenant_providers.dart';
import '../services/tracking/tracking_event.dart';
import '../services/tracking/tracking_service.dart';
import '../services/offline_list_cache.dart';

/// Initialized group repository with tenant context
final groupRepositoryWithTenantProvider = Provider<GroupRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(groupRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [GroupRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final groupRepositoryForTenantProvider =
    Provider.family<GroupRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _groupRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _groupRepositoryForAccountProvider =
    Provider.family<GroupRepository, AccountScopeKey>((ref, key) {
  final repo = GroupRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Provider for groups/instruments list
final groupsProvider = FutureProvider<List<Group>>((ref) async {
  // Keep data in memory - groups rarely change during a session
  ref.keepAlive();

  final repo = ref.watch(groupRepositoryWithTenantProvider);
  // Watch tenant changes to invalidate cache when tenant switches
  ref.watch(currentTenantIdProvider);

  if (!repo.hasTenantId) return [];

  // Offline: the last loaded groups.
  return OfflineListCache.read<Group>(
    ref,
    tenantId: repo.currentTenantId,
    part: 'groups',
    fetch: repo.getGroups,
    // categoryData is not part of Group.toJson (never written to the DB),
    // but the Register headings need it offline too.
    toJson: (g) => {...g.toJson(), 'categoryData': g.categoryData?.toJson()},
    fromJson: Group.fromJson,
  );
});

/// Provider for groups as a map (id -> name)
final groupsMapProvider = FutureProvider<Map<int, String>>((ref) async {
  // Keep data in memory - groups rarely change during a session
  ref.keepAlive();

  final repo = ref.watch(groupRepositoryWithTenantProvider);
  // Watch tenant changes to invalidate cache when tenant switches
  ref.watch(currentTenantIdProvider);

  if (!repo.hasTenantId) return {};

  // Offline: the last loaded id → name map.
  final entries = await OfflineListCache.read<MapEntry<int, String>>(
    ref,
    tenantId: repo.currentTenantId,
    part: 'groups_map',
    fetch: () async => (await repo.getGroupsMap()).entries.toList(),
    toJson: (e) => {'id': e.key, 'name': e.value},
    fromJson: (j) => MapEntry((j['id'] as num).toInt(), j['name'] as String? ?? ''),
  );
  return Map.fromEntries(entries);
});

/// Provider for the main group
final mainGroupProvider = FutureProvider<Group?>((ref) async {
  final repo = ref.watch(groupRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return null;
  
  return repo.getMainGroup();
});

/// Provider for group categories
final groupCategoriesProvider = FutureProvider<List<GroupCategory>>((ref) async {
  final repo = ref.watch(groupRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  return repo.getGroupCategories();
});

/// Provider for player counts per group (instrument)
final playerCountsForGroupsProvider = FutureProvider<Map<int, int>>((ref) async {
  final repo = ref.watch(groupRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return {};

  return repo.getPlayerCountsForGroups();
});

/// Notifier for group mutations
class GroupNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  GroupRepository get _repo => ref.read(groupRepositoryWithTenantProvider);

  Future<Group?> createGroup(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createGroup(data);
      ref.read(trackingServiceProvider).track(TrackingEvent.instrumentAdded, properties: {'maingroup': data['maingroup'] ?? false});
      state = const AsyncValue.data(null);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupsMapProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Group?> updateGroup(int id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateGroup(id, updates);
      ref.read(trackingServiceProvider).track(TrackingEvent.instrumentUpdated);
      state = const AsyncValue.data(null);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupsMapProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Remembers file-name terms as synonyms of groups (upload: "künftig so
  /// erkennen"), so the next upload matches them. [terms] maps group id →
  /// terms; terms the group already knows are skipped. Each group is read
  /// fresh and written only if unchanged since, so synonyms saved meanwhile
  /// (another upload, the group page) are kept.
  Future<bool> addSynonyms(Map<int, List<String>> terms) async {
    // The tenant is fixed before the first await (tenant switch mid-way).
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      for (final entry in terms.entries) {
        // Compare-and-set: a change in between (another upload, the group
        // page) makes the write miss, then the group is read again.
        for (var attempt = 0; ; attempt++) {
          final group = await repo.getGroupById(entry.key);
          final merged = group == null ? null : mergeSynonyms(group.synonyms, entry.value);
          if (merged == null) break;
          if (await repo.updateGroupSynonymsIfUnchanged(entry.key, expected: group!.synonyms, value: merged)) break;
          if (attempt >= 4) throw StateError('synonyms of group ${entry.key} keep changing');
        }
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    } finally {
      // Also after a partial failure: the groups already written are new.
      ref.invalidate(groupsProvider);
      ref.invalidate(groupsMapProvider);
    }
  }

  Future<void> deleteGroup(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteGroup(id);
      ref.read(trackingServiceProvider).track(TrackingEvent.instrumentRemoved);
      state = const AsyncValue.data(null);
      ref.invalidate(groupsProvider);
      ref.invalidate(groupsMapProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<GroupCategory?> createGroupCategory(String name) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createGroupCategory(name: name);
      state = const AsyncValue.data(null);
      ref.invalidate(groupCategoriesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<GroupCategory?> updateGroupCategory(int id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updateGroupCategory(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(groupCategoriesProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Save instrument order (id -> sort_order)
  Future<bool> saveGroupOrder(Map<int, int> sortOrders) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateGroupSortOrders(sortOrders);
      state = const AsyncValue.data(null);
      ref.invalidate(groupsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Save category order and the resulting global instrument order
  Future<bool> saveCategoryOrder(
    Map<int, int> categorySortOrders, {
    Map<int, int> groupSortOrders = const {},
  }) async {
    final repo = _repo; // SOL_FIX4: bind the tenant repository before the first await.
    state = const AsyncValue.loading();
    try {
      await repo.updateGroupCategorySortOrders(categorySortOrders);
      if (groupSortOrders.isNotEmpty) {
        await repo.updateGroupSortOrders(groupSortOrders);
      }
      state = const AsyncValue.data(null);
      ref.invalidate(groupCategoriesProvider);
      ref.invalidate(groupsProvider);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> deleteGroupCategory(int id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteGroupCategory(id);
      state = const AsyncValue.data(null);
      ref.invalidate(groupCategoriesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final groupNotifierProvider = NotifierProvider<GroupNotifier, AsyncValue<void>>(() {
  return GroupNotifier();
});

/// [existing] synonyms (comma separated) plus [terms], or null when nothing
/// is new (case-insensitive; empty terms and terms with a comma are skipped).
String? mergeSynonyms(String? existing, Iterable<String> terms) {
  final list = [
    for (final s in (existing ?? '').split(','))
      if (s.trim().isNotEmpty) s.trim(),
  ];
  var changed = false;
  for (final term in terms) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty || t.contains(',') || list.any((s) => s.toLowerCase() == t)) continue;
    list.add(t);
    changed = true;
  }
  return changed ? list.join(', ') : null;
}
