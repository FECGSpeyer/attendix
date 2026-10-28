import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/paged_query.dart';
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
  /// administration page; each update is scoped to the player `id` AND its own
  /// `tenantId`.
  ///
  /// SOL_FIX3: the church reference lives inside the JSON column
  /// `additional_fields` (no FK column), so a single `UPDATE … SET church`
  /// statement is impossible without overwriting the other fields. Instead:
  /// 1. load ALL referencing persons server-side filtered by the church id,
  ///    page by page (PostgREST max-rows) with a stable order — completely
  ///    loaded before any update, so updated rows leaving the filter cannot
  ///    shift the pages,
  /// 2. update each person with error checking (an update that matches no
  ///    row, e.g. blocked by RLS, counts as failed),
  /// 3. delete the duplicate ONLY if every update succeeded and no reference
  ///    is left; otherwise throw [ChurchMergeIncompleteException] and keep the
  ///    duplicate so no person points to a deleted church.
  Future<int> mergeChurches(String targetId, String duplicateId) async {
    ensureNotDemo('mergeChurches'); // DEMO_GUARD
    if (targetId == duplicateId) return 0;
    try {
      final players = await _playersReferencingChurch(duplicateId);

      var updated = 0;
      var failed = 0;
      for (final row in players) {
        final fields = row['additional_fields'];
        if (fields is! Map || fields[kChurchFieldKey] != duplicateId) continue;
        final newFields = Map<String, dynamic>.from(fields)
          ..[kChurchFieldKey] = targetId;
        try {
          final result = await supabase
              .from('player')
              .update({'additional_fields': newFields})
              .eq('id', row['id'] as Object)
              .eq('tenantId', row['tenantId'] as Object)
              .select('id');
          if ((result as List).isEmpty) {
            failed++;
          } else {
            updated++;
          }
        } catch (_) {
          failed++;
        }
      }

      if (failed > 0) {
        throw ChurchMergeIncompleteException(updated: updated, failed: failed);
      }

      // Re-check: a reference added meanwhile must not end up dangling.
      final remaining = await supabase
          .from('player')
          .select('id')
          .eq(_churchFilterColumn, duplicateId)
          .limit(1);
      if ((remaining as List).isNotEmpty) {
        throw ChurchMergeIncompleteException(updated: updated, failed: 0);
      }

      await supabase.from('churches').delete().eq('id', duplicateId);
      return updated;
    } catch (e, stack) {
      handleError(e, stack, 'mergeChurches');
      rethrow;
    }
  }

  /// JSON key of the church reference inside `player.additional_fields`.
  static const String kChurchFieldKey = 'bfecg_church';

  /// PostgREST JSON path filter on the church reference.
  static const String _churchFilterColumn =
      'additional_fields->>$kChurchFieldKey';

  /// SOL_FIX3: every person (all tenants, see [mergeChurches]) referencing
  /// [churchId], loaded page by page ordered by the unique `id`.
  Future<List<Map<String, dynamic>>> _playersReferencingChurch(
      String churchId) {
    return fetchAllPages<Map<String, dynamic>>((from, to) async {
      final page = await supabase
          .from('player')
          .select('id, tenantId, additional_fields')
          .eq(_churchFilterColumn, churchId)
          .order('id')
          .range(from, to);
      return (page as List).cast<Map<String, dynamic>>();
    });
  }
}

/// SOL_FIX3: church merge stopped before deleting the duplicate because not
/// every referencing person could be re-pointed.
class ChurchMergeIncompleteException implements Exception {
  const ChurchMergeIncompleteException({
    required this.updated,
    required this.failed,
  });

  final int updated;
  final int failed;

  @override
  String toString() =>
      'ChurchMergeIncompleteException(updated: $updated, failed: $failed)';
}
