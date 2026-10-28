import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../models/person/person.dart';
import '../models/instrument/instrument.dart';
import 'base_repository.dart';

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

  /// Pause a player
  Future<void> pausePlayer(Person player, String? pausedUntil, String reason) async {
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

      // Remove from upcoming attendances
      await removeFromUpcomingAttendances(player.id!);
    } catch (e, stack) {
      handleError(e, stack, 'pausePlayer');
      rethrow;
    }
  }

  /// Unpause a player
  Future<void> unpausePlayer(Person player, {String historyText = 'Pause beendet'}) async {
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

  /// Remove player from all upcoming (future) attendances
  Future<void> removeFromUpcomingAttendances(int playerId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Get upcoming attendance IDs for this tenant
      final upcomingAttendances = await supabase
          .from('attendance')
          .select('id')
          .eq('tenantId', currentTenantId)
          .gte('date', today);

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
      // Check by email if available
      if (player.email != null && player.email!.isNotEmpty) {
        final byEmail = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', targetTenantId)
            .eq('email', player.email!)
            .maybeSingle();
        if (byEmail != null) return true;
      }

      // Check by appId if available
      if (player.appId != null && player.appId!.isNotEmpty) {
        final byAppId = await supabase
            .from('player')
            .select('id')
            .eq('tenantId', targetTenantId)
            .eq('appId', player.appId!)
            .maybeSingle();
        if (byAppId != null) return true;
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
}
