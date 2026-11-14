import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../../data/models/tenant/tenant.dart' show ExtraField;
import '../../../../data/services/auth_service.dart';
import '../widgets/planned_absences.dart';
import '../../../duty/presentation/pages/unavailability_page.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/utils/text_utils.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../widgets/person_match_suggestions.dart';
import '../widgets/person_transfer_sheet.dart';
import '../widgets/pause_person_sheet.dart';
import '../widgets/archive_person_modal.dart';
import '../widgets/duplicate_candidates_card.dart';
import '../widgets/parent_review_hint.dart';
import '../widgets/person_detail/person_detail.dart';
import '../widgets/ion/ion_widgets.dart';
import 'package:ionicons/ionicons.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../person_stats.dart';
import '../../person_write.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/utils/people_shift_status.dart' show shiftAssignmentChanged;
import '../../../../core/utils/handover_request.dart';
import '../../../../core/utils/parent_registration.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;

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
    // Ionic Utils.getTypeTitle: typeInfo, else the type name unless
    // hide_name; no title without a known type.
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
      // Beta "Verlauf": a tap opens the Termin.
      'attendanceId': attendance?['id'],
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

/// How a person modal ([showPersonModal]) was closed (Ionic PersonPage
/// dismiss data `{ activated }` / `{ approved }`).
enum PersonModalResult {
  /// An archived person was reactivated ("Person reaktivieren").
  activated,

  /// A pending registration was approved.
  approved,

  /// A pending registration was declined.
  declined,
}

/// Ionic settings `openPlayerModal` / `openApprovePersonModal`:
/// `modalController.create({ component: PersonPage, presentingElement })`.
/// On iOS a card modal ([showIosCardModal]), in md mode a regular
/// `ion-modal` ([showIonModal]: full screen on phones, centred card on
/// desktop). Archived persons are read-only with "Person reaktivieren",
/// pending ones offer approve / decline (both follow from the person).
Future<PersonModalResult?> showPersonModal(
    BuildContext context, int personId) {
  // E2E PERSONEN-56: the cached person can be stale (pause / unpause /
  // archive from the list swipe actions or another page don't touch this
  // family) – load it fresh whenever the modal opens, like Ionic opens the
  // page with the current object.
  ProviderScope.containerOf(context, listen: false)
      .invalidate(personProvider(personId));
  Widget build(BuildContext _) =>
      PersonDetailPage(personId: personId, asModal: true);
  if (useIosLook(context)) {
    return showIosCardModal<PersonModalResult>(
      context,
      backgroundColor: ionContentBackground(context),
      builder: build,
    );
  }
  return showIonModal<PersonModalResult>(context, builder: build);
}

/// Person detail page - with inline editing
class PersonDetailPage extends ConsumerWidget {
  const PersonDetailPage(
      {super.key, required this.personId, this.asModal = false});

  final int personId;

  /// Shown via [showPersonModal]: closing pops the modal route (with a
  /// [PersonModalResult]) instead of the go_router page.
  final bool asModal;

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
              Icon(AppIcons.errorOutline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(error))),
              const SizedBox(height: AppDimensions.paddingM),
              IonButton(
                onPressed: () => ref.refresh(personProvider(personId)),
                label: context.l10n.messagesRetry,
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
        return _PersonDetailContent(
            person: person, personId: personId, asModal: asModal);
      },
    );
  }
}

class _PersonDetailContent extends ConsumerStatefulWidget {
  const _PersonDetailContent(
      {required this.person, required this.personId, this.asModal = false});

  final Person person;
  final int personId;
  final bool asModal;

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

  /// db-ad59e983: Ionic person.page aborts when the shared organisation
  /// values cannot be loaded (toast, nothing saved). Saving the shown
  /// tenant/default values would overwrite the real shared values in every
  /// instance of the organisation.
  bool _sharedFieldsLoadFailed = false;

  /// The latest shared-values load; saving waits for it. Older loads
  /// (superseded by a reload) are ignored via [_sharedLoadGeneration].
  Future<void>? _sharedFieldsLoad;
  int _sharedLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initDraft();
    _loadUserRole();
    _sharedFieldsLoad = _loadSharedFieldValues();
    _fillChurchDefaultsWhenLoaded();
  }

  /// Ionic updates `this.player` in place (Passbild, account) or closes the
  /// page after an action. Here the page stays mounted while the person is
  /// reloaded, so take over the new data instead of showing stale values.
  @override
  void didUpdateWidget(covariant _PersonDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.person;
    final next = widget.person;
    if (old == next) return;
    if (!_hasChanges) {
      _initDraft();
      _sharedFieldsLoad = _loadSharedFieldValues();
    } else {
      // Keep the unsaved edits; every field the user did not touch takes
      // over the new value so saving does not write stale data back.
      _rebaseDraft(next);
    }
    if (old.appId != next.appId) {
      _userRole = null;
      _loadUserRole();
    }
  }

  /// Action of the FAB as of the last build.
  VoidCallback? _fabCallback;

  /// A typed date is applied on focus loss, and tapping the FAB keeps the
  /// focus: commit it first, then run the action the FAB shows afterwards
  /// (save once the date counts as a change) (sol review).
  Future<void> _onFabPressed() async {
    if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    _fabCallback?.call();
  }

  /// Draft = [next] plus the fields changed on this page (sol review).
  void _rebaseDraft(Person next) {
    bool keep(String f) => _changedFields.contains(f);
    final d = _draft;
    _draft = next.copyWith(
      firstName: keep('firstName') ? d.firstName : next.firstName,
      lastName: keep('lastName') ? d.lastName : next.lastName,
      notes: keep('notes') ? d.notes : next.notes,
      phone: keep('phone') ? d.phone : next.phone,
      birthday: keep('birthday') ? d.birthday : next.birthday,
      correctBirthday: keep('birthday') ? true : next.correctBirthday,
      playsSince: keep('playsSince') ? d.playsSince : next.playsSince,
      joined: keep('joined') ? d.joined : next.joined,
      img: keep('img') ? d.img : next.img,
      otherExercise: keep('otherExercise') ? d.otherExercise : next.otherExercise,
      range: keep('range') ? d.range : next.range,
      instruments: keep('instruments') ? d.instruments : next.instruments,
      examinee: keep('examinee') ? d.examinee : next.examinee,
      testResult: keep('testResult') ? d.testResult : next.testResult,
      email: keep('email') ? d.email : next.email,
      otherOrchestras: keep('otherOrchestras') ? d.otherOrchestras : next.otherOrchestras,
    );
    if (!keep('instrument')) _selectedGroupId = next.instrument;
    if (!keep('instrument') && !keep('isLeader')) _isLeader = next.isLeader;
    if (!keep('hasTeacher')) _hasTeacher = next.hasTeacher;
    if (!keep('teacher')) _selectedTeacherId = next.teacher;
    if (!keep('shiftId')) _selectedShiftId = next.shiftId;
    if (!keep('shiftName')) _selectedShiftName = next.shiftName;
    if (!keep('shiftStart')) {
      _shiftStart = next.shiftStart != null ? DateTime.tryParse(next.shiftStart!) : null;
    }
    if (!keep('parentId')) _selectedParentId = next.parentId;
    _draft = _draft.copyWith(
      instrument: _selectedGroupId,
      isLeader: _isLeader,
      hasTeacher: _hasTeacher,
      teacher: _selectedTeacherId,
      shiftId: _selectedShiftId,
      shiftName: _selectedShiftName,
      shiftStart: _shiftStart?.toIso8601String(),
      parentId: _selectedParentId,
    );
    final nextExtra = _withExtraDefaults(Map.from(next.additionalFields ?? {}));
    for (final e in nextExtra.entries) {
      if (!_orgFieldIds.contains(e.key) && !keep('additionalFields.${e.key}')) {
        _additionalFieldValues[e.key] = e.value;
      }
    }
  }

  /// Ionic ngOnInit: missing extra field values get
  /// getFieldTypeDefaultValue(type, defaultValue, options, churches); they
  /// are written with the next save (no change marker).
  Map<String, dynamic> _withExtraDefaults(Map<String, dynamic> values) {
    final fields = ref.read(personListExtraFieldsProvider);
    final churchIds = <Object>[
      for (final c in ref.read(churchesProvider).valueOrNull ?? const <Church>[])
        if (c.id != null) c.id!,
    ];
    return {
      ...values,
      for (final f in fields)
        if (values[f.id] == null)
          f.id: extraFieldDefaultValue(
            f.type,
            defaultValue: f.defaultValue,
            options: f.options,
            churchIds: churchIds,
          ),
    };
  }

  /// Gemeinde defaults need the churches; fill them once they are loaded.
  Future<void> _fillChurchDefaultsWhenLoaded() async {
    final fields = ref
        .read(personListExtraFieldsProvider)
        .where((f) => f.type == 'bfecg_church' && f.defaultValue == null)
        .toList();
    if (fields.isEmpty || ref.read(churchesProvider).hasValue) return;
    try {
      final churches = await ref.read(churchesProvider.future);
      final first = churches.where((c) => c.id != null).firstOrNull?.id;
      if (!mounted || first == null) return;
      setState(() {
        for (final f in fields) {
          if (_additionalFieldValues[f.id] == '' &&
              !_changedFields.contains('additionalFields.${f.id}')) {
            _additionalFieldValues[f.id] = first;
          }
        }
      });
    } catch (_) {}
  }

  /// Closes the page: the modal route ([showPersonModal], with [result])
  /// or, opened via its route, the go_router page as before.
  void _close([PersonModalResult? result]) => _closePage(result);

  /// Ionic getOrganisationPersonKey
  String? get _personKey => organisationPersonKey(widget.person);

  /// Ionic getSharedPersonFieldValues: organisation field values are shared
  /// across the tenants of an organisation.
  Future<void> _loadSharedFieldValues() async {
    final generation = ++_sharedLoadGeneration;
    bool current() => mounted && generation == _sharedLoadGeneration;
    final repo = ref.read(profileRepositoryWithTenantProvider);
    try {
      final fields = await ref.read(personExtraFieldsProvider.future);
      if (!current()) return;
      _orgFieldIds = fields
          .where((f) => f.isOrganisationField)
          .map((f) => f.id)
          .toSet();
      if (_orgFieldIds.isEmpty) {
        _sharedFieldsLoadFailed = false;
        return;
      }
      final orgId = await repo.getOrganisationId();
      if (!current()) return;
      _orgId = orgId;
      final key = _personKey;
      if (orgId == null || key == null) {
        _sharedFieldsLoadFailed = false;
        return;
      }
      final shared = await repo.getSharedFieldValues(orgId, key);
      if (!current()) return;
      setState(() {
        _sharedFieldsLoadFailed = false;
        for (final e in shared.entries) {
          if (_orgFieldIds.contains(e.key) &&
              !_changedFields.contains('additionalFields.${e.key}')) {
            _additionalFieldValues[e.key] = e.value;
          }
          // Ionic existingPlayer carries the shared values too (sync diff).
          if (_orgFieldIds.contains(e.key)) _initialAdditionalFields[e.key] = e.value;
        }
      });
    } catch (_) {
      if (!current()) return;
      setState(() => _sharedFieldsLoadFailed = true);
      ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
    }
  }

  /// Waits for the running shared-values load; true (with Ionic's toast)
  /// when it failed, so nothing is saved.
  Future<bool> _blockedBySharedFieldsLoadError() async {
    await _sharedFieldsLoad;
    if (!mounted) return true;
    if (!_sharedFieldsLoadFailed) return false;
    ToastHelper.showError(context, context.l10n.svcLoadSharedFieldsFailed);
    return true;
  }

  /// Ionic continueUpdatingPlayer: organisation field values go to
  /// tenant_group_person_fields, the rest stays in additional_fields.
  Future<Map<String, dynamic>> _splitAndSaveSharedFields() async {
    final repo = ref.read(profileRepositoryWithTenantProvider);
    // A reload may have started or failed since the check before the
    // dialogs: never write shown defaults over unknown shared values.
    await _sharedFieldsLoad;
    if (_sharedFieldsLoadFailed) {
      throw StateError(l10nWithoutContext.svcLoadSharedFieldsFailed);
    }
    return saveSharedPersonFields(
      repo,
      values: _additionalFieldValues,
      orgFieldIds: _orgFieldIds,
      orgId: _orgId,
      personKey: _personKey,
    );
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
    _additionalFieldValues = _withExtraDefaults(Map.from(p.additionalFields ?? {}));
    _initialAdditionalFields = Map.of(_additionalFieldValues);
    _problemSolved = false;
    _problemNotes = '';
  }

  /// Extra field values as loaded (incl. defaults) – Ionic existingPlayer.
  Map<String, dynamic> _initialAdditionalFields = const {};

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
        // Ionic onBirthdayChange: correctBirthday = true right away (the
        // warning colour disappears before saving).
        _draft = _draft.copyWith(birthday: value as String?, correctBirthday: true);
      } else if (field == 'playsSince') {
        _draft = _draft.copyWith(playsSince: value as String?);
      } else if (field == 'joined') {
        _draft = _draft.copyWith(joined: value as String?);
      } else if (field == 'instrument') {
        // Ionic onInstrumentChange(byUser): a moved person is no longer
        // voice leader; saving then downgrades the voice leader role.
        if (value != _selectedGroupId) _isLeader = false;
        _selectedGroupId = value as int?;
        _draft = _draft.copyWith(instrument: value, isLeader: _isLeader);
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
      } else if (field == 'img') {
        _draft = _draft.copyWith(img: value as String?);
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
    if (_isSaving) return;
    // A typed date is applied on focus loss; tapping the FAB keeps the
    // focus, so commit it first (sol review).
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _isSaving || !_hasChanges) return;

    // Validate required fields
    if (_draft.firstName.isEmpty || _draft.lastName.isEmpty) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personEnterNames, beta: LegacySnackBar.danger);
      }
      return;
    }

    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterNoPermissionEdit, beta: LegacySnackBar.danger);
      }
      return;
    }

    // Sol review: lock before waiting for the shared-values load, so a
    // second tap cannot pass the check while the first one waits.
    setState(() => _isSaving = true);
    final blocked = await _blockedBySharedFieldsLoadError();
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (blocked) return;

    // STATS_PEOPLE_FIXES: Ionic updatePlayer() pre-save dialogs
    final tenantType = ref.read(currentTenantProvider)?.type;
    final isGeneral = tenantType == 'general';
    final emailChanged =
        (widget.person.email ?? '') != (_draft.email ?? '');
    final newEmail = _draft.email?.trim() ?? '';
    final emailValid = isValidPersonEmail(newEmail);
    if (newEmail.isNotEmpty && emailChanged && !emailValid) {
      ToastHelper.showError(context, context.l10n.personInvalidEmail, beta: LegacySnackBar.danger);
      return;
    }

    var createAccount = false;
    var assignVoiceLeaderRole = false;
    if (emailChanged && emailValid && widget.person.appId == null) {
      // Ionic updatePlayer(): only "Abbrechen" (nothing saved) and "Ja"
      // (register the account, then save).
      final create = await confirmCreateAccountForNewEmail(context);
      if (!create || !mounted) return;
      createAccount = true;
    } else if (!isGeneral &&
        widget.person.appId != null &&
        !widget.person.isLeader &&
        _isLeader) {
      final choice = await showVoiceLeaderRoleDialog(
          context, '${_draft.firstName} ${_draft.lastName}');
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

      // Build history entries for tracked changes (Ionic order: solved
      // problem case, group change, notes).
      final List<Map<String, dynamic>> newHistoryEntries = [];
      final solved = _problemSolved;
      if (solved) {
        newHistoryEntries.add(personProblemSolvedEntry(_problemNotes));
      }
      if (_selectedGroupId != person.instrument) {
        final groups = await ref.read(groupsMapProvider.future);
        newHistoryEntries.add(
            personGroupChangeEntry(groups, person.instrument, _selectedGroupId));
      }

      if ((_draft.notes ?? '') != (person.notes ?? '')) {
        newHistoryEntries.add(personNotesChangeEntry(person.notes));
      }

      final existingHistory = person.history.map((h) => h.toJson()).toList();
      final updatedHistory = [...existingHistory, ...newHistoryEntries];

      final personId = person.id;
      if (personId == null || !repo.hasTenantId) {
        throw Exception('Person-ID oder Tenant-ID fehlt');
      }

      // Ionic db.updatePlayer(…, createAccount): register first, the row
      // then carries the new appId.
      if (createAccount) {
        await ref.read(accountCreationNotifierProvider.notifier).createAccount(
              person.copyWith(
                email: _draft.email?.trim(),
                instrument: _selectedGroupId,
              ),
            );
      }

      final localAdditional = await _splitAndSaveSharedFields();

      await repo.updatePlayerFields(personId, {
        ..._draftFields(),
        'history': updatedHistory,
        // Ionic writes `additional_fields: localAdditionalFields` ({}).
        'additional_fields': localAdditional,
        if (solved) ...personProblemSolvedColumns(),
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
          oldAdditionalFields: _initialAdditionalFields,
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
      // NACHTEST-A-17 (PERSONEN-84): the teacher list counts and the teacher
      // sheet read playersProvider, not the realtime list – reload it so a
      // new teacher assignment shows up without an app reload.
      ref.invalidate(playersProvider);

      setState(() {
        _hasChanges = false;
        _changedFields.clear();
      });

      // Ionic: dismiss the page, then toast "Person aktualisiert".
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personUpdated);
        _closePage();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.personUpdateFailedWith(friendlyErrorMessage(e)),
          beta: LegacySnackBar.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Editable person columns of the draft (Ionic writes the whole player).
  Map<String, dynamic> _draftFields() => {
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
        // Ionic keeps the teacher when "Hat Lehrer" is switched off.
        'teacher': _selectedTeacherId,
        'shift_id': _selectedShiftId,
        'shift_name': _selectedShiftName,
        'shift_start': _shiftStart?.toIso8601String(),
        'parent_id': _selectedParentId,
        // LOGIC_PEOPLE: Ionic sets correctBirthday only when the birthday
        // was edited (onBirthdayChange / manual input).
        'correctBirthday':
            _changedFields.contains('birthday') || widget.person.correctBirthday,
        'otherOrchestras': _draft.otherOrchestras,
        'range': _draft.range?.isEmpty ?? true ? null : _draft.range,
        'instruments': _draft.instruments?.isEmpty ?? true ? null : _draft.instruments,
        'examinee': _draft.examinee,
        'testResult': _draft.testResult?.isEmpty ?? true ? null : _draft.testResult,
        'email': _draft.email?.isEmpty ?? true ? null : _draft.email,
        // No img: like Ionic (pickPersonFields) an adopted picture of an
        // e-mail match is only a preview; uploads/removals write it directly.
      };

  /// Ionic dismisses the person modal after save / account / pause actions.
  bool _closing = false;

  void _closePage([PersonModalResult? result]) {
    if (!mounted || _closing) return;
    _closing = true;
    setState(() => _hasChanges = false);
    if (widget.asModal) {
      Navigator.of(context).pop(result);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/people');
    }
  }

  // ---------------------------------------------------------------------
  // STATS_PEOPLE_FIXES helpers
  // ---------------------------------------------------------------------

  bool get _isMainGroupSelected {
    final main = ref.read(mainGroupProvider).valueOrNull;
    return main?.id != null && main!.id == _selectedGroupId;
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
      await syncPersonRoles(
        auth,
        appId: appId,
        tenantId: tenantId,
        mainGroupId: (await mainGroupFuture)?.id,
        oldGroupId: widget.person.instrument,
        newGroupId: _selectedGroupId,
        wasLeader: widget.person.isLeader,
        isLeader: _isLeader,
        isGeneral: isGeneral,
        assignVoiceLeaderRole: assignVoiceLeaderRole,
      );
    } catch (e) {
      if (mounted) {
        ToastHelper.showWarning(
          context,
          context.l10n.personFlutterRoleUpdateFailed(friendlyErrorMessage(e)),
          beta: LegacySnackBar.warning,
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
      // Ionic getPossiblePersonsByEmail: error toast.
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
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
    // Ionic takes the picture and otherExercise/range even when empty. The
    // picture is only shown until closing (never saved, see _draftFields).
    _onFieldChanged('img', p.img);
    _onFieldChanged('otherExercise', p.otherExercise);
    _onFieldChanged('range', p.range);
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.name == chosen.groupName).firstOrNull;
    if (group?.id != null) _onFieldChanged('instrument', group!.id);
    ToastHelper.showSuccess(context, context.l10n.personDataTaken, beta: LegacySnackBar.success);
  }

  /// Ionic searchPerson(): find this person in a linked tenant, adopt the
  /// email and link both rows via a shared global_person_id.
  Future<void> _searchPersonInOtherInstance() async {
    try {
      final linked = await searchPersonInOtherInstance(
        context,
        ref,
        widget.person,
        firstName: _draft.firstName,
        lastName: _draft.lastName,
        onNoMatch: () => ToastHelper.showError(context, context.l10n.personNoMatchOther, beta: LegacySnackBar.danger),
      );
      if (!linked) return;
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personEmailUpdated, beta: LegacySnackBar.success);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)),
          beta: LegacySnackBar.danger,
        );
      }
    }
  }

  /// Ionic assignMyAccount(): link the current user to this person via the
  /// normal account creation (`db.createAccount({...player, email: me.email})`).
  /// Role (Verantwortlicher/Spieler) and the "already linked" check come from
  /// [UserRegistrationRepository.createPlayerAccount]; only `appId` is written.
  Future<void> _assignMyAccount() async {
    final person = widget.person;
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (person.id == null || user == null) return;
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      final email = tenantUser?.email ?? user.email;
      await ref
          .read(accountCreationNotifierProvider.notifier)
          .createAccount(person.copyWith(email: email));
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
      ref.invalidate(currentTenantUserProvider);
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personUserAssigned, beta: LegacySnackBar.success);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, friendlyErrorMessage(e), beta: LegacySnackBar.danger);
      }
    }
  }

  Future<void> _showPauseDialog() async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      ToastHelper.showError(context, context.l10n.personFlutterNoPermissionPause, beta: LegacySnackBar.danger);
      return;
    }
    // PEOPLE2: Ionic confirmPause incl. "Pausiert ab" and other instances
    final paused = await pausePersonFlow(context, ref, widget.person,
        showSuccessToast: false);
    if (paused && mounted) {
      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);
      _closePage(); // Ionic: dismiss, no toast
    }
  }

  Future<void> _unpausePerson() async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterNoPermissionReactivate, beta: LegacySnackBar.danger);
      }
      return;
    }

    final repository = ref.read(playerRepositoryWithTenantProvider);
    final person = widget.person;

    try {
      await repository.unpausePlayer(person, historyText: context.l10n.peopleActiveAgain);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      // Ionic openMoreMenu "Wieder aktivieren": dismiss, no toast.
      _closePage();
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)),
          beta: LegacySnackBar.danger,
        );
      }
    }
  }

  /// Ionic archive modal (full screen, "{Name} Archivieren", X, FAB).
  Future<void> _showArchiveDialog() async {
    final result = await showArchivePersonModal(context, widget.person.fullName);
    if (result != null && mounted) {
      await _archivePerson(result.date, result.note);
    }
  }

  Future<void> _archivePerson(String date, String note) async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.canEdit) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterNoPermissionArchive, beta: LegacySnackBar.danger);
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
        ToastHelper.showSuccess(context, context.l10n.personArchived, beta: LegacySnackBar.success);
        _close();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)),
          beta: LegacySnackBar.danger,
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
        ToastHelper.showSuccess(context, context.l10n.personLateCounterReset, beta: LegacySnackBar.success);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personResetFailed, beta: LegacySnackBar.danger);
      }
    }
  }

  /// Ionic approvePlayer(): no extra confirmation; the edited fields (incl.
  /// a solved problem case) are written together with pending = false.
  Future<void> _approvePerson() async {
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final personId = widget.person.id;
    if (personId == null || !repo.hasTenantId) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (await _blockedBySharedFieldsLoadError()) return;
      final solved = _problemSolved;
      if (_changedFields.isNotEmpty || solved) {
        final localAdditional = await _splitAndSaveSharedFields();
        await repo.updatePlayerFields(personId, {
          ..._draftFields(),
          'additional_fields': localAdditional,
          if (solved) ...{
            'isCritical': false,
            'lastSolve': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }
      await ref.read(playerNotifierProvider.notifier).approvePlayer(
            widget.person.copyWith(
              instrument: _selectedGroupId,
              joined: _draft.joined,
              email: _draft.email,
              additionalFields: _additionalFieldValues,
            ),
          );

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        // Ionic approve/declinePlayer: dismiss, then toast person.updated.
        ToastHelper.showSuccess(context, context.l10n.personUpdated);
        _close(PersonModalResult.approved);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailed);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _declinePerson() async {
    final reasonController = TextEditingController();
    try {
      final reason = await showAppDialog<String>(
        context: context,
        // Ionic declinePlayer: header, subHeader "Gib einen Grund an.",
        // textarea without label; an empty reason shows the message in the
        // alert itself.
        builder: (context) {
          var missing = false;
          return StatefulBuilder(
            builder: (context, setDialogState) => AppAlertDialog(
              title: AppAlertTitle(
                context.l10n.personDeclinePerson,
                subHeader: context.l10n.personGiveReasonShort,
              ),
              content: AppAlertInputGroup(
                message: missing ? Text(context.l10n.signoutGiveReason) : null,
                children: [
                  AppAlertInput(
                    controller: reasonController,
                    textarea: true,
                    autofocus: true,
                  ),
                ],
                beta: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.personGiveReasonShort),
                    if (missing) ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      Text(context.l10n.signoutGiveReason),
                    ],
                    const SizedBox(height: AppDimensions.paddingM),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      minLines: 2,
                      maxLines: 4,
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () {
                    if (reasonController.text.isEmpty) {
                      setDialogState(() => missing = true);
                      return;
                    }
                    Navigator.pop(context, reasonController.text);
                  },
                  child: Text(context.l10n.personDecline),
                ),
              ],
            ),
          );
        },
      );

      if (reason == null || !mounted) return;

      final notifier = ref.read(playerNotifierProvider.notifier);
      await notifier.declinePlayer(widget.person, reason);

      ref.invalidate(personProvider(widget.personId));
      ref.invalidate(realtimePlayersProvider);

      if (mounted) {
        // Ionic approve/declinePlayer: dismiss, then toast person.updated.
        ToastHelper.showSuccess(context, context.l10n.personUpdated);
        _close(PersonModalResult.declined);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUpdateFailed);
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _showPendingActions() async {
    // PEO-15: Ionic action sheet without header and icons, "Abbrechen"
    // with role destructive (the Beta keeps its icons).
    final beta = context.rdSkin != null;
    final action = await showAppActionSheet<VoidCallback>(
      context,
      cancelDestructive: !beta,
      actions: [
        AppActionSheetAction(
          value: _approvePerson,
          icon: beta ? AppIcons.checkCircle : null,
          color: beta ? AppColors.success : null,
          label: context.l10n.personApprovePerson,
        ),
        AppActionSheetAction(
          value: _declinePerson,
          icon: beta ? AppIcons.cancel : null,
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

  /// Ionic transfer modal for this person (target instance + target group).
  /// A transfer (not a copy) closes the person page.
  Future<void> _showTransferSheet({bool copy = false}) async {
    final done = await showPersonTransferSheet(context, widget.person, copy: copy);
    if (!done || !mounted) return;
    ref.invalidate(personProvider(widget.personId));
    ref.invalidate(realtimePlayersProvider);
    if (!copy) _closePage();
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
          // PEO-13: Ionic "Abbrechen" with role destructive.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: appAlertDestructiveStyle(ctx),
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
      _close(PersonModalResult.activated);
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
          // PEO-13: Ionic – "Abbrechen" destructive, "Ja" neutral.
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: appAlertDestructiveStyle(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: context.rdSkin != null
                ? TextButton.styleFrom(foregroundColor: AppColors.danger)
                : null,
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
        _close();
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _updateUserRole(Role newRole) async {
    final currentUserRole = ref.read(currentRoleProvider);
    if (!currentUserRole.isConductor) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterNoPermissionRoles, beta: LegacySnackBar.danger);
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
        ToastHelper.showSuccess(context, context.l10n.personRoleUpdated, beta: LegacySnackBar.success);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)),
          beta: LegacySnackBar.danger,
        );
      }
    }
  }

  Future<void> _unlinkAccount() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        // Ionic removeUserFromTenant alert.
        title: Text(context.l10n.personRemoveAccount),
        content: Text(context.l10n.personRemoveAccountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: appAlertDestructiveStyle(context), // PEO-13
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final currentUserRole = ref.read(currentRoleProvider);
    if (!currentUserRole.isConductor) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterNoPermissionUnlink, beta: LegacySnackBar.danger);
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
        ToastHelper.showSuccess(context, context.l10n.personUserRemoved);
        _closePage();
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.personUserRemoveFailed);
    }
  }

  /// Synchronous lock: a second tap while the account is created is ignored.
  bool _creatingAccount = false;

  Future<void> _createAccount(Person person, {bool confirm = true}) async {
    if (_creatingAccount) return;
    _creatingAccount = true;
    try {
      await _createAccountInner(person, confirm: confirm);
    } finally {
      _creatingAccount = false;
    }
  }

  Future<void> _createAccountInner(Person person, {bool confirm = true}) async {
    final currentRole = ref.read(currentRoleProvider);
    if (!currentRole.isConductor) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.personFlutterNoPermissionCreateAccount,
          beta: LegacySnackBar.danger,
        );
      }
      return;
    }

    if (person.email == null || person.email!.isEmpty) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterNoEmail, beta: LegacySnackBar.danger);
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

      // Ionic register() (key FAB): no confirmation, dismiss the page,
      // toast "Account erstellt".
      if (!confirm) {
        if (mounted) {
          ToastHelper.showSuccess(context, context.l10n.personAccountCreated);
          _closePage();
        }
        return;
      }

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personFlutterAccountCreatedMail, beta: LegacySnackBar.success);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.personFlutterCreateAccountFailed(
            '${person.firstName} ${person.lastName}', e),
          beta: LegacySnackBar.danger,
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
    // Organisation fields can arrive after initState: give them their
    // defaults too, without touching edited values (sol review).
    ref.listen<List<ExtraField>>(personListExtraFieldsProvider, (_, __) {
      final filled = _withExtraDefaults(_additionalFieldValues);
      final added = filled.keys
          .where((k) =>
              !_additionalFieldValues.containsKey(k) &&
              !_changedFields.contains('additionalFields.$k'))
          .toList();
      if (added.isEmpty) return;
      setState(() {
        for (final k in added) {
          _additionalFieldValues[k] = filled[k];
          _initialAdditionalFields = {..._initialAdditionalFields, k: filled[k]};
        }
      });
    });
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
    // Beta-Skin: sections as cards, the FAB's action in the header.
    final rd = context.rdSkin;

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

    // Ionic FAB: save (changes) / approve sheet (pending) / key (create
    // account when e-mail but no account) / "..." more menu.
    final (VoidCallback?, IconData, String?)? fabAction = hasLeft
        ? (isAdmin ? (_activatePerson, AppIcons.undo, context.l10n.personReactivatePerson) : null)
        : canEdit && widget.person.pending
            ? (_showPendingActions, AppIcons.moreHoriz, null)
            : _hasChanges
            ? (_isSaving ? null : _saveChanges, AppIcons.saveOutlined, context.l10n.commonSave)
            : !canEdit
                ? null
                    : person.appId == null && (person.email?.isNotEmpty ?? false)
                        ? (() => _createAccount(person, confirm: false), AppIcons.keyOutlined, context.l10n.personFlutterCreateAccount)
                        : (_showMoreActions, AppIcons.moreHoriz, context.l10n.personFlutterMore);
    _fabCallback = fabAction?.$1;
    final VoidCallback? onFab = fabAction?.$1 == null ? null : _onFabPressed;

    return PopScope(
      // Ionic approve mode does not track changes (no discard prompt).
      canPop: !_hasChanges || widget.person.pending,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showAppDialog<bool>(
          context: context,
          builder: (context) => AppAlertDialog(
            title: Text(context.l10n.personDiscardChanges),
            content: Text(context.l10n.personDiscardChangesMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), style: appAlertDestructiveStyle(context), child: Text(context.l10n.commonCancel)), // PEO-13
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
        backgroundColor: rd?.bg ?? ionContentBackground(context),
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
            if (rd != null && fabAction != null)
              _hasChanges && !widget.person.pending
                  ? TextButton(
                      key: const Key('person_detail_save'),
                      style: person.isCritical ? TextButton.styleFrom(foregroundColor: Colors.white) : null,
                      onPressed: onFab,
                      child: Text(context.l10n.commonSave),
                    )
                  : IconButton(
                      tooltip: fabAction.$3 ?? context.l10n.personFlutterMore,
                      color: person.isCritical ? Colors.white : null,
                      onPressed: onFab,
                      icon: Icon(fabAction.$2),
                    ),
            // PEO-10: Ionic modal close (iOS glass circle); md keeps the
            // white icon on the danger toolbar.
            if (!person.isCritical || useIosLook(context))
              IonCloseButton(onPressed: () => Navigator.of(context).maybePop())
            else
            IconButton(
              tooltip: context.l10n.commonClose,
              icon: Icon(
                AppIcons.close,
                color: person.isCritical ? Colors.white : null,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        body: ListView(
          // PERSONEN-27/81: the FAB floats over the person modal even inside
          // the iOS shell – keep room for it (classic; Beta has no FAB).
          padding: EdgeInsets.only(
              bottom: rd == null
                  ? 16 + 84 + MediaQuery.paddingOf(context).bottom
                  : scrollEndPadding(context, base: 16, fabRoom: 84)),
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
              ...ionBetaGroup(context, [allgemein(AllgemeinPart.names, 'names')], inset: false),
              if (rd == null)
                // PEO-32: Ionic `ion-button expand="block" fill="clear"
                // size="small"` with `checkmark-outline`.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: IonButton(
                    fill: IonButtonFill.clear,
                    small: true,
                    expand: true,
                    icon: AppIcons.check,
                    label: context.l10n.personDone,
                    onPressed: () => setState(() => _editingName = false),
                  ),
                )
              else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: () => setState(() => _editingName = false),
                  icon: Icon(AppIcons.check, size: 18),
                  label: IonButtonLabel(context.l10n.personDone),
                ),
              ),
            ],

            // "Mein Kind" registration: who registered the child and what
            // the approval does with that account (U9, also classic).
            if (widget.person.pending && canEdit)
              if (parentRegistrationOf(widget.person) case final parent?)
                Padding(
                  key: const Key('person-parent-review-hint'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    '${context.l10n.parentRegisterChildOf(parent.fullName)}. '
                    '${parentReviewHint(ref, context.l10n, parent)}',
                    style: IonText.note(context),
                  ),
                ),

            // PEOPLE2: duplicate candidates + merge for pending registrations
            // (never for a child registered by an Elternteil: the merge
            // would move the parent's account onto the existing person).
            // Neither for a handover request of another group: it is taken
            // in or declined as it is.
            if (widget.person.pending &&
                canEdit &&
                parentRegistrationOf(widget.person) == null &&
                handoverRequestOf(widget.person) == null)
              DuplicateCandidatesCard(
                person: widget.person,
                onMerged: () {
                  ref.invalidate(realtimePlayersProvider);
                  ref.invalidate(pendingPlayersProvider);
                  if (mounted) _close();
                },
              ),

            // Ionic: "Notizen" textarea (existingPlayer && isAdmin)
            // (archived persons: shown disabled for admins)
            if (isAdmin) ...ionBetaGroup(context, [allgemein(AllgemeinPart.notes, 'notes')], inset: false),

            // Problem Person Accordion (Ionic: !readOnly && isCritical)
            if (canEdit)
              ProblemfallAccordion(
              person: person,
              isExpanded: _showProblemfall,
              onToggle: () => setState(() => _showProblemfall = !_showProblemfall),
              problemSolved: _problemSolved,
              // Ionic: the toggle marks a change, solved with the save.
              onProblemSolvedChanged: (v) => setState(() {
                _problemSolved = v;
                _hasChanges = v || _changedFields.isNotEmpty;
              }),
              problemNotes: _problemNotes,
              onProblemNotesChanged: (v) => _problemNotes = v,
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
                onEmailTyped: _onFieldChanged,
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

            // Historie Accordion (PEO-31: Ionic renders it only with
            // history entries; the Beta keeps its empty state).
            if (rd != null || (historyAsync.valueOrNull?.isNotEmpty ?? true))
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
                      // PEO-28: Ionic `calendar-clear-outline`.
                      start: Icon(
                          AppIcons.ionic
                              ? Ionicons.calendarClearOutline
                              : AppIcons.eventBusyOutlined,
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
        floatingActionButton: rd != null || fabAction == null
            ? null
            : TabBarFab.wrap(IonFabButton(
                onPressed: onFab,
                tooltip: fabAction.$3,
                icon: fabAction.$2,
              )),
      ),
    );
  }
}
