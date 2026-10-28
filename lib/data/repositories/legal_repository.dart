import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_repository.dart';

/// Read-only access to the global legal text (Impressum & Datenschutz).
///
/// Port of Ionic `services/legal/legal.service.ts`.
///
/// NOTE (Multi-Tenant): `legal_content` is a global, single-row table
/// (`id = 1`) without a `tenantId` column — the legal text is the same for
/// every tenant and must be readable before login. Therefore this repository
/// intentionally does NOT use [TenantAwareRepository]; it only ever selects the
/// fixed row `id = 1` and never writes.
class LegalRepository extends BaseRepository {
  LegalRepository(super.ref);

  static const String tableName = 'legal_content';
  static const int legalRowId = 1;

  /// Returns the legal content as HTML.
  Future<String> getLegalContent() async {
    try {
      final response = await supabase
          .from(tableName)
          .select('content_html')
          .eq('id', legalRowId)
          .single();

      return (response['content_html'] as String?) ?? '';
    } catch (e, stack) {
      handleError(e, stack, 'getLegalContent');
      rethrow;
    }
  }
}

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(ref);
});
