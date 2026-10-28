import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/viewer/viewer.dart';
import '../../core/constants/enums.dart';
import '../../l10n/l10n.dart';
import 'base_repository.dart';
import 'user_registration_repository.dart' show AccountFlowException;

/// Provider for ViewerRepository
final viewerRepositoryProvider = Provider<ViewerRepository>((ref) {
  return ViewerRepository(ref);
});

/// Repository for viewer operations
class ViewerRepository extends BaseRepository with TenantAwareRepository {
  ViewerRepository(super.ref);

  /// Get all viewers for the current tenant
  Future<List<Viewer>> getViewers() async {
    try {
      final response = await supabase
          .from('viewers')
          .select('*')
          .eq('tenantId', currentTenantId)
          .order('lastName')
          .order('firstName');

      return (response as List)
          .map((e) => Viewer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getViewers');
      rethrow;
    }
  }

  /// Create a new viewer
  Future<Viewer> createViewer(Viewer viewer) async {
    ensureNotDemo('createViewer'); // DEMO_GUARD
    try {
      final data = viewer.toJson();
      data.remove('id');
      data.remove('created_at');
      data['tenantId'] = currentTenantId;

      final response = await supabase
          .from('viewers')
          .insert(data)
          .select()
          .single();

      return Viewer.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createViewer');
      rethrow;
    }
  }

  /// Delete a viewer.
  ///
  /// LOGIC_PEOPLE: Ionic db.deleteViewer — first revokes the account's access
  /// (removeEmailFromAuth → tenantUsers row of this tenant, admins are kept)
  /// and aborts when that fails; then deletes the `viewers` row.
  Future<void> deleteViewer(int id, {String? appId}) async {
    ensureNotDemo('deleteViewer'); // DEMO_GUARD
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
          .from('viewers')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (_) {
      throw AccountFlowException(l10nWithoutContext.dbDeleteViewerFailed);
    }
  }
}
