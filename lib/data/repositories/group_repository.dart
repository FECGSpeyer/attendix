import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instrument/instrument.dart';
import 'base_repository.dart';

/// Provider for GroupRepository
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(ref);
});

/// Repository for groups/instruments operations
class GroupRepository extends BaseRepository with TenantAwareRepository {
  GroupRepository(super.ref);

  /// Get all groups/instruments for the current tenant
  Future<List<Group>> getGroups() async {
    try {
      final response = await supabase
          .from('instruments')
          .select('*, categoryData:category(*)')
          .eq('tenantId', currentTenantId)
          .order('category')
          .order('sort_order', ascending: true, nullsFirst: false)
          .order('name');

      return (response as List)
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getGroups');
      rethrow;
    }
  }

  /// Get groups as a map (id -> name)
  Future<Map<int, String>> getGroupsMap() async {
    try {
      final response = await supabase
          .from('instruments')
          .select('id, name')
          .eq('tenantId', currentTenantId);

      final map = <int, String>{};
      for (final row in response as List) {
        map[row['id'] as int] = row['name'] as String;
      }
      return map;
    } catch (e, stack) {
      handleError(e, stack, 'getGroupsMap');
      rethrow;
    }
  }

  /// Get the main group for the tenant
  Future<Group?> getMainGroup() async {
    try {
      final response = await supabase
          .from('instruments')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('maingroup', true)
          .maybeSingle();

      if (response == null) return null;
      return Group.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getMainGroup');
      rethrow;
    }
  }

  /// Get a single group by ID
  Future<Group?> getGroupById(int id) async {
    try {
      final response = await supabase
          .from('instruments')
          .select('*')
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Group.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getGroupById');
      rethrow;
    }
  }

  /// Create a new group/instrument
  Future<Group> createGroup(Map<String, dynamic> data) async {
    try {
      // Create a sanitized copy — don't mutate caller's map
      final sanitized = Map<String, dynamic>.from(data);
      sanitized['tenantId'] = currentTenantId;
      sanitized.putIfAbsent('tuning', () => 'C');
      sanitized.putIfAbsent('clefs', () => ['g']);
      // Remove read-only fields that shouldn't be inserted
      sanitized.remove('id');
      sanitized.remove('created_at');
      sanitized.remove('categoryData');

      // RT-008: Use maybeSingle() to avoid StateError on empty result
      final response = await supabase
          .from('instruments')
          .insert(sanitized)
          .select()
          .maybeSingle();

      if (response == null) {
        throw RepositoryException(
          message: 'Gruppe konnte nicht erstellt werden',
          operation: 'createGroup',
        );
      }
      return Group.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createGroup');
      rethrow;
    }
  }

  /// Update a group
  Future<Group> updateGroup(int id, Map<String, dynamic> updates) async {
    try {
      // Remove read-only fields
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('tenantId');
      updates.remove('categoryData');
      updates.remove('count');

      // RT-008: Use maybeSingle() to avoid StateError
      final response = await supabase
          .from('instruments')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw RepositoryException(
          message: 'Gruppe mit ID $id nicht gefunden',
          operation: 'updateGroup',
        );
      }
      return Group.fromJson(response);
    } catch (e, stack) {
      // Handle unique constraint violation (only one maingroup)
      if (e.toString().contains('23505')) {
        throw RepositoryException(
          message: 'Es kann nur eine Hauptgruppe existieren',
          operation: 'updateGroup',
          code: '23505',
        );
      }
      handleError(e, stack, 'updateGroup');
      rethrow;
    }
  }

  /// Get count of players assigned to a group
  Future<int> getPlayerCountInGroup(int groupId) async {
    try {
      final response = await supabase
          .from('player')
          .select('id')
          .eq('tenantId', currentTenantId)
          .eq('instrument', groupId)
          .isFilter('left', null); // Only active players

      return (response as List).length;
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerCountInGroup');
      rethrow;
    }
  }

  /// Get player counts for all groups in a single query
  Future<Map<int, int>> getPlayerCountsForGroups() async {
    try {
      final response = await supabase
          .from('player')
          .select('instrument')
          .eq('tenantId', currentTenantId)
          .isFilter('left', null)
          .not('instrument', 'is', null);

      final counts = <int, int>{};
      for (final row in response as List) {
        final groupId = row['instrument'] as int;
        counts[groupId] = (counts[groupId] ?? 0) + 1;
      }
      return counts;
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerCountsForGroups');
      rethrow;
    }
  }

  /// Delete a group
  /// BL-008: Throws if players are still assigned to the group
  Future<void> deleteGroup(int id) async {
    try {
      // BL-008: Check for assigned players before deletion
      final playerCount = await getPlayerCountInGroup(id);
      if (playerCount > 0) {
        throw RepositoryException(
          message: 'Gruppe kann nicht gelöscht werden: $playerCount Spieler sind noch zugewiesen',
          operation: 'deleteGroup',
          code: 'FK_VIOLATION',
        );
      }

      await supabase
          .from('instruments')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteGroup');
      rethrow;
    }
  }

  // --- Group Categories ---

  /// Get all group categories
  Future<List<GroupCategory>> getGroupCategories() async {
    try {
      final response = await supabase
          .from('group_categories')
          .select('*')
          .eq('tenant_id', currentTenantId)
          .order('sort_order', ascending: true, nullsFirst: false)
          .order('name');

      return (response as List)
          .map((e) => GroupCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getGroupCategories');
      rethrow;
    }
  }

  /// Create a group category
  Future<GroupCategory> createGroupCategory({
    required String name,
  }) async {
    try {
      // RT-008: Use maybeSingle() to avoid StateError
      final response = await supabase
          .from('group_categories')
          .insert({
            'name': name,
            'tenant_id': currentTenantId,
          })
          .select()
          .maybeSingle();

      if (response == null) {
        throw RepositoryException(
          message: 'Kategorie konnte nicht erstellt werden',
          operation: 'createGroupCategory',
        );
      }
      return GroupCategory.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createGroupCategory');
      rethrow;
    }
  }

  /// Update a group category
  Future<GroupCategory> updateGroupCategory(int id, Map<String, dynamic> updates) async {
    try {
      updates.remove('id');
      updates.remove('created_at');
      updates.remove('tenant_id');

      // RT-008: Use maybeSingle() to avoid StateError
      final response = await supabase
          .from('group_categories')
          .update(updates)
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select()
          .maybeSingle();

      if (response == null) {
        throw RepositoryException(
          message: 'Gruppenkategorie mit ID $id nicht gefunden',
          operation: 'updateGroupCategory',
        );
      }
      return GroupCategory.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateGroupCategory');
      rethrow;
    }
  }

  /// Persist new sort_order values for instruments (id -> sort_order).
  /// Ionic: instrument-list.page.ts saveOrder()
  Future<void> updateGroupSortOrders(Map<int, int> sortOrders) async {
    try {
      for (final entry in sortOrders.entries) {
        await supabase
            .from('instruments')
            .update({'sort_order': entry.value})
            .eq('id', entry.key)
            .eq('tenantId', currentTenantId);
      }
    } catch (e, stack) {
      handleError(e, stack, 'updateGroupSortOrders');
      rethrow;
    }
  }

  /// Persist new sort_order values for group categories (id -> sort_order).
  /// Ionic: group-category.service.ts updateGroupCategorySortOrder()
  Future<void> updateGroupCategorySortOrders(Map<int, int> sortOrders) async {
    try {
      for (final entry in sortOrders.entries) {
        await supabase
            .from('group_categories')
            .update({'sort_order': entry.value})
            .eq('id', entry.key)
            .eq('tenant_id', currentTenantId);
      }
    } catch (e, stack) {
      handleError(e, stack, 'updateGroupCategorySortOrders');
      rethrow;
    }
  }

  /// Delete a group category
  Future<void> deleteGroupCategory(int id) async {
    try {
      await supabase
          .from('group_categories')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteGroupCategory');
      rethrow;
    }
  }
}
