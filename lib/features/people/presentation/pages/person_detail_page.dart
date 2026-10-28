import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/services/auth_service.dart';
import '../widgets/planned_absences.dart';
import '../../../duty/presentation/pages/unavailability_page.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/utils/text_utils.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../widgets/person_match_suggestions.dart';
import 'package:uuid/uuid.dart';
import '../widgets/handover_sheet.dart';
import '../widgets/pause_person_sheet.dart';
import '../widgets/duplicate_candidates_card.dart';
import '../widgets/person_detail/person_detail.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';

/// Provider for single person with group name
final personProvider =
    FutureProvider.family<Person?, int>((ref, personId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);
  final groups = await ref.watch(groupsMapProvider.future);

  if (tenant == null) return null;
  final tenantId = tenant.id;
  if (tenantId == null) return null;

  final response = await supabase
      .from('player')
      .select('*')
      .eq('id', personId)
      .eq('tenantId', tenantId)
      .maybeSingle();

  if (response == null) return null;
  final person = Person.fromJson(response);

  // Add group name from the groups map
  final groupName = person.instrument != null ? groups[person.instrument] : null;
  return person.copyWith(groupName: groupName);
});

/// Provider for person attendance statistics
final personAttendanceStatsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, personId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenant = ref.watch(currentTenantProvider);

  final tenantId = tenant?.id;
  if (tenantId == null) {
    return {
      'total': 0,
      'attended': 0,
      'percentage': 0,
      'lateCount': 0,
      'lateStatuses': <int>[3],
    };
  }

  // Get late rule from CriticalRules - find first rule that includes status 3 (late)
  List<int> lateStatuses = [3, 5]; // Fallback: both late statuses
  CriticalRulePeriodType? latePeriodType;
  int? latePeriodDays;

  final criticalRules = tenant?.criticalRules;
  if (criticalRules != null) {
    for (final rule in criticalRules) {
      if (rule.statuses.contains(3) && rule.enabled) {
        lateStatuses = rule.statuses;
        latePeriodType = rule.periodType;
        latePeriodDays = rule.periodDays;
        break;
      }
    }
  }

  final response = await supabase
      .from('person_attendances')
      .select('status, notes, attendance:attendance_id!inner(id, date, tenantId)')
      .eq('person_id', personId)
      .eq('attendance.tenantId', tenantId);

  final attendances = response as List;
  final now = DateTime.now();
  final seasonStartStr = tenant?.seasonStart;
  final seasonStart = seasonStartStr != null
      ? DateTime.tryParse(seasonStartStr)
      : null;

  final pastAttendances = attendances.where((a) {
    final attendance = a['attendance'] as Map<String, dynamic>?;
    final date = DateTime.tryParse(attendance?['date'] ?? '');
    if (date == null || !date.isBefore(now)) return false;
    // Only count attendances from the current season
    if (seasonStart != null && date.isBefore(seasonStart)) return false;
    return true;
  }).toList();

  final total = pastAttendances.length;
  final attended = pastAttendances.where((a) {
    final status = a['status'];
    if (status is int) {
      // SETTINGS2: shift_excused_as_present (Ionic getPersonAttendances)
      return AttendanceStatus.fromValue(status).countsAsAttended(
        notes: a['notes'] as String?,
        shiftExcusedAsPresent: tenant?.shiftExcusedAsPresent ?? false,
      );
    }
    return false;
  }).length;
  final percentage = total > 0 ? (attended / total * 100).round() : 0;

  // Determine the start date for counting late based on periodType
  DateTime? lateCountStartDate;
  if (latePeriodType == CriticalRulePeriodType.season) {
    // Use tenant's seasonStart
    if (seasonStartStr != null) {
      lateCountStartDate = DateTime.tryParse(seasonStartStr);
    }
  } else if (latePeriodType == CriticalRulePeriodType.days) {
    // Use last X days
    lateCountStartDate = now.subtract(Duration(days: latePeriodDays ?? 30));
  }
  // For allTime or null, lateCountStartDate remains null (count all)

  // Count late based on CriticalRule statuses AND periodType
  final lateCount = pastAttendances.where((a) {
    final status = a['status'];
    if (status is! int || !lateStatuses.contains(status)) {
      return false;
    }

    // If we have a start date filter, apply it
    if (lateCountStartDate != null) {
      final attendance = a['attendance'] as Map<String, dynamic>?;
      final date = DateTime.tryParse(attendance?['date'] ?? '');
      if (date == null || date.isBefore(lateCountStartDate)) {
        return false;
      }
    }

    return true;
  }).length;

  return {
    'total': total,
    'attended': attended,
    'percentage': percentage,
    'lateCount': lateCount,
    'lateStatuses': lateStatuses,
  };
});

/// Provider for person history (attendance + player history combined)
final personHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, personId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final person = await ref.watch(personProvider(personId).future);
  final tenant = ref.watch(currentTenantProvider);

  if (person == null || tenant == null) return [];
  final tenantId = tenant.id;
  if (tenantId == null) return [];

  final today = DateTime.now().toIso8601String().substring(0, 10);

  final attendanceResponse = await supabase
      .from('person_attendances')
      .select('*, attendance:attendance_id!inner(id, date, type, typeInfo, type_id, tenantId)')
      .eq('person_id', personId)
      .eq('attendance.tenantId', tenantId);

  List<Map<String, dynamic>> attendanceTypes = [];
  final typesResponse = await supabase
      .from('attendance_types')
      .select('*')
      .eq('tenant_id', tenantId);
  attendanceTypes = List<Map<String, dynamic>>.from(typesResponse as List);

  final attendanceHistory = (attendanceResponse as List)
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
      final typeName = attType['name']?.toString() ?? '';
      meetingName = (typeInfo != null && typeInfo.isNotEmpty) ? typeInfo : typeName;
    } else {
      meetingName = typeInfo ?? attendance?['type']?.toString() ?? 'Anwesenheit';
    }

    final statusValue = a['status'];
    int statusInt = 0;
    if (statusValue is int) {
      statusInt = statusValue;
    } else if (statusValue != null) {
      statusInt = int.tryParse(statusValue.toString()) ?? 0;
    }

    String displayStatus;
    switch (statusInt) {
      case 1:
        displayStatus = 'X';
        break;
      case 2:
        displayStatus = 'E';
        break;
      case 3:
        displayStatus = 'L';
        break;
      case 4:
        displayStatus = 'A';
        break;
      case 5:
        displayStatus = 'L';
        break;
      case 0:
      default:
        displayStatus = 'N';
    }

    return {
      'date': attendance?['date']?.toString(),
      'meetingName': meetingName,
      'text': displayStatus,
      'type': PlayerHistoryType.attendance.value,
      'notes': a['notes'],
      'status': statusInt,
    };
  }).toList();

  final playerHistory = person.history.map((h) {
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

  return allHistory.take(100).toList();
});

/// Person detail page - with inline editing
class PersonDetailPage extends ConsumerWidget {
  const PersonDetailPage({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personProvider(personId));

    return personAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Person')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Person')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text('Fehler: $error'),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.refresh(personProvider(personId)),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
      data: (person) {
        if (person == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Person')),
            body: const Center(child: Text('Person nicht gefunden')),
          );
        }
        return _PersonDetailContent(person: person, personId: personId);
      },
    );
  }
}

class _PersonDetailContent extends ConsumerStatefulWidget {
  const _PersonDetailContent({required this.person, required this.personId});

  final Person person;
  final int personId;

  @override
  ConsumerState<_PersonDetailContent> createState() =>
      _PersonDetailContentState();
}

class _PersonDetailContentState extends ConsumerState<_PersonDetailContent> {
  // Draft state for inline editing
  late Person _draft;
  bool _hasChanges = false;
  bool _isSaving = false;
  final Set<String> _changedFields = {};

  // Separate draft values for fields that need special handling
  late int? _selectedGroupId;
  late int? _selectedTeacherId;
  late String? _selectedShiftId;
  late String? _selectedShiftName;
  late DateTime? _shiftStart;
  late int? _selectedParentId;
  late bool _isLeader;
  late bool _hasTeacher;
  late Map<String, dynamic> _additionalFieldValues;

  // Section states
  bool _showAllgemein = false;
  bool _showAccount = false;
  bool _showHistorie = true;
  bool _showProblemfall = true;

  // Problem person state
  bool _problemSolved = false;
  String _problemNotes = '';

  // User role state
  Role? _userRole;
  bool _isLoadingRole = false;

  // PEOPLE2: organisation person fields (tenant_group_person_fields)
  Set<String> _orgFieldIds = {};
  int? _orgId;

  @override
  void initState() {
    super.initState();
    _initDraft();
    _loadUserRole();
    _loadSharedFieldValues();
  }

  /// Ionic getOrganisationPersonKey
  String? get _personKey {
    final g = widget.person.globalPersonId;
    if (g != null && g.isNotEmpty) return 'global:$g';
    final a = widget.person.appId;
    if (a != null && a.isNotEmpty) return 'app:$a';
    return null;
  }

  /// Ionic getSharedPersonFieldValues: organisation field values are shared
  /// across the tenants of an organisation.
  Future<void> _loadSharedFieldValues() async {
    try {
      final fields = await ref.read(personExtraFieldsProvider.future);
      _orgFieldIds = fields
          .where((f) => f.isOrganisationField)
          .map((f) => f.id)
          .toSet();
      if (_orgFieldIds.isEmpty) return;
      final repo = ref.read(profileRepositoryWithTenantProvider);
      _orgId = await repo.getOrganisationId();
      final key = _personKey;
      if (_orgId == null || key == null) return;
      final shared = await repo.getSharedFieldValues(_orgId!, key);
      if (!mounted || shared.isEmpty) return;
      setState(() {
        for (final e in shared.entries) {
          if (_orgFieldIds.contains(e.key) &&
              !_changedFields.contains('additionalFields.${e.key}')) {
            _additionalFieldValues[e.key] = e.value;
          }
        }
      });
    } catch (_) {
      // Optional — tenant values are shown instead
    }
  }

  /// Ionic continueUpdatingPlayer: organisation field values go to
  /// tenant_group_person_fields, the rest stays in additional_fields.
  Future<Map<String, dynamic>> _splitAndSaveSharedFields() async {
    final local = Map<String, dynamic>.from(_additionalFieldValues);
    final key = _personKey;
    if (_orgFieldIds.isEmpty || _orgId == null || key == null) return local;
    final shared = <String, dynamic>{
      for (final id in _orgFieldIds)
        if (local.containsKey(id)) id: local.remove(id),
    };
    await ref
        .read(profileRepositoryWithTenantProvider)
        .updateSharedFieldValues(_orgId!, key, shared);
    return local;
  }

  void _initDraft() {
    final p = widget.person;
    _draft = p;
    _selectedGroupId = p.instrument;
    _selectedTeacherId = p.teacher;
    _selectedShiftId = p.shiftId;
    _selectedShiftName = p.shiftName;
    _shiftStart = p.shiftStart != null ? DateTime.tryParse(p.shiftStart!) : null;
    _selectedParentId = p.parentId;
    _isLeader = p.isLeader;
    _hasTeacher = p.hasTeacher;
    _additionalFieldValues = Map.from(p.additionalFields ?? {});
  }

  Future<void> _loadUserRole() async {
    if (widget.person.appId == null) return;
    final tenant = ref.read(currentTenantProvider);
    final appId = widget.person.appId;
    final tenantId = tenant?.id;

    if (appId == null || tenantId == null) return;

    setState(() => _isLoadingRole = true);
    try {
      final role = await _getUserRole(appId, tenantId);
      if (mounted) {
        setState(() {
          _userRole = role ?? Role.player;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRole = false);
      }
    }
  }

  Future<Role?> _getUserRole(String userId, int tenantId) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final response = await supabase
          .from('tenantUsers')
          .select('role')
          .eq('userId', userId)
          .eq('tenantId', tenantId)
          .maybeSingle();

      if (response == null) return null;
      return Role.fromValue(response['role'] as int? ?? 99);
    } catch (e) {
      return null;
    }
  }

  void _onFieldChanged(String field, dynamic value) {
    setState(() {
      _changedFields.add(field);
      _hasChanges = true;

      // Handle special fields
      if (field == 'firstName') {
        _draft = _draft.copyWith(firstName: value as String? ?? '');
      } else if (field == 'lastName') {
        _draft = _draft.copyWith(lastName: value as String? ?? '');
      } else if (field == 'notes') {
        _draft = _draft.copyWith(notes: value as String?);
      } else if (field == 'phone') {
        _draft = _draft.copyWith(phone: value as String?);
      } else if (field == 'birthday') {
        _draft = _draft.copyWith(birthday: value as String?);
      } else if (field == 'playsSince') {
        _draft = _draft.copyWith(playsSince: value as String?);
      } else if (field == 'joined') {
        _draft = _draft.copyWith(joined: value as String?);
      } else if (field == 'instrument') {
        _selectedGroupId = value as int?;
        _draft = _draft.copyWith(instrument: value);
      } else if (field == 'isLeader') {
        _isLeader = value as bool;
        _draft = _draft.copyWith(isLeader: value);
      } else if (field == 'hasTeacher') {
        _hasTeacher = value as bool;
        _draft = _draft.copyWith(hasTeacher: value);
      } else if (field == 'teacher') {
        _selectedTeacherId = value as int?;
        _draft = _draft.copyWith(teacher: value);
      } else if (field == 'shiftId') {
        _selectedShiftId = value as String?;
        _draft = _draft.copyWith(shiftId: value);
      } else if (field == 'shiftName') {
        _selectedShiftName = value as String?;
        _draft = _draft.copyWith(shiftName: value);
      } else if (field == 'shiftStart') {
        _shiftStart = value != null ? DateTime.tryParse(value as String) : null;
        _draft = _draft.copyWith(shiftStart: value as String?);
      } else if (field == 'parentId') {
        _selectedParentId = value as int?;
        _draft = _draft.copyWith(parentId: value);
      } else if (field == 'otherExercise') {
        _draft = _draft.copyWith(otherExercise: value as String?);
      } else if (field == 'range') {
        _draft = _draft.copyWith(range: value as String?);
      } else if (field == 'instruments') {
        _draft = _draft.copyWith(instruments: value as String?);
      } else if (field == 'examinee') {
        _draft = _draft.copyWith(examinee: value as bool);
      } else if (field == 'testResult') {
        _draft = _draft.copyWith(testResult: value as String?);
      } else if (field == 'email') {
        _draft = _draft.copyWith(email: value as String?);
      } else if (field == 'otherOrchestras') {
        _draft = _draft.copyWith(otherOrchestras: value as List<String>?);
      } else if (field.startsWith('additionalFields.')) {
        final fieldId = field.substring('additionalFields.'.length);
        _additionalFieldValues[fieldId] = value;
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving || !_hasChanges) return;

    // Validate required fields
    if (_draft.firstName.isEmpty || _draft.lastName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vorname und Nachname sind erforderlich'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Berechtigung zum Bearbeiten'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    // STATS_PEOPLE_FIXES: Ionic updatePlayer() pre-save dialogs
    final tenantType = ref.read(currentTenantProvider)?.type;
    final isGeneral = tenantType == 'general';
    final emailChanged =
        (widget.person.email ?? '') != (_draft.email ?? '');
    final newEmail = _draft.email?.trim() ?? '';
    final emailValid =
        RegExp(r'^[\w-\.+]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(newEmail);
    if (newEmail.isNotEmpty && emailChanged && !emailValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte gib eine gültige E-Mail-Adresse ein'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    var createAccountAfterSave = false;
    var assignVoiceLeaderRole = false;
    if (emailChanged && emailValid && widget.person.appId == null) {
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('E-Mail Adresse hinzugefügt'),
          content: const Text(
              'Möchtest du gleich ein Konto für die Person anlegen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nur speichern'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ja'),
            ),
          ],
        ),
      );
      if (create == null || !mounted) return;
      createAccountAfterSave = create;
    } else if (!isGeneral &&
        widget.person.appId != null &&
        !widget.person.isLeader &&
        _isLeader) {
      final choice = await _showVoiceLeaderDialog();
      if (!mounted) return;
      if (choice == null) {
        setState(() {
          _isLeader = false;
          _draft = _draft.copyWith(isLeader: false);
        });
        return;
      }
      assignVoiceLeaderRole = choice;
    }

    setState(() => _isSaving = true);

    try {
      // Sprint 2a: migrated to PlayerRepository.updatePlayerFields.
      // The remaining supabaseClientProvider reads in this file (personProvider,
      // appointmentsProvider, _getUserRole, _updateUserRole, _unlinkAccount)
      // are Sprint 2b scope — they need TenantUserRepository which doesn't
      // exist yet.
      final repo = ref.read(playerRepositoryWithTenantProvider);
      final person = widget.person;

      // Build history entries for tracked changes
      final List<Map<String, dynamic>> newHistoryEntries = [];
      if (_selectedGroupId != person.instrument) {
        final groups = await ref.read(groupsMapProvider.future);
        final oldGroupName = groups[person.instrument] ?? 'Unbekannt';
        final newGroupName = groups[_selectedGroupId] ?? 'Unbekannt';
        newHistoryEntries.add({
          'date': DateTime.now().toIso8601String(),
          'text': '$oldGroupName -> $newGroupName',
          'type': PlayerHistoryType.instrumentChange.value,
        });
      }

      if (_draft.notes != (person.notes ?? '')) {
        newHistoryEntries.add({
          'date': DateTime.now().toIso8601String(),
          'text': person.notes ?? 'Keine Notiz',
          'type': PlayerHistoryType.notes.value,
        });
      }

      final existingHistory = person.history.map((h) => h.toJson()).toList();
      final updatedHistory = [...existingHistory, ...newHistoryEntries];

      final personId = person.id;
      if (personId == null || !repo.hasTenantId) {
        throw Exception('Person-ID oder Tenant-ID fehlt');
      }

      final localAdditional = await _splitAndSaveSharedFields();

      await repo.updatePlayerFields(personId, {
        'firstName': _draft.firstName,
        'lastName': _draft.lastName,
        'phone': _draft.phone?.isEmpty ?? true ? null : _draft.phone,
        'notes': _draft.notes?.isEmpty ?? true ? null : _draft.notes,
        'otherExercise': _draft.otherExercise?.isEmpty ?? true ? null : _draft.otherExercise,
        'instrument': _selectedGroupId,
        'birthday': _draft.birthday,
        'playsSince': _draft.playsSince,
        'joined': _draft.joined,
        'isLeader': _isLeader,
        'hasTeacher': _hasTeacher,
        'teacher': _hasTeacher ? _selectedTeacherId : null,
        'shift_id': _selectedShiftId,
        'shift_name': _selectedShiftName,
        'shift_start': _shiftStart?.toIso8601String(),
        'parent_id': _selectedParentId,
        'correctBirthday': true,
        'history': updatedHistory,
        'additional_fields': localAdditional.isNotEmpty ? localAdditional : null,
        'otherOrchestras': _draft.otherOrchestras,
        'range': _draft.range?.isEmpty ?? true ? null : _draft.range,
        'instruments': _draft.instruments?.isEmpty ?? true ? null : _draft.instruments,
        'examinee': _draft.examinee,
        'testResult': _draft.testResult?.isEmpty ?? true ? null : _draft.testResult,
        'email': _draft.email?.isEmpty ?? true ? null : _draft.email,
      });
      ref.read(trackingServiceProvider).track(TrackingEvent.playerUpdated);

      // STATS_PEOPLE_FIXES: role sync (main group / voice leader) and
      // shared identity propagation (global_person_id)
      await _syncRolesAfterSave(
        isGeneral: isGeneral,
        assignVoiceLeaderRole: assignVoiceLeaderRole,
      );
      await _propagateSharedIdentityFields();

      // Ionic syncPlayerWithUpcomingAttendancesByAdditionalFields
      try {
        await repo.syncPlayerWithUpcomingAttendances(
          person.copyWith(
            instrument: _selectedGroupId,
            additionalFields: _additionalFieldValues,
          ),
          oldInstrument: _selectedGroupId,
          oldAdditionalFields: person.additionalFields,
        );
      } catch (_) {}

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      setState(() {
        _hasChanges = false;
        _changedFields.clear();
      });

      if (createAccountAfterSave && mounted) {
        await _createAccount(
          widget.person.copyWith(
            email: _draft.email?.trim(),
            instrument: _selectedGroupId,
          ),
          confirm: false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Änderungen gespeichert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ---------------------------------------------------------------------
  // STATS_PEOPLE_FIXES helpers
  // ---------------------------------------------------------------------

  bool get _isMainGroupSelected {
    final main = ref.read(mainGroupProvider).valueOrNull;
    return main?.id != null && main!.id == _selectedGroupId;
  }

  /// Ionic: person.enableVoiceLeader alert. Returns true = save with role,
  /// false = status only, null = cancel.
  Future<bool?> _showVoiceLeaderDialog() {
    final name = '${_draft.firstName} ${_draft.lastName}';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stimmführer aktivieren'),
        content: Text(
          'Mit der Stimmführer-Rolle kann $name die Kontaktdaten und '
          'anstehenden Termine aller Personen in der Stimme einsehen. '
          'Soll die Rolle vergeben werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nur Stimmführer-Status'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mit Rolle speichern'),
          ),
        ],
      ),
    );
  }

  /// Ionic continueUpdatingPlayer(): main group ⇄ responsible role and
  /// voice leader role assignment/removal.
  Future<void> _syncRolesAfterSave({
    required bool isGeneral,
    required bool assignVoiceLeaderRole,
  }) async {
    final appId = widget.person.appId;
    final tenantId = ref.read(currentTenantIdProvider);
    if (appId == null || tenantId == null) return;
    final auth = ref.read(authServiceProvider);

    try {
      final mainId = (await ref.read(mainGroupProvider.future))?.id;
      final oldGroup = widget.person.instrument;
      if (mainId != null &&
          ((oldGroup != _selectedGroupId && _selectedGroupId == mainId) ||
              oldGroup == mainId)) {
        final role = await auth.getUserRole(userId: appId, tenantId: tenantId);
        if (role != Role.admin) {
          await auth.updateUserRole(
            userId: appId,
            tenantId: tenantId,
            newRole: _selectedGroupId == mainId ? Role.responsible : Role.player,
          );
        }
      }

      if (!isGeneral) {
        if (assignVoiceLeaderRole) {
          final role = await auth.getUserRole(userId: appId, tenantId: tenantId);
          await auth.updateUserRole(
            userId: appId,
            tenantId: tenantId,
            newRole: role == Role.helper
                ? Role.voiceLeaderHelper
                : Role.voiceLeader,
          );
        } else if (widget.person.isLeader && !_isLeader) {
          final role = await auth.getUserRole(userId: appId, tenantId: tenantId);
          if (role == Role.voiceLeader) {
            await auth.updateUserRole(
                userId: appId, tenantId: tenantId, newRole: Role.player);
          } else if (role == Role.voiceLeaderHelper) {
            await auth.updateUserRole(
                userId: appId, tenantId: tenantId, newRole: Role.helper);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rolle konnte nicht angepasst werden: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
    await _loadUserRole();
  }

  /// Ionic player.service updatePlayer(): propagate shared identity fields
  /// to all rows with the same global_person_id in linked tenants.
  Future<void> _propagateSharedIdentityFields() async {
    final globalId = widget.person.globalPersonId;
    final personId = widget.person.id;
    if (globalId == null || globalId.isEmpty || personId == null) return;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      await ref
          .read(crossTenantPersonRepositoryWithTenantProvider)
          .propagateSharedFields(
            globalPersonId: globalId,
            excludePlayerId: personId,
            linkedTenantIds: linkedIds,
            fields: {
              'firstName': _draft.firstName,
              'lastName': _draft.lastName,
              'birthday': _draft.birthday,
              'email': _draft.email?.isEmpty ?? true ? null : _draft.email,
              'phone': _draft.phone?.isEmpty ?? true ? null : _draft.phone,
            },
          );
    } catch (_) {
      // Non-critical: the person itself was saved
    }
  }

  /// Email edits trigger a cross-tenant lookup (Ionic onEmailBlur).
  void _onAccountFieldChanged(String field, dynamic value) {
    _onFieldChanged(field, value);
    if (field == 'email' && value is String && value.trim().isNotEmpty) {
      _lookupEmailInOtherInstances(value.trim());
    }
  }

  Future<void> _lookupEmailInOtherInstances(String email) async {
    if (emailsMatch(email, widget.person.email)) return;
    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await ref
          .read(crossTenantPersonRepositoryWithTenantProvider)
          .getPossiblePersonsByEmail(email, linkedTenantIds: linkedIds);
    } catch (_) {
      return;
    }
    matches = matches.where((m) => m.person.id != widget.person.id).toList();
    if (matches.isEmpty || !mounted) return;
    final chosen = await showEmailTakenDialog(context, matches);
    if (chosen == null || !mounted) return;

    // Ionic applyMatchedPerson()
    final p = chosen.person;
    _onFieldChanged('firstName', p.firstName);
    _onFieldChanged('lastName', p.lastName);
    _onFieldChanged('email', p.email);
    if (p.correctBirthday && p.birthday != null) {
      _onFieldChanged('birthday', p.birthday);
    }
    if (p.otherExercise != null) _onFieldChanged('otherExercise', p.otherExercise);
    if (p.range != null) _onFieldChanged('range', p.range);
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.name == chosen.groupName).firstOrNull;
    if (group?.id != null) _onFieldChanged('instrument', group!.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Die Daten wurden erfolgreich übernommen'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// Ionic searchPerson(): find this person in a linked tenant, adopt the
  /// email and link both rows via a shared global_person_id.
  Future<void> _searchPersonInOtherInstance() async {
    final person = widget.person;
    final personId = person.id;
    if (personId == null) return;
    final linkedIds = await ref.read(linkedTenantIdsProvider.future);
    final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final matches = await repo.getPossiblePersonsByName(
      _draft.firstName,
      _draft.lastName,
      linkedTenantIds: linkedIds,
    );
    if (!mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Es wurde keine passende Person in einer anderen Instanz gefunden'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<CrossTenantPersonCandidate>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Eintrag auswählen',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final m in matches)
              ListTile(
                leading: const Icon(Icons.person_search),
                title: Text(m.candidate.label),
                subtitle: Text(m.reason),
                onTap: () => Navigator.pop(ctx, m.candidate),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final email = chosen.person.email?.trim();
    if (email == null || email.isEmpty) return;

    try {
      final globalId = chosen.person.globalPersonId ?? const Uuid().v4();
      await ref
          .read(playerRepositoryWithTenantProvider)
          .updatePlayerFields(personId, {
        'email': email,
        'global_person_id': globalId,
      });
      if (chosen.person.globalPersonId == null && chosen.person.id != null) {
        await repo.setGlobalPersonId([chosen.person.id!], globalId,
            linkedTenantIds: linkedIds);
      }
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die E-Mail Adresse wurde erfolgreich aktualisiert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  /// Ionic assignMyAccount(): link the current user to this person.
  Future<void> _assignMyAccount() async {
    final personId = widget.person.id;
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (personId == null || user == null) return;
    final tenantUser = await ref.read(currentTenantUserProvider.future);
    final email = tenantUser?.email ?? user.email;
    try {
      await ref
          .read(playerRepositoryWithTenantProvider)
          .updatePlayerFields(personId, {
        'appId': user.id,
        'email': email,
      });
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Benutzer wurde erfolgreich zugewiesen'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showPauseDialog() async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Berechtigung zum Pausieren'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    // PEOPLE2: Ionic confirmPause incl. "Pausiert ab" and other instances
    final paused = await pausePersonFlow(context, ref, widget.person);
    if (paused) {
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
    }
  }

  Future<void> _unpausePerson() async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Berechtigung zum Reaktivieren'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final repository = ref.read(playerRepositoryWithTenantProvider);
    final person = widget.person;

    try {
      await repository.unpausePlayer(person, historyText: 'Person wieder aktiv');

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Person wurde reaktiviert'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showArchiveDialog() async {
    final noteController = TextEditingController();
    DateTime archiveDate = DateTime.now();

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Person archivieren'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Austrittsdatum'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(archiveDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: archiveDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() => archiveDate = date);
                    }
                  },
                ),
                const SizedBox(height: AppDimensions.paddingM),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Grund (optional)',
                    hintText: 'Warum verlässt die Person?',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.pop(context, {'date': archiveDate.toIso8601String(), 'note': noteController.text});
                },
                child: const Text('Archivieren'),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        await _archivePerson(result['date'], result['note']);
      }
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _archivePerson(String date, String note) async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Berechtigung zum Archivieren'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final repository = ref.read(playerRepositoryWithTenantProvider);
    final person = widget.person;

    try {
      await repository.archivePlayer(person, date, note.isNotEmpty ? note : null);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Person wurde archiviert'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _resetLateCount() async {
    final notifier = ref.read(playerNotifierProvider.notifier);
    final person = widget.person;

    try {
      await notifier.resetLateCount(person);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(personAttendanceStatsProvider(widget.personId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verspätungen zurückgesetzt'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _resolveProblem() async {
    if (!_problemSolved) return;

    final notifier = ref.read(playerNotifierProvider.notifier);
    final person = widget.person;

    try {
      await notifier.resolveCritical(person, _problemNotes.isNotEmpty ? _problemNotes : null);

      ref.invalidate(personProvider(widget.personId));

      if (mounted) {
        setState(() {
          _problemSolved = false;
          _problemNotes = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problemfall gelöst'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _approvePerson() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Person genehmigen?'),
        content: Text('${widget.person.fullName} als Mitglied freischalten?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Genehmigen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final notifier = ref.read(playerNotifierProvider.notifier);
      await notifier.approvePlayer(widget.person);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Person wurde genehmigt'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _declinePerson() async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Person ablehnen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.person.fullName} wird abgelehnt und archiviert.'),
              const SizedBox(height: AppDimensions.paddingM),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Grund *',
                  hintText: 'Warum wird die Person abgelehnt?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                if (reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bitte Grund angeben')),
                  );
                  return;
                }
                Navigator.pop(context, reasonController.text);
              },
              child: const Text('Ablehnen'),
            ),
          ],
        ),
      );

      if (reason == null || !mounted) return;

      final notifier = ref.read(playerNotifierProvider.notifier);
      await notifier.declinePlayer(widget.person, reason);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Person wurde abgelehnt'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  void _showPendingActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.success),
              title: const Text('Person genehmigen'),
              onTap: () { Navigator.pop(context); _approvePerson(); },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: AppColors.danger),
              title: const Text('Person ablehnen'),
              onTap: () { Navigator.pop(context); _declinePerson(); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Ionic person.page openMoreMenu (action sheet, same option order):
  /// Meinen Benutzer zuweisen, Wieder aktivieren / Pausieren, In andere
  /// Instanz übertragen / kopieren, Archivieren, Entfernen, Abbrechen.
  void _showMoreActions() {
    final role = ref.read(currentRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isSelf = widget.person.appId != null && widget.person.appId == userId;

    Widget option(String text, VoidCallback onTap, {bool destructive = false}) {
      return ListTile(
        title: Text(
          text,
          textAlign: TextAlign.center,
          style: destructive ? const TextStyle(color: AppColors.danger) : null,
        ),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.person.appId == null && isAdmin)
                option('Meinen Benutzer zuweisen', _assignMyAccount),
              if (widget.person.paused)
                option('Wieder aktivieren', _unpausePerson)
              else
                option('Pausieren', _showPauseDialog),
              option('In andere Instanz übertragen', _showTransferSheet),
              option('In andere Instanz kopieren',
                  () => _showTransferSheet(copy: true)),
              option('Archivieren', _showArchiveDialog, destructive: true),
              if (!isSelf && isAdmin)
                option('Entfernen', _showDeleteDialog, destructive: true),
              const Divider(height: 1),
              ListTile(
                title: const Text(
                  'Abbrechen',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransferSheet({bool copy = false}) async {
    final result = await showHandoverSheet(
      context,
      selectedPlayers: [widget.person],
      initialStayInInstance: copy,
    );

    if (result == true && mounted) {
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
    }
  }

  /// Ionic: alert "Person entfernen" → Abbrechen / Ja.
  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Person entfernen'),
        content: const Text(
          'Möchtest du die Person wirklich entfernen? Alle zugehörigen Daten '
          '(Abwesenheiten, Notizen, etc.) gehen dabei verloren!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(playerNotifierProvider.notifier).deletePlayer(widget.personId);
      if (mounted) {
        ToastHelper.showSuccess(context, 'Die Person wurde erfolgreich entfernt');
        context.pop();
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    }
  }

  Future<void> _updateUserRole(Role newRole) async {
    final currentUserRole = ref.read(currentRoleProvider);
    if (!currentUserRole.isConductor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Berechtigung zum Ändern von Rollen'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final supabase = ref.read(supabaseClientProvider);
    final tenant = ref.read(currentTenantProvider);
    final appId = widget.person.appId;
    final tenantId = tenant?.id;

    if (appId == null || tenantId == null) return;

    try {
      await supabase
          .from('tenantUsers')
          .update({'role': newRole.value})
          .eq('userId', appId)
          .eq('tenantId', tenantId);

      if (mounted) {
        setState(() => _userRole = newRole);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rolle geändert'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _unlinkAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account-Verknüpfung aufheben?'),
        content: Text(
          'Die Account-Verknüpfung für ${widget.person.fullName} wird aufgehoben. '
          'Die Person kann sich dann nicht mehr in der App anmelden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verknüpfung aufheben'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final currentUserRole = ref.read(currentRoleProvider);
    if (!currentUserRole.isConductor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Berechtigung zum Aufheben von Account-Verknüpfungen'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final notifier = ref.read(playerNotifierProvider.notifier);
    final tenant = ref.read(currentTenantProvider);
    final person = widget.person;

    try {
      await notifier.unlinkAccount(person);

      if (person.appId != null && tenant?.id != null) {
        final supabase = ref.read(supabaseClientProvider);
        await supabase
            .from('tenantUsers')
            .delete()
            .eq('userId', person.appId!)
            .eq('tenantId', tenant!.id!);
      }

      ref.invalidate(personProvider(widget.personId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account-Verknüpfung aufgehoben'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _createAccount(Person person, {bool confirm = true}) async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.isConductor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Berechtigung zum Erstellen von Accounts'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (person.email == null || person.email!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine E-Mail-Adresse vorhanden'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final confirmed = !confirm ? true : await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account erstellen?'),
        content: Text(
          'Für ${person.fullName} wird ein Account mit der E-Mail '
          '${person.email} erstellt. Die Person erhält eine E-Mail '
          'zum Setzen des Passworts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Account erstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // AUTH: server-side account creation (attendix-user Edge Function);
      // role RESPONSIBLE for main-group members, otherwise PLAYER (Ionic).
      await ref
          .read(accountCreationNotifierProvider.notifier)
          .createAccount(person);

      ref.invalidate(personProvider(widget.personId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account erstellt. Passwort-E-Mail wurde gesendet.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${person.firstName} ${person.lastName} - Fehler beim Erstellen des Accounts: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = _draft;
    final statsAsync = ref.watch(personAttendanceStatsProvider(widget.personId));
    final historyAsync = ref.watch(personHistoryProvider(widget.personId));
    final canEdit = ref.watch(currentRoleProvider).canEdit;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Änderungen verwerfen?'),
            content: const Text('Du hast ungespeicherte Änderungen. Möchtest du diese verwerfen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verwerfen')),
            ],
          ),
        );
        if (shouldDiscard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        // Ionic person.page header: "Person bearbeiten" / "Person genehmigen",
        // red toolbar for Problemfälle; actions live in the FAB.
        appBar: AppBar(
          title: canEdit
              ? Text(widget.person.pending
                  ? 'Person genehmigen'
                  : 'Person bearbeiten')
              : null,
          backgroundColor: person.isCritical ? AppColors.danger : null,
          foregroundColor: person.isCritical ? Colors.white : null,
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Header with avatar and stats
            PersonHeader(person: person, statsAsync: statsAsync, canEdit: canEdit),

            // Status badges
            PersonStatusBadges(person: person),

            // PEOPLE2: duplicate candidates + merge for pending registrations
            if (widget.person.pending && canEdit)
              DuplicateCandidatesCard(
                person: widget.person,
                onMerged: () {
                  ref.invalidate(realtimePlayersProvider);
                  ref.invalidate(pendingPlayersProvider);
                  if (mounted) context.pop();
                },
              ),

            // Problem Person Accordion
            ProblemfallAccordion(
              person: person,
              isExpanded: _showProblemfall,
              onToggle: () => setState(() => _showProblemfall = !_showProblemfall),
              problemSolved: _problemSolved,
              onProblemSolvedChanged: (v) => setState(() => _problemSolved = v),
              problemNotes: _problemNotes,
              onProblemNotesChanged: (v) => _problemNotes = v,
              onResolveProblem: _resolveProblem,
            ),

            // Late Warning Card
            LateWarningCard(
              person: person,
              statsAsync: statsAsync,
              onResetLateCount: _resetLateCount,
            ),

            // Allgemein Accordion with inline editing
            AllgemeinAccordion(
              person: person,
              isExpanded: _showAllgemein,
              onToggle: () => setState(() => _showAllgemein = !_showAllgemein),
              onFieldChanged: _onFieldChanged,
              canEdit: canEdit,
              selectedGroupId: _selectedGroupId,
              selectedTeacherId: _selectedTeacherId,
              selectedShiftId: _selectedShiftId,
              selectedShiftName: _selectedShiftName,
              shiftStart: _shiftStart,
              selectedParentId: _selectedParentId,
              isLeader: _isLeader,
              hasTeacher: _hasTeacher,
              additionalFieldValues: _additionalFieldValues,
              isMainGroup: _isMainGroupSelected,
              otherOrchestras: _draft.otherOrchestras,
            ),

            // Account Accordion
            AccountAccordion(
              person: person,
              isExpanded: _showAccount,
              onToggle: () => setState(() => _showAccount = !_showAccount),
              userRole: _userRole,
              isLoadingRole: _isLoadingRole,
              onRoleChanged: _updateUserRole,
              onUnlinkAccount: _unlinkAccount,
              onCreateAccount: () => _createAccount(person),
              canEdit: canEdit,
              onFieldChanged: _onAccountFieldChanged,
              draftEmail: _draft.email,
              isLeader: _isLeader,
              isMainGroup: _isMainGroupSelected,
              onSearchOtherInstance: _searchPersonInOtherInstance,
            ),

            // Ionic order: Andere Instanzen after Allgemein. Other Tenants Accordion (only if person has an account)
            if (widget.person.appId != null)
              AndereInstanzenAccordion(appId: widget.person.appId!),

            // Historie Accordion
            HistorieAccordion(
              isExpanded: _showHistorie,
              onToggle: () => setState(() => _showHistorie = !_showHistorie),
              historyAsync: historyAsync,
              statsAsync: statsAsync,
              personId: widget.personId,
              canEdit: canEdit,
            ),

            // Upcoming Appointments Accordion
            UpcomingAppointmentsAccordion(personId: widget.personId),

            // PEOPLE_IMPORT: Planned absences (Ionic person.page "Abwesenheiten")
            if (canEdit) PlannedAbsencesAccordion(personId: widget.personId),
            // DUTY: "Regelmäßig verhindert" (only when the tenant uses the Dienstplan)
            if (canEdit && ref.watch(hasDutyTypesProvider))
              Card(
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
                child: ListTile(
                  leading: const Icon(Icons.event_busy_outlined, color: AppColors.primary),
                  title: const Text('Regelmäßig verhindert', style: TextStyle(color: AppColors.primary)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openUnavailabilityPage(
                    context,
                    personId: widget.personId,
                    personName: person.fullName,
                    forOther: true,
                  ),
                ),
              ),

          ],
        ),
        // Ionic FAB: save (changes) / approve sheet (pending) / key (create
        // account when e-mail but no account) / "..." more menu.
        floatingActionButton: _hasChanges
            ? FloatingActionButton(
                onPressed: _isSaving ? null : _saveChanges,
                tooltip: 'Speichern',
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
              )
            : !canEdit
                ? null
                : widget.person.pending
                    ? FloatingActionButton(
                        onPressed: _showPendingActions,
                        child: const Icon(Icons.more_horiz),
                      )
                    : person.appId == null &&
                            (person.email?.isNotEmpty ?? false)
                        ? FloatingActionButton(
                            onPressed: () => _createAccount(person),
                            tooltip: 'Account erstellen',
                            child: const Icon(Icons.key_outlined),
                          )
                        : FloatingActionButton(
                            onPressed: _showMoreActions,
                            tooltip: 'Mehr',
                            child: const Icon(Icons.more_horiz),
                          ),
      ),
    );
  }
}
