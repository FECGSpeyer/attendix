import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/church/church.dart';
import 'base_repository.dart';

/// Provider for ChurchRepository
final churchRepositoryProvider = Provider<ChurchRepository>((ref) {
  return ChurchRepository(ref);
});

/// Repository for church operations (BFECG special feature)
/// NOTE: This repository does NOT use TenantAwareRepository as churches are global
class ChurchRepository extends BaseRepository {
  ChurchRepository(super.ref);

  /// Get all churches (global, no tenant filter)
  Future<List<Church>> getChurches() async {
    try {
      final response = await supabase
          .from('churches')
          .select('*')
          .order('name');

      return (response as List)
          .map((e) => Church.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getChurches');
      rethrow;
    }
  }

  /// Create a new church
  Future<String> createChurch(String name, {String? userId}) async {
    ensureNotDemo('createChurch'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('churches')
          .insert({
            'name': name,
            'created_from': userId,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e, stack) {
      handleError(e, stack, 'createChurch');
      rethrow;
    }
  }

  // DASHBOARD (Administration / Gemeinden-Verwaltung, super-developer only)

  /// Rename a church (global table, no tenant filter).
  Future<void> renameChurch(String id, String name) async {
    ensureNotDemo('renameChurch'); // DEMO_GUARD
    try {
      await supabase.from('churches').update({'name': name}).eq('id', id);
    } catch (e, stack) {
      handleError(e, stack, 'renameChurch');
      rethrow;
    }
  }

  /// Merge [duplicateId] into [targetId] (Ionic `ChurchService.mergeChurches`):
  /// re-points `additional_fields.bfecg_church` of every person and deletes the
  /// duplicate. Returns the number of updated persons.
  ///
  /// NOTE: Intentionally cross-tenant (churches are global and persons of all
  /// BFECG tenants reference them). Only reachable from the super-developer
  /// administration page; each update is scoped to a single player `id`.
  Future<int> mergeChurches(String targetId, String duplicateId) async {
    ensureNotDemo('mergeChurches'); // DEMO_GUARD
    try {
      final players = await supabase
          .from('player')
          .select('id, additional_fields')
          .not('additional_fields', 'is', null);

      var updated = 0;
      for (final row in players as List) {
        final fields = row['additional_fields'];
        if (fields is Map && fields['bfecg_church'] == duplicateId) {
          final newFields = Map<String, dynamic>.from(fields)
            ..['bfecg_church'] = targetId;
          try {
            await supabase
                .from('player')
                .update({'additional_fields': newFields})
                .eq('id', row['id']);
            updated++;
          } catch (_) {
            // Ionic counts only successful updates and continues.
          }
        }
      }

      await supabase.from('churches').delete().eq('id', duplicateId);
      return updated;
    } catch (e, stack) {
      handleError(e, stack, 'mergeChurches');
      rethrow;
    }
  }
}
