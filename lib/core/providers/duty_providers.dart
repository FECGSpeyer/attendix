import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance/attendance.dart';
import '../../data/models/duty/person_unavailability.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/duty_repository.dart';
import '../constants/enums.dart';
import '../utils/duty_utils.dart';
import 'attendance_detail_providers.dart';
import 'attendance_type_providers.dart';
import 'self_service_providers.dart';
import 'signout_providers.dart';
import 'tenant_providers.dart';

export '../../data/repositories/duty_repository.dart'
    show DutyTermin, DutyTakeResult, DutyNotifyType;

/// Duty repository with tenant context
final dutyRepositoryWithTenantProvider = Provider<DutyRepository>((ref) {
  final repo = ref.watch(dutyRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
  return repo;
});

/// Attendance types in Dienst-Modus
final dutyTypesProvider = Provider<List<AttendanceType>>((ref) {
  final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
  return types.where((t) => t.dutyMode).toList();
});

/// Whether the tenant uses the Dienstplan at all
final hasDutyTypesProvider = Provider<bool>((ref) {
  return ref.watch(dutyTypesProvider).isNotEmpty;
});

/// Leadership (admin/responsible) manages assignments (Ionic isTeamLeader)
final canManageDutyProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == Role.admin || role == Role.responsible;
});

/// Upcoming duty Termine (from today) with all persons
final upcomingDutyTermineProvider = FutureProvider<List<DutyTermin>>((ref) async {
  final repo = ref.watch(dutyRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  final types = await ref.watch(attendanceTypesProvider.future);
  if (!types.any((t) => t.dutyMode)) return [];
  return repo.getUpcomingDutyTermine(types);
});

/// Duty Termine of the last 180 days and the future, by attendance id
/// (for badges/names in the attendance list).
final dutyTermineByIdProvider = FutureProvider<Map<int, DutyTermin>>((ref) async {
  final repo = ref.watch(dutyRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return {};
  final types = await ref.watch(attendanceTypesProvider.future);
  if (!types.any((t) => t.dutyMode)) return {};
  final termine = await repo.getUpcomingDutyTermine(
    types,
    from: DateTime.now().subtract(const Duration(days: 180)),
  );
  return {for (final t in termine) if (t.attendance.id != null) t.attendance.id!: t};
});

/// Unavailability rules of one person ("Regelmäßig verhindert")
final unavailabilityByPersonProvider =
    FutureProvider.family<List<PersonUnavailability>, int>((ref, personId) async {
  final repo = ref.watch(dutyRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getUnavailabilityForPerson(personId);
});

/// Own duty data of the logged-in person in the current tenant
/// ("Meine Dienste", "Bitte bestätigen", "Offene Dienste").
class MyDutyOverview {
  const MyDutyOverview({
    this.person,
    this.termine = const [],
    this.requests = const [],
    this.openDuties = const [],
    this.confirmed = const [],
    this.dutiesThisMonth = 0,
    this.dutyView = false,
  });

  final Person? person;

  /// Duty Termine the person is part of (circle)
  final List<DutyTermin> termine;

  /// Own assignments waiting for confirmation (not cancelled)
  final List<({DutyTermin termin, PersonAttendance pa})> requests;

  /// Duties the person could take (self signup allowed, not assigned, not full)
  final List<DutyTermin> openDuties;

  /// Own confirmed (or self) duties, not cancelled, oldest first
  final List<({DutyTermin termin, PersonAttendance pa})> confirmed;
  final int dutiesThisMonth;

  /// Tenant switch "Dienstplan-Ansicht" is on
  final bool dutyView;

  bool get inDutyCircle => termine.isNotEmpty;

  /// "Meine Dienste" layout: tenant switch on and the person is in a duty circle
  bool get useDutyView => dutyView && inDutyCircle;

  /// Attendance ids of duties the person is not assigned to (hidden in lists)
  Set<int> get unassignedDutyIds => {
        for (final t in termine)
          if (t.persons.any((p) => p.personId == person?.id && (p.dutyState ?? '').isEmpty))
            t.attendance.id ?? -1,
      };

  /// First names of the others on the same duty
  List<String> teamOf(DutyTermin t) => t.persons
      .where((p) => p.personId != person?.id && occupiesDuty(p))
      .map((p) => p.firstName ?? '')
      .where((n) => n.isNotEmpty)
      .toList();
}

final myDutyOverviewProvider = FutureProvider<MyDutyOverview>((ref) async {
  final types = await ref.watch(attendanceTypesProvider.future);
  if (!types.any((t) => t.dutyMode)) return const MyDutyOverview();
  final person = await ref.watch(currentSelfServicePlayerProvider.future);
  final dutyView = ref.watch(currentTenantProvider)?.dutyView ?? false;
  if (person == null) return MyDutyOverview(dutyView: dutyView);

  final termine = await ref.watch(upcomingDutyTermineProvider.future);
  final mine = termine.where((t) => t.persons.any((p) => p.personId == person.id)).toList();

  PersonAttendance own(DutyTermin t) => t.persons.firstWhere((p) => p.personId == person.id);

  final requests = <({DutyTermin termin, PersonAttendance pa})>[];
  final confirmed = <({DutyTermin termin, PersonAttendance pa})>[];
  final open = <DutyTermin>[];
  final now = DateTime.now();
  var thisMonth = 0;
  for (final t in mine) {
    final pa = own(t);
    final hasState = (pa.dutyState ?? '').isNotEmpty;
    if (hasState && !isCancelled(pa)) {
      final date = DateTime.tryParse(t.attendance.date)?.toLocal();
      if (date != null && date.year == now.year && date.month == now.month) thisMonth++;
      if (pa.dutyState == DutyState.requested) {
        requests.add((termin: t, pa: pa));
      } else {
        confirmed.add((termin: t, pa: pa));
      }
    } else if (!hasState && !isCancelled(pa) && t.type.dutySelfSignup && t.occupied < t.required) {
      open.add(t);
    }
  }

  return MyDutyOverview(
    person: person,
    termine: mine,
    requests: requests,
    openDuties: open,
    confirmed: confirmed,
    dutiesThisMonth: thisMonth,
    dutyView: dutyView,
  );
});

/// Whether an open duty is urgent (within the type's urgent hours)
bool isUrgentDuty(DutyTermin t) {
  final hours = t.type.dutyUrgentHours;
  if (hours == null || hours <= 0) return false;
  final date = DateTime.tryParse(t.attendance.date)?.toLocal();
  if (date == null) return false;
  final time = (t.attendance.startTime ?? t.type.startTime ?? '00:00');
  final parts = time.split(':');
  final start = DateTime(date.year, date.month, date.day,
      int.tryParse(parts[0]) ?? 0, parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  return start.difference(DateTime.now()).inMinutes / 60 <= hours;
}

/// Mutations of the Dienstplan
class DutyNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  DutyRepository get _repo => ref.read(dutyRepositoryWithTenantProvider);

  void _invalidate({int? attendanceId}) {
    ref.invalidate(upcomingDutyTermineProvider);
    ref.invalidate(dutyTermineByIdProvider);
    ref.invalidate(myDutyOverviewProvider);
    ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
    if (attendanceId != null) {
      ref.invalidate(personAttendancesForAttendanceProvider(attendanceId));
      ref.invalidate(attendanceDetailProvider(attendanceId));
    }
  }

  Future<bool> _run(Future<void> Function() action, {int? attendanceId}) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      _invalidate(attendanceId: attendanceId);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> assign(List<String> personAttendanceIds, int attendanceId) =>
      _run(() => _repo.assign(personAttendanceIds, attendanceId), attendanceId: attendanceId);

  Future<bool> unassign(String personAttendanceId, int attendanceId) =>
      _run(() => _repo.unassign(personAttendanceId), attendanceId: attendanceId);

  Future<bool> confirm(String personAttendanceId, int attendanceId) =>
      _run(() => _repo.confirm(personAttendanceId), attendanceId: attendanceId);

  /// "Kann nicht": LOGIC_SELF — Ionic declineMyDuty/declineOwnDuty call
  /// `db.signout([pa.id], reason, false, false, true)` (Entschuldigt, leaders
  /// get the "abgemeldet" quick-processor notification with isSelf) and then
  /// `duty-notify {type: 'understaffed'}`.
  Future<bool> decline(String personAttendanceId, int attendanceId, String reason) =>
      _run(() async {
        await ref.read(signInOutRepositoryWithTenantProvider).signOut(
              [personAttendanceId],
              reason,
              isLateComing: false,
              isSelf: true,
            );
        await _repo.notify(DutyNotifyType.understaffed, attendanceId);
      }, attendanceId: attendanceId);

  Future<bool> updateDutyRequired(int attendanceId, int required) =>
      _run(() => _repo.updateDutyRequired(attendanceId, required), attendanceId: attendanceId);

  /// "Ich übernehme"
  Future<DutyTakeResult?> take(int attendanceId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repo.take(attendanceId);
      state = const AsyncValue.data(null);
      _invalidate(attendanceId: attendanceId);
      return result;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<PersonUnavailability?> saveUnavailability(PersonUnavailability rule) async {
    state = const AsyncValue.loading();
    try {
      final saved = await _repo.saveUnavailability(rule);
      state = const AsyncValue.data(null);
      ref.invalidate(unavailabilityByPersonProvider(rule.personId));
      return saved;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  Future<bool> deleteUnavailability(PersonUnavailability rule) async {
    if (rule.id == null) return false;
    final ok = await _run(() => _repo.deleteUnavailability(rule.id!));
    ref.invalidate(unavailabilityByPersonProvider(rule.personId));
    return ok;
  }

  Future<int> applyUnavailabilityToFuture(PersonUnavailability rule) async {
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const [];
    try {
      final n = await _repo.applyUnavailabilityToFuture(rule, types);
      _invalidate();
      return n;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return 0;
    }
  }
}

final dutyNotifierProvider = NotifierProvider<DutyNotifier, AsyncValue<void>>(
  DutyNotifier.new,
);
