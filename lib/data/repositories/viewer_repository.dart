import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/viewer/viewer.dart';
import 'base_repository.dart';

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

  /// Delete a viewer
  Future<void> deleteViewer(int id) async {
    ensureNotDemo('deleteViewer'); // DEMO_GUARD
    try {
      await supabase
          .from('viewers')
          .delete()
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deleteViewer');
      rethrow;
    }
  }
}
