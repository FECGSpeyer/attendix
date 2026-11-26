import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../constants/enums.dart';
import '../services/cross_tenant_service.dart';
import '../utils/archived_attendance.dart';
import '../utils/person_matcher.dart';
import '../../data/models/person/person.dart';
import '../../data/repositories/user_registration_repository.dart';
import '../../features/people/person_stats.dart';
import '../../l10n/l10n.dart';
import 'attendance_type_providers.dart';
import 'cross_tenant_person_providers.dart';
import 'group_providers.dart';
import 'player_providers.dart';
import 'realtime_providers.dart';
import 'tenant_providers.dart';

/// Provider for single person with group name.
final personProvider =
    FutureProvider.family<Person?, int>((ref, personId) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final groups = await ref.watch(groupsMapProvider.future);

  if (!repo.hasTenantId) return null;

  final person = await repo.getPlayerById(personId);
  if (person == null) return null;

  final groupName = person.instrument != null ? groups[person.instrument] : null;
  return person.copyWith(groupName: groupName);
});

/// Provider for person attendance statistics (average over `include_in_average`
/// types of the current season, late counts since the last "Gespräch geführt").
final personAttendanceStatsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, personId) async {
  ref.watch(currentAuthUserIdProvider);
  ref.watch(attendanceRefetchCounter);
  ref.watch(currentRoleProvider);
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final tenant = ref.watch(currentTenantProvider);
  await ref.watch(attendanceTypesProvider.future);
  final person = await ref.watch(personProvider(personId).future);

  if (!repo.hasTenantId || person == null) {
    return {
      'total': 0,
      'attended': 0,
      'percentage': 0,
      'lateCount': 0,
      'lateCountExcused': 0,
    };
  }

  final rows = await repo.getPersonAttendanceStatsRows(personId);

  return computePersonAttendanceStats(
    rows,
    now: DateTime.now(),
    windowStart: personAttendanceWindowStart(
      seasonStart: tenant?.seasonStart,
      hasLeft: person.left != null,
    ),
    lastSolve: person.lastSolve,
    shiftExcusedAsPresent: tenant?.shiftExcusedAsPresent ?? false,
  );
});

/// Provider for person history (attendance + player history combined).
final personHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, personId) async {
  ref.watch(attendanceRefetchCounter);
  final role = ref.watch(currentRoleProvider);
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final typeRepo = ref.watch(attendanceTypeRepositoryWithTenantProvider);
  await ref.watch(attendanceTypesProvider.future);
  final person = await ref.watch(personProvider(personId).future);

  if (person == null || !repo.hasTenantId || !typeRepo.hasTenantId) return [];

  final today = DateTime.now().toIso8601String().substring(0, 10);

  final attendanceResponse = await repo.getPersonAttendanceHistoryRows(personId);
  final attendanceTypes = await typeRepo.getTypeRows();

  final attendanceHistory = attendanceResponse
      .where((a) => a['attendance'] != null)
      .where((a) {
        final attendance = a['attendance'] as Map<String, dynamic>?;
        final dateStr = attendance?['date']?.toString();
        if (dateStr == null) return false;
        return dateStr.compareTo(today) <= 0;
      })
      .map((a) {
    final attendance = a['attendance'] as Map<String, dynamic>?;
    final typeId = attendance?['type_id'];
    final typeInfo = attendance?['typeInfo']?.toString();

    String meetingName = '';
    final attType = attendanceTypes.firstWhere(
      (t) => t['id'] == typeId,
      orElse: () => <String, dynamic>{},
    );
    if (attType.isNotEmpty) {
      final typeName = attType['hide_name'] == true ? '' : attType['name']?.toString() ?? '';
      meetingName = (typeInfo != null && typeInfo.isNotEmpty) ? typeInfo : typeName;
    }

    final statusValue = a['status'];
    int statusInt = 0;
    if (statusValue is int) {
      statusInt = statusValue;
    } else if (statusValue != null) {
      statusInt = int.tryParse(statusValue.toString()) ?? 0;
    }

    final displayStatus = switch (statusInt) {
      1 => 'X',
      2 => 'E',
      3 => 'L',
      4 => 'A',
      5 => 'L',
      _ => 'N',
    };

    return {
      'date': attendance?['date']?.toString(),
      'attendanceId': attendance?['id'],
      'meetingName': meetingName,
      'text': displayStatus,
      'type': PlayerHistoryType.attendance.value,
      'notes': a['notes'],
      'status': statusInt,
    };
  }).toList();

  final isAdmin = role.isAdmin || role.isResponsible;
  final playerHistory = person.history
      .where((h) => isAdmin || visibleHistoryTypesForMembers.contains(h.type))
      .map((h) {
    return {
      'date': h.date,
      'title': h.typeLabel,
      'text': h.text ?? '',
      'type': h.type,
      'notes': null,
    };
  }).toList();

  final allHistory = [...attendanceHistory, ...playerHistory];
  allHistory.sort((a, b) {
    final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1900);
    final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1900);
    return dateB.compareTo(dateA);
  });

  return allHistory;
});

/// Provider for upcoming attendances (future dates) for a person.
final upcomingAttendancesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, personId) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final typeRepo = ref.watch(attendanceTypeRepositoryWithTenantProvider);

  if (!repo.hasTenantId || !typeRepo.hasTenantId) return [];

  final today = DateTime.now().toIso8601String().substring(0, 10);
  final attendanceTypes = await typeRepo.getTypeRows();
  final response =
      await repo.getPersonAttendanceHistoryRows(personId, fromDate: today);

  final attendances = response.where((a) => a['attendance'] != null).map((a) {
    final attendance = a['attendance'] as Map<String, dynamic>;
    final typeId = attendance['type_id'];
    final typeInfo = attendance['typeInfo']?.toString();

    String meetingName = '';
    final attType = attendanceTypes.firstWhere(
      (t) => t['id'] == typeId,
      orElse: () => <String, dynamic>{},
    );
    if (attType.isNotEmpty) {
      final typeName = attType['name']?.toString() ?? '';
      meetingName =
          (typeInfo != null && typeInfo.isNotEmpty) ? typeInfo : typeName;
    } else {
      meetingName =
          typeInfo ?? attendance['type']?.toString() ?? 'Anwesenheit';
    }

    final statusValue = a['status'];
    int statusInt = 0;
    if (statusValue is int) {
      statusInt = statusValue;
    } else if (statusValue != null) {
      statusInt = int.tryParse(statusValue.toString()) ?? 0;
    }

    return {
      'date': attendance['date']?.toString(),
      'attendanceId': attendance['id'],
      'meetingName': meetingName,
      'status': statusInt,
      'notes': a['notes']?.toString(),
    };
  }).toList();

  attendances.sort((a, b) {
    final dateA =
        DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2099);
    final dateB =
        DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2099);
    return dateA.compareTo(dateB);
  });

  return attendances;
});

/// Provider for other tenants where this person has an account.
/// Cross-tenant queries rely on Supabase RLS at the database level.
final otherTenantsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, appId) async {
  ref.watch(currentAuthUserIdProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final currentTenant = ref.watch(currentTenantProvider);
  final showArchived = canSeeArchivedAttendances(ref.watch(currentRoleProvider));

  if (currentTenant == null) return [];

  final linkedIds = (await ref.watch(linkedTenantIdsProvider.future)).toSet();

  final tenantUsersResponse = await supabase
      .from('tenantUsers')
      .select('tenantId, role, tenant:tenantId(id, longName, shortName)')
      .eq('userId', appId);

  final tenantUsers = (tenantUsersResponse as List)
      .where((tu) {
        final tenant = tu['tenant'] as Map<String, dynamic>?;
        final tenantId = tenant?['id'];
        return tenantId != null &&
            tenantId != currentTenant.id &&
            linkedIds.contains(tenantId) &&
            tu['role'] != Role.viewer.value;
      })
      .toList();

  final results = <Map<String, dynamic>>[];

  for (final tu in tenantUsers) {
    final tenant = tu['tenant'] as Map<String, dynamic>?;
    if (tenant == null) continue;

    final tenantId = tenant['id'] as int;
    final tenantName = tenant['longName']?.toString() ??
        tenant['shortName']?.toString() ??
        l10nWithoutContext.commonUnknown;
    final role = tu['role'] as int? ?? 99;

    int? percentage;
    try {
      final playerRows = await supabase
          .from('player')
          .select('id, left, pending')
          .eq('appId', appId)
          .eq('tenantId', tenantId)
          .eq('pending', false);
      final playerId = CrossTenantService.pickPersonIdForTenant(
          (playerRows as List).cast<Map<String, dynamic>>());

      if (playerId != null) {
        final seasonStart = currentTenant.seasonStart ?? '2023-01-01T00:00:00.000Z';
        final attendanceResponse = await supabase
            .from('person_attendances')
            .select('status, notes, attendance:attendance_id!inner(date, archived, tenantId)')
            .eq('person_id', playerId)
            .eq('attendance.tenantId', tenantId)
            .gt('attendance.date', seasonStart);

        final now = DateTime.now();
        final attendances = (attendanceResponse as List).where((a) {
          final attendance = a['attendance'] as Map<String, dynamic>?;
          if (attendance == null) return false;
          if (!showArchived && attendance['archived'] == true) return false;
          final date = DateTime.tryParse(attendance['date']?.toString() ?? '');
          return date != null && date.isBefore(now);
        }).toList();

        final total = attendances.length;
        final attended = attendances.where((a) {
          final status = a['status'];
          return status is int &&
              AttendanceStatus.fromValue(status).countsAsAttended(
                notes: a['notes'] as String?,
                shiftExcusedAsPresent: currentTenant.shiftExcusedAsPresent,
              );
        }).length;

        percentage = total > 0 ? (attended / total * 100).round() : null;
      }
    } catch (_) {
      // Ignore errors for individual tenants
    }

    final roleText = UserRegistrationRepository.roleText(Role.fromValue(role));

    results.add({
      'tenantName': tenantName,
      'role': roleText,
      'percentage': percentage,
    });
  }

  return results;
});

/// Same-tenant, account-less people similar to a pending applicant.
final duplicateCandidatesProvider =
    FutureProvider.family<List<RankedMatch<Person>>, Person>((ref, person) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  if (!repo.hasTenantId || person.id == null || !person.pending) return [];
  try {
    return await repo.getPossibleDuplicatesInTenant(
      person.firstName,
      person.lastName,
      excludeId: person.id!,
    );
  } catch (_) {
    return [];
  }
});
