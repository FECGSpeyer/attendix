import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/person_matcher.dart';
import '../../core/utils/text_utils.dart';
import '../models/person/person.dart';
import 'base_repository.dart';

/// Provider for CrossTenantPersonRepository
final crossTenantPersonRepositoryProvider =
    Provider<CrossTenantPersonRepository>((ref) {
  return CrossTenantPersonRepository(ref);
});

/// A person row from a linked tenant, with display data for the UI.
class CrossTenantPersonCandidate {
  const CrossTenantPersonCandidate({
    required this.person,
    this.groupName,
    this.tenantName,
  });

  final Person person;
  final String? groupName;
  final String? tenantName;

  PersonLike get identity => PersonLike(
        firstName: person.firstName,
        lastName: person.lastName,
        email: person.email,
        appId: person.appId,
        globalPersonId: person.globalPersonId,
        birthday: person.birthday,
      );

  /// "Vorname Nachname · Gruppe (Instanz)"
  String get label =>
      '${person.firstName} ${person.lastName} · ${groupName ?? '?'} (${tenantName ?? '?'})';

  factory CrossTenantPersonCandidate.fromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    final instrumentData = data.remove('instrumentData') as Map?;
    final tenantData = data.remove('tenantData') as Map?;
    return CrossTenantPersonCandidate(
      person: Person.fromJson(data),
      groupName: instrumentData?['name'] as String?,
      tenantName: (tenantData?['longName'] ?? tenantData?['shortName']) as String?,
    );
  }
}

/// Cross-tenant person lookups and identity linking (Ionic
/// services/cross-tenant + player.service setGlobalPersonId / shared field
/// propagation).
///
/// Multi-tenant safety: these queries intentionally read/write rows of OTHER
/// tenants. They are restricted with `.inFilter('tenantId', tenantIds)` to
/// tenants linked to the current tenant via an organisation (resolved by
/// OrganisationRepository.getLinkedTenants, which verifies membership) plus
/// the current tenant itself. RLS enforces access on the server.
class CrossTenantPersonRepository extends BaseRepository
    with TenantAwareRepository {
  CrossTenantPersonRepository(super.ref);

  static const _select =
      '*, instrumentData:instrument(name), tenantData:tenantId(id, shortName, longName)';

  /// Strip characters with meaning in PostgREST `.or()` and cap length.
  static String sanitizeOrToken(String? input) {
    final cleaned = (input ?? '').replaceAll(RegExp(r'[,*%():\\]+'), '').trim();
    return cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
  }

  /// Typeahead lookup by name in linked tenants, ranked with Levenshtein
  /// (Ionic getPossiblePersonsByName). Ex-members are included on purpose.
  Future<List<RankedMatch<CrossTenantPersonCandidate>>> getPossiblePersonsByName(
    String firstName,
    String lastName, {
    required List<int> linkedTenantIds,
    bool onlyWithAccount = false,
  }) async {
    if (linkedTenantIds.isEmpty) return [];
    final safeFirst = sanitizeOrToken(firstName);
    final safeLast = sanitizeOrToken(lastName);
    if (safeFirst.isEmpty && safeLast.isEmpty) return [];

    final orParts = <String>[
      if (safeFirst.isNotEmpty) 'firstName.ilike.$safeFirst%',
      if (safeLast.isNotEmpty) 'lastName.ilike.$safeLast%',
    ];

    try {
      var query = supabase
          .from('player')
          .select(_select)
          .inFilter('tenantId', linkedTenantIds)
          .eq('pending', false)
          .or(orParts.join(','));
      if (onlyWithAccount) {
        query = query.not('email', 'is', null);
      }
      final response = await query
          .order('lastName', ascending: true)
          .order('firstName', ascending: true)
          .limit(500);

      final candidates = (response as List)
          .map((e) => CrossTenantPersonCandidate.fromRow(
              Map<String, dynamic>.from(e as Map)))
          .toList();

      return rankCandidates<CrossTenantPersonCandidate>(
        PersonLike(firstName: firstName, lastName: lastName),
        candidates,
        (c) => c.identity,
        prefixMode: true,
      );
    } catch (e, stack) {
      handleError(e, stack, 'getPossiblePersonsByName');
      rethrow;
    }
  }

  /// Active people in linked tenants using this email — case-insensitive
  /// (Ionic getPossiblePersonsByEmail uses `.ilike('email', normalized)`).
  Future<List<CrossTenantPersonCandidate>> getPossiblePersonsByEmail(
    String email, {
    required List<int> linkedTenantIds,
  }) async {
    if (linkedTenantIds.isEmpty) return [];
    final normalized = normalizeEmailForMatch(email);
    if (normalized == null) return [];
    try {
      final response = await supabase
          .from('player')
          .select(_select)
          .inFilter('tenantId', linkedTenantIds)
          .eq('pending', false)
          .isFilter('left', null)
          .ilike('email', escapeLikePattern(normalized));
      return (response as List)
          .map((e) => CrossTenantPersonCandidate.fromRow(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPossiblePersonsByEmail');
      rethrow;
    }
  }

  /// Link the given player rows to one global identity
  /// (Ionic player.service setGlobalPersonId). Only rows in the current or
  /// linked tenants are touched.
  Future<void> setGlobalPersonId(
    List<int> playerIds,
    String globalPersonId, {
    required List<int> linkedTenantIds,
  }) async {
    if (playerIds.isEmpty) return;
    try {
      await supabase
          .from('player')
          .update({'global_person_id': globalPersonId})
          .inFilter('id', playerIds)
          .inFilter('tenantId', [currentTenantId, ...linkedTenantIds]);
    } catch (e, stack) {
      handleError(e, stack, 'setGlobalPersonId');
      rethrow;
    }
  }

  /// Propagate shared identity fields (firstName, lastName, birthday, email,
  /// phone) to all rows with the same global_person_id in linked tenants
  /// (Ionic player.service updatePlayer).
  Future<void> propagateSharedFields({
    required String globalPersonId,
    required int excludePlayerId,
    required Map<String, dynamic> fields,
    required List<int> linkedTenantIds,
  }) async {
    const shared = ['firstName', 'lastName', 'birthday', 'email', 'phone'];
    final patch = <String, dynamic>{
      for (final key in shared)
        if (fields.containsKey(key)) key: fields[key],
    };
    if (patch.isEmpty) return;
    try {
      await supabase
          .from('player')
          .update(patch)
          .eq('global_person_id', globalPersonId)
          .neq('id', excludePlayerId)
          .inFilter('tenantId', [currentTenantId, ...linkedTenantIds]);
    } catch (e, stack) {
      handleError(e, stack, 'propagateSharedFields');
      rethrow;
    }
  }
}
