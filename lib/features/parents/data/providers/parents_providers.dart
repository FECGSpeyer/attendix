import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../l10n/l10n.dart';

/// Statistics for a child
class ChildStats {
  final int percentage;
  final int lateCount;
  final int totalCount;
  final int presentCount;

  const ChildStats({
    required this.percentage,
    required this.lateCount,
    required this.totalCount,
    required this.presentCount,
  });
}

/// Attendance record for a child
class ChildPersonAttendance {
  final String? id;
  final int? personId;
  final int? attendanceId;
  final AttendanceStatus status;
  final String? notes;
  final String? date;
  final String? typeInfo;
  final String? startTime;
  final String? endTime;
  final String? deadline;
  final Map<String, dynamic>? plan;
  /// ASTRA_PARENTS: Ionic `attendance.extra_plans` (further plans, e.g. one
  /// per day of a multi-day Termin) for the plan viewer's day selection.
  final List<Map<String, dynamic>>? extraPlans;
  final bool sharePlan;
  final String? typeId;
  final int childId;
  final String childName;
  // ATTENDANCE_SIGNOUT: card layout fields
  final String childFirstName;
  final int? durationDays;
  final String? place;
  final String? description;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? legacyType;

  ChildPersonAttendance({
    this.id,
    this.personId,
    this.attendanceId,
    this.status = AttendanceStatus.neutral,
    this.notes,
    this.date,
    this.typeInfo,
    this.startTime,
    this.endTime,
    this.deadline,
    this.plan,
    this.extraPlans,
    this.sharePlan = false,
    this.typeId,
    required this.childId,
    required this.childName,
    this.childFirstName = '',
    this.durationDays,
    this.place,
    this.description,
    this.attachmentUrl,
    this.attachmentName,
    this.legacyType,
  });

  /// Past only after the last day of a multi-day Termin.
  bool get isPast => EventListUtils.hasEnded(date, durationDays);

  bool get isUpcoming => date != null && !isPast;

  bool get isDeadlinePassed {
    if (deadline == null) return false;
    final deadlineDate = DateTime.tryParse(deadline!);
    if (deadlineDate == null) return false;
    return DateTime.now().isAfter(deadlineDate);
  }

  bool get attended => status.countsAsPresent;

  bool get hasPlan {
    if (!sharePlan || plan == null) return false;
    final fields = plan?['fields'] as List?;
    return fields != null && fields.isNotEmpty;
  }

  String? get deadlineText {
    if (deadline == null) return null;
    final deadlineDate = DateTime.tryParse(deadline!);
    if (deadlineDate == null) return null;

    final now = DateTime.now();
    if (now.isAfter(deadlineDate)) {
      return l10nWithoutContext.signoutDeadlinePassed;
    }

    return l10nWithoutContext.selfServiceFlutterSignInUntil(
        DateFormat('${dateFmt()} HH:mm').format(deadlineDate));
  }

  String get displayTitle {
    if (typeInfo != null && typeInfo!.isNotEmpty) {
      return typeInfo!;
    }
    return l10nWithoutContext.attendanceEventFallback;
  }
}

/// Combined attendance with all children's records for that date
class ParentAttendanceGroup {
  final int attendanceId;
  final String? date;
  final String? typeInfo;
  final String? startTime;
  final String? endTime;
  final String? deadline;
  final Map<String, dynamic>? plan;
  /// ASTRA_PARENTS: Ionic `attendance.extra_plans`.
  final List<Map<String, dynamic>>? extraPlans;
  final bool sharePlan;
  final List<ChildPersonAttendance> childAttendances;
  // ATTENDANCE_SIGNOUT: card layout fields
  final String? typeId;
  final int? durationDays;
  final String? place;
  final String? description;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? legacyType;

  ParentAttendanceGroup({
    required this.attendanceId,
    this.date,
    this.typeInfo,
    this.startTime,
    this.endTime,
    this.deadline,
    this.plan,
    this.extraPlans,
    this.sharePlan = false,
    required this.childAttendances,
    this.typeId,
    this.durationDays,
    this.place,
    this.description,
    this.attachmentUrl,
    this.attachmentName,
    this.legacyType,
  });

  /// Past only after the last day of a multi-day Termin.
  bool get isPast => EventListUtils.hasEnded(date, durationDays);

  bool get isUpcoming => !isPast;

  /// Starts today or still running ("Heute").
  bool get isRunning => EventListUtils.isRunning(date, durationDays);

  bool get isDeadlinePassed {
    if (deadline == null) return false;
    final deadlineDate = DateTime.tryParse(deadline!);
    if (deadlineDate == null) return false;
    return DateTime.now().isAfter(deadlineDate);
  }

  bool get hasPlan {
    if (!sharePlan || plan == null) return false;
    final fields = plan?['fields'] as List?;
    return fields != null && fields.isNotEmpty;
  }

  String? get deadlineText {
    if (deadline == null) return null;
    final deadlineDate = DateTime.tryParse(deadline!);
    if (deadlineDate == null) return null;

    final now = DateTime.now();
    if (now.isAfter(deadlineDate)) {
      return l10nWithoutContext.signoutDeadlinePassed;
    }

    return l10nWithoutContext.selfServiceFlutterSignInUntil(
        DateFormat('${dateFmt()} HH:mm').format(deadlineDate));
  }

  bool get allChildrenResponded =>
      childAttendances.every((c) => !c.status.isNeutral);

  String get displayTitle {
    if (typeInfo != null && typeInfo!.isNotEmpty) {
      return typeInfo!;
    }
    return l10nWithoutContext.attendanceEventFallback;
  }
}

/// Provider for children linked to the current parent
final parentChildrenProvider = FutureProvider<List<Person>>((ref) async {
  final tenantUser = ref.watch(currentTenantUserProvider).valueOrNull;
  if (tenantUser?.parentId == null) return [];

  final repo = ref.watch(playerRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];

  return repo.getChildrenForParent(tenantUser!.parentId!);
});

/// Provider for all attendances of children
final childrenAttendancesProvider =
    FutureProvider<List<ChildPersonAttendance>>((ref) async {
  final children = ref.watch(parentChildrenProvider).valueOrNull ?? [];
  if (children.isEmpty) return [];

  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];

  final childIds = children.map((c) => c.id).whereType<int>().toList();
  if (childIds.isEmpty) return [];

  // Build child name map
  final childNameMap = {
    for (final child in children)
      if (child.id != null) child.id!: '${child.firstName} ${child.lastName}',
  };

  final childFirstNameMap = {
    for (final child in children)
      if (child.id != null) child.id!: child.firstName,
  };

  // Fetch all person attendances for children via repository
  final rows = await repo.getPersonAttendancesForPersons(childIds);

  return rows.map((json) {
    final attendance = json['attendance'] as Map<String, dynamic>?;
    final personId = json['person_id'] as int?;

    return ChildPersonAttendance(
      id: json['id']?.toString(),
      personId: personId,
      attendanceId: json['attendance_id'] as int?,
      status: _parseStatus(json['status']),
      notes: json['notes'] as String?,
      date: attendance?['date'] as String?,
      typeInfo: attendance?['typeInfo'] as String?,
      startTime: attendance?['start_time'] as String?,
      endTime: attendance?['end_time'] as String?,
      deadline: attendance?['deadline'] as String?,
      plan: attendance?['plan'] as Map<String, dynamic>?,
      extraPlans: parseExtraPlans(attendance?['extra_plans']),
      sharePlan: attendance?['share_plan'] == true,
      typeId: attendance?['type_id']?.toString(),
      childId: personId ?? 0,
      childName: childNameMap[personId] ?? l10nWithoutContext.selfServiceFlutterChild,
      childFirstName: childFirstNameMap[personId] ?? l10nWithoutContext.selfServiceFlutterChild,
      durationDays: (attendance?['duration_days'] as num?)?.toInt(),
      place: attendance?['place'] as String?,
      description: attendance?['description'] as String?,
      attachmentUrl: attendance?['attachment_url'] as String?,
      attachmentName: attendance?['attachment_name'] as String?,
      legacyType: attendance?['type'] as String?,
    );
  }).toList();
});

/// Provider for attendance groups (combined by date)
final parentAttendanceGroupsProvider =
    Provider<List<ParentAttendanceGroup>>((ref) {
  final attendances = ref.watch(childrenAttendancesProvider).valueOrNull ?? [];
  if (attendances.isEmpty) return [];

  // Group by attendance ID
  final Map<int, List<ChildPersonAttendance>> grouped = {};
  for (final att in attendances) {
    if (att.attendanceId != null) {
      grouped.putIfAbsent(att.attendanceId!, () => []).add(att);
    }
  }

  // Convert to ParentAttendanceGroup
  // BL-008: Use firstOrNull for safety even though grouped entries should never be empty
  return grouped.entries
      .where((entry) => entry.value.isNotEmpty)
      .map((entry) {
    final childAtts = entry.value;
    final first = childAtts.first;
    return ParentAttendanceGroup(
      attendanceId: entry.key,
      date: first.date,
      typeInfo: first.typeInfo,
      startTime: first.startTime,
      endTime: first.endTime,
      deadline: first.deadline,
      plan: first.plan,
      extraPlans: first.extraPlans,
      sharePlan: first.sharePlan,
      childAttendances: childAtts,
      typeId: first.typeId,
      durationDays: first.durationDays,
      place: first.place,
      description: first.description,
      attachmentUrl: first.attachmentUrl,
      attachmentName: first.attachmentName,
      legacyType: first.legacyType,
    );
  }).toList();
});

/// Provider for upcoming attendance groups
final upcomingParentAttendancesProvider =
    Provider<List<ParentAttendanceGroup>>((ref) {
  final groups = ref.watch(parentAttendanceGroupsProvider);
  final upcoming = groups.where((g) => g.isUpcoming).toList()
    ..sort((a, b) {
      final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime.now();
      return dateA.compareTo(dateB);
    });
  return upcoming;
});

/// Provider for past attendance groups
final pastParentAttendancesProvider =
    Provider<List<ParentAttendanceGroup>>((ref) {
  final groups = ref.watch(parentAttendanceGroupsProvider);
  final past = groups.where((g) => g.isPast).toList()
    ..sort((a, b) {
      final dateA = DateTime.tryParse(a.date ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b.date ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA); // Most recent first
    });
  // Limit to 10 past attendances
  return past.take(10).toList();
});

/// Provider for the running Termin ("Heute" card, like Ionic parents page)
final currentParentAttendanceProvider = Provider<ParentAttendanceGroup?>((ref) {
  final upcoming = ref.watch(upcomingParentAttendancesProvider);
  return upcoming.where((g) => g.isRunning).firstOrNull;
});

/// Provider for child statistics
final childStatsProvider = Provider.family<ChildStats, int>((ref, childId) {
  final attendances = ref.watch(childrenAttendancesProvider).valueOrNull ?? [];
  final childAttendances =
      attendances.where((a) => a.childId == childId && a.isPast).toList();

  if (childAttendances.isEmpty) {
    return const ChildStats(
      percentage: 0,
      lateCount: 0,
      totalCount: 0,
      presentCount: 0,
    );
  }

  // SETTINGS2: Ionic parents.page — shift-excused counts as present (tenant flag)
  final shiftExcused =
      ref.watch(currentTenantProvider)?.shiftExcusedAsPresent ?? false;
  final attended = childAttendances
      .where((a) => a.status
          .countsAsAttended(notes: a.notes, shiftExcusedAsPresent: shiftExcused))
      .length;
  final late =
      childAttendances.where((a) => a.status == AttendanceStatus.late).length;

  return ChildStats(
    // BL-002: Safe division - avoid division by zero
    percentage: childAttendances.isEmpty
        ? 0
        : (attended / childAttendances.length * 100).round(),
    lateCount: late,
    totalCount: childAttendances.length,
    presentCount: attended,
  );
});

/// Notifier for parent sign in/out operations
class ParentSignInOutNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  SignInOutRepository get _repo =>
      ref.read(signInOutRepositoryWithTenantProvider);

  /// Sign in a child to an attendance
  Future<void> signIn(
    String personAttendanceId,
    SignInType type, {
    String notes = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signIn(personAttendanceId, type, notes: notes);
      state = const AsyncValue.data(null);
      ref.invalidate(childrenAttendancesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// ASTRA_PARENTS: Ionic ParentsPage.signin — signs in the selected
  /// children one after another and stops at the first failure (Ionic's
  /// loop awaits each `db.signin`, a thrown error aborts the rest).
  ///
  /// Returns true only when every entry was signed in; the state is the
  /// first error otherwise, so a later success can never hide a failure.
  /// The list is refreshed in both cases (entries before the failure are
  /// already saved).
  Future<bool> signInAll(List<(String, SignInType)> entries) async {
    state = const AsyncValue.loading();
    try {
      for (final (id, type) in entries) {
        await _repo.signIn(id, type);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    } finally {
      ref.invalidate(childrenAttendancesProvider);
    }
  }

  /// Sign out a child from attendance
  Future<void> signOut(
    List<String> personAttendanceIds,
    String reason, {
    bool isLateComing = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut(personAttendanceIds, reason,
          isLateComing: isLateComing, isParents: true);
      state = const AsyncValue.data(null);
      ref.invalidate(childrenAttendancesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update attendance note
  Future<void> updateNote(String personAttendanceId, String note) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateAttendanceNote(personAttendanceId, note);
      state = const AsyncValue.data(null);
      ref.invalidate(childrenAttendancesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final parentSignInOutNotifierProvider =
    NotifierProvider<ParentSignInOutNotifier, AsyncValue<void>>(() {
  return ParentSignInOutNotifier();
});

/// ASTRA_PARENTS: `attendance.extra_plans` (JSON array of plan objects) as
/// plain maps; anything else yields null.
List<Map<String, dynamic>>? parseExtraPlans(dynamic raw) {
  if (raw is! List) return null;
  final plans = [
    for (final p in raw)
      if (p is Map) Map<String, dynamic>.from(p),
  ];
  return plans.isEmpty ? null : plans;
}

// Helper function to parse status
AttendanceStatus _parseStatus(dynamic status) {
  if (status == null) return AttendanceStatus.neutral;
  if (status is AttendanceStatus) return status;

  if (status is int) {
    return AttendanceStatus.fromValue(status);
  }

  final statusStr = status.toString();
  final intValue = int.tryParse(statusStr);
  if (intValue != null) {
    return AttendanceStatus.fromValue(intValue);
  }

  return AttendanceStatus.values.firstWhere(
    (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
    orElse: () => AttendanceStatus.neutral,
  );
}
