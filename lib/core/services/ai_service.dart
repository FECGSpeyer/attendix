import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../../l10n/l10n.dart';

/// AI helpers backed by Supabase Edge Functions.
///
/// Mirrors Ionic `services/ai.service.ts`. The Edge Function itself is
/// stateless (no table access), so no tenantId filter is involved.
class AiService {
  AiService(this._supabase);

  final SupabaseClient _supabase;

  /// Other names for a group/instrument as they appear in the file names of
  /// sheet music, from the `synonyms-gpt` Edge Function (returns
  /// `text/plain`), added to [existing]: what is already there stays, and a
  /// term that names one of [otherGroups] (name or synonym) is left out, as
  /// a synonym counts more than a group name when files are assigned.
  Future<String> getGroupSynonyms(
    String group, {
    String? existing,
    List<({String name, String? synonyms})> otherGroups = const [],
  }) async {
    final response = await _supabase.functions.invoke(
      'synonyms-gpt',
      body: {
        'group': group,
        'existing': splitSynonyms(existing ?? ''),
        'others': [for (final g in otherGroups.take(150)) g.name],
      },
    );
    final data = response.data;
    if (data == null) throw Exception(l10nWithoutContext.coreFlutterNoResponse);
    return mergeSynonyms(
      existing ?? '',
      normalizeSynonyms(data is String ? data : data.toString()),
      group: group,
      taken: [
        for (final g in otherGroups) ...[g.name, ...splitSynonyms(g.synonyms ?? '')],
      ],
    );
  }

  /// The terms of a synonyms field.
  static List<String> splitSynonyms(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  static String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s.\-_]+'), ' ').trim();

  /// [existing] with the terms of [generated] it does not have yet. Nothing
  /// of [existing] is removed or reordered; left out are the name of the
  /// [group] itself and terms [taken] by other groups.
  static String mergeSynonyms(
    String existing,
    String generated, {
    String group = '',
    Iterable<String> taken = const [],
  }) {
    final result = splitSynonyms(existing);
    final seen = {for (final s in result) _key(s), _key(group)};
    final blocked = {for (final t in taken) _key(t)};
    for (final s in splitSynonyms(generated)) {
      final key = _key(s);
      // A single letter ("S", "A") is in too many file names.
      if (key.length < 2 || blocked.contains(key) || !seen.add(key)) continue;
      result.add(s);
    }
    return result.join(', ');
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
