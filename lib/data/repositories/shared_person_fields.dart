import '../models/person/person.dart';
import '../../core/utils/paged_query.dart';
import 'base_repository.dart';

/// PARITY_B: organisation person fields (`tenant_group_person_fields`).
///
/// Ionic: `utilities/organisation-person-key.ts`, `db.service.ts`
/// (hydrateSharedPersonFieldValues / setGlobalPersonId) and
/// `organisation.service.ts` (getPersonFieldValuesForPeople /
/// updatePersonFieldValues).
///
/// `tenant_group_person_fields` and `tenant_groups` have no tenantId column:
/// rows are scoped by the organisation id (`tenant_group`), which callers
/// resolve from the current tenant via `tenant_group_tenants.tenant_id`.

/// Ionic getOrganisationPersonKey: `global:<id>` for linked persons,
/// `app:<uuid>` for accounts, otherwise null.
String? organisationPersonKeyOf(Person person) {
  final g = person.globalPersonId;
  if (g != null && g.isNotEmpty) return 'global:$g';
  final a = person.appId;
  if (a != null && a.isNotEmpty) return 'app:$a';
  return null;
}

/// Ionic hydrateSharedPersonFieldValues (merge loop): shared values override
/// the tenant `additional_fields` of the same person.
List<Person> mergeSharedPersonFieldValues(
  List<Person> players,
  Map<String, Map<String, dynamic>> valuesByPersonKey,
) {
  if (valuesByPersonKey.isEmpty) return players;
  return [
    for (final p in players)
      () {
        final key = organisationPersonKeyOf(p);
        final shared = key == null ? null : valuesByPersonKey[key];
        if (shared == null) return p;
        return p.copyWith(additionalFields: {
          ...?p.additionalFields,
          ...shared,
        });
      }(),
  ];
}

/// Default values of the organisation fields (Ionic setGlobalPersonId:
/// `Object.fromEntries(additional_fields.map(f => [f.id, f.defaultValue]))`).
Map<String, dynamic> organisationFieldDefaults(List<dynamic>? additionalFields) {
  return {
    for (final f in additionalFields ?? const [])
      if (f is Map && f['id'] != null) f['id'].toString(): f['defaultValue'],
  };
}

mixin SharedPersonFieldsRepository on BaseRepository {
  /// Ionic getPersonFieldValuesForPeople: one batch read for many persons.
  Future<Map<String, Map<String, dynamic>>> getSharedFieldValuesForPeople(
    int organisationId,
    List<String> personKeys,
  ) async {
    if (personKeys.isEmpty) return {};
    try {
      // Sol review: page through the rows (PostgREST max-rows) with a stable
      // order, and chunk the key list so the `in` filter URL stays short.
      const chunkSize = 100;
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < personKeys.length; i += chunkSize) {
        final chunk = personKeys.sublist(
            i, (i + chunkSize).clamp(0, personKeys.length));
        rows.addAll(await fetchAllPages<Map<String, dynamic>>((from, to) async {
          final page = await supabase
              .from('tenant_group_person_fields')
              .select('person_key, field_id, value')
              .eq('tenant_group', organisationId)
              .inFilter('person_key', chunk)
              .order('id')
              .range(from, to);
          return (page as List).cast<Map<String, dynamic>>();
        }));
      }

      final values = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final key = row['person_key'].toString();
        (values[key] ??= {})[row['field_id'].toString()] = row['value'];
      }
      return values;
    } catch (e, stack) {
      handleError(e, stack, 'getSharedFieldValuesForPeople');
      rethrow;
    }
  }

  /// Ionic hydrateSharedPersonFieldValues for [organisationId].
  Future<List<Person>> hydrateSharedPersonFieldValuesFor(
    int? organisationId,
    List<Person> players,
  ) async {
    if (organisationId == null) return players;
    final keys = players
        .map(organisationPersonKeyOf)
        .whereType<String>()
        .toSet()
        .toList();
    final values = await getSharedFieldValuesForPeople(organisationId, keys);
    return mergeSharedPersonFieldValues(players, values);
  }

  /// Ionic setGlobalPersonId (db.service): after linking, upsert the
  /// organisation field defaults for `global:<id>`.
  Future<void> writeOrganisationFieldDefaults(
    int organisationId,
    String globalPersonId,
  ) async {
    try {
      // tenant_groups has no tenantId: scoped by the organisation id that the
      // caller resolved from the current tenant.
      final org = await supabase
          .from('tenant_groups')
          .select('additional_fields')
          .eq('id', organisationId)
          .maybeSingle();
      final defaults =
          organisationFieldDefaults(org?['additional_fields'] as List?);
      if (defaults.isEmpty) return;
      final rows = defaults.entries
          .map((e) => {
                'tenant_group': organisationId,
                'person_key': 'global:$globalPersonId',
                'field_id': e.key,
                'value': e.value,
              })
          .toList();
      await supabase
          .from('tenant_group_person_fields')
          .upsert(rows, onConflict: 'tenant_group,person_key,field_id');
    } catch (e, stack) {
      handleError(e, stack, 'writeOrganisationFieldDefaults');
      rethrow;
    }
  }
}
