import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/person/person.dart';
import '../models/tenant/tenant.dart';
import 'base_repository.dart';

/// Provider for ImportRepository
final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return ImportRepository(ref);
});

/// Repository for person and song imports (Ionic: DbService.importPlayers,
/// getExistingEmails, getExistingNumbers, importSongs).
///
/// Tables:
/// - player: `tenantId`
/// - songs: `tenantId`
/// - tenants: the tenant row itself (filtered by `id` = currentTenantId)
class ImportRepository extends BaseRepository with TenantAwareRepository {
  ImportRepository(super.ref);

  static const int _pageSize = 1000;

  /// Lowercased, non-empty emails already used by players in the tenant.
  /// Paginated to defeat the PostgREST 1000-row cap.
  Future<Set<String>> getExistingPlayerEmails() async {
    try {
      final emails = <String>{};
      final tenantId = currentTenantId; // SOL_FIX1: one tenant for all pages
      var from = 0;
      while (true) {
        final data = await supabase
            .from('player')
            .select('email')
            .eq('tenantId', tenantId)
            .order('id') // SOL_FIX1: stable paging
            .range(from, from + _pageSize - 1);
        final rows = data as List;
        for (final row in rows) {
          final email = (row['email'] ?? '').toString().trim().toLowerCase();
          if (email.isNotEmpty) emails.add(email);
        }
        if (rows.length < _pageSize) break;
        from += _pageSize;
      }
      return emails;
    } catch (e, stack) {
      handleError(e, stack, 'getExistingPlayerEmails');
      rethrow;
    }
  }

  /// Insert one imported person into the current tenant.
  Future<Person> insertPlayer(Map<String, dynamic> playerData) async {
    ensureNotDemo('insertPlayer'); // DEMO_GUARD
    try {
      final data = Map<String, dynamic>.from(playerData)
        ..remove('id');
      data['tenantId'] = currentTenantId;

      final response = await supabase
          .from('player')
          .insert(data)
          .select()
          .single();
      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'insertPlayer');
      rethrow;
    }
  }

  /// Composite song keys (`${prefix ?? ''}${number}`) already in the
  /// effective song library. [songTenantId] is the Werk-Synchronisierung
  /// source tenant (Ionic `getExistingNumbers`: `effectiveSongTenantId()`);
  /// null = own library.
  Future<Set<String>> getExistingSongKeys({int? songTenantId}) async {
    final libraryTenantId = songTenantId ?? currentTenantId;
    try {
      final keys = <String>{};
      var from = 0;
      while (true) {
        final data = await supabase
            .from('songs')
            .select('number, prefix')
            .eq('tenantId', libraryTenantId)
            .order('id') // SOL_FIX1: stable paging
            .range(from, from + _pageSize - 1);
        final rows = data as List;
        for (final row in rows) {
          keys.add('${row['prefix'] ?? ''}${row['number']}');
        }
        if (rows.length < _pageSize) break;
        from += _pageSize;
      }
      return keys;
    } catch (e, stack) {
      handleError(e, stack, 'getExistingSongKeys');
      rethrow;
    }
  }

  /// Insert one imported song into the effective song library
  /// (Ionic `importSongs` → `addSong`: `effectiveSongTenantId()`).
  /// [songTenantId] = Werk-Synchronisierung source tenant, null = own library.
  Future<Map<String, dynamic>> insertSong(
    Map<String, dynamic> songData, {
    int? songTenantId,
  }) async {
    ensureNotDemo('insertSong'); // DEMO_GUARD
    try {
      final data = Map<String, dynamic>.from(songData)..remove('id');
      data['tenantId'] = songTenantId ?? currentTenantId;

      final response = await supabase
          .from('songs')
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e, stack) {
      handleError(e, stack, 'insertSong');
      rethrow;
    }
  }

  /// `tenants.song_additional_fields` of the current tenant.
  Future<List<ExtraField>> getSongAdditionalFields() async {
    try {
      final response = await supabase
          .from('tenants')
          .select('song_additional_fields')
          .eq('id', currentTenantId)
          .maybeSingle();
      final raw = response?['song_additional_fields'];
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ExtraField.fromJson)
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getSongAdditionalFields');
      rethrow;
    }
  }
}
