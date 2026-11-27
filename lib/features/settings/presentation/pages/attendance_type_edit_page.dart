import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../data/models/instrument/instrument.dart' show Group;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../shared/widgets/common/swipe_actions.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../widgets/type_protocol_settings.dart';
import '../widgets/registration_fields_editor.dart';
import '../widgets/type_reminders_editor.dart';
import '../widgets/settings_form_items.dart';
import '../widgets/settings_list.dart' show IonBadge;
import '../../../../core/providers/organisation_providers.dart' show currentOrganisationProvider;
import '../../../../core/providers/plan_providers.dart' show planAttendanceTypesProvider;
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/team_org/team_org.dart' show agendaItemsPlaceholderId;
import '../../../../data/models/plan/plan.dart' show PlanField;
import '../../../planning/presentation/widgets/plan_field_dialogs.dart' show showPlanFieldDialog, PlanSheetAction;
import '../../../planning/presentation/widgets/plan_fields_editor.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/services/web_window.dart' show setUnloadWarning;
import '../../../../core/theme/design_theme.dart';
import '../../../planning/presentation/widgets/plan_widgets.dart';
import '../../data/manage_logic.dart' show RdManageEntry;
import '../../../../core/logic/words.dart';
import '../widgets/manage/manage_entries.dart' show rdManageTitle;
import '../../../attendance/presentation/widgets/event/form_widgets.dart' show RdValueBox;
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;

part 'attendance_type_edit_view.dart';
part 'attendance_type_edit_subpages.dart';
part 'attendance_type_edit_plan_checklist.dart';
part 'attendance_type_edit_sections.dart';


/// Attendance Type Edit Page
class AttendanceTypeEditPage extends ConsumerStatefulWidget {
  final String? typeId;

  const AttendanceTypeEditPage({
    super.key,
    required String this.typeId,
  });

  @override
  ConsumerState<AttendanceTypeEditPage> createState() => _AttendanceTypeEditPageState();
}

class _AttendanceTypeEditPageState extends ConsumerState<AttendanceTypeEditPage> {
  final _nameController = TextEditingController();
  final _durationDaysController = TextEditingController(text: '1');
  final _planningTitleController = TextEditingController();
  final _dutyRequiredController = TextEditingController(text: '1');

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  AttendanceStatus _defaultStatus = AttendanceStatus.present;
  Set<AttendanceStatus> _availableStatuses = {
    AttendanceStatus.neutral,
    AttendanceStatus.present,
    AttendanceStatus.absent,
    AttendanceStatus.excused,
    AttendanceStatus.late,
  };
  bool _manageSongs = false;
  bool _placeEnabled = false;
  List<RegistrationField> _registrationFields = [];
  bool _visible = true;
  bool _highlight = false;
  bool _hideName = false;
  bool _includeInAverage = true;
  String _color = 'primary';
  bool _allDay = false;
  int _durationDays = 1;
  bool _notification = false;
  List<int> _reminders = [];
  List<ChecklistItem> _checklist = [];

  /// Ionic `type.checklist !== null` ("Checkliste aktivieren").
  bool _checklistEnabled = false;
  final _newTodoController = TextEditingController();
  final _customDeadlineController = TextEditingController();

  /// Ionic `newChecklistDeadline`: null = keine, -1 = benutzerdefiniert.
  int? _newTodoDeadline;
  List<Map<String, dynamic>> _planFields = [];

  /// Row identities given only in memory (local uid → stored uid, null =
  /// the row had none); restored before saving. See [_withRowUid].
  final Map<String, String?> _localPlanUids = {};
  String _planningTitle = '';
  bool _planningPrefixInstanceName = false;
  bool _isDefaultOrgPlan = false;
  /// Only write is_default_org_plan when it was loaded, so a failed load
  /// never overwrites a stored `true`.
  bool _isDefaultOrgPlanLoaded = false;

  /// Ionic `end`: computed by calculateEnd() after a change to the plan.
  String? _planEnd;
  List<int> _relevantGroups = [];
  Map<String, dynamic>? _additionalFieldsFilter;
  TypeProtocolSettings _protocol = const TypeProtocolSettings();

  // DUTY: Dienst-Modus (Dienstplan)
  bool _dutyMode = false;
  int _dutyRequired = 1;
  bool _dutySelfSignup = true;
  int? _dutyConfirmReminderDays = 2;

  /// Ionic onDutyToggle sets duty_confirm_reminder_days to 2 only while it
  /// is still `undefined`: a new type whose reminder was never chosen
  /// (field-8aa4fd37). A chosen "Aus" (null) stays.
  bool _dutyReminderDaysUnset = false;
  bool _dutyNotifyUnderstaffed = true;
  int? _dutyUrgentHours;

  bool _isLoading = true;
  bool _hasChanges = false;

  // Live saving for the view (attendance_type_edit_view.dart).
  final _rdTick = ValueNotifier<int>(0);
  Timer? _rdSaveTimer;
  bool _rdSaving = false;
  bool _rdInvalid = false;

  /// What was last loaded or saved, and what last failed. A change is any
  /// difference in the saved data, whichever editor made it (also the
  /// sub-editors and text fields without setState). A failed state
  /// is not retried in a loop; any further change is saved again.
  String? _rdSavedJson;
  String? _rdFailedJson;
  // REDESIGN: the state of the save last put on [_rdChain] (null when none
  // is pending); a change back to the stored state is still saved after it.
  String? _rdQueuedJson;
  bool _rdListening = false;

  /// Saves run one after another, also the flush on dispose, so an older
  /// state never overwrites a newer one.
  Future<void> _rdChain = Future.value();

  /// Captured with the notifier: invalidates the plan and protocol type
  /// lists also when a save ends after the page is gone.
  ProviderContainer? _rdContainer;

  void _rdInvalidateCaches() {
    _rdContainer?.invalidate(protocolTypesProvider);
    _rdContainer?.invalidate(planAttendanceTypesProvider);
  }

  String _rdJson() => jsonEncode(_buildTypeData(), toEncodable: (o) => o.toString());

  /// Captured with the first change: a pending save still runs on dispose.
  AttendanceTypeNotifier? _rdNotifier;

  void _update(VoidCallback fn) => setState(fn);
  AttendanceType? _originalType;
  int _usageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadType();
  }

  Future<void> _loadType() async {
    final typeId = widget.typeId!;
    final repo = ref.read(attendanceTypeRepositoryWithTenantProvider);
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    final type = await ref.read(attendanceTypeByIdProvider(typeId).future);

    if (type != null && mounted) {
      // Fetch usage count
      try {
        _usageCount = await repo.getAttendanceCountForType(typeId);
        // SETTINGS2: "Instanz-Name vor Werken"
        _planningPrefixInstanceName =
            await repo.getPlanningPrefixInstanceName(typeId);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'attendance_type_edit_page');
      }

      // Ionic type.page: is_default_org_plan is edited with the other fields.
      try {
        final planTypes = await ref.read(planAttendanceTypesProvider.future);
        _isDefaultOrgPlan =
            planTypes.where((t) => t.id == typeId).firstOrNull?.isDefaultOrgPlan ?? false;
        _isDefaultOrgPlanLoaded = true;
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'attendance_type_edit_page');
      }

      // PROTOCOL: enable_protocol etc. are not part of the AttendanceType model
      try {
        final types = await protocolRepo.getProtocolTypes();
        _protocol = TypeProtocolSettings.fromType(types.where((t) => t.id == typeId).firstOrNull);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'attendance_type_edit_page');
      }
      if (!mounted) return;

      setState(() => _applyType(type));
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Copies [type] into the form state (the loaded type or the Ionic
  /// defaults of a new one).
  void _applyType(AttendanceType type) {
        _originalType = type;
        _nameController.text = type.name;
        _startTime = _parseTime(type.startTime ?? '19:00');
        _endTime = _parseTime(type.endTime ?? '20:30');

        // Load available statuses with fallback
        _availableStatuses = type.availableStatuses?.isNotEmpty == true
            ? Set.from(type.availableStatuses!)
            : {AttendanceStatus.present};

        // Validate defaultStatus is in availableStatuses (Issue #5)
        if (_availableStatuses.contains(type.defaultStatus)) {
          _defaultStatus = type.defaultStatus;
        } else if (_availableStatuses.isNotEmpty) {
          _defaultStatus = _availableStatuses.first;
        } else {
          // Fallback: ensure at least one status exists
          _availableStatuses = {AttendanceStatus.present};
          _defaultStatus = AttendanceStatus.present;
        }

        _manageSongs = type.manageSongs;
        _placeEnabled = type.placeEnabled;
        _registrationFields = List<RegistrationField>.from(type.registrationFields ?? []);
        _visible = type.visible;
        _highlight = type.highlight;
        _hideName = type.hideName;
        _includeInAverage = type.includeInAverage;
        _dutyMode = type.dutyMode;
        _dutyRequired = type.dutyRequired ?? 1;
        _dutyRequiredController.text = '$_dutyRequired';
        _dutySelfSignup = type.dutySelfSignup;
        _dutyConfirmReminderDays = type.dutyConfirmReminderDays;
        _dutyReminderDaysUnset = false;
        _dutyNotifyUnderstaffed = type.dutyNotifyUnderstaffed;
        _dutyUrgentHours = type.dutyUrgentHours;
        _color = type.color ?? 'primary';
        _allDay = type.allDay;
        _durationDays = type.durationDays ?? 1;
        _durationDaysController.text = '$_durationDays';
        _notification = type.notification;
        _reminders = List<int>.from(type.reminders ?? []);
        _checklist = List<ChecklistItem>.from(type.checklist ?? []);
        _checklistEnabled = type.checklist != null;
        _planningTitle = type.planningTitle ?? '';
        _planningTitleController.text = _planningTitle;
        // Ionic ngOnInit: the agenda marker takes no time (older plans
        // stored 30 min on it).
        // Added one by one so _withRowUid sees the rows already loaded.
        _localPlanUids.clear();
        _planFields = [];
        for (final f in _parsePlanFields(type.defaultPlan)) {
          _planFields.add(_withRowUid(f['id'] == agendaItemsPlaceholderId ? {...f, 'time': '0'} : f));
        }
        _relevantGroups = List<int>.from(type.relevantGroups ?? []);
        _additionalFieldsFilter = type.additionalFieldsFilter != null
            ? Map<String, dynamic>.from(type.additionalFieldsFilter!)
            : null;
        _isLoading = false;
  }

  @override
  void dispose() {
    // REDESIGN: a change made right before leaving is still saved.
    _rdSaveTimer?.cancel();
    final notifier = _rdNotifier;
    if (notifier != null &&
        _rdSavedJson != null &&
        _nameController.text.trim().isNotEmpty &&
        _availableStatuses.length >= 2) {
      final json = _rdJson();
      if (json != (_rdQueuedJson ?? _rdSavedJson) && json != _rdFailedJson) {
        final data = _buildTypeData();
        final id = widget.typeId!;
        final invalidate = _rdInvalidateCaches;
        unawaited(
          _rdChain.then((_) => notifier.updateType(id, data)).then((r) {
            if (r != null) invalidate();
          }, onError: (_) {}),
        );
      }
    }
    _rdTick.dispose();
    setUnloadWarning(this, false);
    _nameController.dispose();
    _durationDaysController.dispose();
    _planningTitleController.dispose();
    _dutyRequiredController.dispose();
    _newTodoController.dispose();
    _customDeadlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.typeSettingsFlutterTypeTitle)),
        body: const Center(child: AppSpinner()),
      );
    }

    if (_originalType == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.typeSettingsFlutterTypeTitle)),
        body: Center(child: Text(context.l10n.typeSettingsFlutterNotFound)),
      );
    }

    setUnloadWarning(this, false);
    return _rdBuild(context);
  }

  /// Opens the colour picker dialog for the attendance type.
  Future<void> _pickColor() async {
    final picked = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final colorName in ColorUtils.availableColors)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(ctx, colorName),
                child: Container(
                  width: 72,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _color == colorName ? AppColors.mediumOf(context) : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    AppIcons.circle,
                    size: 24,
                    color: ColorUtils.getColorForPicker(colorName),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _color = picked;
      _hasChanges = true;
    });
  }

  /// Ionic `ion-select multiple` for the available statuses (Anwesend
  /// cannot be deselected, like Ionic's disabled option).
  Future<void> _pickAvailableStatuses() async {
    final selected = {..._availableStatuses};
    final result = await showAppDialog<Set<AttendanceStatus>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(context.l10n.typeSettingsAvailableStatus),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final status in _ionicStatusOptions)
                  CheckboxListTile(
                    title: Text(_getStatusName(status)),
                    value: selected.contains(status),
                    onChanged: status == AttendanceStatus.present
                        ? null
                        : (v) => setLocal(() {
                              if (v == true) {
                                selected.add(status);
                              } else if (selected.length > 1) {
                                selected.remove(status);
                              }
                            }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _availableStatuses
        ..clear()
        ..addAll(_statusOrder.where(result.contains));
      // Ionic onAvailableStatusesChanged: fall back to Anwesend.
      if (!_availableStatuses.contains(_defaultStatus)) {
        _defaultStatus = AttendanceStatus.present;
      }
      _hasChanges = true;
    });
  }

  EdgeInsetsGeometry? get _rowPad => EdgeInsets.zero;

  bool get _flush => true;

  Widget _section({String? title, Widget? action, required List<Widget> items}) =>
      _buildSection(
        title: title,
        action: action,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
      );

  Widget _buildSection({String? title, required Widget child, Widget? action}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mediumOf(context),
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 8),
        ],
        child,
      ],
    );
  }

  /// Columns of the type as edited on the page (update and, for a new type,
  /// insert; the repository adds the tenant).
  Map<String, dynamic> _buildTypeData() {
      return {
        'name': _nameController.text.trim(),
        // SETTINGS2: for all-day types start_time is the plan start (Ionic)
        'start_time': _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0)),
        // Ionic keeps end_time for all-day types too (new attendances take
        // type.end_time); only an untouched null stays null.
        'end_time': _allDay &&
                _originalType != null &&
                _originalType!.endTime == null &&
                _endTime == const TimeOfDay(hour: 20, minute: 30)
            ? null
            : _formatTime(_endTime ?? const TimeOfDay(hour: 20, minute: 30)),
        'default_status': _defaultStatus.value,
        'available_statuses': _availableStatuses.map((s) => s.value).toList(),
        'manage_songs': _manageSongs,
        'visible': _visible,
        'highlight': _highlight,
        'hide_name': _hideName,
        'include_in_average': _includeInAverage,
        'color': _color,
        'all_day': _allDay,
        // Ionic keeps duration_days when "ganztägig" is off; only an untouched
        // null (shown as 1) stays null.
        'duration_days': !_allDay &&
                _originalType?.durationDays == null &&
                _durationDays == 1
            ? null
            : _durationDays,
        'notification': _notification,
        // Ionic writes the reminder list as is, also [] (never null).
        'reminders': _reminders,
        // Ionic: "Checkliste aktivieren" off = null, on = list (also []).
        'checklist': _checklistEnabled
            ? _checklist.map((item) => item.toJson()).toList()
            : null,
        // LOGIC_SETTINGS: Ionic always keeps default_plan = {time, end, fields}
        // (never null) and preserves the stored time/end.
        'default_plan': buildDefaultPlanUpdate(
          _originalType?.defaultPlan,
          _planFieldsForSave,
        ),
        // Ionic writes the input as is ('' once edited); untouched null stays null.
        'planning_title': _planningTitle.isEmpty && _originalType?.planningTitle == null
            ? null
            : _planningTitle,
        if (_isDefaultOrgPlanLoaded) 'is_default_org_plan': _isDefaultOrgPlan,
        'planning_prefix_instance_name': _planningPrefixInstanceName,
        // LOGIC_SETTINGS: Ionic keeps relevant_groups as [] (never null);
        // Ionic code calls relevant_groups.length without null check.
        'relevant_groups': _relevantGroups,
        'additional_fields_filter': _additionalFieldsFilter,
        'place_enabled': _placeEnabled,
        'registration_fields': _registrationFields.map((f) => f.toJson()).toList(),
        'duty_mode': _dutyMode,
        'duty_required': _dutyRequired < 1 ? 1 : _dutyRequired,
        'duty_self_signup': _dutySelfSignup,
        'duty_confirm_reminder_days': _dutyConfirmReminderDays,
        'duty_notify_understaffed': _dutyNotifyUnderstaffed,
        'duty_urgent_hours': _dutyUrgentHours,
        ..._protocol.toUpdate(),
      };
  }

  Future<void> _deleteType() async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      // Only unused Terminarten get here (see _rdDeleteType), so no
      // Termin is deleted with it.
      title: context.l10n.rdTextTypeDeleteTitle,
      message: context.l10n.rdTextTypeDeleteMessage(_originalType!.name),
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
      // EIA-29: Ionic type.page deleteType uses `role: 'destructive'`.
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      final success = await ref.read(attendanceTypeNotifierProvider.notifier).deleteType(widget.typeId!);

      if (success && mounted) {
        ToastHelper.showSuccess(context, context.l10n.typeSettingsDeleted);
        context.pop();
      } else if (!success && mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsDeleteFailed);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsDeleteFailed);
      }
    }
  }
}

/// LOGIC_SETTINGS: defaults of a new type as in Ionic type.page.ts (isNew).
AttendanceType buildNewAttendanceType(String name) {
  return AttendanceType(
    name: name.trim(),
    planningTitle: '',
    defaultStatus: AttendanceStatus.present,
    availableStatuses: const [
      AttendanceStatus.neutral,
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.excused,
      AttendanceStatus.late,
    ],
    manageSongs: false,
    startTime: '19:00',
    endTime: '20:30',
    relevantGroups: const [],
    index: 999,
    visible: true,
    color: 'primary',
    highlight: false,
    hideName: false,
    includeInAverage: true,
    reminders: const [],
    defaultPlan: const {'time': '', 'end': '', 'fields': <dynamic>[]},
  );
}

/// LOGIC_SETTINGS: Ionic always stores `default_plan` as
/// `{time, end, fields}` (never null). Keeps any other stored keys
/// (e.g. time/end) and replaces only the fields list.
Map<String, dynamic> buildDefaultPlanUpdate(
  Map<String, dynamic>? original,
  List<Map<String, dynamic>> fields,
) {
  return <String, dynamic>{
    ...?original,
    'time': original?['time'] ?? '',
    'end': original?['end'] ?? '',
    'fields': fields,
  };
}

const _planFieldKeys = {
  'id', 'name', 'time', 'conductor', 'currentTime', 'songId', 'info', 'agendaItemId',
  'isGroup', 'groupId', 'uid', 'needsBeamer', 'beamerFile',
};

/// Merges the edited [fields] back into the stored [originals] rows: each
/// row is matched by its `uid` (the row identity, ids repeat), else by id.
/// The matched row keeps unknown keys and the legacy `isNote` flag; keys
/// PlanField knows but dropped (cleared to null) are removed, the
/// Flutter-only `isGroup: false` default is not added.
@visibleForTesting
List<Map<String, dynamic>> mergePlanRows(
  List<Map<String, dynamic>> originals,
  List<PlanField> fields,
) {
  final remaining = [...originals];
  return [
    for (final field in fields) _mergePlanRow(remaining, field),
  ];
}

Map<String, dynamic> _mergePlanRow(List<Map<String, dynamic>> remaining, PlanField field) {
  final json = field.toJson();
  final uid = json['uid'];
  final idx = uid != null
      ? remaining.indexWhere((o) => o['uid'] == uid)
      : remaining.indexWhere((o) => '${o['id']}' == '${json['id']}');
  final original = idx >= 0 ? remaining.removeAt(idx) : const <String, dynamic>{};
  final merged = {...original, ...json}..removeWhere((k, _) => _planFieldKeys.contains(k) && !json.containsKey(k));
  if (merged['isGroup'] == false && !original.containsKey('isGroup')) merged.remove('isGroup');
  return merged;
}
