import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../core/services/cross_tenant_service.dart' show CrossTenantService;
import '../../core/utils/event_list_utils.dart';
import '../../core/utils/paged_query.dart'; // SOL_FIX37
import '../models/attendance/attendance.dart';
import '../../core/utils/duty_utils.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for SignInOutRepository (without tenant – use the WithTenant variant).
final signInOutRepositoryProvider = Provider<SignInOutRepository>((ref) {
  return SignInOutRepository(ref);
});

/// Columns of `attendance` needed by the Terminlisten (signout, overview, parents).
const String kSignoutAttendanceColumns =
    'id, date, type, typeInfo, songs, type_id, start_time, end_time, deadline, '
    'duration_days, plan, share_plan, description, attachment_url, '
    'attachment_name, files_folder, place, tenantId';

/// IOS_FORMS2: `attendance` columns of the Übersicht – exactly Ionic
/// `getPersonAttendancesForTenant` (no `place`, `plan`, `share_plan`), so the
/// Übersicht shows no place / "Route" chip and no Ablaufplan action.
const String kOverviewAttendanceColumns =
    'id, date, type, typeInfo, songs, type_id, start_time, end_time, deadline, '
    'duration_days, description, attachment_url, attachment_name, '
    'files_folder, tenantId';

/// Columns of `attendance_types` joined into the Terminlisten.
const String kSignoutAttendanceTypeColumns =
    'id, name, highlight, include_in_average, color, hide_name, all_day, '
    'duration_days, start_time, end_time, available_statuses, '
    'default_status, registration_fields, duty_mode';

/// Repository for self-service sign in/out operations
class SignInOutRepository extends BaseRepository with TenantAwareRepository {
  SignInOutRepository(super.ref);

  /// Predefined distinct colors for tenant visual separation (from Ionic app)
  static const _distinctColors = [
    '#E53935', // Red
    '#1E88E5', // Blue
    '#43A047', // Green
    '#FB8C00', // Orange
    '#8E24AA', // Purple
    '#00ACC1', // Cyan
    '#F4511E', // Deep Orange
    '#3949AB', // Indigo
    '#7CB342', // Light Green
    '#C2185B', // Pink
    '#00897B', // Teal
    '#6D4C41', // Brown
    '#5E35B1', // Deep Purple
    '#039BE5', // Light Blue
    '#D81B60', // Pink Dark
  ];

  /// Get color for tenant based on index (like Ionic app)
  String _getTenantColor(int tenantId, List<dynamic> tenantIds) {
    final index = tenantIds.indexOf(tenantId);
    final colorIndex = index >= 0
        ? index % _distinctColors.length
        : tenantId.abs() % _distinctColors.length;
    return _distinctColors[colorIndex];
  }

  /// SEC: person_attendances has no tenantId column. Ownership is checked via
  /// the joined attendance (current tenant) or – for the cross-tenant
  /// overview – via the linked person's appId (= current user).
  Future<List<String>> _validatePersonAttendanceIds(
    List<String> ids,
    String operation, {
    bool ownAcrossTenants = false,
  }) async {
    if (ids.isEmpty) return [];
    if (ownAcrossTenants) {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final rows = await supabase
          .from('person_attendances')
          .select('id, person:person_id(appId)')
          .inFilter('id', ids);
      return (rows as List)
          .where((r) => r['person']?['appId'] == userId)
          .map((r) => r['id'].toString())
          .toList();
    }

    final rows = await supabase
        .from('person_attendances')
        .select('id, attendance:attendance_id(tenantId)')
        .inFilter('id', ids);
    return (rows as List)
        .where((r) => r['attendance']?['tenantId'] == currentTenantId)
        .map((r) => r['id'].toString())
        .toList();
  }

  Future<void> _updatePersonAttendances(
    List<String> ids,
    Map<String, dynamic> fields,
  ) async {
    await supabase.from('person_attendances').update({
      ...fields,
      'changed_at': DateTime.now().toUtc().toIso8601String(),
      'changed_by': supabase.auth.currentUser?.id,
    }).inFilter('id', ids);
  }

  /// Telegram/Push notification for the conductors (Ionic notifyPerTelegram).
  /// Errors are swallowed: the sign in/out itself already succeeded.
  Future<void> _notify({
    required String attId,
    required String type,
    String? reason,
    bool isParents = false,
    String notes = '',
    bool isSelf = false,
  }) async {
    try {
      await supabase.functions.invoke('quick-processor', body: {
        'attId': attId,
        'type': type,
        'reason': reason,
        'isParents': isParents,
        'notes': notes,
        'isSelf': isSelf,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[SignInOutRepository] notify failed: $e');
    }
  }

  /// DUTY: duty fields to write along with a status change (Ionic
  /// syncDutyWithStatus). The id must already be validated for the tenant.
  Future<Map<String, dynamic>> _dutyUpdateForStatus(
    String personAttendanceId,
    AttendanceStatus newStatus,
  ) async {
    final row = await supabase
        .from('person_attendances')
        .select('duty_state, attendance:attendance_id(attType:type_id(duty_mode))')
        .eq('id', personAttendanceId)
        .maybeSingle();
    if (row == null || row['attendance']?['attType']?['duty_mode'] != true) {
      return const {};
    }
    return dutySyncFieldsForStatus(
      isDutyTermin: true,
      currentDutyState: row['duty_state'] as String?,
      newStatus: newStatus,
      userId: supabase.auth.currentUser?.id,
    );
  }

  /// Sign in to an attendance (status → Anwesend, like Ionic `signin`).
  ///
  /// [type] only selects the notification text (previous status).
  Future<void> signIn(
    String personAttendanceId,
    SignInType type, {
    String notes = '',
    bool ownAcrossTenants = false,
  }) async {
    try {
      final valid = await _validatePersonAttendanceIds(
        [personAttendanceId],
        'signIn',
        ownAcrossTenants: ownAcrossTenants,
      );
      if (valid.isEmpty) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'signIn',
        );
      }

      // DUTY: keep assignment and status in sync (Ionic syncDutyWithStatus)
      final dutyUpdate =
          await _dutyUpdateForStatus(personAttendanceId, AttendanceStatus.present);

      await _updatePersonAttendances(valid, {
        'status': AttendanceStatus.present.value,
        'notes': notes,
        ...dutyUpdate,
      });

      await _notify(attId: personAttendanceId, type: type.telegramType, notes: notes);
    } catch (e, stack) {
      handleError(e, stack, 'signIn');
      rethrow;
    }
  }

  /// Sign out from attendances (Entschuldigt / Verspätung gemeldet).
  Future<void> signOut(
    List<String> personAttendanceIds,
    String reason, {
    bool isLateComing = false,
    bool isParents = false,
    bool isSelf = false,
    bool ownAcrossTenants = false,
  }) async {
    try {
      final validIds = await _validatePersonAttendanceIds(
        personAttendanceIds,
        'signOut',
        ownAcrossTenants: ownAcrossTenants,
      );

      if (validIds.isEmpty) {
        throw RepositoryException(
          message: 'No valid person attendances found for current tenant',
          operation: 'signOut',
        );
      }

      final status =
          isLateComing ? AttendanceStatus.lateExcused : AttendanceStatus.excused;

      await _updatePersonAttendances(validIds, {
        'status': status.value,
        'notes': reason,
      });

      await _notify(
        attId: validIds.first,
        type: isLateComing ? 'lateSignout' : 'signout',
        reason: reason,
        isParents: isParents,
        isSelf: isSelf,
      );
    } catch (e, stack) {
      handleError(e, stack, 'signOut');
      rethrow;
    }
  }

  /// Update attendance note
  Future<void> updateAttendanceNote(
    String personAttendanceId,
    String note, {
    bool ownAcrossTenants = false,
  }) async {
    try {
      final valid = await _validatePersonAttendanceIds(
        [personAttendanceId],
        'updateAttendanceNote',
        ownAcrossTenants: ownAcrossTenants,
      );
      if (valid.isEmpty) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'updateAttendanceNote',
        );
      }

      await _updatePersonAttendances(valid, {'notes': note});
      await _notify(attId: personAttendanceId, type: 'noteUpdate', reason: note);
    } catch (e, stack) {
      handleError(e, stack, 'updateAttendanceNote');
      rethrow;
    }
  }

  /// Saves the answers to the attendance type's registration fields.
  Future<void> updateRegistrationAnswers(
    String personAttendanceId,
    Map<String, dynamic> answers,
  ) async {
    try {
      final valid = await _validatePersonAttendanceIds(
        [personAttendanceId],
        'updateRegistrationAnswers',
      );
      if (valid.isEmpty) {
        throw RepositoryException(
          message: 'Access denied: PersonAttendance belongs to different tenant',
          operation: 'updateRegistrationAnswers',
        );
      }
      await _updatePersonAttendances(valid, {'registration_answers': answers});
    } catch (e, stack) {
      handleError(e, stack, 'updateRegistrationAnswers');
      rethrow;
    }
  }

  /// Whether the Dateiablage is shared with all members of the current
  /// tenant (`tenants.files_shared`). Returns false when the column is
  /// missing (files module not migrated yet).
  Future<bool> getTenantFilesShared() async {
    try {
      final row = await supabase
          .from('tenants')
          .select('files_shared')
          .eq('id', currentTenantId)
          .maybeSingle();
      return row?['files_shared'] == true;
    } catch (_) {
      return false;
    }
  }

  AttendanceType? _parseType(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return AttendanceType.fromJson({'name': '', ...json});
    } catch (_) {
      return null;
    }
  }

  /// Own Termine of a person in the current tenant ("Meine Termine").
  ///
  /// With [all] = false only Termine since [since] are loaded (season start).
  Future<List<CrossTenantPersonAttendance>> getPersonAttendances(
    int personId, {
    String? since,
    String tenantName = '',
  }) async {
    try {
      // SEC: person_attendances has no tenantId column – the inner join on
      // attendance is filtered by tenantId so only Termine of this tenant
      // are returned.
      // SOL_FIX37: paged in a stable order, so a long history never pushes
      // rows (upcoming Termine, quota) past the PostgREST row limit.
      final response = await fetchAllPages<Map<String, dynamic>>((from, to) async {
        var query = supabase
            .from('person_attendances')
            .select(
                '*, attendance:attendance_id!inner($kSignoutAttendanceColumns, '
                'attType:type_id($kSignoutAttendanceTypeColumns))')
            .eq('person_id', personId)
            .eq('attendance.tenantId', currentTenantId);
        if (since != null) {
          query = query.gt('attendance.date', since);
        }
        final page = await query.order('id', ascending: true).range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });

      return response
          .where((json) => json['attendance'] != null)
          .map((json) => _fromRows(
                json['attendance'] as Map<String, dynamic>,
                json,
                tenantId: currentTenantId,
                tenantName: tenantName,
                // Ionic getPersonAttendances: attType without hide_name
                honorHideName: false,
              ))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPersonAttendances');
      rethrow;
    }
  }

  /// All running/upcoming Termine of the tenant plus the own status
  /// (tenant setting "Alle Termine für Mitglieder sichtbar").
  Future<List<CrossTenantPersonAttendance>> getAllUpcomingAttendancesForSignout(
    int playerId, {
    String tenantName = '',
  }) async {
    try {
      // Look back a bit so multi-day Termine that started earlier and are
      // still running stay included.
      final since = DateTime.now()
          .subtract(const Duration(days: 31))
          .toUtc()
          .toIso8601String();
      final atts = await supabase
          .from('attendance')
          .select('$kSignoutAttendanceColumns, '
              'attType:type_id($kSignoutAttendanceTypeColumns)')
          .eq('tenantId', currentTenantId)
          .gt('date', since)
          .order('date', ascending: true);

      final running = (atts as List)
          .cast<Map<String, dynamic>>()
          .where((a) => !EventListUtils.hasEnded(
                a['date']?.toString(),
                _toInt(a['duration_days']),
              ))
          .toList();
      if (running.isEmpty) return [];

      // SEC: filtered by own person_id and attendance ids of this tenant.
      final pas = await supabase
          .from('person_attendances')
          .select('id, attendance_id, status, notes, registration_answers, duty_state')
          .eq('person_id', playerId)
          .inFilter('attendance_id', running.map((a) => a['id']).toList());
      final paMap = <int, Map<String, dynamic>>{
        for (final pa in (pas as List).cast<Map<String, dynamic>>())
          _toInt(pa['attendance_id']) ?? -1: pa,
      };

      return running.map((att) {
        final pa = paMap[_toInt(att['id'])];
        return _fromRows(
          att,
          pa ?? {'person_id': playerId},
          tenantId: currentTenantId,
          tenantName: tenantName,
          isMember: pa != null,
          // Ionic getAllUpcomingAttendancesForSignout: attType without hide_name
          honorHideName: false,
        );
      }).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAllUpcomingAttendancesForSignout');
      rethrow;
    }
  }

  CrossTenantPersonAttendance _fromRows(
    Map<String, dynamic> att,
    Map<String, dynamic> pa, {
    required int tenantId,
    required String tenantName,
    String tenantColor = '#3880FF',
    bool isMember = true,
    bool honorHideName = true,
  }) {
    final type = _parseType(att['attType']);
    return CrossTenantPersonAttendance(
      id: pa['id']?.toString(),
      personId: _toInt(pa['person_id']),
      attendanceId: _toInt(att['id']),
      status: isMember ? _parseStatus(pa['status']) : AttendanceStatus.neutral,
      notes: pa['notes'] as String?,
      date: att['date'] as String?,
      typeInfo: att['typeInfo'] as String?,
      startTime: att['start_time'] as String?,
      endTime: att['end_time'] as String?,
      deadline: att['deadline'] as String?,
      tenantId: tenantId,
      tenantName: tenantName,
      tenantColor: tenantColor,
      plan: att['plan'] as Map<String, dynamic>?,
      sharePlan: att['share_plan'] == true,
      typeId: att['type_id']?.toString(),
      includeInAverage: type?.includeInAverage ?? true,
      durationDays: _toInt(att['duration_days']),
      place: att['place'] as String?,
      filesFolder: att['files_folder'] as String?,
      description: att['description'] as String?,
      attachmentUrl: att['attachment_url'] as String?,
      attachmentName: att['attachment_name'] as String?,
      songs: (att['songs'] is List)
          ? (att['songs'] as List).map((e) => _toInt(e) ?? 0).toList()
          : const [],
      attendanceType: type,
      isMember: isMember,
      dutyState: pa['duty_state'] as String?,
      registrationAnswers: pa['registration_answers'] is Map
          ? Map<String, dynamic>.from(pa['registration_answers'] as Map)
          : null,
      legacyType: att['type'] as String?,
      honorHideName: honorHideName,
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// Own Termine of the current user in all tenants he belongs to
  /// ("Übersicht", Ionic `loadAllPersonAttendancesAcrossTenants`).
  ///
  /// IOS_ATT_PAGES: same scope as Ionic –
  /// * tenants = the user's `tenantUsers` memberships (not every `player`
  ///   row linked to the account),
  /// * one person per tenant: the active linked row (SOL_FIX14 – Ionic's
  ///   `.single()` skipped tenants with several rows; no row → skipped),
  /// * only Termine after the tenant's `seasonStart` (default 2023-01-01),
  /// * tenant label `longName || shortName`, colour by membership order,
  /// * sorted by date ascending.
  Future<List<CrossTenantPersonAttendance>> getAllPersonAttendancesAcrossTenants() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // SEC: cross-tenant by design – only the user's own memberships.
      final memberships = await supabase
          .from('tenantUsers')
          .select('tenantId')
          .eq('userId', userId);
      final tenantIds = <int>[];
      for (final m in memberships as List) {
        final id = _toInt(m['tenantId']);
        if (id != null && !tenantIds.contains(id)) tenantIds.add(id);
      }
      if (tenantIds.isEmpty) return [];

      final tenants = await supabase
          .from('tenants')
          .select('id, shortName, longName, seasonStart')
          .inFilter('id', tenantIds);
      final tenantRows = <int, Map<String, dynamic>>{
        for (final t in (tenants as List).cast<Map<String, dynamic>>())
          if (_toInt(t['id']) != null) _toInt(t['id'])!: t,
      };

      final perTenant = await Future.wait([
        for (final tenantId in tenantIds)
          _ownAttendancesOfTenant(
            userId: userId,
            tenantId: tenantId,
            tenant: tenantRows[tenantId],
            tenantColor: _getTenantColor(tenantId, tenantIds),
          ),
      ]);

      return sortCrossTenantByDate(perTenant.expand((l) => l).toList());
    } catch (e, stack) {
      handleError(e, stack, 'getAllPersonAttendancesAcrossTenants');
      rethrow;
    }
  }

  /// Ionic `getPersonIdForTenant` + `getPersonAttendancesForTenant`.
  Future<List<CrossTenantPersonAttendance>> _ownAttendancesOfTenant({
    required String userId,
    required int tenantId,
    required Map<String, dynamic>? tenant,
    required String tenantColor,
  }) async {
    // SEC: the person of the user in this tenant (tenantId + appId).
    // SOL_FIX14: load every linked row incl. pending / left and pick the
    // active one (same choice as CrossTenantService.getPersonIdForTenant).
    // Ionic's `.single()` fails when the account has several rows in the
    // tenant (e.g. an archived and a new active one) and the tenant's
    // Termine vanished from the Übersicht.
    final persons = await supabase
        .from('player')
        .select('id, pending, left')
        .eq('tenantId', tenantId)
        .eq('appId', userId);
    final personId = CrossTenantService.pickPersonIdForTenant(
        (persons as List).cast<Map<String, dynamic>>());
    if (personId == null) return const [];

    // SEC: person_attendances has no tenantId – the inner join on attendance
    // is filtered by the membership's tenantId.
    final rows = await supabase
        .from('person_attendances')
        .select(
            '*, attendance:attendance_id!inner($kOverviewAttendanceColumns, '
            'attType:type_id($kSignoutAttendanceTypeColumns))')
        .eq('person_id', personId)
        .eq('attendance.tenantId', tenantId)
        .gt('attendance.date', overviewSeasonStart(tenant?['seasonStart']));

    final tenantName = tenantDisplayName(
      tenant?['longName'] as String?,
      tenant?['shortName'] as String?,
    );
    return (rows as List)
        .where((json) => json['attendance'] != null)
        .where((json) => _toInt(json['attendance']['tenantId']) == tenantId)
        // IOS_FORMS2: like Ionic, duty Termine are listed (and count for the
        // average) even when the person was not assigned.
        .map((json) => _fromRows(
              json['attendance'] as Map<String, dynamic>,
              json as Map<String, dynamic>,
              tenantId: tenantId,
              tenantName: tenantName,
              tenantColor: tenantColor,
            ))
        .toList();
  }

  /// Ionic `tenant?.longName || tenant?.shortName || 'Unbekannt'`.
  @visibleForTesting
  static String tenantDisplayName(String? longName, String? shortName) {
    if (longName != null && longName.isNotEmpty) return longName;
    if (shortName != null && shortName.isNotEmpty) return shortName;
    return l10nWithoutContext.commonUnknown;
  }

  /// Ionic `tenantData?.seasonStart || dayjs('2023-01-01').toISOString()`.
  @visibleForTesting
  static String overviewSeasonStart(dynamic seasonStart) {
    final value = seasonStart?.toString();
    if (value != null && value.isNotEmpty) return value;
    return DateTime(2023).toUtc().toIso8601String();
  }

  /// Ionic: flattened list sorted by date ascending.
  @visibleForTesting
  static List<CrossTenantPersonAttendance> sortCrossTenantByDate(
    List<CrossTenantPersonAttendance> list,
  ) {
    DateTime d(CrossTenantPersonAttendance a) =>
        EventListUtils.parse(a.date) ?? DateTime(1970);
    return [...list]..sort((a, b) => d(a).compareTo(d(b)));
  }

  AttendanceStatus _parseStatus(dynamic status) {
    if (status == null) return AttendanceStatus.neutral;
    if (status is AttendanceStatus) return status;

    // Handle integer values (as stored in database)
    if (status is int) {
      return AttendanceStatus.fromValue(status);
    }

    // Handle string values (enum names or integer strings)
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
}

/// Previous status of a sign-in – selects the notification text.
enum SignInType {
  normal('signin'),
  neutral('neutralSignin'),
  late('lateSignIn');

  const SignInType(this.telegramType);

  final String telegramType;

  /// Sign-in type derived from the current status (Ionic signin()).
  static SignInType fromStatus(AttendanceStatus status) {
    if (status == AttendanceStatus.lateExcused) return SignInType.late;
    if (status == AttendanceStatus.neutral) return SignInType.neutral;
    return SignInType.normal;
  }
}

/// Person attendance with its Termin (used by Meine Termine, Übersicht and
/// the plan viewer). In the cross-tenant overview it carries the tenant.
class CrossTenantPersonAttendance {
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
  final int tenantId;
  final String tenantName;
  final String tenantColor;
  final Map<String, dynamic>? plan;
  final bool sharePlan;
  final String? typeId;
  final bool includeInAverage;
  final int? durationDays;
  final String? place;
  final String? filesFolder;
  final String? description;
  final String? attachmentUrl;
  final String? attachmentName;
  final List<int> songs;
  final AttendanceType? attendanceType;

  /// false when the person is not part of the Termin (show_all_attendances).
  final bool isMember;
  final Map<String, dynamic>? registrationAnswers;
  final String? legacyType;

  /// DUTY: 'requested' | 'confirmed' | 'self' or null
  final String? dutyState;

  /// IOS_ATT_PAGES: whether the title honours the type's `hide_name`.
  /// Ionic "Meine Termine" joins `attType:type_id(id, highlight,
  /// include_in_average, name, color, registration_fields, duty_mode)` –
  /// without `hide_name` – so its rows always show the type name ("Übung").
  /// The Übersicht loads the full types and honours it.
  final bool honorHideName;

  /// DUTY: Termin of a type in Dienst-Modus
  bool get isDutyType => attendanceType?.dutyMode ?? false;

  /// DUTY: own assignment that still waits for confirmation
  bool get isDutyRequested =>
      isDutyType && dutyState == DutyState.requested && !isCancelledStatus(status);

  CrossTenantPersonAttendance({
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
    required this.tenantId,
    required this.tenantName,
    required this.tenantColor,
    this.plan,
    this.sharePlan = false,
    this.typeId,
    this.includeInAverage = true,
    this.durationDays,
    this.place,
    this.filesFolder,
    this.description,
    this.attachmentUrl,
    this.attachmentName,
    this.songs = const [],
    this.attendanceType,
    this.isMember = true,
    this.registrationAnswers,
    this.legacyType,
    this.dutyState,
    this.honorHideName = true,
  });

  CrossTenantPersonAttendance copyWith({
    AttendanceStatus? status,
    String? notes,
    Map<String, dynamic>? registrationAnswers,
  }) {
    return CrossTenantPersonAttendance(
      id: id,
      personId: personId,
      attendanceId: attendanceId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      date: date,
      typeInfo: typeInfo,
      startTime: startTime,
      endTime: endTime,
      deadline: deadline,
      tenantId: tenantId,
      tenantName: tenantName,
      tenantColor: tenantColor,
      plan: plan,
      sharePlan: sharePlan,
      typeId: typeId,
      includeInAverage: includeInAverage,
      durationDays: durationDays,
      place: place,
      filesFolder: filesFolder,
      description: description,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      songs: songs,
      attendanceType: attendanceType,
      isMember: isMember,
      registrationAnswers: registrationAnswers ?? this.registrationAnswers,
      legacyType: legacyType,
      dutyState: dutyState,
      honorHideName: honorHideName,
    );
  }

  /// Duration including the type's default for all-day types.
  int? get effectiveDurationDays => durationDays ??
      ((attendanceType?.allDay ?? false) ? attendanceType?.durationDays : null);

  /// Past only once the last day of a multi-day Termin is over.
  bool get isPast => EventListUtils.hasEnded(date, effectiveDurationDays);

  /// Today, running or in the future.
  bool get isUpcoming => date != null && !isPast;

  /// Starts today or still running today ("Heute").
  bool get isRunning => EventListUtils.isRunning(date, effectiveDurationDays);

  /// Check if the deadline has passed
  bool get isDeadlinePassed => !EventListUtils.isSigninOpen(deadline);

  /// Status letter (Ionic att.text)
  String get text => isMember ? EventListUtils.attText(status) : '';

  /// Check if the person was present (attended)
  bool get attended => status.countsAsPresent;

  bool get isExcusedStatus =>
      status == AttendanceStatus.excused ||
      status == AttendanceStatus.lateExcused;

  /// Highlighted type (Vortrag etc.)
  bool get highlight => attendanceType?.highlight ?? legacyType == 'vortrag';

  /// Check if plan is available for viewing
  bool get hasPlan {
    if (!sharePlan || plan == null) return false;
    final fields = plan?['fields'] as List?;
    return fields != null && fields.isNotEmpty;
  }

  /// Get deadline as DateTime
  DateTime? get deadlineDateTime => EventListUtils.deadlineLocal(deadline);

  /// Get readable deadline text
  String? get deadlineText {
    if (deadline == null) return null;
    return EventListUtils.deadlineText(deadline);
  }

  /// Readable date ("Di., 20.10.2026", range for multi-day all-day types)
  String get readableDate => EventListUtils.readableDate(
        date,
        allDay: attendanceType?.allDay ?? false,
        durationDays: attendanceType?.durationDays,
      );

  /// Title like Ionic `getTypeTitle`: typeInfo, else type name unless hidden.
  String get title {
    if (typeInfo != null && typeInfo!.isNotEmpty) return typeInfo!;
    final type = attendanceType;
    if (type == null || (honorHideName && type.hideName)) return '';
    return type.name;
  }

  /// Title shown in the lists; falls back to the readable date.
  String get eventTitle => title.isNotEmpty ? title : readableDate;

  /// Registration fields of the attendance type.
  List<RegistrationField> get registrationFields =>
      attendanceType?.registrationFields ?? const [];

  /// Time line; multi-day Termine (and the current card) also show the date
  /// unless it is the title.
  String eventMeta({bool withDate = false, bool withPlace = true}) {
    final type = attendanceType;
    final showDate = withDate ||
        EventListUtils.isMultiDay(durationDays) ||
        ((type?.allDay ?? false) && (type?.durationDays ?? 1) > 1);
    final readable = readableDate;
    return EventListUtils.meta([
      showDate && readable != eventTitle ? readable : '',
      EventListUtils.timeRange(startTime ?? type?.startTime, endTime ?? type?.endTime),
      withPlace ? place : '',
    ]);
  }

  /// Display title - returns typeInfo if not empty, otherwise 'Termin'
  String get displayTitle {
    if (typeInfo != null && typeInfo!.isNotEmpty) {
      return typeInfo!;
    }
    return title.isNotEmpty ? title : l10nWithoutContext.attendanceEventFallback;
  }
}
