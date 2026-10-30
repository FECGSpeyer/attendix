import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/enums.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/repositories.dart';
import 'tenant_providers.dart';
import 'group_providers.dart';
import '../services/tracking/tracking_event.dart';
import '../services/tracking/tracking_service.dart';
import '../services/offline_list_cache.dart';
import 'user_registration_providers.dart';

/// Initialized player repository with tenant context
/// SOL_FIX1: per-tenant immutable instance, so a tenant switch never
/// changes the tenant of an operation that is already running.
final playerRepositoryWithTenantProvider = Provider<PlayerRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(playerRepositoryForTenantProvider(tenant));
});

/// Provider for active players list
final playersProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);

  if (!repo.hasTenantId) return [];

  // Offline: the last loaded list (rehearsal rooms without reception).
  return OfflineListCache.read<Person>(
    ref,
    tenantId: repo.currentTenantId,
    part: 'players',
    fetch: repo.getPlayers,
    toJson: (p) => p.toJson(),
    fromJson: Person.fromJson,
  );
});

/// Provider for players with group names enriched
final playersWithGroupsProvider = FutureProvider<List<Person>>((ref) async {
  final players = await ref.watch(playersProvider.future);
  final groupsMap = await ref.watch(groupsMapProvider.future);
  
  return players.map((person) {
    final groupName = person.instrument != null 
        ? groupsMap[person.instrument] 
        : null;
    return person.copyWith(groupName: groupName);
  }).toList();
});

/// Provider for a single player by ID
final playerByIdProvider = FutureProvider.family<Person?, int>((ref, id) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return null;
  
  return repo.getPlayerById(id);
});

/// Provider for pending players
final pendingPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getPendingPlayers();
});

/// Provider for archived players
final archivedPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getArchivedPlayers();
});

/// Provider for critical players
final criticalPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getCriticalPlayers();
});

/// Provider for player count by instrument
final playerCountByInstrumentProvider = FutureProvider<Map<int, int>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return {};
  
  return repo.getPlayerCountByInstrument();
});

/// Notifier for player mutations
class PlayerNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  PlayerRepository get _repo => ref.read(playerRepositoryWithTenantProvider);

  Future<Person?> createPlayer(Person player) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.createPlayer(player);
      ref.read(trackingServiceProvider).track(TrackingEvent.playerAdded, properties: {'instrumentId': player.instrument});
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      return result;
    } catch (e, stack) {
      // LOGIC_PEOPLE: surface errors to the caller (Ionic shows a toast);
      // swallowing them made pages show success toasts on failure.
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Person?> updatePlayer(Person player) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updatePlayer(player);
      ref.read(trackingServiceProvider).track(TrackingEvent.playerUpdated);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
      return result;
    } catch (e, stack) {
      // LOGIC_PEOPLE: surface errors to the caller (Ionic shows a toast);
      // swallowing them made pages show success toasts on failure.
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> archivePlayer(Person player, String leftDate, String? reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.archivePlayer(player, leftDate, reason);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(archivedPlayersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  Future<void> reactivatePlayer(Person player) async {
    state = const AsyncValue.loading();
    try {
      await _repo.reactivatePlayer(player);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(archivedPlayersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  Future<void> pausePlayer(Person player, String? pausedUntil, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.pausePlayer(player, pausedUntil, reason);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  Future<void> unpausePlayer(Person player) async {
    state = const AsyncValue.loading();
    try {
      await _repo.unpausePlayer(player);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  /// Ionic db.removePlayer: deletes the person and (when [appId] is set)
  /// removes the account's access to this instance.
  Future<void> deletePlayer(int playerId, {String? appId}) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deletePlayer(playerId, appId: appId);
      ref.read(trackingServiceProvider).track(TrackingEvent.playerRemoved);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  Future<void> approvePlayer(Person player) async {
    // SOL_FIX4: read both tenant-bound repositories once before the first
    // await, so a tenant switch A→B mid-flow cannot approve in A but change
    // the account role in B.
    final repo = _repo;
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    state = const AsyncValue.loading();
    try {
      await repo.approvePlayer(player);
      await _notifyApproval(registration, player);
      state = const AsyncValue.data(null);
      ref.invalidate(pendingPlayersProvider);
      ref.invalidate(playersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  Future<void> declinePlayer(Person player, String reason) async {
    // SOL_FIX4: both repositories bound before the first await.
    final repo = _repo;
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    state = const AsyncValue.loading();
    try {
      await repo.declinePlayer(player, reason);
      await _notifyReject(registration, player);
      state = const AsyncValue.data(null);
      ref.invalidate(pendingPlayersProvider);
      ref.invalidate(playersProvider);
      ref.invalidate(archivedPlayersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // LOGIC_PEOPLE: rethrow
      rethrow;
    }
  }

  // AUTH: Ionic approvePlayer/declinePlayer – applicant becomes PLAYER and
  // gets the approve/reject mail via the attendix-user Edge Function.
  // Mail failures are non-blocking (the person is already updated).
  Future<void> _notifyApproval(
      UserRegistrationRepository registration, Person player) async {
    if (!registration.hasTenantId) return;
    // DB_REVIEW_REST: like Ionic person.page approvePlayer a failed role
    // update fails the approval (otherwise the account silently stays
    // Bewerber); only the mail stays non-blocking.
    if (player.appId != null && player.appId!.isNotEmpty) {
      await registration.updateTenantUserRole(player.appId!, Role.player);
    }
    try {
      if (player.email != null && player.email!.isNotEmpty) {
        await registration.informUserAboutApproval(
            player.email!, player.firstName, Role.player);
      }
    } catch (e) {
      debugPrint('approvePlayer: notify failed (non-blocking): $e');
    }
  }

  Future<void> _notifyReject(
      UserRegistrationRepository registration, Person player) async {
    if (!registration.hasTenantId) return;
    if (player.email == null || player.email!.isEmpty) return;
    try {
      await registration.informUserAboutReject(player.email!, player.firstName);
    } catch (e) {
      debugPrint('declinePlayer: notify failed (non-blocking): $e');
    }
  }

  Future<Person?> resetLateCount(Person player) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.resetLateCount(player);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
      return result;
    } catch (e, stack) {
      // LOGIC_PEOPLE: surface errors to the caller (Ionic shows a toast);
      // swallowing them made pages show success toasts on failure.
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Person?> resolveCritical(Person player, String? notes) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.resolveCritical(player, notes);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(criticalPlayersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
      return result;
    } catch (e, stack) {
      // LOGIC_PEOPLE: surface errors to the caller (Ionic shows a toast);
      // swallowing them made pages show success toasts on failure.
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Person?> linkAccount(Person player, String appId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.linkAccount(player, appId);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
      return result;
    } catch (e, stack) {
      // LOGIC_PEOPLE: surface errors to the caller (Ionic shows a toast);
      // swallowing them made pages show success toasts on failure.
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<Person?> unlinkAccount(Person player) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.unlinkAccount(player);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
      return result;
    } catch (e, stack) {
      // LOGIC_PEOPLE: surface errors to the caller (Ionic shows a toast);
      // swallowing them made pages show success toasts on failure.
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final playerNotifierProvider = NotifierProvider<PlayerNotifier, AsyncValue<void>>(() {
  return PlayerNotifier();
});
