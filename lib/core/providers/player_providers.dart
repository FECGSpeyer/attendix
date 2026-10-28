import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/enums.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/repositories.dart';
import 'tenant_providers.dart';
import 'group_providers.dart';
import 'user_registration_providers.dart'; // AUTH

/// Initialized player repository with tenant context
final playerRepositoryWithTenantProvider = Provider<PlayerRepository>((ref) {
  final repo = ref.watch(playerRepositoryProvider);
  final tenant = ref.watch(currentTenantIdProvider);
  
  if (tenant != null) {
    repo.setTenantId(tenant);
  }
  
  return repo;
});

/// Provider for active players list
final playersProvider = FutureProvider<List<Person>>((ref) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  
  if (!repo.hasTenantId) return [];
  
  return repo.getPlayers();
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
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<Person?> updatePlayer(Person player) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.updatePlayer(player);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
      ref.invalidate(playerByIdProvider(player.id!));
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
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
      state = AsyncValue.error(e, stack);
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
      state = AsyncValue.error(e, stack);
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
      state = AsyncValue.error(e, stack);
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
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deletePlayer(int playerId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deletePlayer(playerId);
      state = const AsyncValue.data(null);
      ref.invalidate(playersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> approvePlayer(Person player) async {
    state = const AsyncValue.loading();
    try {
      await _repo.approvePlayer(player);
      await _notifyApproval(player); // AUTH
      state = const AsyncValue.data(null);
      ref.invalidate(pendingPlayersProvider);
      ref.invalidate(playersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> declinePlayer(Person player, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.declinePlayer(player, reason);
      await _notifyReject(player); // AUTH
      state = const AsyncValue.data(null);
      ref.invalidate(pendingPlayersProvider);
      ref.invalidate(playersProvider);
      ref.invalidate(archivedPlayersProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // AUTH: Ionic approvePlayer/declinePlayer – applicant becomes PLAYER and
  // gets the approve/reject mail via the attendix-user Edge Function.
  // Mail failures are non-blocking (the person is already updated).
  Future<void> _notifyApproval(Person player) async {
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    if (!registration.hasTenantId) return;
    try {
      if (player.appId != null && player.appId!.isNotEmpty) {
        await registration.updateTenantUserRole(player.appId!, Role.player);
      }
      if (player.email != null && player.email!.isNotEmpty) {
        await registration.informUserAboutApproval(
            player.email!, player.firstName, Role.player);
      }
    } catch (e) {
      debugPrint('approvePlayer: notify failed (non-blocking): $e');
    }
  }

  Future<void> _notifyReject(Person player) async {
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
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
      state = AsyncValue.error(e, stack);
      return null;
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
      state = AsyncValue.error(e, stack);
      return null;
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
      state = AsyncValue.error(e, stack);
      return null;
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
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

final playerNotifierProvider = NotifierProvider<PlayerNotifier, AsyncValue<void>>(() {
  return PlayerNotifier();
});
