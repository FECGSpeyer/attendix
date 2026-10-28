import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parent/parent_model.dart';
import 'base_repository.dart';

/// Provider for ParentRepository
final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepository(ref);
});

/// Repository for parent operations
class ParentRepository extends BaseRepository with TenantAwareRepository {
  ParentRepository(super.ref);

  /// Get all parents for the current tenant
  Future<List<ParentModel>> getParents() async {
    try {
      final response = await supabase
          .from('parents')
          .select('*')
          .eq('tenantId', currentTenantId)
          .order('lastName')
          .order('firstName');

      return (response as List)
          .map((e) => ParentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getParents');
      rethrow;
    }
  }

  /// Create a new parent
  Future<ParentModel> createParent(ParentModel parent) async {
    ensureNotDemo('createParent'); // DEMO_GUARD
    try {
      final data = parent.toJson();
      data.remove('id');
      data.remove('created_at');
      data['tenantId'] = currentTenantId;

      final response = await supabase
          .from('parents')
          .insert(data)
          .select()
          .single();

      return ParentModel.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createParent');
      rethrow;
    }
  }

  /// Delete a parent
  Future<void> deleteParent(int id) async {
    ensureNotDemo('deleteParent'); // DEMO_GUARD
    try {
      await supabase
          .from('parents')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteParent');
      rethrow;
    }
  }
}
