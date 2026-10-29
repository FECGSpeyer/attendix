import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

import '../../data/models/person/person.dart';
import '../../data/models/team_org/team_org.dart';
import '../../data/repositories/agenda_item_repository.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../features/team_organization/team_org_utils.dart';
import 'debug_providers.dart';
import 'self_service_providers.dart';
import 'tenant_providers.dart';
import '../../l10n/l10n.dart';

// ── Repositories with tenant ────────────────────────────────

final agendaItemRepositoryWithTenantProvider = Provider<AgendaItemRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(agendaItemRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [AgendaItemRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final agendaItemRepositoryForTenantProvider =
    Provider.family<AgendaItemRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _agendaItemRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _agendaItemRepositoryForAccountProvider =
    Provider.family<AgendaItemRepository, AccountScopeKey>((ref, key) {
  final repo = AgendaItemRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

final taskRepositoryWithTenantProvider = Provider<TaskRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(taskRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [TaskRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final taskRepositoryForTenantProvider =
    Provider.family<TaskRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _taskRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _taskRepositoryForAccountProvider =
    Provider.family<TaskRepository, AccountScopeKey>((ref, key) {
  final repo = TaskRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

final protocolRepositoryWithTenantProvider = Provider<ProtocolRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(protocolRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ProtocolRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final protocolRepositoryForTenantProvider =
    Provider.family<ProtocolRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _protocolRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _protocolRepositoryForAccountProvider =
    Provider.family<ProtocolRepository, AccountScopeKey>((ref, key) {
  final repo = ProtocolRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

// ── Context: types, role, person ────────────────────────────

/// Attendance types with their protocol settings.
final protocolTypesProvider = FutureProvider<List<ProtocolType>>((ref) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(protocolRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getProtocolTypes();
});

/// Protocol settings of one attendance type (null while loading / unknown).
final protocolTypeByIdProvider = Provider.family<ProtocolType?, String?>((ref, typeId) {
  if (typeId == null) return null;
  final types = ref.watch(protocolTypesProvider).valueOrNull ?? const <ProtocolType>[];
  for (final t in types) {
    if (t.id == typeId) return t;
  }
  return null;
});

/// Teamorganisation is visible once at least one type has protocols enabled.
final teamOrgEnabledProvider = Provider<bool>((ref) {
  final types = ref.watch(protocolTypesProvider).valueOrNull;
  return isTeamOrgEnabled(types);
});

/// Leadership (Admin / Verantwortlicher): plans, writes protocols, manages tasks.
final isTeamLeaderProvider = Provider<bool>((ref) {
  return isTeamLeaderRole(ref.watch(effectiveRoleProvider));
});

/// The signed-in person (player row) of the current tenant.
final teamPersonProvider = FutureProvider<Person?>((ref) async {
  return ref.watch(currentSelfServicePlayerProvider.future);
});

/// Whether the user belongs to the circle of at least one protocol type.
final inTeamCircleProvider = Provider<bool>((ref) {
  if (!ref.watch(teamOrgEnabledProvider)) return false;
  if (ref.watch(isTeamLeaderProvider)) return true;
  final person = ref.watch(teamPersonProvider).valueOrNull;
  if (person == null || (person.left != null && person.left!.isNotEmpty)) return false;
  final types = ref.watch(protocolTypesProvider).valueOrNull;
  return isInAnyCircle(types, ref.watch(effectiveRoleProvider), person.instrument);
});

// ── Tasks ───────────────────────────────────────────────────

/// Tasks of the signed-in person.
final myTasksProvider = FutureProvider<List<TeamTask>>((ref) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(taskRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final person = await ref.watch(teamPersonProvider.future);
  if (person?.id == null) return [];
  return repo.getTasksForPersons([person!.id!]);
});

/// Tasks shown in the "Aufgaben" tab: all for leadership, own for members.
final teamTasksProvider = FutureProvider<List<TeamTask>>((ref) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(taskRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  if (ref.watch(isTeamLeaderProvider)) return repo.getTasks();
  return ref.watch(myTasksProvider.future);
});

final taskByIdProvider = FutureProvider.family<TeamTask?, String>((ref, id) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(taskRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getTaskById(id);
});

final tasksForAgendaItemProvider = FutureProvider.family<List<TeamTask>, String>((ref, id) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(taskRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getTasksForAgendaItem(id);
});

final tasksForAttendanceProvider = FutureProvider.family<List<TeamTask>, int>((ref, id) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(taskRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getTasksForAttendance(id);
});

// ── Topics ──────────────────────────────────────────────────

/// Leadership: all topics. Members: their own suggestions (RLS).
final agendaItemsProvider = FutureProvider<List<AgendaItem>>((ref) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(agendaItemRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getAgendaItems();
});

final agendaItemByIdProvider = FutureProvider.family<AgendaItem?, String>((ref, id) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(agendaItemRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getAgendaItemById(id);
});

final agendaItemHistoryProvider =
    FutureProvider.family<List<AgendaItemHistoryEntry>, String>((ref, id) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(agendaItemRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final list = await repo.getHistory(id);
  list.sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
  return list;
});

// ── Protocols / attendances ────────────────────────────────

/// Protocol of one Termin (null when none was started yet).
final protocolForAttendanceProvider = FutureProvider.family<Protocol?, int>((ref, attendanceId) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(protocolRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getProtocolForAttendance(attendanceId);
});

final protocolsProvider = FutureProvider<List<Protocol>>((ref) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(protocolRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getProtocols();
});

/// Upcoming Termine of protocol-enabled types, soonest first.
final upcomingProtocolAttendancesProvider = FutureProvider<List<ProtocolAttendance>>((ref) async {
  // SOL_FIX15: RLS/role-dependent (leaders see all topics, decision notes
  // and protocol results) – never keep them across an account switch.
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(protocolRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final types = await ref.watch(protocolTypesProvider.future);
  final upcoming = await repo.getUpcomingAttendances();
  return upcomingProtocolAttendances(upcoming, types);
});

// ── Mutations ───────────────────────────────────────────────

/// Mutations of tasks (create / update / delete) with cache invalidation.
class TeamTaskNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  TaskRepository get _repo => ref.read(taskRepositoryWithTenantProvider);

  void _invalidate(TeamTask? task) {
    ref.invalidate(teamTasksProvider);
    ref.invalidate(myTasksProvider);
    if (task?.id != null) ref.invalidate(taskByIdProvider(task!.id!));
    if (task?.agendaItemId != null) ref.invalidate(tasksForAgendaItemProvider(task!.agendaItemId!));
    if (task?.attendanceId != null) ref.invalidate(tasksForAttendanceProvider(task!.attendanceId!));
  }

  Future<TeamTask> create(TeamTask task, {bool notify = false}) async {
    // SOL_FIX4: bind the tenant repository before the first await.
    final repo = _repo;
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    state = const AsyncValue.loading();
    try {
      final created = await repo.createTask(task);
      state = const AsyncValue.data(null);
      if (notify && created.id != null) {
        await protocolRepo.notifyTeam({'type': 'task_assigned', 'taskId': created.id});
      }
      _invalidate(created);
      return created;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<TeamTask> update(String id, Map<String, dynamic> updates, {bool notify = false}) async {
    // SOL_FIX4: bind the tenant repository before the first await.
    final repo = _repo;
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    state = const AsyncValue.loading();
    try {
      final updated = await repo.updateTask(id, updates);
      state = const AsyncValue.data(null);
      if (notify) {
        await protocolRepo.notifyTeam({'type': 'task_assigned', 'taskId': id});
      }
      _invalidate(updated);
      return updated;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> delete(TeamTask task) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteTask(task.id!);
      state = const AsyncValue.data(null);
      _invalidate(task);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final teamTaskNotifierProvider = NotifierProvider<TeamTaskNotifier, AsyncValue<void>>(
  TeamTaskNotifier.new,
);

/// Mutations of topics with cache invalidation.
class AgendaItemNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  AgendaItemRepository get _repo => ref.read(agendaItemRepositoryWithTenantProvider);

  Future<AgendaItem> create(AgendaItem item) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repo.createAgendaItem(item);
      state = const AsyncValue.data(null);
      ref.invalidate(agendaItemsProvider);
      return created;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<AgendaItem> update(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repo.updateAgendaItem(id, updates);
      state = const AsyncValue.data(null);
      ref.invalidate(agendaItemsProvider);
      ref.invalidate(agendaItemByIdProvider(id));
      return updated;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Accept / reject a member's suggestion and notify the proposer.
  Future<void> decide(String id, Map<String, dynamic> changes) async {
    // SOL_FIX4: bind the tenant repository before the first await.
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    await update(id, changes);
    await protocolRepo.notifyTeam({'type': 'proposal_decided', 'agendaItemId': id});
  }

  Future<void> propose(String title, String? description) async {
    final repo = _repo; // SOL_FIX4: bind the tenant repository before the first await.
    state = const AsyncValue.loading();
    try {
      final person = await ref.read(teamPersonProvider.future);
      if (person?.id == null) throw Exception(l10nWithoutContext.dbNoPersonFound);
      await repo.proposeAgendaItem(title: title, description: description, proposedBy: person!.id!);
      state = const AsyncValue.data(null);
      ref.invalidate(agendaItemsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteAgendaItem(id);
      state = const AsyncValue.data(null);
      ref.invalidate(agendaItemsProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final agendaItemNotifierProvider = NotifierProvider<AgendaItemNotifier, AsyncValue<void>>(
  AgendaItemNotifier.new,
);

/// Saves topics into a Termin's plan (re-reads the plan first) and returns the new plan.
Future<Map<String, dynamic>> addTopicsToAttendance(
  ProtocolRepository repo,
  ProtocolAttendance attendance,
  ProtocolType? type,
  List<({AgendaItem item, int duration})> selections, {
  List<String> removeIds = const [],
}) async {
  var current = attendance;
  ProtocolAttendance? fresh;
  try {
    fresh = await repo.getAttendance(attendance.id);
  } catch (_) {
    // fall back to the loaded plan
  }
  if (fresh != null) {
    // SOL_FIX32: a plan deleted since the picker opened is a conflict –
    // `copyWith(plan: null)` would keep (and write back) the old plan.
    if (fresh.plan == null && attendance.plan != null) {
      throw StateError('plan of attendance ${attendance.id} was deleted');
    }
    current = attendance.copyWith(plan: fresh.plan);
  }
  final plan = planWithTopics(current, type, selections, removeIds: removeIds);
  return await repo.updateAttendancePlan(attendance.id, plan) ?? plan;
}
