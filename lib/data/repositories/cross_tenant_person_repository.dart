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

/// A linked tenant in which a user is a member.
class LinkedTenantRef {
  const LinkedTenantRef({
    required this.id,
    required this.name,
    this.shortName = '',
  });

  final int id;
  final String name;
  final String shortName;
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

  // -------------------------------------------------------------------
  // PEOPLE2: other-instance membership + pausing in other instances
  // (Ionic db.service getTenantsFromUser / getUsersFromTenant /
  // getPersonIdFromTenant / pausePlayerInOtherTenant)
  // -------------------------------------------------------------------

  /// Linked tenants (excluding the current one) where [userId] is a member
  /// with a role other than viewer.
  Future<List<LinkedTenantRef>> getLinkedTenantsOfUser(
    String userId, {
    required List<int> linkedTenantIds,
  }) async {
    final others =
        linkedTenantIds.where((id) => id != currentTenantId).toList();
    if (others.isEmpty) return [];
    try {
      final response = await supabase
          .from('tenantUsers')
          .select('tenantId, role, tenant:tenantId(id, shortName, longName)')
          .eq('userId', userId)
          .inFilter('tenantId', others)
          .neq('role', _viewerRole);
      return (response as List).map((row) {
        final tenant = row['tenant'] as Map?;
        final short = tenant?['shortName']?.toString() ?? '';
        final long = tenant?['longName']?.toString() ?? '';
        return LinkedTenantRef(
          id: row['tenantId'] as int,
          name: long.isNotEmpty ? long : short,
          shortName: short,
        );
      }).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getLinkedTenantsOfUser');
      rethrow;
    }
  }

  /// User ids (non-viewer) of a linked tenant (Ionic getUsersFromTenant),
  /// used for the "Mitglied anderer Instanz" filter.
  Future<Set<String>> getUserIdsInTenant(
    int tenantId, {
    required List<int> linkedTenantIds,
  }) async {
    if (!linkedTenantIds.contains(tenantId)) return {};
    try {
      final response = await supabase
          .from('tenantUsers')
          .select('userId')
          .eq('tenantId', tenantId)
          .neq('role', _viewerRole);
      return (response as List)
          .map((r) => r['userId']?.toString())
          .whereType<String>()
          .toSet();
    } catch (e, stack) {
      handleError(e, stack, 'getUserIdsInTenant');
      rethrow;
    }
  }

  /// Player id of [userId] in a linked tenant (active row preferred).
  Future<int?> getPersonIdFromTenant(
    String userId,
    int tenantId, {
    required List<int> linkedTenantIds,
  }) async {
    if (!linkedTenantIds.contains(tenantId)) return null;
    try {
      final response = await supabase
          .from('player')
          .select('id, left')
          .eq('appId', userId)
          .eq('tenantId', tenantId)
          .eq('pending', false);
      final rows = response as List;
      if (rows.isEmpty) return null;
      final row = rows.firstWhere((r) => r['left'] == null,
          orElse: () => rows.first);
      return row['id'] as int?;
    } catch (e, stack) {
      handleError(e, stack, 'getPersonIdFromTenant');
      rethrow;
    }
  }

  /// Pause the same person in another linked tenant and remove it from that
  /// tenant's attendances (upcoming, or all since [pauseFrom]).
  Future<void> pausePlayerInOtherTenant({
    required int playerId,
    required int tenantId,
    required List<int> linkedTenantIds,
    required Map<String, dynamic> historyEntry,
    String? pausedUntil,
    String? pauseFrom,
  }) async {
    if (!linkedTenantIds.contains(tenantId)) {
      throw RepositoryException(
        message: 'Instanz ist nicht verknüpft',
        operation: 'pausePlayerInOtherTenant',
      );
    }
    try {
      // Append to that row's own history (Ionic copied the source history
      // over it, which dropped the other tenant's entries).
      final row = await supabase
          .from('player')
          .select('history')
          .eq('id', playerId)
          .eq('tenantId', tenantId)
          .maybeSingle();
      final existing = row?['history'];
      final history = <dynamic>[
        if (existing is List) ...existing,
        historyEntry,
      ];

      await supabase
          .from('player')
          .update({
            'paused': true,
            'paused_until': pausedUntil,
            'history': history,
          })
          .eq('id', playerId)
          .eq('tenantId', tenantId);

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final since = (pauseFrom != null && pauseFrom.length >= 10)
          ? pauseFrom.substring(0, 10)
          : today;
      final attendances = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', tenantId)
          .gte('date', since);
      final ids = (attendances as List).map((a) => a['id']).toList();
      if (ids.isEmpty) return;
      await supabase
          .from('person_attendances')
          .delete()
          .eq('person_id', playerId)
          .inFilter('attendance_id', ids);
    } catch (e, stack) {
      handleError(e, stack, 'pausePlayerInOtherTenant');
      rethrow;
    }
  }

  static const _viewerRole = 3; // Role.viewer

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
