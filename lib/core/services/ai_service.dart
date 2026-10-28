import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// AI helpers backed by Supabase Edge Functions.
///
/// Mirrors Ionic `services/ai.service.ts`. The Edge Function itself is
/// stateless (no table access), so no tenantId filter is involved.
class AiService {
  AiService(this._supabase);

  final SupabaseClient _supabase;

  /// Generates a comma-separated list of synonyms for a group/instrument
  /// name via the `synonyms-gpt` Edge Function (returns `text/plain`).
  Future<String> getGroupSynonyms(String group) async {
    final response = await _supabase.functions.invoke(
      'synonyms-gpt',
      body: {'group': group},
    );
    final data = response.data;
    if (data == null) throw Exception('Keine Antwort erhalten');
    return normalizeSynonyms(data is String ? data : data.toString());
  }

  /// Trims whitespace/quotes around the reply and normalises separators to
  /// `", "` so the result can be stored directly in `instruments.synonyms`.
  static String normalizeSynonyms(String raw) {
    return raw
        .replaceAll('\n', ',')
        .split(',')
        .map((s) => s.trim().replaceAll(RegExp(r'^["\x27]+|["\x27.]+$'), '').trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
}

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref.watch(supabaseClientProvider));
});
