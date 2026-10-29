import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parent/parent_model.dart';
import '../../core/constants/enums.dart';
import '../../l10n/l10n.dart';
import 'base_repository.dart';
import 'user_registration_repository.dart' show AccountFlowException;

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

  /// Delete a parent.
  ///
  /// LOGIC_PEOPLE: Ionic db.deleteParent — first revokes the account's access
  /// (removeEmailFromAuth → tenantUsers row of this tenant, admins are kept)
  /// and aborts when that fails; then deletes the `parents` row.
  Future<void> deleteParent(int id, {String? appId}) async {
    ensureNotDemo('deleteParent'); // DEMO_GUARD
    if (appId != null && appId.isNotEmpty) {
      try {
        final admin = await supabase
            .from('tenantUsers')
            .select('userId')
            .eq('tenantId', currentTenantId)
            .eq('role', Role.admin.value)
            .eq('userId', appId)
            .limit(1);
        if ((admin as List).isEmpty) {
          await supabase
              .from('tenantUsers')
              .delete()
              .eq('tenantId', currentTenantId)
              .eq('userId', appId);
        }
      } catch (_) {
        throw AccountFlowException(l10nWithoutContext.dbRemoveAuthEmailFailed);
      }
    }
    try {
      await supabase
          .from('parents')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbDeleteParentFailed);
    }
  }
}
