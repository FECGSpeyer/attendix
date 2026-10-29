import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../models/person/person.dart';
import '../models/instrument/instrument.dart';
import '../models/shift/shift_plan.dart';
import '../../core/utils/people_shift_status.dart';
import '../../core/utils/person_matcher.dart';
import '../../core/utils/text_utils.dart';
import '../../core/utils/db_helpers.dart';
import '../../core/utils/paged_query.dart'; // SOL_FIX4
import '../../core/config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;
import 'base_repository.dart';
import 'user_registration_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for PlayerRepository
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref);
});

/// SOL_FIX1: one immutable repository instance per tenant. A running
/// multi-step operation keeps its instance (and tenant) even when the user
/// switches tenants, instead of a shared instance changing tenant mid-flow.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final playerRepositoryForTenantProvider =
    Provider.family<PlayerRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _playerRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _playerRepositoryForAccountProvider =
    Provider.family<PlayerRepository, AccountScopeKey>((ref, key) {
  final repo = PlayerRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Ionic DEFAULT_IMAGE (placeholder avatar).
const String kDefaultPersonImage =
    'https://ionicframework.com/docs/img/demos/avatar.svg';

/// Repository for player/person operations
class PlayerRepository extends BaseRepository with TenantAwareRepository {
  PlayerRepository(super.ref);

  /// Get all active players for the current tenant
  Future<List<Person>> getPlayers({
    bool includeAttendances = false,
    bool all = false,
  }) async {
    try {
      var query = supabase
          .from('player')
          .select(includeAttendances ? '*, person_attendances(*)' : '*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false);

      if (!all) {
        query = query.isFilter('left', null);
      }

      final response = await query
          .order('instrument')
          .order('isLeader', ascending: false)
          .order('lastName');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayers');
      rethrow;
    }
  }

  /// Get a single player by ID
  Future<Person?> getPlayerById(int id) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerById');
      rethrow;
    }
  }

  /// Get player by app ID (user ID)
  Future<Person?> getPlayerByAppId(String appId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('appId', appId)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerByAppId');
      rethrow;
    }
  }

  /// Get pending (not yet approved) players
  Future<List<Person>> getPendingPlayers() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('pending', true)
          .order('created_at');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPendingPlayers');
      rethrow;
    }
  }

  /// Get archived (left) players
  Future<List<Person>> getArchivedPlayers() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false)
          .not('left', 'is', null)
          .order('left', ascending: false);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getArchivedPlayers');
      rethrow;
    }
  }

  /// Get active players for a specific instrument/voice group.
  ///
  /// Returns players whose `instrument` matches [instrumentId] and who are
  /// not pending and have not left. Ordered by leader first, then last name.
  Future<List<Person>> getPlayersByInstrument(int instrumentId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('instrument', instrumentId)
          .isFilter('left', null)
          .isFilter('pending', false)
          .order('isLeader', ascending: false)
          .order('lastName');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayersByInstrument');
      rethrow;
    }
  }

  /// Get conductors (main group members)
  Future<List<Person>> getConductors(int mainGroupId, {bool includeLeft = false}) async {
    try {
      var query = supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('instrument', mainGroupId)
          .isFilter('pending', false);

      if (!includeLeft) {
        query = query.isFilter('left', null);
      }

      final response = await query.order('lastName');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getConductors');
      rethrow;
    }
  }

  /// Returns players whose `parent_id` equals [parentId], in the current
  /// tenant. Filters out pending and left players (matches `isFilter`
  /// semantics used by the parents portal).
  ///
  /// Note: the DB column is `parent_id` (snake_case). Confirmed against
  /// existing repository methods and the Ionic db.service.ts.
  Future<List<Person>> getChildrenForParent(int parentId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('parent_id', parentId)
          // LOGIC_SELF: Ionic getPlayers (PARENT) `.is('pending', false)` —
          // approved players have pending=false, not NULL.
          .isFilter('pending', false)
          .isFilter('left', null)
          .order('lastName');
      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getChildrenForParent');
      rethrow;
    }
  }

  /// Get players by parent ID (for parent role)
  Future<List<Person>> getPlayersByParentId(int parentId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*, person_attendances(*)')
          .eq('tenantId', currentTenantId)
          .eq('parent_id', parentId)
          .isFilter('pending', false)
          .isFilter('left', null)
          .order('instrument')
          .order('isLeader', ascending: false)
          .order('lastName');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayersByParentId');
      rethrow;
    }
  }

  /// Find players by first and last name (for duplicate detection)
  Future<List<Person>> findPlayersByName(String firstName, String lastName) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .ilike('firstName', firstName)
          .ilike('lastName', lastName);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'findPlayersByName');
      return [];
    }
  }

  /// Create a new player
  Future<Person> createPlayer(Person player) async {
    ensureNotDemo('createPlayer'); // DEMO_GUARD
    try {
      // Computed fields stripped, tenantId set (shared with reactivation).
      final data = _personInsertData(player);

      final response = await supabase
          .from('player')
          .insert(data)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createPlayer');
      rethrow;
    }
  }

  /// LOGIC_PEOPLE: Ionic db.addPlayer(player, register, role).
  ///
  /// With [register] and an e-mail the account is registered/linked right
  /// away (registerUser with [role]). When the account already has a player
  /// row in this tenant (e.g. a returning member who left), that row is
  /// reactivated (`left = null`, fields overwritten) instead of inserting a
  /// duplicate. Non-pending persons are added to every Termin since their
  /// join date.
  Future<Person> addPlayer(
    Person player, {
    required bool register,
    required Role role,
  }) async {
    ensureNotDemo('addPlayer'); // DEMO_GUARD
    var person = player;
    final email = player.email?.trim() ?? '';
    if (register && email.isNotEmpty) {
      final appId = await _registration().registerUser(
        email: email,
        name: player.firstName,
        role: role,
      );
      person = person.copyWith(appId: appId);
    }

    Person result;
    final appId = person.appId;
    Map<String, dynamic>? existing;
    if (appId != null && appId.isNotEmpty) {
      existing = await supabase
          .from('player')
          .select('id')
          .eq('appId', appId)
          .eq('tenantId', currentTenantId)
          .limit(1)
          .maybeSingle();
    }

    if (existing != null && existing['id'] != null) {
      try {
        final data = _personInsertData(person)
          ..remove('id')
          ..['left'] = null;
        final updated = await supabase
            .from('player')
            .update(data)
            .eq('id', existing['id'])
            .eq('tenantId', currentTenantId)
            .select()
            .single();
        result = Person.fromJson(updated);
      } catch (e, stack) {
        handleError(e, stack, 'addPlayer');
        rethrow;
      }
    } else {
      result = await createPlayer(person);
    }

    if (!person.pending) {
      await addPlayerToAttendancesByDate(result);
    }
    return result;
  }

  /// DB_FIX: insert / reactivate payload like Ionic addPlayer:
  /// `pickPersonFields({...player, tenantId, id: Utils.getId()})`.
  ///
  /// Only whitelisted `player` columns are sent (Person.toJson also holds
  /// client-only keys such as `telegramId` → PGRST204). Null values are
  /// dropped: they correspond to Ionic's undefined form fields, which JSON
  /// serialisation omits, so DB defaults / existing values (e.g. `img` of a
  /// reactivated row) stay intact. `img` is not part of pickPersonFields; a
  /// non-data URL (adopted picture of a cross-tenant match) is still sent,
  /// mirroring Ionic sanitizeImg.
  Map<String, dynamic> _personInsertData(Person player) {
    final data = pickPersonFields(player.toJson())
      ..remove('created_at')
      ..removeWhere((_, v) => v == null);
    data['id'] = generateIonicId();
    data['tenantId'] = currentTenantId;
    final img = player.img;
    if (img != null && img.isNotEmpty && !img.startsWith('data:')) {
      data['img'] = img;
    }
    return data;
  }

  /// Update an existing player
  Future<Person> updatePlayer(Person player) async {
    ensureNotDemo('updatePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for update',
        operation: 'updatePlayer',
      );
    }

    try {
      // DB_FIX: Ionic updatePlayer → update(pickPersonFields(player)) without
      // id / created_at (no img, no client-only keys like telegramId).
      // tenantId stays out of the body: the row is filtered by it.
      final data = pickPersonFields(player.toJson())
        ..remove('id')
        ..remove('created_at')
        ..remove('tenantId');

      final response = await supabase
          .from('player')
          .update(data)
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .maybeSingle();

      // RT-008: Handle case where player was not found
      if (response == null) {
        throw RepositoryException(
          message: 'Player not found or belongs to different tenant',
          operation: 'updatePlayer',
        );
      }

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updatePlayer');
      rethrow;
    }
  }

  /// Update arbitrary fields on a player row. Used by inline-edit pages
  /// where building a full Person object would be overkill (e.g. when
  /// the payload mixes top-level fields with JSON-column updates).
  ///
  /// Read-only fields (id, tenantId, created_at) are stripped from the
  /// input map before the update is sent.
  Future<void> updatePlayerFields(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updatePlayerFields'); // DEMO_GUARD
    try {
      updates.remove('id');
      updates.remove('tenantId');
      updates.remove('created_at');

      await supabase
          .from('player')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updatePlayerFields');
      rethrow;
    }
  }

  /// Archive a player (soft delete)
  Future<void> archivePlayer(Person player, String leftDate, String? reason) async {
    ensureNotDemo('archivePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for archive',
        operation: 'archivePlayer',
      );
    }

    try {
      // LOGIC_PEOPLE: Ionic db.archivePlayer — revoke the account's access
      // (tenantUsers, guarded for admins / other linked persons) and clear
      // appId.
      // SOL_FIX1: tied solely to appId (Ionic additionally requires an
      // e-mail, which left the account link + access of persons without
      // e-mail in place after archiving).
      var clearAppId = false;
      final appId = player.appId;
      if (appId != null && appId.isNotEmpty) {
        await removeUserFromTenant(appId, personId: player.id);
        clearAppId = true;
      }

      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': (reason == null || reason.isEmpty)
            ? 'Kein Grund angegeben'
            : reason,
        'type': PlayerHistoryType.archived.value,
      });

      await supabase
          .from('player')
          .update({
            'left': leftDate,
            'history': history,
            if (clearAppId) 'appId': null,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Ionic removePlayerFromUpcomingAttendances(id, left): drop the person
      // from every Termin after the leave date.
      await removeFromUpcomingAttendances(player.id!, from: leftDate);
    } catch (e, stack) {
      handleError(e, stack, 'archivePlayer');
      rethrow;
    }
  }

  /// LOGIC_PEOPLE: Ionic db.removeUserFromTenant — removes the account's
  /// access (tenantUsers row) from the current tenant.
  ///
  /// Without [deleteAdmin] nothing happens when the account is ADMIN here,
  /// and with [personId] access is kept while the same account is still
  /// linked to another active person of this tenant.
  Future<void> removeUserFromTenant(
    String appId, {
    int? personId,
    bool deleteAdmin = false,
  }) async {
    ensureNotDemo('removeUserFromTenant'); // DEMO_GUARD
    try {
      if (deleteAdmin) {
        await supabase
            .from('tenantUsers')
            .delete()
            .eq('tenantId', currentTenantId)
            .eq('role', Role.admin.value)
            .eq('userId', appId);
        return;
      }

      final admin = await supabase
          .from('tenantUsers')
          .select('userId')
          .eq('tenantId', currentTenantId)
          .eq('role', Role.admin.value)
          .eq('userId', appId)
          .limit(1);
      if ((admin as List).isNotEmpty) return;

      if (personId != null) {
        final others = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', currentTenantId)
            .eq('appId', appId)
            .isFilter('left', null)
            .neq('id', personId)
            .limit(1);
        if ((others as List).isNotEmpty) return;
      }

      await supabase
          .from('tenantUsers')
          .delete()
          .eq('tenantId', currentTenantId)
          .eq('userId', appId);
    } catch (e) {
      // Ionic: throw new Error(translate('db.removeFromTenantFailed'))
      throw AccountFlowException(l10nWithoutContext.dbRemoveFromTenantFailed);
    }
  }

  /// Reactivate an archived player
  Future<void> reactivatePlayer(Person player) async {
    ensureNotDemo('reactivatePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for reactivate',
        operation: 'reactivatePlayer',
      );
    }

    // LOGIC_PEOPLE: Ionic db.activatePlayer — (re)create the account when an
    // e-mail is set, history 'Person wieder aktiviert', left = null, then add
    // the person to upcoming Termine (with shift / extra-field filters).
    //
    // SOL_FIX25: a person that kept its account link (e.g. transferred to
    // another tenant: archived here with `appId`) reuses that link when the
    // account still has access to this tenant; registering again would find
    // this very person as a duplicate and abort before `left` is reset.
    var person = player;
    if ((player.email ?? '').trim().isNotEmpty) {
      final linked = await _existingAccountLink(player);
      if (linked == null) {
        final appId = await _registration().createPlayerAccount(
          player,
          mainGroupId: await _mainGroupId(),
        );
        person = person.copyWith(appId: appId);
      }
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': 'Person wieder aktiviert',
        'type': PlayerHistoryType.returned.value,
      });

      await supabase
          .from('player')
          .update({
            'left': null,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'reactivatePlayer');
      rethrow;
    }

    await addToUpcomingAttendances(person);
  }

  /// SOL_FIX25: [player]'s `appId` when that account still has access to
  /// this tenant (`tenantUsers` row), otherwise null.
  Future<String?> _existingAccountLink(Person player) async {
    final appId = player.appId;
    if (appId == null || appId.isEmpty) return null;
    try {
      final rows = await supabase
          .from('tenantUsers')
          .select('userId')
          .eq('tenantId', currentTenantId)
          .eq('userId', appId)
          .limit(1);
      return (rows as List).isNotEmpty ? appId : null;
    } catch (e, stack) {
      handleError(e, stack, '_existingAccountLink');
      rethrow;
    }
  }

  /// Registration repository bound to the current tenant.
  ///
  /// SOL_FIX1: own instance bound to this repository's tenant instead of
  /// mutating the shared registration repository.
  UserRegistrationRepository _registration() {
    return UserRegistrationRepository(ref)..bindTenantId(currentTenantId);
  }

  /// Main group (Hauptgruppe) of [tenantId] (default: current tenant).
  Future<int?> _mainGroupId({int? tenantId}) async {
    final row = await supabase
        .from('instruments')
        .select('id')
        .eq('tenantId', tenantId ?? currentTenantId)
        .eq('maingroup', true)
        .limit(1)
        .maybeSingle();
    return row?['id'] as int?;
  }

  /// Delete a player permanently.
  ///
  /// LOGIC_PEOPLE: Ionic db.removePlayer — afterwards the account's access
  /// to this tenant is removed (guarded like [removeUserFromTenant]).
  Future<void> deletePlayer(int playerId, {String? appId}) async {
    ensureNotDemo('deletePlayer'); // DEMO_GUARD
    try {
      await supabase
          .from('player')
          .delete()
          .eq('id', playerId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'deletePlayer');
      rethrow;
    }
    if (appId != null && appId.isNotEmpty) {
      await removeUserFromTenant(appId, personId: playerId);
    }
  }

  /// Pause a player.
  ///
  /// [pauseFrom] (YYYY-MM-DD, optional, Ionic "Pausiert ab"): when set, the
  /// player is removed from every attendance on/after that date — including
  /// past ones — instead of only from upcoming attendances.
  /// Returns the updated history (reused for pausing in other tenants).
  Future<List<Map<String, dynamic>>> pausePlayer(
    Person player,
    String? pausedUntil,
    String reason, {
    String? pauseFrom,
  }) async {
    ensureNotDemo('pausePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for pause',
        operation: 'pausePlayer',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': reason,
        'type': PlayerHistoryType.paused.value,
      });

      await supabase
          .from('player')
          .update({
            'paused': true,
            'paused_until': pausedUntil,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Remove from upcoming attendances (or from all since pauseFrom)
      await removeFromUpcomingAttendances(player.id!, from: pauseFrom);
      return history;
    } catch (e, stack) {
      handleError(e, stack, 'pausePlayer');
      rethrow;
    }
  }

  /// Unpause a player
  Future<void> unpausePlayer(Person player, {String historyText = 'Pause beendet'}) async {
    ensureNotDemo('unpausePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for unpause',
        operation: 'unpausePlayer',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': historyText,
        'type': PlayerHistoryType.unpaused.value,
      });

      await supabase
          .from('player')
          .update({
            'paused': false,
            'paused_until': null,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Add to upcoming attendances
      await addToUpcomingAttendances(player);
    } catch (e, stack) {
      handleError(e, stack, 'unpausePlayer');
      rethrow;
    }
  }

  /// Remove player from all upcoming (future) attendances.
  ///
  /// With [from] (YYYY-MM-DD) the player is removed from every attendance
  /// on/after that date, including past ones (Ionic
  /// removePlayerFromUpcomingAttendances with `from`).
  Future<void> removeFromUpcomingAttendances(int playerId, {String? from}) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final since = (from != null && from.length >= 10)
          ? from.substring(0, 10)
          : today;

      // Get attendance IDs (since the given date) for this tenant
      final upcomingAttendances = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId)
          .gte('date', since);

      final attendanceIds = (upcomingAttendances as List)
          .map((a) => a['id']) // Can be int or String (UUID)
          .toList();

      if (attendanceIds.isEmpty) return;

      // Delete person_attendances for these attendances
      await supabase
          .from('person_attendances')
          .delete()
          .eq('person_id', playerId)
          .inFilter('attendance_id', attendanceIds);
    } catch (e, stack) {
      handleError(e, stack, 'removeFromUpcomingAttendances');
      // Don't rethrow - this is a secondary operation
    }
  }

  /// Add player to all upcoming attendances.
  ///
  /// LOGIC_PEOPLE: Ionic db.addPlayerToUpcomingAttendances — respects the
  /// type's `relevant_groups` AND `additional_fields_filter`, and (for
  /// non all-day types) sets status/notes from the person's shift plan
  /// (Utils.getStatusByShift, e.g. "Entschuldigt" + 'Schichtbedingt').
  Future<void> addToUpcomingAttendances(Person player) async {
    final playerId = player.id;
    if (playerId == null) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Get upcoming attendances for this tenant
      // SOL_FIX4: paginated (PostgREST max-rows), stable order by id.
      final upcomingAttendances =
          await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('attendance')
            .select('id, type_id, date, start_time, end_time')
            .eq('tenantId', currentTenantId)
            .gte('date', today)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });

      if (upcomingAttendances.isEmpty) return;

      final types = await _loadTypeFilters();
      final defaults = await _loadExtraFieldDefaults();
      final existing = await _existingAttendanceIds(playerId);
      final shift = await _loadShiftPlan(player.shiftId);

      final rows = <Map<String, dynamic>>[];
      for (final att in upcomingAttendances) {
        if (existing.contains(att['id']?.toString())) continue;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        if (!_matchesType(player, type, defaults, checkPaused: false)) continue;

        final initial = _initialStatus(player, type, att, shift);
        rows.add({
          'attendance_id': att['id'],
          'person_id': playerId,
          'notes': initial.notes,
          'status': initial.status,
        });
      }
      if (rows.isNotEmpty) {
        await supabase.from('person_attendances').insert(rows);
      }
    } catch (e, stack) {
      handleError(e, stack, 'addToUpcomingAttendances');
      rethrow; // Rethrow to see error in UI
    }
  }

  /// Shift plan of [tenantId] (default: current tenant) by id (null when
  /// unset / missing / belonging to another tenant).
  Future<ShiftPlan?> _loadShiftPlan(String? shiftId, {int? tenantId}) async {
    if (shiftId == null || shiftId.isEmpty) return null;
    final row = await supabase
        .from('shifts')
        .select('*')
        .eq('id', shiftId)
        .eq('tenant_id', tenantId ?? currentTenantId)
        .maybeSingle();
    return row == null ? null : ShiftPlan.fromJson(row);
  }

  /// Initial person_attendances status/notes for [player] in [att]: the
  /// type's default status, or — for non all-day types and a person with a
  /// shift plan — the shift-based status (Utils.getStatusByShift, e.g.
  /// "Entschuldigt" + 'Schichtbedingt').
  ///
  /// SOL_FIX1: shared by addToUpcomingAttendances and
  /// addPlayerToAttendancesByDate (approve / addPlayer / handover backfill),
  /// so every backfill path applies the shift plan.
  ({int status, String notes}) _initialStatus(
    Person player,
    _TypeFilter type,
    Map att,
    ShiftPlan? shift,
  ) {
    if (shift == null || type.allDay) {
      return (status: type.defaultStatus, notes: '');
    }
    final result = peopleStatusByShift(
      shift: shift,
      attDate: att['date']?.toString() ?? '',
      attendanceStart: att['start_time']?.toString() ?? type.startTime ?? '',
      attendanceEnd: att['end_time']?.toString() ?? type.endTime ?? '',
      defaultStatus: AttendanceStatus.fromValue(type.defaultStatus),
      shiftStart: player.shiftStart,
      shiftName: player.shiftName,
    );
    return (status: result.status.value, notes: result.note);
  }

  /// LOGIC_PEOPLE: Ionic db.updateShiftAssignmentsForPerson — after a shift
  /// change, reset the person's future shift-excused entries to the type
  /// default and re-apply the (new) shift plan.
  Future<void> updateShiftAssignmentsForPerson(Person person) async {
    final personId = person.id;
    if (personId == null) return;
    try {
      final rows = await supabase
          .from('person_attendances')
          .select(
              'id, status, notes, attendance:attendance_id!inner(id, date, type_id, start_time, end_time, tenantId)')
          .eq('person_id', personId)
          .eq('attendance.tenantId', currentTenantId);
      final types = await _loadTypeFilters();
      final shift = await _loadShiftPlan(person.shiftId);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      bool isPast(Map att) {
        final d = DateTime.tryParse(att['date']?.toString() ?? '');
        if (d == null) return true;
        return DateTime(d.year, d.month, d.day).isBefore(todayStart);
      }

      final entries = (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((r) => r['attendance'] is Map && !isPast(r['attendance'] as Map))
          .toList();

      // Phase 1: reset future shift-excused entries to the type default.
      for (final r in entries) {
        final att = r['attendance'] as Map;
        if (!isWorkExcusedNote(r['notes'] as String?) ||
            r['status'] != AttendanceStatus.excused.value) {
          continue;
        }
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        await supabase
            .from('person_attendances')
            .update({'status': type.defaultStatus, 'notes': ''})
            .eq('id', r['id'])
            .eq('person_id', personId);
        r['status'] = type.defaultStatus;
        r['notes'] = '';
      }

      // Phase 2: apply the new shift.
      if (shift == null) return;
      for (final r in entries) {
        final att = r['attendance'] as Map;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        ({AttendanceStatus status, String note}) result;
        try {
          result = peopleStatusByShift(
            shift: shift,
            attDate: att['date']?.toString() ?? '',
            attendanceStart:
                att['start_time']?.toString() ?? type.startTime ?? '',
            attendanceEnd: att['end_time']?.toString() ?? type.endTime ?? '',
            defaultStatus: AttendanceStatus.fromValue(type.defaultStatus),
            shiftStart: person.shiftStart,
            shiftName: person.shiftName,
          );
        } catch (_) {
          continue; // shift_name not in the new plan — skip like Ionic
        }
        if (result.status == AttendanceStatus.excused &&
            r['status'] == type.defaultStatus) {
          await supabase
              .from('person_attendances')
              .update({'status': result.status.value, 'notes': result.note})
              .eq('id', r['id'])
              .eq('person_id', personId);
        }
      }
    } catch (e, stack) {
      handleError(e, stack, 'updateShiftAssignmentsForPerson');
      rethrow;
    }
  }

  /// Check for players whose pause period has ended and unpause them
  Future<void> checkAndUnpausePlayers() async {
    // Skip if tenant is not set yet
    if (!hasTenantId) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Get players where paused_until has passed
      final pausedPlayers = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('paused', true)
          .not('paused_until', 'is', null)
          .lte('paused_until', today);

      for (final playerData in pausedPlayers as List) {
        final player = Person.fromJson(playerData as Map<String, dynamic>);

        // Add history entry
        final history = List<Map<String, dynamic>>.from(
          player.history.map((e) => e.toJson()),
        );
        history.add({
          'date': DateTime.now().toUtc().toIso8601String(),
          'text': 'Automatisch reaktiviert (Pausendatum erreicht)',
          'type': PlayerHistoryType.unpaused.value,
        });

        // Update player
        await supabase.from('player').update({
          'paused': false,
          'paused_until': null,
          'history': history,
        }).eq('id', player.id!)
          .eq('tenantId', currentTenantId);

        // Add to upcoming attendances
        await addToUpcomingAttendances(player);
      }
    } catch (e, stack) {
      handleError(e, stack, 'checkAndUnpausePlayers');
      // Don't rethrow - this runs in the background
    }
  }

  /// Approve a pending player
  Future<void> approvePlayer(Person player) async {
    ensureNotDemo('approvePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required',
        operation: 'approvePlayer',
      );
    }

    try {
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        // LOGIC_PEOPLE: Ionic history text incl. the approver.
        'text': 'Person genehmigt von ${_actorEmail()}',
        'type': PlayerHistoryType.approved.value,
      });

      await supabase
          .from('player')
          .update({
            'pending': false,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // LOGIC_PEOPLE: Ionic approvePlayer → addPlayerToAttendancesByDate
      // (every Termin since the join date, with group / extra-field filters).
      await addPlayerToAttendancesByDate(player);
    } catch (e, stack) {
      handleError(e, stack, 'approvePlayer');
      rethrow;
    }
  }

  /// E-mail of the signed-in user (Ionic `tenantUser().email`) for history
  /// entries like 'Person genehmigt von …'.
  String _actorEmail() {
    try {
      return supabase.auth.currentUser?.email ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Decline a pending player - archives them with a reason
  Future<void> declinePlayer(Person player, String reason) async {
    ensureNotDemo('declinePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required',
        operation: 'declinePlayer',
      );
    }

    try {
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        // LOGIC_PEOPLE: Ionic history text incl. decliner and reason.
        'text': 'Person abgelehnt von ${_actorEmail()}: $reason',
        'type': PlayerHistoryType.declined.value,
      });

      await supabase
          .from('player')
          .update({
            'pending': false,
            'left': DateTime.now().toUtc().toIso8601String(),
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Ionic removeUserFromTenant(appId, false, id): keeps admins and
      // accounts still linked to another active person.
      if (player.appId != null && player.appId!.isNotEmpty) {
        await removeUserFromTenant(player.appId!, personId: player.id);
      }
    } catch (e, stack) {
      handleError(e, stack, 'declinePlayer');
      rethrow;
    }
  }

  /// Update player's instrument
  Future<void> updatePlayerInstrument(
    Person player,
    int newInstrumentId,
    String? reason,
  ) async {
    ensureNotDemo('updatePlayerInstrument'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required',
        operation: 'updatePlayerInstrument',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        'text': reason ?? 'Instrument gewechselt',
        'type': PlayerHistoryType.instrumentChange.value,
      });

      await supabase
          .from('player')
          .update({
            'instrument': newInstrumentId,
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updatePlayerInstrument');
      rethrow;
    }
  }

  /// Search players by name
  Future<List<Person>> searchPlayers(String query) async {
    try {
      // SEC-003: Sanitize search input to prevent SQL wildcard injection
      final sanitizedQuery = sanitizeSearchQuery(query);
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false)
          .isFilter('left', null)
          .or('firstName.ilike.%$sanitizedQuery%,lastName.ilike.%$sanitizedQuery%')
          .order('lastName')
          .limit(20);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'searchPlayers');
      rethrow;
    }
  }

  /// Get player count by instrument
  Future<Map<int, int>> getPlayerCountByInstrument() async {
    try {
      final response = await supabase
          .from('player')
          .select('instrument')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false)
          .isFilter('left', null);

      final counts = <int, int>{};
      for (final row in response as List) {
        final instrument = row['instrument'] as int?;
        if (instrument != null) {
          counts[instrument] = (counts[instrument] ?? 0) + 1;
        }
      }
      return counts;
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerCountByInstrument');
      rethrow;
    }
  }

  /// Get critical players
  Future<List<Person>> getCriticalPlayers() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('isCritical', true)
          .isFilter('pending', false)
          .isFilter('left', null)
          .order('lastName');

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getCriticalPlayers');
      rethrow;
    }
  }

  /// Reset late count for a player (mark as resolved after conversation)
  Future<Person> resetLateCount(Person player) async {
    ensureNotDemo('resetLateCount'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for resetLateCount',
        operation: 'resetLateCount',
      );
    }

    try {
      // LOGIC_PEOPLE: Ionic person.page resetLateCount only sets lastSolve
      // (no history entry).
      final response = await supabase
          .from('player')
          .update({
            'lastSolve': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'resetLateCount');
      rethrow;
    }
  }

  /// Resolve critical status for a player
  Future<Person> resolveCritical(Person player, String? notes) async {
    ensureNotDemo('resolveCritical'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for resolveCritical',
        operation: 'resolveCritical',
      );
    }

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toUtc().toIso8601String(),
        // LOGIC_PEOPLE: Ionic pushes `this.notes` as is (may be empty).
        'text': notes ?? '',
        'type': PlayerHistoryType.criticalPerson.value,
      });

      final response = await supabase
          .from('player')
          .update({
            'isCritical': false,
            'lastSolve': DateTime.now().toUtc().toIso8601String(),
            // Ionic keeps criticalReason untouched.
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'resolveCritical');
      rethrow;
    }
  }

  /// Link an existing account to a player
  Future<Person> linkAccount(Person player, String appId) async {
    ensureNotDemo('linkAccount'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for linkAccount',
        operation: 'linkAccount',
      );
    }

    try {
      final response = await supabase
          .from('player')
          .update({'appId': appId})
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'linkAccount');
      rethrow;
    }
  }

  /// Unlink account from a player
  Future<Person> unlinkAccount(Person player) async {
    ensureNotDemo('unlinkAccount'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for unlinkAccount',
        operation: 'unlinkAccount',
      );
    }

    // LOGIC_PEOPLE: Ionic person.page removeUserFromTenant →
    // db.removeUserFromTenant(appId, false, id) (keeps admins / accounts
    // linked to another active person) and then clears email AND appId.
    final appId = player.appId;
    if (appId != null && appId.isNotEmpty) {
      await removeUserFromTenant(appId, personId: player.id);
    }

    try {
      final response = await supabase
          .from('player')
          .update({'appId': null, 'email': null})
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'unlinkAccount');
      rethrow;
    }
  }

  // ============= HANDOVER METHODS =============

  /// Result of a handover operation for a single player
  static const int handoverSuccess = 0;
  static const int handoverDuplicate = 1;
  static const int handoverError = 2;

  /// Check if a player already exists in the target tenant.
  ///
  /// LOGIC_PEOPLE: Ionic db.personExistsInTenant — e-mail (ilike, trimmed),
  /// then first + last name (ilike) as fallback.
  Future<bool> playerExistsInTenant(Person player, int targetTenantId) async {
    try {
      final email = normalizeEmailForMatch(player.email);
      if (email != null) {
        final byEmail = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', targetTenantId)
            .ilike('email', escapeLikePattern(email))
            .limit(1);
        if ((byEmail as List).isNotEmpty) return true;
      }

      final firstName = player.firstName.trim();
      final lastName = player.lastName.trim();
      if (firstName.isEmpty && lastName.isEmpty) return false;

      final byName = await supabase
          .from('player')
          .select('id')
          .eq('tenantId', targetTenantId)
          .ilike('firstName', escapeLikePattern(firstName))
          .ilike('lastName', escapeLikePattern(lastName))
          .limit(1);
      return (byName as List).isNotEmpty;
    } catch (e, stack) {
      handleError(e, stack, 'playerExistsInTenant');
      rethrow;
    }
  }

  /// Groups of a handover target tenant (cross-tenant read by design, the
  /// query is scoped to the explicit target tenantId).
  Future<List<Group>> getTargetTenantGroups(int targetTenantId) async {
    try {
      final response = await supabase
          .from('instruments')
          .select('*')
          .eq('tenantId', targetTenantId)
          .order('name');
      return (response as List)
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getTargetTenantGroups');
      rethrow;
    }
  }

  /// Handover a single player to another tenant
  ///
  /// [player] - The player to transfer
  /// [targetTenantId] - The target tenant ID
  /// [targetGroupId] - The mapped group/instrument ID in the target tenant
  /// [targetTenantName] - Name of target tenant for history entry
  /// [sourceTenantName] - Name of source tenant for history entry
  /// [stayInInstance] - If true, copies player (COPIED_FROM/TO), otherwise transfers (TRANSFERRED_FROM/TO)
  ///
  /// LOGIC_PEOPLE: Ionic db.handoverPerson — the target person is created
  /// FIRST (account linked/registered in the target instance with
  /// RESPONSIBLE for the target main group, else PLAYER; an existing row of
  /// the same account is reactivated; attendances since today are
  /// backfilled). Only then is the source updated (history; on transfer
  /// `left`), so a failed insert never archives the source. The source keeps
  /// its appId like in Ionic.
  ///
  /// Returns handoverSuccess, handoverDuplicate, or handoverError
  Future<int> handoverPlayer({
    required Person player,
    required int targetTenantId,
    required int? targetGroupId,
    required String targetTenantName,
    required String sourceTenantName,
    required bool stayInInstance,
  }) async {
    ensureNotDemo('handoverPlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for handover',
        operation: 'handoverPlayer',
      );
    }

    try {
      // Check for duplicates
      final exists = await playerExistsInTenant(player, targetTenantId);
      if (exists) {
        return handoverDuplicate;
      }

      final now = DateTime.now();
      final nowIso = now.toUtc().toIso8601String();
      final todayUtc =
          DateTime.utc(now.year, now.month, now.day).toIso8601String();

      // 1. Create the person in the target tenant (Ionic addPlayer).
      final targetHistory = <Map<String, dynamic>>[
        {
          'date': nowIso,
          'text':
              'Person wurde von der Instanz "$sourceTenantName" übertragen.',
          'type': (stayInInstance
                  ? PlayerHistoryType.copiedFrom
                  : PlayerHistoryType.transferredFrom)
              .value,
        },
      ];

      String? appId = player.appId;
      final email = player.email?.trim() ?? '';
      if (email.isNotEmpty) {
        final targetMainGroup = await _mainGroupId(tenantId: targetTenantId);
        final role = targetGroupId != null && targetGroupId == targetMainGroup
            ? Role.responsible
            : Role.player;
        appId = await _registration().registerUser(
          email: email,
          name: player.firstName,
          role: role,
          tenantId: targetTenantId,
        );
      }

      final img = (player.img ?? '').isNotEmpty &&
              !(player.img!.startsWith('data:'))
          ? player.img
          : kDefaultPersonImage;

      final newPlayerData = <String, dynamic>{
        'tenantId': targetTenantId,
        'firstName': player.firstName,
        'lastName': player.lastName,
        'instrument': targetGroupId,
        'img': img,
        'joined': todayUtc,
        'email': player.email,
        'appId': appId,
        'hasTeacher': player.hasTeacher,
        'teacher': player.teacher,
        'playsSince': player.playsSince,
        'correctBirthday': player.correctBirthday,
        'birthday': player.birthday,
        'isLeader': false,
        'isCritical': false,
        'notes': player.notes,
        'history': targetHistory,
        'pending': false,
        'self_register': false,
      };

      Map<String, dynamic>? existingRow;
      if (appId != null && appId.isNotEmpty) {
        existingRow = await supabase
            .from('player')
            .select('id')
            .eq('appId', appId)
            .eq('tenantId', targetTenantId)
            .limit(1)
            .maybeSingle();
      }

      final Map<String, dynamic> created;
      if (existingRow != null && existingRow['id'] != null) {
        // Ionic: reactivate the previous row of this account.
        created = await supabase
            .from('player')
            .update({...newPlayerData, 'left': null})
            .eq('id', existingRow['id'])
            .eq('tenantId', targetTenantId)
            .select()
            .single();
      } else {
        // DB_FIX: Ionic copy/transfer → addPlayer sets the id (Utils.getId)
        newPlayerData['id'] = generateIonicId();
        created = await supabase
            .from('player')
            .insert(newPlayerData)
            .select()
            .single();
      }

      final createdPerson = Person.fromJson(created);
      await addPlayerToAttendancesByDate(createdPerson,
          tenantId: targetTenantId);

      // 2. Update the source (history; transfer also sets `left`).
      final sourceHistory = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      sourceHistory.add({
        'date': nowIso,
        'text': stayInInstance
            ? 'Person wurde zu "$targetTenantName" kopiert.'
            : 'Person wurde zu "$targetTenantName" übertragen.',
        'type': (stayInInstance
                ? PlayerHistoryType.copiedTo
                : PlayerHistoryType.transferredTo)
            .value,
      });

      await supabase
          .from('player')
          .update({
            'history': sourceHistory,
            if (!stayInInstance) 'left': nowIso,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      return handoverSuccess;
    } catch (e) {
      if (e is DemoModeException) rethrow;
      debugPrint('handoverPlayer failed: $e');
      return handoverError;
    }
  }

  /// Handover multiple players to another tenant
  ///
  /// Returns a map with counts: {'success': n, 'duplicate': n, 'error': n}
  Future<Map<String, int>> handoverPlayers({
    required List<Person> players,
    required int targetTenantId,
    required Map<int, int?> groupMapping,
    required String targetTenantName,
    required String sourceTenantName,
    required bool stayInInstance,
    void Function(int current, int total, String playerName)? onProgress,
  }) async {
    ensureNotDemo('handoverPlayers'); // DEMO_GUARD
    final results = {'success': 0, 'duplicate': 0, 'error': 0};

    for (var i = 0; i < players.length; i++) {
      final player = players[i];
      onProgress?.call(i + 1, players.length, player.fullName);

      final targetGroupId = player.instrument != null
          ? groupMapping[player.instrument]
          : null;

      final result = await handoverPlayer(
        player: player,
        targetTenantId: targetTenantId,
        targetGroupId: targetGroupId,
        targetTenantName: targetTenantName,
        sourceTenantName: sourceTenantName,
        stayInInstance: stayInInstance,
      );

      switch (result) {
        case handoverSuccess:
          results['success'] = results['success']! + 1;
        case handoverDuplicate:
          results['duplicate'] = results['duplicate']! + 1;
        case handoverError:
          results['error'] = results['error']! + 1;
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------
  // PEOPLE2: reorder, duplicate detection and merge (Ionic person/list page)
  // ---------------------------------------------------------------------

  /// Persist the manual order of players inside their group
  /// (Ionic list.page savePlayerOrder). [orders] maps player id → sort_order.
  Future<void> savePlayerOrder(Map<int, int> orders) async {
    ensureNotDemo('savePlayerOrder'); // DEMO_GUARD
    try {
      for (final entry in orders.entries) {
        await supabase
            .from('player')
            .update({'sort_order': entry.value})
            .eq('id', entry.key)
            .eq('tenantId', currentTenantId);
      }
    } catch (e, stack) {
      handleError(e, stack, 'savePlayerOrder');
      rethrow;
    }
  }

  /// Same-tenant, account-less, confirmed players with a similar name —
  /// candidates for merging a pending registration into
  /// (Ionic player.service getPossibleDuplicatesInTenant).
  Future<List<RankedMatch<Person>>> getPossibleDuplicatesInTenant(
    String firstName,
    String lastName, {
    required int excludeId,
  }) async {
    String clean(String v) {
      final c = v.replaceAll(RegExp(r'[,*%():\\]+'), '').trim();
      return c.length > 50 ? c.substring(0, 50) : c;
    }

    final safeFirst = clean(firstName);
    final safeLast = clean(lastName);
    if (safeFirst.isEmpty && safeLast.isEmpty) return [];
    final orParts = <String>[
      if (safeFirst.isNotEmpty) 'firstName.ilike.$safeFirst%',
      if (safeLast.isNotEmpty) 'lastName.ilike.$safeLast%',
    ];

    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('pending', false)
          .isFilter('appId', null)
          .neq('id', excludeId)
          .or(orParts.join(','))
          .limit(500);

      final candidates = (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
      return rankCandidates<Person>(
        PersonLike(firstName: firstName, lastName: lastName),
        candidates,
        (p) => PersonLike(
          firstName: p.firstName,
          lastName: p.lastName,
          email: p.email,
          appId: p.appId,
          globalPersonId: p.globalPersonId,
          birthday: p.birthday,
        ),
        threshold: 0.65,
      );
    } catch (e, stack) {
      handleError(e, stack, 'getPossibleDuplicatesInTenant');
      rethrow;
    }
  }

  /// Merge a pending self-registration into an existing account-less person
  /// (Ionic db.service mergePendingPlayerIntoExisting): attendance and
  /// absence history move onto [target] (target wins on conflicts), the
  /// applicant's account is adopted and the pending row is deleted.
  Future<void> mergePendingPlayerIntoExisting(
    Person pending,
    Person target, {
    required String approverEmail,
  }) async {
    final pendingId = pending.id;
    final targetId = target.id;
    if (pendingId == null || targetId == null) {
      throw RepositoryException(
        message: 'Player IDs are required for merge',
        operation: 'mergePendingPlayerIntoExisting',
      );
    }

    try {
      // Both rows must belong to the current tenant (person_attendances has
      // no tenant column, so verify ownership before re-pointing rows).
      final owned = await supabase
          .from('player')
          .select('id')
          .inFilter('id', [pendingId, targetId])
          .eq('tenantId', currentTenantId);
      if ((owned as List).length != 2) {
        throw RepositoryException(
          message: l10nWithoutContext.coreFlutterRepoPersonsNotInTenant,
          operation: 'mergePendingPlayerIntoExisting',
        );
      }

      await _reassignPersonAttendances(pendingId, targetId);

      // player_absences uses snake_case tenant_id
      await supabase
          .from('player_absences')
          .update({'person_id': targetId})
          .eq('person_id', pendingId)
          .eq('tenant_id', currentTenantId);

      // SOL_FIX7: abort (keep the pending person) unless every row moved.
      await _ensureNothingLeftToTransfer(
          pendingId, 'mergePendingPlayerIntoExisting');

      final history = [
        ...target.history.map((e) => e.toJson()),
        {
          'date': DateTime.now().toUtc().toIso8601String(),
          'text': 'Zusammengeführt mit Registrierung von '
              '${pending.firstName} ${pending.lastName} '
              '(genehmigt von $approverEmail)',
          'type': PlayerHistoryType.approved.value,
        },
      ];

      await supabase
          .from('player')
          .update({
            'appId': pending.appId,
            'email': target.email ?? pending.email,
            'self_register': true,
            'history': history,
            'pending': false,
          })
          .eq('id', targetId)
          .eq('tenantId', currentTenantId);

      // Role like Ionic createAccount: main group → RESPONSIBLE.
      final mainGroup = await supabase
          .from('instruments')
          .select('id')
          .eq('tenantId', currentTenantId)
          .eq('maingroup', true)
          .limit(1)
          .maybeSingle();
      final role = UserRegistrationRepository.accountRoleFor(
        instrumentId: target.instrument,
        mainGroupId: mainGroup?['id'] as int?,
      );

      if (pending.appId != null) {
        await supabase
            .from('tenantUsers')
            .update({'role': role.value})
            .eq('userId', pending.appId!)
            .eq('tenantId', currentTenantId);
      }

      // Best-effort: notification + attendance backfill must not block cleanup
      final email = target.email ?? pending.email;
      if (email != null && email.isNotEmpty) {
        try {
          await supabase.functions.invoke('attendix-user', body: {
            'action': 'approve',
            'email': email,
            'name': target.firstName,
            'role': UserRegistrationRepository.roleText(role),
            'roleId': role.value,
            'tenantId': currentTenantId,
          });
        } catch (_) {}
      }
      // A paused person is not added to upcoming attendances.
      if (!target.paused) {
        try {
          await addToUpcomingAttendances(target);
        } catch (_) {}
      }

      await supabase
          .from('player')
          .delete()
          .eq('id', pendingId)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'mergePendingPlayerIntoExisting');
      rethrow;
    }
  }

  /// Attendance types of the current tenant with parsed filter data.
  Future<List<_TypeFilter>> _loadTypeFilters({int? tenantId}) async {
    final types = await supabase
        .from('attendance_types')
        .select(
            'id, relevant_groups, default_status, additional_fields_filter, all_day, start_time, end_time')
        .eq('tenant_id', tenantId ?? currentTenantId);
    return (types as List).map((t) {
      final raw = t['default_status'];
      final status = raw is int
          ? raw
          : AttendanceStatus.values
              .firstWhere((s) => s.name == raw,
                  orElse: () => AttendanceStatus.neutral)
              .value;
      final groups = t['relevant_groups'];
      final filter = t['additional_fields_filter'];
      return _TypeFilter(
        id: t['id'],
        relevantGroups: groups is List ? groups.whereType<int>().toList() : const [],
        defaultStatus: status,
        filterKey: filter is Map ? filter['key']?.toString() : null,
        filterOption: filter is Map ? filter['option'] : null,
        allDay: t['all_day'] == true,
        startTime: t['start_time'] as String?,
        endTime: t['end_time'] as String?,
      );
    }).toList();
  }

  /// Default values of the tenant's extra fields (for filter matching).
  Future<Map<String, dynamic>> _loadExtraFieldDefaults({int? tenantId}) async {
    final row = await supabase
        .from('tenants')
        .select('additional_fields')
        .eq('id', tenantId ?? currentTenantId)
        .maybeSingle();
    final fields = row?['additional_fields'];
    return {
      if (fields is List)
        for (final f in fields.whereType<Map>())
          f['id'].toString(): f['defaultValue'],
    };
  }

  bool _matchesType(
    Person player,
    _TypeFilter type,
    Map<String, dynamic> defaults, {
    bool checkPaused = true,
  }) {
    if (checkPaused && player.paused) return false;
    if (type.relevantGroups.isNotEmpty &&
        !type.relevantGroups.contains(player.instrument)) {
      return false;
    }
    final key = type.filterKey;
    if (key != null && type.filterOption != null && defaults.containsKey(key)) {
      final value = player.additionalFields?[key] ?? defaults[key];
      if (value != type.filterOption) return false;
    }
    return true;
  }

  /// Ionic db.addPlayerToAttendancesByDate: add the person to every
  /// attendance after their join date (or today when unknown) that matches
  /// the type's group / extra field filters.
  ///
  /// [tenantId] targets another tenant (Ionic handover: backfill in the
  /// target instance); defaults to the current tenant.
  Future<void> addPlayerToAttendancesByDate(Person player,
      {int? tenantId}) async {
    final playerId = player.id;
    if (playerId == null) return;
    final targetTenantId = tenantId ?? currentTenantId;
    try {
      final joined = player.joined != null && player.joined!.length >= 10
          ? player.joined!.substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);
      // SOL_FIX4: paginated — more than 1000 matching Termine (PostgREST
      // max-rows) were silently missed; stable order by id.
      final attendances =
          await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('attendance')
            .select('id, type_id, date, start_time, end_time')
            .eq('tenantId', targetTenantId)
            .gt('date', joined)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });
      if (attendances.isEmpty) return;

      final types = await _loadTypeFilters(tenantId: targetTenantId);
      final defaults = await _loadExtraFieldDefaults(tenantId: targetTenantId);
      final existing =
          await _existingAttendanceIds(playerId, tenantId: targetTenantId);

      final rows = <Map<String, dynamic>>[];
      for (final att in attendances) {
        if (existing.contains(att['id']?.toString())) continue;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        if (!_matchesType(player, type, defaults, checkPaused: false)) continue;
        // PARITY_A (D4): Ionic db.addPlayerToAttendancesByDate inserts the
        // type's default_status with empty notes (no shift plan here).
        rows.add({
          'attendance_id': att['id'],
          'person_id': playerId,
          'notes': '',
          'status': type.defaultStatus,
        });
      }
      if (rows.isNotEmpty) {
        await supabase.from('person_attendances').insert(rows);
      }
    } catch (e, stack) {
      handleError(e, stack, 'addPlayerToAttendancesByDate');
      rethrow;
    }
  }

  /// Ionic db.syncPlayerWithUpcomingAttendances: after a group or
  /// filter-relevant extra field change, add the person to upcoming
  /// attendances they now match and remove them from ones they no longer
  /// match. Only attendance types with a filter are touched.
  Future<void> syncPlayerWithUpcomingAttendances(
    Person player, {
    int? oldInstrument,
    Map<String, dynamic>? oldAdditionalFields,
  }) async {
    final playerId = player.id;
    if (playerId == null) return;
    try {
      final types = (await _loadTypeFilters())
          .where((t) =>
              t.relevantGroups.isNotEmpty ||
              (t.filterKey != null && t.filterOption != null))
          .toList();
      if (types.isEmpty) return;

      final defaults = await _loadExtraFieldDefaults();
      final groupChanged = oldInstrument != player.instrument;
      final changedFields = <String>{};
      for (final t in types) {
        final key = t.filterKey;
        if (key == null || !defaults.containsKey(key)) continue;
        final oldValue = oldAdditionalFields?[key] ?? defaults[key];
        final newValue = player.additionalFields?[key] ?? defaults[key];
        if (oldValue != newValue) changedFields.add(key);
      }
      if (!groupChanged && changedFields.isEmpty) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      // SOL_FIX4: paginated, stable order by id.
      final upcoming =
          await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('attendance')
            .select('id, type_id')
            .eq('tenantId', currentTenantId)
            .gte('date', today)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });
      if (upcoming.isEmpty) return;

      final existing = await _existingAttendanceIds(playerId);
      final toAdd = <Map<String, dynamic>>[];
      final toRemove = <dynamic>[];
      for (final att in upcoming) {
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        final affectsGroup = groupChanged && type.relevantGroups.isNotEmpty;
        final affectsField =
            type.filterKey != null && changedFields.contains(type.filterKey);
        if (!affectsGroup && !affectsField) continue;

        final should = _matchesType(player, type, defaults);
        final isIn = existing.contains(att['id']?.toString());
        if (should && !isIn) {
          toAdd.add({
            'attendance_id': att['id'],
            'person_id': playerId,
            'notes': '',
            'status': type.defaultStatus,
          });
        } else if (!should && isIn) {
          toRemove.add(att['id']);
        }
      }
      if (toAdd.isNotEmpty) {
        await supabase.from('person_attendances').insert(toAdd);
      }
      if (toRemove.isNotEmpty) {
        await supabase
            .from('person_attendances')
            .delete()
            .eq('person_id', playerId)
            .inFilter('attendance_id', toRemove);
      }
    } catch (e, stack) {
      handleError(e, stack, 'syncPlayerWithUpcomingAttendances');
      rethrow;
    }
  }

  /// Attendance ids (as strings) the player already has rows for, restricted
  /// to the current tenant via the attendance join.
  ///
  /// SOL_FIX4: paginated (a long-standing member easily has more than 1000
  /// rows; a truncated set re-inserted duplicates), stable order by id.
  Future<Set<String>> _existingAttendanceIds(int playerId,
      {int? tenantId}) async {
    final rows = await fetchAllPages<Map<String, dynamic>>((from, to) async {
      final page = await supabase
          .from('person_attendances')
          .select('id, attendance_id, attendance:attendance_id!inner(tenantId)')
          .eq('person_id', playerId)
          .eq('attendance.tenantId', tenantId ?? currentTenantId)
          .order('id', ascending: true)
          .range(from, to);
      return (page as List).cast<Map<String, dynamic>>();
    });
    return rows
        .map((r) => r['attendance_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  /// Move person_attendances from [fromId] to [toId]; rows that would
  /// conflict (same attendance) are deleted, the target's row wins.
  /// Callers must verify both ids belong to the current tenant
  /// (person_attendances has no tenant column).
  ///
  /// SOL_FIX7: both sides are loaded completely (paged, stable order by id;
  /// a long-standing member easily has more than PostgREST's 1000 rows) and
  /// the id lists are written in chunks. Same writes as Ionic
  /// reassignPersonAttendances otherwise (delete conflicts, re-point rest).
  Future<void> _reassignPersonAttendances(int fromId, int toId) async {
    final fromRows = await _personAttendanceRows(fromId, 'id, attendance_id');
    if (fromRows.isEmpty) return;

    final toRows = await _personAttendanceRows(toId, 'id, attendance_id');
    final toAttendanceIds =
        toRows.map((r) => r['attendance_id']?.toString()).toSet();

    final conflicting = <dynamic>[];
    final movable = <dynamic>[];
    for (final r in fromRows) {
      if (toAttendanceIds.contains(r['attendance_id']?.toString())) {
        conflicting.add(r['id']);
      } else {
        movable.add(r['id']);
      }
    }

    for (final chunk in _chunks(conflicting)) {
      await supabase
          .from('person_attendances')
          .delete()
          .inFilter('id', chunk)
          .eq('person_id', fromId);
    }
    for (final chunk in _chunks(movable)) {
      await supabase
          .from('person_attendances')
          .update({'person_id': toId})
          .inFilter('id', chunk)
          .eq('person_id', fromId);
    }
  }

  /// All person_attendances rows of [personId] (paged, ordered by id).
  Future<List<Map<String, dynamic>>> _personAttendanceRows(
      int personId, String columns) {
    return fetchAllPages<Map<String, dynamic>>((from, to) async {
      final page = await supabase
          .from('person_attendances')
          .select(columns)
          .eq('person_id', personId)
          .order('id', ascending: true)
          .range(from, to);
      return (page as List).cast<Map<String, dynamic>>();
    });
  }

  /// SOL_FIX7: id lists for `in.(…)` filters are split so the request URL
  /// stays short (a member can have thousands of rows).
  static Iterable<List<dynamic>> _chunks(List<dynamic> ids, [int size = 200]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }

  /// SOL_FIX7: the source person of a merge may only be deleted when every
  /// attendance and absence row was transferred; anything left would be
  /// lost with it (or block the delete). Throws to abort the merge.
  Future<void> _ensureNothingLeftToTransfer(int fromId, String operation) async {
    final leftAttendances = await supabase
        .from('person_attendances')
        .select('id')
        .eq('person_id', fromId)
        .limit(1);
    // player_absences uses snake_case tenant_id
    final leftAbsences = await supabase
        .from('player_absences')
        .select('id')
        .eq('person_id', fromId)
        .eq('tenant_id', currentTenantId)
        .limit(1);
    if ((leftAttendances as List).isNotEmpty || (leftAbsences as List).isNotEmpty) {
      throw RepositoryException(
        message: l10nWithoutContext.svcTransferPersonAttendancesFailed,
        operation: operation,
      );
    }
  }
}

/// Filter data of an attendance type (relevant groups + extra field filter).
class _TypeFilter {
  const _TypeFilter({
    required this.id,
    required this.relevantGroups,
    required this.defaultStatus,
    this.filterKey,
    this.filterOption,
    this.allDay = false,
    this.startTime,
    this.endTime,
  });

  final dynamic id;
  final List<int> relevantGroups;
  final int defaultStatus;
  final String? filterKey;
  final dynamic filterOption;
  final bool allDay;
  final String? startTime;
  final String? endTime;
}
