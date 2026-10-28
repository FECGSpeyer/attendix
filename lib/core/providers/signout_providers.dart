import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sign_in_out_repository.dart';
import '../constants/enums.dart';
import '../utils/event_list_utils.dart';
import 'self_service_providers.dart';
import 'tenant_providers.dart';

/// ATTENDANCE_SIGNOUT: providers for "Meine Termine" (Ionic signout page).

/// Sign in/out repository with the current tenant set.
final signInOutRepositoryWithTenantProvider = Provider<SignInOutRepository>((ref) {
  final repo = ref.watch(signInOutRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
  return repo;
});

/// `tenants.files_shared` of the current tenant (hook for the Dateiablage).
final tenantFilesSharedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(signInOutRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return false;
  return repo.getTenantFilesShared();
});

// canAccessFilesProvider lives in role_permission_providers.dart

/// INTEGRATION: Termin of an /open-attendance deep link (or push) that the
/// landing page ("Meine Termine") opens in its action sheet once loaded
/// (Ionic PushService.pendingAttendanceId). Read-and-clear.
final pendingAttendanceIdProvider = StateProvider<int?>((ref) => null);

/// Data of the "Meine Termine" page.
class SignoutData {
  const SignoutData({
    this.current,
    this.upcoming = const [],
    this.past = const [],
    this.percentage = 0,
    this.lateCount = 0,
  });

  /// "Heute" / "Nächster Termin" card.
  final CrossTenantPersonAttendance? current;

  /// Further upcoming Termine (without [current]), ascending.
  final List<CrossTenantPersonAttendance> upcoming;

  /// Own past Termine, newest first.
  final List<CrossTenantPersonAttendance> past;

  final int percentage;
  final int lateCount;

  /// All upcoming including the current one.
  List<CrossTenantPersonAttendance> get allUpcoming =>
      [if (current != null) current!, ...upcoming];
}

/// Splits Termine into current / upcoming / past and computes the stats
/// (Ionic SignoutPage.getAttendances).
SignoutData buildSignoutData({
  required List<CrossTenantPersonAttendance> own,
  List<CrossTenantPersonAttendance>? allUpcoming,
  DateTime? now,
}) {
  int compareDate(CrossTenantPersonAttendance a, CrossTenantPersonAttendance b) {
    final da = EventListUtils.parse(a.date) ?? DateTime(1970);
    final db = EventListUtils.parse(b.date) ?? DateTime(1970);
    return da.compareTo(db);
  }

  bool ended(CrossTenantPersonAttendance a) =>
      EventListUtils.hasEnded(a.date, a.effectiveDurationDays, now: now);

  final past = own.where(ended).toList()..sort((a, b) => compareDate(b, a));
  final upcoming = (allUpcoming ?? own.where((a) => !ended(a)).toList())
      .where((a) => !ended(a))
      .toList()
    ..sort(compareDate);

  final relevant = past.where((a) => a.attendanceType?.includeInAverage ?? a.includeInAverage).toList();
  final attended = relevant.where((a) => a.attended).length;
  final perc = relevant.isEmpty ? 0 : (attended / relevant.length * 100).round();
  final lateCount = past.where((a) => a.status == AttendanceStatus.late).length;

  return SignoutData(
    current: upcoming.isNotEmpty ? upcoming.first : null,
    upcoming: upcoming.length > 1 ? upcoming.sublist(1) : const [],
    past: past,
    percentage: perc,
    lateCount: lateCount,
  );
}

/// Termine of the current user in the current tenant.
///
/// With the tenant setting `show_all_attendances` all upcoming Termine of the
/// tenant are listed (own status where the person is part of it).
final signoutDataProvider = FutureProvider<SignoutData>((ref) async {
  final repo = ref.watch(signInOutRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const SignoutData();

  final player = await ref.watch(currentSelfServicePlayerProvider.future);
  if (player?.id == null) return const SignoutData();

  final tenant = ref.watch(currentTenantProvider);
  final tenantName = tenant?.shortName ?? '';
  final showAll = tenant?.showAllAttendances ?? false;

  final own = await repo.getPersonAttendances(
    player!.id!,
    since: showAll ? DateTime(2020).toIso8601String() : tenant?.seasonStart ?? DateTime(2023).toIso8601String(),
    tenantName: tenantName,
  );

  if (showAll) {
    final all = await repo.getAllUpcomingAttendancesForSignout(
      player.id!,
      tenantName: tenantName,
    );
    return buildSignoutData(own: own, allUpcoming: all);
  }
  return buildSignoutData(own: own);
});

/// Mutations of the "Meine Termine" page.
class SignoutNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SignInOutRepository get _repo => ref.read(signInOutRepositoryWithTenantProvider);

  void _refresh() {
    ref.invalidate(signoutDataProvider);
    ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      _refresh();
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Zusagen / Anmelden (optionally with note).
  Future<bool> signIn(CrossTenantPersonAttendance att, {String notes = ''}) {
    final id = att.id;
    if (id == null) return Future.value(false);
    return _run(() => _repo.signIn(id, SignInType.fromStatus(att.status), notes: notes));
  }

  /// Absagen / Verspätung with reason.
  Future<bool> signOut(List<String> ids, String reason, {required bool isLate}) {
    return _run(() => _repo.signOut(ids, reason, isLateComing: isLate, isSelf: true));
  }

  /// Notiz anpassen.
  Future<bool> updateNote(String id, String note) {
    return _run(() => _repo.updateAttendanceNote(id, note));
  }

  /// Anmeldefelder speichern.
  Future<bool> saveRegistrationAnswers(String id, Map<String, dynamic> answers) {
    return _run(() => _repo.updateRegistrationAnswers(id, answers));
  }
}

final signoutNotifierProvider =
    NotifierProvider<SignoutNotifier, AsyncValue<void>>(SignoutNotifier.new);
