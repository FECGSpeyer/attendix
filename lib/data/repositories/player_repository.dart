import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../models/person/person.dart';
import '../models/instrument/instrument.dart';
import '../../core/utils/person_matcher.dart';
import '../../core/utils/text_utils.dart';
import 'base_repository.dart';
import 'user_registration_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for PlayerRepository
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref);
});

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
          .isFilter('pending', null)
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
      final data = player.toJson();
      // Remove computed fields
      data.remove('groupName');
      data.remove('firstOfInstrument');
      data.remove('instrumentLength');
      data.remove('teacherName');
      data.remove('criticalReasonText');
      data.remove('person_attendances');
      data.remove('percentage');
      
      // Set tenant ID
      data['tenantId'] = currentTenantId;

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
      final data = player.toJson();
      // Remove read-only and computed fields
      data.remove('id');
      data.remove('created_at');
      data.remove('createdAt');
      data.remove('groupName');
      data.remove('firstOfInstrument');
      data.remove('instrumentLength');
      data.remove('teacherName');
      data.remove('criticalReasonText');
      data.remove('isPresent');
      data.remove('text');
      data.remove('attStatus');
      data.remove('person_attendances');
      data.remove('percentage');

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
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toIso8601String(),
        'text': reason ?? 'Kein Grund angegeben',
        'type': PlayerHistoryType.archived.value,
      });

      await supabase
          .from('player')
          .update({
            'left': leftDate,
            'history': history,
            'appId': null,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'archivePlayer');
      rethrow;
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

    try {
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toIso8601String(),
        'text': 'Person wurde reaktiviert',
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
  }

  /// Delete a player permanently
  Future<void> deletePlayer(int playerId) async {
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
        'date': DateTime.now().toIso8601String(),
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
        'date': DateTime.now().toIso8601String(),
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

  /// Add player to all upcoming attendances (based on relevant groups)
  Future<void> addToUpcomingAttendances(Person player) async {
    if (player.id == null) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Get upcoming attendances for this tenant
      final upcomingAttendances = await supabase
          .from('attendance')
          .select('id, type_id')
          .eq('tenantId', currentTenantId)
          .gte('date', today);

      if ((upcomingAttendances as List).isEmpty) return;

      // Get attendance types to check relevant_groups and default_status
      final types = await supabase
          .from('attendance_types')
          .select('id, relevant_groups, default_status')
          .eq('tenant_id', currentTenantId);

      final typeMap = <dynamic, Map<String, dynamic>>{};
      for (final t in types as List) {
        final id = t['id']; // Can be int or String
        final groups = t['relevant_groups'];
        final defaultStatusRaw = t['default_status'];

        // Convert String name to Integer value (DB stores "present", "neutral", etc.)
        int defaultStatusInt;
        if (defaultStatusRaw is int) {
          defaultStatusInt = defaultStatusRaw;
        } else if (defaultStatusRaw is String) {
          defaultStatusInt = AttendanceStatus.values
              .firstWhere(
                (s) => s.name == defaultStatusRaw,
                orElse: () => AttendanceStatus.neutral,
              )
              .value;
        } else {
          defaultStatusInt = AttendanceStatus.neutral.value;
        }

        typeMap[id] = {
          'relevant_groups': groups is List ? groups : [],
          'default_status': defaultStatusInt,
        };
      }

      for (final attendance in upcomingAttendances) {
        final attendanceId = attendance['id']; // Can be int or String (UUID)
        final typeId = attendance['type_id'];
        final typeData = typeId != null ? typeMap[typeId] : null;
        final relevantGroups = (typeData?['relevant_groups'] as List?) ?? [];
        final defaultStatus = typeData?['default_status'] ?? 0;

        // Check if player's instrument is in relevant groups (or all groups allowed)
        final isRelevant = relevantGroups.isEmpty ||
            relevantGroups.contains(player.instrument);

        if (isRelevant) {
          // Check if entry already exists
          final existing = await supabase
              .from('person_attendances')
              .select('id')
              .eq('attendance_id', attendanceId)
              .eq('person_id', player.id!)
              .maybeSingle();

          if (existing == null) {
            await supabase.from('person_attendances').insert({
              'attendance_id': attendanceId,
              'person_id': player.id,
              'status': defaultStatus, // Use default status from attendance type
            });
          }
        }
      }
    } catch (e, stack) {
      handleError(e, stack, 'addToUpcomingAttendances');
      rethrow; // Rethrow to see error in UI
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
          'date': DateTime.now().toIso8601String(),
          'text': 'Automatisch reaktiviert (Pausenzeit abgelaufen)',
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
        'date': DateTime.now().toIso8601String(),
        'text': 'Genehmigt',
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

      // Add to upcoming attendances (same as unpause)
      await addToUpcomingAttendances(player);
    } catch (e, stack) {
      handleError(e, stack, 'approvePlayer');
      rethrow;
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
        'date': DateTime.now().toIso8601String(),
        'text': reason,
        'type': PlayerHistoryType.declined.value,
      });

      await supabase
          .from('player')
          .update({
            'pending': false,
            'left': DateTime.now().toIso8601String(),
            'history': history,
          })
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // Remove from tenantUsers if linked
      if (player.appId != null) {
        await supabase
            .from('tenantUsers')
            .delete()
            .eq('userId', player.appId!)
            .eq('tenantId', currentTenantId);
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
        'date': DateTime.now().toIso8601String(),
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
      // Add history entry
      final history = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      history.add({
        'date': DateTime.now().toIso8601String(),
        'text': 'Verspätungen besprochen und zurückgesetzt',
        'type': PlayerHistoryType.notes.value,
      });

      final response = await supabase
          .from('player')
          .update({
            'lastSolve': DateTime.now().toIso8601String(),
            'history': history,
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
        'date': DateTime.now().toIso8601String(),
        'text': notes ?? 'Problemfall besprochen und gelöst',
        'type': PlayerHistoryType.criticalPerson.value,
      });

      final response = await supabase
          .from('player')
          .update({
            'isCritical': false,
            'lastSolve': DateTime.now().toIso8601String(),
            'criticalReason': null,
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

    try {
      final response = await supabase
          .from('player')
          .update({'appId': null})
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

  /// Check if a player already exists in the target tenant
  /// Uses email or appId for duplicate detection
  Future<bool> playerExistsInTenant(Person player, int targetTenantId) async {
    try {
      // Check by email if available — case-insensitive & trimmed like Ionic
      // (`.ilike('email', normalized)`); empty emails never match (B10-007/008)
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

      // Check by appId if available
      if (player.appId != null && player.appId!.isNotEmpty) {
        final byAppId = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', targetTenantId)
            .eq('appId', player.appId!)
            .limit(1);
        if ((byAppId as List).isNotEmpty) return true;
      }

      return false;
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

      // Determine history types based on stayInInstance
      final sourceHistoryType = stayInInstance
          ? PlayerHistoryType.copiedTo
          : PlayerHistoryType.transferredTo;
      final targetHistoryType = stayInInstance
          ? PlayerHistoryType.copiedFrom
          : PlayerHistoryType.transferredFrom;

      final now = DateTime.now().toIso8601String();

      // 1. Update source player with history entry
      final sourceHistory = List<Map<String, dynamic>>.from(
        player.history.map((e) => e.toJson()),
      );
      sourceHistory.add({
        'date': now,
        'text': stayInInstance
            ? 'Kopiert nach $targetTenantName'
            : 'Übertragen nach $targetTenantName',
        'type': sourceHistoryType.value,
      });

      final sourceUpdate = <String, dynamic>{
        'history': sourceHistory,
      };

      // If transferring (not copying), archive the source player
      if (!stayInInstance) {
        sourceUpdate['left'] = now.substring(0, 10); // Date only
        sourceUpdate['appId'] = null; // Unlink account
      }

      await supabase
          .from('player')
          .update(sourceUpdate)
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId);

      // 2. Create new player in target tenant
      final targetHistory = <Map<String, dynamic>>[
        {
          'date': now,
          'text': stayInInstance
              ? 'Kopiert von $sourceTenantName'
              : 'Übertragen von $sourceTenantName',
          'type': targetHistoryType.value,
        },
      ];

      final newPlayerData = <String, dynamic>{
        'tenantId': targetTenantId,
        'firstName': player.firstName,
        'lastName': player.lastName,
        'email': player.email,
        'birthday': player.birthday,
        'joined': player.joined ?? now.substring(0, 10),
        'phone': player.phone,
        'notes': player.notes,
        'instrument': targetGroupId,
        'isLeader': false, // Reset leader status
        'isCritical': false, // Reset critical status
        'pending': false,
        'paused': false,
        'history': targetHistory,
        // Don't copy: appId (user must re-link), img, shift_id, etc.
      };

      await supabase.from('player').insert(newPlayerData);

      return handoverSuccess;
    } catch (e, stack) {
      handleError(e, stack, 'handoverPlayer');
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

      final history = [
        ...target.history.map((e) => e.toJson()),
        {
          'date': DateTime.now().toIso8601String(),
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
  Future<List<_TypeFilter>> _loadTypeFilters() async {
    final types = await supabase
        .from('attendance_types')
        .select('id, relevant_groups, default_status, additional_fields_filter')
        .eq('tenant_id', currentTenantId);
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
      );
    }).toList();
  }

  /// Default values of the tenant's extra fields (for filter matching).
  Future<Map<String, dynamic>> _loadExtraFieldDefaults() async {
    final row = await supabase
        .from('tenants')
        .select('additional_fields')
        .eq('id', currentTenantId)
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
  Future<void> addPlayerToAttendancesByDate(Person player) async {
    final playerId = player.id;
    if (playerId == null) return;
    try {
      final joined = player.joined != null && player.joined!.length >= 10
          ? player.joined!.substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);
      final attendances = await supabase
          .from('attendance')
          .select('id, type_id')
          .eq('tenantId', currentTenantId)
          .gt('date', joined);
      if ((attendances as List).isEmpty) return;

      final types = await _loadTypeFilters();
      final defaults = await _loadExtraFieldDefaults();
      final existing = await _existingAttendanceIds(playerId);

      final rows = <Map<String, dynamic>>[];
      for (final att in attendances) {
        if (existing.contains(att['id']?.toString())) continue;
        final type = types.where((t) => t.id == att['type_id']).firstOrNull;
        if (type == null) continue;
        if (!_matchesType(player, type, defaults, checkPaused: false)) continue;
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
      final upcoming = await supabase
          .from('attendance')
          .select('id, type_id')
          .eq('tenantId', currentTenantId)
          .gte('date', today);
      if ((upcoming as List).isEmpty) return;

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
  Future<Set<String>> _existingAttendanceIds(int playerId) async {
    final rows = await supabase
        .from('person_attendances')
        .select('attendance_id, attendance:attendance_id!inner(tenantId)')
        .eq('person_id', playerId)
        .eq('attendance.tenantId', currentTenantId);
    return (rows as List)
        .map((r) => r['attendance_id']?.toString())
        .whereType<String>()
        .toSet();
  }

  /// Move person_attendances from [fromId] to [toId]; rows that would
  /// conflict (same attendance) are deleted, the target's row wins.
  /// Callers must verify both ids belong to the current tenant
  /// (person_attendances has no tenant column).
  Future<void> _reassignPersonAttendances(int fromId, int toId) async {
    final fromRows = await supabase
        .from('person_attendances')
        .select('id, attendance_id')
        .eq('person_id', fromId);
    if ((fromRows as List).isEmpty) return;

    final toRows = await supabase
        .from('person_attendances')
        .select('attendance_id')
        .eq('person_id', toId);
    final toAttendanceIds =
        (toRows as List).map((r) => r['attendance_id']?.toString()).toSet();

    final conflicting = <dynamic>[];
    final movable = <dynamic>[];
    for (final r in fromRows) {
      if (toAttendanceIds.contains(r['attendance_id']?.toString())) {
        conflicting.add(r['id']);
      } else {
        movable.add(r['id']);
      }
    }

    if (conflicting.isNotEmpty) {
      await supabase
          .from('person_attendances')
          .delete()
          .inFilter('id', conflicting)
          .eq('person_id', fromId);
    }
    if (movable.isNotEmpty) {
      await supabase
          .from('person_attendances')
          .update({'person_id': toId})
          .inFilter('id', movable)
          .eq('person_id', fromId);
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
  });

  final dynamic id;
  final List<int> relevantGroups;
  final int defaultStatus;
  final String? filterKey;
  final dynamic filterOption;
}
