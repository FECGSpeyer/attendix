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
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
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
import '../widgets/ion/ion_widgets.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../person_stats.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/utils/people_shift_status.dart' show shiftAssignmentChanged;
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

/// Provider for single person with group name
final personProvider =
    FutureProvider.family<Person?, int>((ref, personId) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final groups = await ref.watch(groupsMapProvider.future);

  if (!repo.hasTenantId) return null;

  final person = await repo.getPlayerById(personId);
  if (person == null) return null;

  // Add group name from the groups map
  final groupName = person.instrument != null ? groups[person.instrument] : null;
  return person.copyWith(groupName: groupName);
});

/// Provider for person attendance statistics (Ionic person.page
/// getHistoryInfo: average over `include_in_average` types of the current
/// season, late counts since the last "Gespräch geführt").
final personAttendanceStatsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, personId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final tenant = ref.watch(currentTenantProvider);
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

/// Provider for person history (attendance + player history combined)
final personHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, personId) async {
  final repo = ref.watch(playerRepositoryWithTenantProvider);
  final typeRepo = ref.watch(attendanceTypeRepositoryWithTenantProvider);
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
      final typeName = attType['name']?.toString() ?? '';
      meetingName = (typeInfo != null && typeInfo.isNotEmpty) ? typeInfo : typeName;
    } else {
      meetingName = typeInfo ?? attendance?['type']?.toString() ?? l10nWithoutContext.peopleAttendance;
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

  // Ionic getHistoryInfo: non-admins only see group changes and pauses.
  final role = ref.watch(currentRoleProvider);
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

  // Ionic shows the complete history (no limit).
  return allHistory;
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
        appBar: AppBar(title: Text(context.l10n.tasksPerson)),
        body: const Center(child: AppSpinner()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.tasksPerson)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(error))),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.refresh(personProvider(personId)),
                child: IonButtonLabel(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
      ),
      data: (person) {
        if (person == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.tasksPerson)),
            body: Center(child: Text(context.l10n.personFlutterNotFound)),
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
    final repo = ref.read(profileRepositoryWithTenantProvider);
    try {
      final fields = await ref.read(personExtraFieldsProvider.future);
      _orgFieldIds = fields
          .where((f) => f.isOrganisationField)
          .map((f) => f.id)
          .toSet();
      if (_orgFieldIds.isEmpty) return;
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
    final userRegistrationRepo = ref.read(userRegistrationRepositoryWithTenantProvider);
    final appId = widget.person.appId;
    final tenantId = tenant?.id;

    if (appId == null || tenantId == null) return;

    setState(() => _isLoadingRole = true);
    try {
      var role = await _getUserRole(appId);

      // LOGIC_PEOPLE: Ionic person.page ngOnInit — repair a half-approved
      // account (pending=false but role still APPLICANT) by promoting it to
      // RESPONSIBLE (main group) or PLAYER.
      if (role == Role.applicant && !widget.person.pending) {
        try {
          final mainGroupId = (await ref.read(mainGroupProvider.future))?.id;
          final promoted = mainGroupId != null &&
                  widget.person.instrument == mainGroupId
              ? Role.responsible
              : Role.player;
          await userRegistrationRepo
              .updateTenantUserRole(appId, promoted);
          role = promoted;
        } catch (_) {
          // Leave role as-is; admin can retry via approve or role selector.
        }
      }

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

  Future<Role?> _getUserRole(String userId) async {
    final repo = ref.read(userRegistrationRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return null;
    try {
      return await repo.getTenantUserRole(userId);
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
    final repo = ref.read(playerRepositoryWithTenantProvider);
    // Sol review: capture tenant + main group before the first async gap so
    // role sync after saving can never target a tenant switched to meanwhile.
    final roleTenantId = ref.read(currentTenantIdProvider);
    final mainGroupFuture = ref
        .read(mainGroupProvider.future)
        .then<Group?>((g) => g, onError: (Object _) => null);
    if (_isSaving || !_hasChanges) return;

    // Validate required fields
    if (_draft.firstName.isEmpty || _draft.lastName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personEnterNames),
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
          SnackBar(
            content: Text(context.l10n.personFlutterNoPermissionEdit),
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
        SnackBar(
          content: Text(context.l10n.personInvalidEmail),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    var createAccountAfterSave = false;
    var assignVoiceLeaderRole = false;
    if (emailChanged && emailValid && widget.person.appId == null) {
      final create = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(context.l10n.personEmailAdded),
          content: Text(context.l10n.personCreateAccountNow),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.personFlutterSaveOnly),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.commonYes),
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
      final person = widget.person;

      // Build history entries for tracked changes
      final List<Map<String, dynamic>> newHistoryEntries = [];
      if (_selectedGroupId != person.instrument) {
        final groups = await ref.read(groupsMapProvider.future);
        final oldGroupName = groups[person.instrument] ?? 'Unbekannt';
        final newGroupName = groups[_selectedGroupId] ?? 'Unbekannt';
        newHistoryEntries.add({
          'date': DateTime.now().toUtc().toIso8601String(),
          'text': '$oldGroupName -> $newGroupName',
          'type': PlayerHistoryType.instrumentChange.value,
        });
      }

      if (_draft.notes != (person.notes ?? '')) {
        newHistoryEntries.add({
          'date': DateTime.now().toUtc().toIso8601String(),
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
        // LOGIC_PEOPLE: Ionic sets correctBirthday only when the birthday
        // was edited (onBirthdayChange / manual input).
        'correctBirthday':
            _changedFields.contains('birthday') || person.correctBirthday,
        'history': updatedHistory,
        // Ionic writes `additional_fields: localAdditionalFields` ({}).
        'additional_fields': localAdditional,
        'otherOrchestras': _draft.otherOrchestras,
        'range': _draft.range?.isEmpty ?? true ? null : _draft.range,
        'instruments': _draft.instruments?.isEmpty ?? true ? null : _draft.instruments,
        'examinee': _draft.examinee,
        'testResult': _draft.testResult?.isEmpty ?? true ? null : _draft.testResult,
        'email': _draft.email?.isEmpty ?? true ? null : _draft.email,
      });
      ref.read(trackingServiceProvider).track(TrackingEvent.playerUpdated);

      // STATS_PEOPLE_FIXES: role sync (main group / voice leader).
      // PARITY_A (D1): Ionic updatePlayer only changes this one row - no
      // propagation of identity fields to linked tenants.
      await _syncRolesAfterSave(
        tenantId: roleTenantId,
        mainGroupFuture: mainGroupFuture,
        isGeneral: isGeneral,
        assignVoiceLeaderRole: assignVoiceLeaderRole,
      );

      // Ionic syncPlayerWithUpcomingAttendancesByAdditionalFields
      // DB_REVIEW_REST (M2): Ionic person.page only syncs extra-field
      // filters here; a group change must NOT add/remove future
      // person_attendances (that would drop sign-outs and notes). Passing the
      // new group as "old" group disables the group branch of the sync.
      try {
        await repo.syncPlayerWithUpcomingAttendances(
          person.copyWith(
            instrument: _selectedGroupId,
            additionalFields: _additionalFieldValues,
          ),
          oldInstrument: _selectedGroupId,
          oldAdditionalFields: person.additionalFields,
        );
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'person_detail_page');
      }

      // LOGIC_PEOPLE: Ionic updatePlayer(..., updateShifts) →
      // updateShiftAssignmentsForPerson when the shift plan changed.
      // SOL_FIX4: shift name and start date change the computed shift
      // status too, so any of the three fields triggers the recalculation.
      if (shiftAssignmentChanged(
        oldShiftId: person.shiftId,
        oldShiftName: person.shiftName,
        oldShiftStart: person.shiftStart,
        newShiftId: _selectedShiftId,
        newShiftName: _selectedShiftName,
        newShiftStart: _shiftStart,
      )) {
        await repo.updateShiftAssignmentsForPerson(person.copyWith(
          shiftId: _selectedShiftId,
          shiftName: _selectedShiftName,
          shiftStart: _shiftStart?.toIso8601String(),
        ));
      }

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
          SnackBar(
            content: Text(context.l10n.personUpdated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personUpdateFailedWith(friendlyErrorMessage(e))),
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
    return showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.personEnableVoiceLeader),
        content: Text(context.l10n.personVoiceLeaderMessage(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.personVoiceLeaderStatusOnly),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.personSaveWithRole),
          ),
        ],
      ),
    );
  }

  /// Ionic continueUpdatingPlayer(): main group ⇄ responsible role and
  /// voice leader role assignment/removal.
  Future<void> _syncRolesAfterSave({
    required int? tenantId,
    required Future<Group?> mainGroupFuture,
    required bool isGeneral,
    required bool assignVoiceLeaderRole,
  }) async {
    final appId = widget.person.appId;
    if (appId == null || tenantId == null) return;
    final auth = ref.read(authServiceProvider);

    try {
      final mainId = (await mainGroupFuture)?.id;
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
            content: Text(context.l10n.personFlutterRoleUpdateFailed(friendlyErrorMessage(e))),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
    await _loadUserRole();
  }

  /// Email edits trigger a cross-tenant lookup (Ionic onEmailBlur).
  void _onAccountFieldChanged(String field, dynamic value) {
    _onFieldChanged(field, value);
    if (field == 'email' && value is String && value.trim().isNotEmpty) {
      _lookupEmailInOtherInstances(value.trim());
    }
  }

  Future<void> _lookupEmailInOtherInstances(String email) async {
    final crossTenantPersonRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    if (emailsMatch(email, widget.person.email)) return;
    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await crossTenantPersonRepo
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
      SnackBar(
        content: Text(context.l10n.personDataTaken),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// Ionic searchPerson(): find this person in a linked tenant, adopt the
  /// email and link both rows via a shared global_person_id.
  Future<void> _searchPersonInOtherInstance() async {
    final playerRepo = ref.read(playerRepositoryWithTenantProvider);
    final repo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final person = widget.person;
    final personId = person.id;
    if (personId == null) return;
    final linkedIds = await ref.read(linkedTenantIdsProvider.future);
    final matches = await repo.getPossiblePersonsByName(
      _draft.firstName,
      _draft.lastName,
      linkedTenantIds: linkedIds,
    );
    if (!mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.personNoMatchOther),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final chosen = await showAppActionSheet<CrossTenantPersonCandidate>(
      context,
      title: context.l10n.personChooseEntry,
      actions: [
        for (final m in matches)
          AppActionSheetAction(
            value: m.candidate,
            icon: Icons.person_search,
            label: m.candidate.label,
            subtitle: m.reason,
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    final email = chosen.person.email?.trim();
    if (email == null || email.isEmpty) return;

    try {
      final globalId = chosen.person.globalPersonId ?? const Uuid().v4();
      await playerRepo
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
          SnackBar(
            content: Text(context.l10n.personEmailUpdated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  /// Ionic assignMyAccount(): link the current user to this person.
  Future<void> _assignMyAccount() async {
    final playerRepo = ref.read(playerRepositoryWithTenantProvider);
    final personId = widget.person.id;
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (personId == null || user == null) return;
    final tenantUser = await ref.read(currentTenantUserProvider.future);
    final email = tenantUser?.email ?? user.email;
    try {
      await playerRepo
          .updatePlayerFields(personId, {
        'appId': user.id,
        'email': email,
      });
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personUserAssigned),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showPauseDialog() async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.personFlutterNoPermissionPause),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    // PEOPLE2: Ionic confirmPause incl. "Pausiert ab" and other instances
    final paused = await pausePersonFlow(context, ref, widget.person);
    if (paused && mounted) {
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
    }
  }

  Future<void> _unpausePerson() async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterNoPermissionReactivate),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final repository = ref.read(playerRepositoryWithTenantProvider);
    final person = widget.person;

    try {
      await repository.unpausePlayer(person, historyText: context.l10n.peopleActiveAgain);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.personReactivated), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showArchiveDialog() async {
    final noteController = TextEditingController();
    DateTime archiveDate = DateTime.now();

    try {
      final result = await showAppDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AppAlertDialog(
            title: Text(context.l10n.peopleArchiveTitle(widget.person.fullName)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.peopleLeaveDate),
                  subtitle: Text(DateFormat(dateFmt()).format(archiveDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showAppDatePicker(
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
                  decoration: InputDecoration(
                    labelText: context.l10n.dutyReasonOptional,
                    hintText: context.l10n.personFlutterArchiveReasonHint,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.pop(context, {'date': archiveDate.toIso8601String(), 'note': noteController.text});
                },
                child: Text(context.l10n.peopleArchive),
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
          SnackBar(
            content: Text(context.l10n.personFlutterNoPermissionArchive),
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
          SnackBar(content: Text(context.l10n.personArchived), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
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
          SnackBar(
            content: Text(context.l10n.personLateCounterReset),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.personResetFailed), backgroundColor: AppColors.danger),
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
          SnackBar(
            content: Text(context.l10n.personFlutterProblemSolved),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _approvePerson() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.personFlutterApproveQuestion),
        content: Text(context.l10n.personFlutterApproveMessage(widget.person.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.personFlutterApprove),
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
          SnackBar(
            content: Text(context.l10n.personFlutterApproved),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _declinePerson() async {
    final reasonController = TextEditingController();
    try {
      final reason = await showAppDialog<String>(
        context: context,
        builder: (context) => AppAlertDialog(
          title: Text(context.l10n.personDeclinePerson),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.personFlutterDeclineMessage(widget.person.fullName)),
              const SizedBox(height: AppDimensions.paddingM),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: context.l10n.peopleReasonRequired,
                  hintText: context.l10n.personFlutterDeclineReasonHint,
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
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                if (reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.signoutGiveReason)),
                  );
                  return;
                }
                Navigator.pop(context, reasonController.text);
              },
              child: Text(context.l10n.personDecline),
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
          SnackBar(
            content: Text(context.l10n.personFlutterDeclined),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _showPendingActions() async {
    final action = await showAppActionSheet<VoidCallback>(
      context,
      actions: [
        AppActionSheetAction(
          value: _approvePerson,
          icon: Icons.check_circle,
          color: AppColors.success,
          label: context.l10n.personApprovePerson,
        ),
        AppActionSheetAction(
          value: _declinePerson,
          icon: Icons.cancel,
          label: context.l10n.personDeclinePerson,
          destructive: true,
        ),
      ],
    );
    action?.call();
  }

  /// Ionic person.page openMoreMenu (action sheet, same option order):
  /// Meinen Benutzer zuweisen, Wieder aktivieren / Pausieren, In andere
  /// Instanz übertragen / kopieren, Archivieren, Entfernen, Abbrechen.
  Future<void> _showMoreActions() async {
    // LOGIC_PEOPLE: Ionic shows transfer/copy only `if (this.organisation
    // && this.tenants.length)` (other instances of the organisation).
    var canTransfer = false;
    try {
      final organisation = await ref.read(currentOrganisationProvider.future);
      if (organisation != null) {
        canTransfer = (await ref.read(linkedTenantsProvider.future)).isNotEmpty;
      }
    } catch (_) {
      canTransfer = false;
    }
    if (!mounted) return;

    final role = ref.read(currentRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isSelf = widget.person.appId != null && widget.person.appId == userId;

    AppActionSheetAction<VoidCallback> option(String text, VoidCallback onTap,
            {bool destructive = false}) =>
        AppActionSheetAction(value: onTap, label: text, destructive: destructive);

    // Ionic: header "Aktionen", "Abbrechen" with role destructive.
    final action = await showAppActionSheet<VoidCallback>(
      context,
      title: context.l10n.personActions,
      cancelDestructive: true,
      actions: [
        if (widget.person.appId == null && isAdmin)
          option(context.l10n.personAssignMyUser, _assignMyAccount),
        if (widget.person.paused)
          option(context.l10n.personReactivate, _unpausePerson)
        else
          option(context.l10n.peoplePause, _showPauseDialog),
        if (canTransfer) ...[
          option(context.l10n.personTransferOther, _showTransferSheet),
          option(context.l10n.personCopyOther,
              () => _showTransferSheet(copy: true)),
        ],
        option(context.l10n.peopleArchive, _showArchiveDialog, destructive: true),
        // Ionic: shown whenever the person is not the current user.
        if (!isSelf)
          option(context.l10n.commonRemove, _showDeleteDialog, destructive: true),
      ],
    );
    action?.call();
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
      // Ionic transferPerson: a transfer (not a copy) closes the person page.
      // The sheet can switch between copy and transfer, so look at the
      // result: a transferred person is archived (`left` set).
      final updated = await ref.read(personProvider(widget.personId).future);
      if (mounted && (updated == null || updated.left != null)) context.pop();
    }
  }

  /// Ionic person.page activate(): "Person reaktivieren" for archived
  /// persons → db.activatePlayer, close the page, toast "reaktiviert".
  Future<void> _activatePerson() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.personReactivatePerson),
        content: Text(ctx.l10n.personReactivateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonYes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(playerNotifierProvider.notifier).reactivatePlayer(widget.person);
      ref.invalidate(realtimePlayersProvider);
      // The page reads left/hasLeft from this cache: reopening must show the
      // active person, not the read-only archive view.
      if (widget.person.id != null) ref.invalidate(personProvider(widget.person.id!));
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.personReactivated);
      context.pop();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  /// Ionic: alert "Person entfernen" → Abbrechen / Ja.
  Future<void> _showDeleteDialog() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.attendanceRemovePerson),
        content: Text(context.l10n.personRemovePersonMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(playerNotifierProvider.notifier).deletePlayer(
            widget.personId,
            appId: widget.person.appId,
          );
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personRemoved);
        context.pop();
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _updateUserRole(Role newRole) async {
    final currentUserRole = ref.read(currentRoleProvider);
    if (!currentUserRole.isConductor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterNoPermissionRoles),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final repo = ref.read(userRegistrationRepositoryWithTenantProvider);
    final appId = widget.person.appId;

    if (appId == null || !repo.hasTenantId) return;

    try {
      await repo.updateTenantUserRole(appId, newRole);

      if (mounted) {
        setState(() => _userRole = newRole);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personRoleUpdated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _unlinkAccount() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.personFlutterUnlinkQuestion),
        content: Text(context.l10n.personFlutterUnlinkMessage(widget.person.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.personFlutterUnlink),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final currentUserRole = ref.read(currentRoleProvider);
    if (!currentUserRole.isConductor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterNoPermissionUnlink),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final notifier = ref.read(playerNotifierProvider.notifier);
    final person = widget.person;
    if (DemoGuard.blocked()) return; // DEMO_GUARD

    try {
      // LOGIC_PEOPLE: the repository removes tenant access like Ionic
      // removeUserFromTenant (keeps admins / accounts linked to another
      // active person) and clears email + appId.
      await notifier.unlinkAccount(person);

      ref.invalidate(personProvider(widget.personId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterUnlinked),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _createAccount(Person person, {bool confirm = true}) async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.isConductor) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterNoPermissionCreateAccount),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (person.email == null || person.email!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterNoEmail),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final confirmed = !confirm ? true : await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.personFlutterCreateAccountQuestion),
        content: Text(context.l10n.personFlutterCreateAccountMessage(
            person.fullName, person.email ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.personFlutterCreateAccount),
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
          SnackBar(
            content: Text(context.l10n.personFlutterAccountCreatedMail),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.personFlutterCreateAccountFailed(
                '${person.firstName} ${person.lastName}', e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// UX_PEOPLE: Ionic accordion group "Allgemein / Account / Zusatzfelder /
  /// Andere Instanzen" — only one section open at a time. Allgemein starts
  /// open for read-only viewers (`existingPlayer && !readOnly ? '' : 'more'`).
  bool _sectionTouched = false;
  String? _openSection;
  bool _editingName = false;

  String? _currentSection(bool canEdit) =>
      _sectionTouched ? _openSection : (canEdit ? null : 'general');

  void _toggleSection(String key, bool canEdit) {
    final current = _currentSection(canEdit);
    setState(() {
      _sectionTouched = true;
      _openSection = current == key ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final person = _draft;
    final statsAsync = ref.watch(personAttendanceStatsProvider(widget.personId));
    final historyAsync = ref.watch(personHistoryProvider(widget.personId));
    // Ionic person.page: readOnly = !isAdmin (Admin / Verantwortlicher);
    // archived persons (settings "Ausgetretene", `hasLeft`) are read-only and
    // only offer "Person reaktivieren".
    final role = ref.watch(currentRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final hasLeft = widget.person.left != null;
    final canEdit = isAdmin && !hasLeft;
    final openSection = _currentSection(canEdit);

    AllgemeinAccordion allgemein(AllgemeinPart part, String key) =>
        AllgemeinAccordion(
          part: part,
          person: person,
          isExpanded: openSection == key,
          onToggle: () => _toggleSection(key, canEdit),
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
        );

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showAppDialog<bool>(
          context: context,
          builder: (context) => AppAlertDialog(
            title: Text(context.l10n.personDiscardChanges),
            content: Text(context.l10n.personDiscardChangesMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.commonYes)), // Ionic: Abbrechen / Ja
            ],
          ),
        );
        if (shouldDiscard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        // UX_PEOPLE: Ionic `ion-content.modalBackground` (white / black)
        backgroundColor: ionContentBackground(context),
        // Ionic person.page header: "Person bearbeiten" / "Person genehmigen",
        // red toolbar for Problemfälle, close button at the end; actions
        // live in the FAB.
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: canEdit
              ? Text(widget.person.pending
                  ? context.l10n.personApprovePerson
                  : context.l10n.personEditPerson)
              : null,
          backgroundColor: person.isCritical ? AppColors.danger : null,
          foregroundColor: person.isCritical ? Colors.white : null,
          actions: [
            IconButton(
              tooltip: context.l10n.commonClose,
              icon: Icon(
                Icons.close,
                color: person.isCritical ? Colors.white : null,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 84)),
          children: [
            // Ionic .profile-header: avatar + name with pencil
            PersonHeader(
              person: person,
              statsAsync: statsAsync,
              canEdit: canEdit,
              onEditName: canEdit && !_editingName
                  ? () => setState(() => _editingName = true)
                  : null,
            ),

            // Ionic: Vorname | Nachname inputs while editing the name
            if (canEdit && _editingName) ...[
              allgemein(AllgemeinPart.names, 'names'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: () => setState(() => _editingName = false),
                  icon: const Icon(Icons.check, size: 18),
                  label: IonButtonLabel(context.l10n.personDone),
                ),
              ),
            ],

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

            // Ionic: "Notizen" textarea (existingPlayer && isAdmin)
            if (canEdit) allgemein(AllgemeinPart.notes, 'notes'),

            // Problem Person Accordion (Ionic: !readOnly && isCritical)
            if (canEdit)
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

            // Late Warning Card (Ionic: !readOnly && isAdmin && lateCount >=
            // lateThreshold)
            if (canEdit)
              LateWarningCard(
              person: person,
              statsAsync: statsAsync,
              onResetLateCount: _resetLateCount,
            ),

            // Ionic accordion group: Allgemein, Account, Zusatzfelder,
            // Andere Instanzen (single open)
            allgemein(AllgemeinPart.general, 'general'),

            // Account (!readOnly && !approveMode)
            if (canEdit && !widget.person.pending)
              AccountAccordion(
                person: person,
                isExpanded: openSection == 'account',
                onToggle: () => _toggleSection('account', canEdit),
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

            // Zusatzfelder
            allgemein(AllgemeinPart.extraFields, 'extra'),

            // Andere Instanzen (only if person has an account)
            if (widget.person.appId != null)
              AndereInstanzenAccordion(
                appId: widget.person.appId!,
                isExpanded: openSection == 'otherTenants',
                onToggle: () => _toggleSection('otherTenants', canEdit),
              ),

            // Historie Accordion
            HistorieAccordion(
              isExpanded: _showHistorie,
              onToggle: () => setState(() => _showHistorie = !_showHistorie),
              historyAsync: historyAsync,
              statsAsync: statsAsync,
              personId: widget.personId,
              canEdit: canEdit,
              hasLeft: hasLeft,
            ),

            // Upcoming Appointments Accordion
            UpcomingAppointmentsAccordion(personId: widget.personId),

            // PEOPLE_IMPORT: Planned absences (Ionic person.page "Abwesenheiten")
            // DUTY: "Regelmäßig verhindert" as the last item of that list
            // (only when the tenant uses the Dienstplan)
            if (canEdit)
              PlannedAbsencesAccordion(
                personId: widget.personId,
                extra: [
                  if (ref.watch(hasDutyTypesProvider))
                    IonItem(
                      detail: true,
                      start: const Icon(Icons.event_busy_outlined,
                          color: AppColors.primary),
                      onTap: () => openUnavailabilityPage(
                        context,
                        personId: widget.personId,
                        personName: person.fullName,
                        forOther: true,
                      ),
                      child: Text(
                        context.l10n.signoutRegularlyUnavailable,
                        style: IonText.h2(context)
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
          ],
        ),
        // Ionic FAB: save (changes) / approve sheet (pending) / key (create
        // account when e-mail but no account) / "..." more menu.
        floatingActionButton: TabBarFab.wrap(hasLeft
            ? (isAdmin
                ? IonFabButton(
                    onPressed: _activatePerson,
                    tooltip: context.l10n.personReactivatePerson,
                    icon: Icons.undo,
                  )
                : null)
            : _hasChanges
            ? IonFabButton(
                onPressed: _isSaving ? null : _saveChanges,
                tooltip: context.l10n.commonSave,
                icon: Icons.save_outlined,
              )
            : !canEdit
                ? null
                : widget.person.pending
                    ? IonFabButton(
                        onPressed: _showPendingActions,
                        icon: Icons.more_horiz,
                      )
                    : person.appId == null &&
                            (person.email?.isNotEmpty ?? false)
                        ? IonFabButton(
                            onPressed: () => _createAccount(person),
                            tooltip: context.l10n.personFlutterCreateAccount,
                            icon: Icons.key_outlined,
                          )
                        : IonFabButton(
                            onPressed: _showMoreActions,
                            tooltip: context.l10n.personFlutterMore,
                            icon: Icons.more_horiz,
                          )),
      ),
    );
  }
}
