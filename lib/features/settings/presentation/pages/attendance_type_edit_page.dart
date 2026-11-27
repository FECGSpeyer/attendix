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
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../redesign/data/rd_manage_logic.dart' show RdManageEntry;
import '../../../redesign/data/rd_words.dart';
import '../../../redesign/presentation/widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart' show RdValueBox;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

part 'attendance_type_edit_page_beta.dart';


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

  // REDESIGN: live saving of the Beta page (attendance_type_edit_page_beta.dart).
  final _rdTick = ValueNotifier<int>(0);
  Timer? _rdSaveTimer;
  bool _rdSaving = false;
  bool _rdInvalid = false;

  /// What was last loaded or saved, and what last failed. A change is any
  /// difference in the saved data, whichever editor made it (also the
  /// classic sub-editors and text fields without setState). A failed state
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

  /// The colour dialog of the Beta design (also attendance_type_edit_page_beta).
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

  // DUTY: Dienstplan section (Ionic type.page "Dienstplan")
  Widget _buildDutySection() {
    void mark(VoidCallback fn) => setState(() {
          fn();
          _hasChanges = true;
        });

    return _section(
      title: context.l10n.typeSettingsDutyRoster,
      items: [
          IonSwitchListTile(
            title: Text(context.l10n.typeSettingsDutyMode),
            subtitle: Text(
              context.l10n.typeSettingsDutyHelper,
            ),
            value: _dutyMode,
            onChanged: (value) => mark(() {
              _dutyMode = value;
              if (value) {
                // Nobody is expected until assigned, so new Termine start neutral.
                if (_dutyRequired < 1) _dutyRequired = 1;
                _dutyRequiredController.text = '$_dutyRequired';
                if (_dutyReminderDaysUnset) {
                  _dutyConfirmReminderDays = 2;
                  _dutyReminderDaysUnset = false;
                }
                _availableStatuses = {
                  ..._availableStatuses,
                  AttendanceStatus.neutral,
                  AttendanceStatus.present,
                  AttendanceStatus.excused,
                };
                _defaultStatus = AttendanceStatus.neutral;
              }
            }),
            contentPadding: _rowPad,
          ),
          ListTile(
            contentPadding: _rowPad,
            leading: Icon(AppIcons.helpOutline, color: AppColors.primary),
            title: Text(context.l10n.typeSettingsLearnMore, style: const TextStyle(color: AppColors.primary)),
            onTap: () => context.push('/settings/help/article/duty-setup'),
          ),
          if (_dutyMode) ...[
            ListTile(
              contentPadding: _rowPad,
              title: Text(context.l10n.typeSettingsNeededPeople),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(AppIcons.remove),
                    tooltip: context.l10n.attListLess,
                    onPressed: _dutyRequired <= 1 ? null : () => mark(() => _dutyRequired--),
                  ),
                  Text('$_dutyRequired'),
                  IconButton(
                    icon: Icon(AppIcons.add),
                    tooltip: context.l10n.attListMore,
                    onPressed: () => mark(() => _dutyRequired++),
                  ),
                ],
              ),
            ),
            IonSwitchListTile(
              title: Text(context.l10n.typeSettingsSelfAssign),
              subtitle: Text(context.l10n.typeSettingsSelfAssignHelper),
              value: _dutySelfSignup,
              onChanged: (v) => mark(() => _dutySelfSignup = v),
              contentPadding: _rowPad,
            ),
            ListTile(
              contentPadding: _rowPad,
              title: Text(context.l10n.typeSettingsRemindUnconfirmed),
              trailing: AppDropdownButton<int?>(
                value: _dutyConfirmReminderDays,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.typeSettingsOff)),
                  DropdownMenuItem(value: 1, child: Text(context.l10n.typeSettingsAfter1Day)),
                  DropdownMenuItem(value: 2, child: Text(context.l10n.typeSettingsAfter2Days)),
                  DropdownMenuItem(value: 3, child: Text(context.l10n.typeSettingsAfter3Days)),
                  DropdownMenuItem(value: 7, child: Text(context.l10n.typeSettingsAfter7Days)),
                ],
                onChanged: (v) => mark(() {
                  _dutyConfirmReminderDays = v;
                  _dutyReminderDaysUnset = false;
                }),
              ),
            ),
            IonSwitchListTile(
              title: Text(context.l10n.typeSettingsNotifyGroup),
              subtitle: Text(
                context.l10n.typeSettingsNotifyGroupHelper,
              ),
              value: _dutyNotifyUnderstaffed,
              onChanged: (v) => mark(() => _dutyNotifyUnderstaffed = v),
              contentPadding: _rowPad,
            ),
            ListTile(
              contentPadding: _rowPad,
              title: Text(context.l10n.typeSettingsUrgentIfOpen),
              subtitle: Text(context.l10n.typeSettingsUrgentHelper),
              trailing: AppDropdownButton<int?>(
                value: _dutyUrgentHours,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.typeSettingsOff)),
                  DropdownMenuItem(value: 6, child: Text(context.l10n.typeSettingsH6)),
                  DropdownMenuItem(value: 12, child: Text(context.l10n.typeSettingsH12)),
                  DropdownMenuItem(value: 24, child: Text(context.l10n.typeSettingsH24)),
                  DropdownMenuItem(value: 48, child: Text(context.l10n.typeSettingsH48)),
                  DropdownMenuItem(value: 72, child: Text(context.l10n.typeSettingsH72)),
                ],
                onChanged: (v) => mark(() => _dutyUrgentHours = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.paddingS),
              child: Text(
                context.l10n.typeSettingsCircleHint,
                style: TextStyle(color: AppColors.mediumOf(context), fontSize: 13),
              ),
            ),
          ],
        ],
    );
  }

  /// Ionic "Filter": multi-select "Relevante Gruppen" and the extra field
  /// filter (select and Ja/Nein fields) in one list.
  Widget _buildFilterSection() {
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = (tenant?.additionalFields ?? [])
        .where((f) => f.type == 'select' || f.type == 'boolean')
        .toList();

    final selectedFieldId = _additionalFieldsFilter?['key'] as String?;
    final selectedField = extraFields.where((f) => f.id == selectedFieldId).firstOrNull;
    final rawOption = _additionalFieldsFilter?['option'];

    final groupNames = [
      for (final g in groups)
        if (g.id != null && _relevantGroups.contains(g.id)) g.name,
    ];

    return _section(
      title: context.l10n.typeSettingsFilter,
      items: [
          SettingsStackedValue(
            flush: _flush,
            label: context.l10n.typeSettingsRelevantGroups,
            value: groupNames.join(', '),
            helper: context.l10n.typeSettingsRelevantGroupsHelper,
            onTap: groups.isEmpty ? null : () => _pickRelevantGroups(groups),
          ),
          if (extraFields.isNotEmpty)
            SettingsStackedField(
              flush: _flush,
              label: context.l10n.typeSettingsExtraFilter,
              helper: context.l10n.typeSettingsExtraFilterHelper,
              builder: (decoration) => AppDropdownFormField<String?>(
                interface: AppSelectInterface.alert,
                header: context.l10n.typeSettingsExtraFilter,
                decoration: decoration,
                value: selectedField?.id,
                items: [
                  DropdownMenuItem(value: null, child: Text(context.l10n.typeSettingsNoFilter)),
                  for (final f in extraFields) DropdownMenuItem(value: f.id, child: Text(f.name)),
                ],
                // Ionic onAdditionalFieldFilterChanged: Ja/Nein starts with
                // true, a select field with its first option.
                onChanged: (value) => setState(() {
                  final field = extraFields.where((f) => f.id == value).firstOrNull;
                  _additionalFieldsFilter = field == null
                      ? null
                      : {
                          'key': field.id,
                          'option': field.type == 'boolean' ? true : field.options?.firstOrNull,
                        };
                  _hasChanges = true;
                }),
              ),
            ),
          if (selectedField != null && selectedField.type == 'boolean')
            SettingsStackedField(
              flush: _flush,
              label: context.l10n.typeSettingsValue,
              builder: (decoration) => AppDropdownFormField<bool>(
                interface: AppSelectInterface.alert,
                header: context.l10n.typeSettingsValue,
                decoration: decoration,
                value: rawOption is bool ? rawOption : null,
                items: [
                  DropdownMenuItem(value: true, child: Text(context.l10n.commonYes)),
                  DropdownMenuItem(value: false, child: Text(context.l10n.commonNo)),
                ],
                onChanged: (value) => setState(() {
                  _additionalFieldsFilter = {'key': selectedField.id, 'option': value};
                  _hasChanges = true;
                }),
              ),
            )
          else if (selectedField != null &&
              _additionalFieldsFilter!.containsKey('option') &&
              (selectedField.options ?? const []).isNotEmpty)
            SettingsStackedField(
              flush: _flush,
              label: context.l10n.typeSettingsOption,
              builder: (decoration) => AppDropdownFormField<String>(
                interface: AppSelectInterface.alert,
                header: context.l10n.typeSettingsOption,
                decoration: decoration,
                value: rawOption is String && selectedField.options!.contains(rawOption) ? rawOption : null,
                items: [
                  for (final opt in selectedField.options!) DropdownMenuItem(value: opt, child: Text(opt)),
                ],
                onChanged: (value) => setState(() {
                  _additionalFieldsFilter = {'key': selectedField.id, 'option': value};
                  _hasChanges = true;
                }),
              ),
            ),
        ],
    );
  }

  /// Ionic `ion-select multiple` "Relevante Gruppen" (options: group.name).
  Future<void> _pickRelevantGroups(List<Group> groups) async {
    final selected = {..._relevantGroups};
    final result = await showAppDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AppAlertDialog(
          title: Text(context.l10n.typeSettingsRelevantGroups),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final group in groups.where((g) => g.id != null))
                  CheckboxListTile(
                    title: Text(group.name),
                    value: selected.contains(group.id),
                    onChanged: (v) => setLocal(() {
                      if (v == true) {
                        selected.add(group.id!);
                      } else {
                        selected.remove(group.id!);
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
      // Keep the group order of the instance (Ionic writes the selection in option order).
      _relevantGroups = [
        for (final g in groups)
          if (g.id case final id? when result.contains(id)) id,
      ];
      _hasChanges = true;
    });
  }

  Future<void> _openReminders() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.95,
        child: StatefulBuilder(
          builder: (sheetContext, setSheet) => Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(context.l10n.typeSettingsReminders),
              actions: [
                IconButton(
                  tooltip: context.l10n.commonOk,
                  icon: Icon(AppIcons.check),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                TypeRemindersEditor(
                  reminders: _reminders,
                  onChanged: (list) {
                    setState(() {
                      _reminders = list;
                      _hasChanges = true;
                    });
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusName(AttendanceStatus status) {
    final l10n = context.l10n;
    switch (status) {
      case AttendanceStatus.present:
        return l10n.commonStatusPresent;
      case AttendanceStatus.absent:
        return l10n.commonStatusAbsent;
      case AttendanceStatus.excused:
        return l10n.commonStatusExcused;
      case AttendanceStatus.late:
        return l10n.commonStatusLate;
      case AttendanceStatus.lateExcused:
        return l10n.commonStatusLateExcused;
      case AttendanceStatus.neutral:
        return l10n.commonStatusNeutral;
    }
  }

  /// Ionic type.page `attendanceStatuses`: Verspätet (entsch.) is never offered.
  static const _ionicStatusOptions = [
    AttendanceStatus.neutral,
    AttendanceStatus.present,
    AttendanceStatus.absent,
    AttendanceStatus.excused,
    AttendanceStatus.late,
  ];

  /// Display order: Ionic options, then a status stored by older Flutter
  /// versions (kept, not offered).
  static const _statusOrder = [..._ionicStatusOptions, AttendanceStatus.lateExcused];

  bool get _isGeneral => ref.read(currentTenantProvider)?.type == 'general';

  Widget _timeValue(String text, {VoidCallback? onTap, Color? betaColor}) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Text(text, style: betaColor == null ? style : style?.copyWith(color: betaColor));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showAppTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 19, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 20, minute: 30)),
      minuteInterval: 1,
    );
    if (time != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = time;
          // Ionic: the plan start picker always recalculates "Ende".
          _calculateEnd();
        } else {
          _endTime = time;
        }
        _hasChanges = true;
      });
    }
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _parsePlanFields(Map<String, dynamic>? plan) {
    if (plan == null) return [];
    final fields = plan['fields'];
    if (fields is! List || fields.isEmpty) return [];
    return fields
        .map((f) => Map<String, dynamic>.from(f as Map))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Ablaufplan (Ionic type.page default_plan)
  // ---------------------------------------------------------------------------

  List<PlanField> get _planFieldModels => [for (final f in _planFields) PlanField.fromJson(f)];

  /// Gives a row a unique `uid` as its identity while editing: ids repeat
  /// (free text id = text, e.g. "Pause" twice), the uid travels through the
  /// [PlanFieldsEditor] unchanged. A stored, unique uid is kept; otherwise a
  /// local one is set and removed (or the stored one restored) on save.
  Map<String, dynamic> _withRowUid(Map<String, dynamic> row) {
    final stored = row['uid'];
    final storedUid = stored is String && stored.isNotEmpty ? stored : null;
    final taken = storedUid != null &&
        (_localPlanUids.containsKey(storedUid) || _planFields.any((f) => f['uid'] == storedUid));
    if (storedUid != null && !taken) return row;
    final local = 'local-${PlanUtils.uuid()}';
    _localPlanUids[local] = storedUid;
    return {...row, 'uid': local};
  }

  /// [_planFields] as stored: local row identities removed again.
  List<Map<String, dynamic>> get _planFieldsForSave => [
        for (final f in _planFields)
          if (_localPlanUids.containsKey(f['uid']))
            _localPlanUids[f['uid']] == null
                ? ({...f}..remove('uid'))
                : {...f, 'uid': _localPlanUids[f['uid']]}
          else
            f,
      ];

  /// Back to the stored map: the original row (matched by its row identity
  /// `uid`, see [_withRowUid]) is kept and only updated, so unknown keys and
  /// the legacy `isNote` flag survive. The Flutter-only `isGroup: false`
  /// default is not written.
  void _setPlanFields(List<PlanField> fields) {
    setState(() {
      _planFields = mergePlanRows(_planFields, fields);
      _calculateEnd();
      _hasChanges = true;
    });
  }

  /// Ionic calculateEnd(): start time + all minutes, shown as "Ende".
  void _calculateEnd() {
    final start = _startTime ?? const TimeOfDay(hour: 19, minute: 0);
    var minutes = start.hour * 60 + start.minute;
    for (final f in _planFields) {
      minutes += int.tryParse('${f['time'] ?? ''}'.trim()) ?? 0;
    }
    _planEnd = PlanUtils.formatMinutes(minutes);
  }

  void _addPlanRow(Map<String, dynamic> field) {
    setState(() {
      _planFields = [..._planFields, _withRowUid(field)];
      _calculateEnd();
      _hasChanges = true;
    });
  }

  Widget _buildPlanSection() {
    final l10n = context.l10n;
    final isGeneral = _isGeneral;
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final start = _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0));
    return _section(
      title: l10n.typeSettingsRunSheet,
      action: Builder(
        builder: (anchorContext) => IconButton(
          tooltip: l10n.typeSettingsAddField,
          icon: Icon(AppIcons.add, color: AppColors.primary),
          onPressed: () => _showPlanAddMenu(anchorContext),
        ),
      ),
      items: [
          SettingsStackedField(
            flush: _flush,
            label: l10n.typeSettingsPlanHeading,
            helper: l10n.typeSettingsTitleHelper,
            builder: (decoration) => TextFormField(
              controller: _planningTitleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
              onChanged: (value) {
                _planningTitle = value;
                _hasChanges = true;
              },
            ),
          ),
          // SETTINGS2: Ionic "Instanz-Name vor Werken" (not for general tenants)
          if (!isGeneral)
            IonSwitchListTile(
              contentPadding: _rowPad,
              title: Text(l10n.typeSettingsTenantNameBefore),
              subtitle: Text(l10n.typeSettingsTenantNameHelper),
              value: _planningPrefixInstanceName,
              onChanged: (v) => setState(() {
                _planningPrefixInstanceName = v;
                _hasChanges = true;
              }),
            ),
          // ORG_PLANS: Ionic `@if (db.organisation())`, saved with the FAB.
          // Disabled until the stored value is loaded (it is only saved then).
          if (org != null)
            IonSwitchListTile(
              contentPadding: _rowPad,
              title: Text(l10n.typeSettingsOrgPlanDefault),
              value: _isDefaultOrgPlan,
              onChanged: _isDefaultOrgPlanLoaded
                  ? (v) => setState(() {
                        _isDefaultOrgPlan = v;
                        _hasChanges = true;
                      })
                  : null,
            ),
          // Ionic: "Start" always; editable only for all-day types (otherwise
          // the type's start time, disabled).
          ListTile(
            contentPadding: _rowPad,
            title: Text(l10n.typeSettingsStartShort),
            subtitle: _allDay ? Text(l10n.typeSettingsStartAllDay) : null,
            trailing: _timeValue(
              start,
              onTap: _allDay ? () => _pickTime(isStart: true) : null,
              betaColor: _allDay ? null : AppColors.mediumOf(context),
            ),
            onTap: _allDay ? () => _pickTime(isStart: true) : null,
          ),
          PlanFieldsEditor(
            templateMode: true,
            fields: _planFieldModels,
            startTime: start,
            emptyText: '',
            onChanged: _setPlanFields,
          ),
          if (_planEnd != null)
            ListTile(
              contentPadding: _rowPad,
              title: Text(l10n.typeSettingsEnd),
              trailing: _timeValue(_planEnd!, betaColor: AppColors.mediumOf(context)),
            ),
        ],
    );
  }

  Future<void> _showPlanAddMenu(BuildContext anchorContext) async {
    final l10n = context.l10n;
    final box = anchorContext.findRenderObject() as RenderBox;
    final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final action = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      items: [
        PopupMenuItem(value: 'field', child: Text(l10n.typeSettingsAddField)),
        PopupMenuItem(value: 'note', child: Text(l10n.typeSettingsAddNoteField)),
        if (!_isGeneral) PopupMenuItem(value: 'song', child: Text(l10n.typeSettingsSongPlaceholder)),
        if (_protocol.enableProtocol)
          PopupMenuItem(
            value: 'agenda',
            child: Row(children: [
              Icon(AppIcons.commit, color: AppColors.mediumOf(context)),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.typeSettingsAgendaPlaceholder)),
            ]),
          ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'field':
        await _addPlanField();
      case 'note':
        await _addNoteField();
      case 'song':
        _addSongPlaceholder();
      case 'agenda':
        _addAgendaPlaceholder();
    }
  }

  /// Ionic addExtraField: free text + optional info; id = text, 20 minutes.
  Future<void> _addPlanField() async {
    final l10n = context.l10n;
    final result = await showPlanFieldDialog(
      context,
      title: l10n.typeSettingsAddField,
      nameLabel: '',
      nameHint: l10n.typeSettingsFreeTextPh,
      infoHint: l10n.typeSettingsInfoOptional,
      withConductor: false,
      withMinutes: false,
      requireName: false,
    );
    if (result == null || !mounted) return;
    _addPlanRow({
      'id': result.name,
      'name': result.name,
      if (result.info != null) 'info': result.info,
      'time': '20',
    });
  }

  /// Ionic addNoteField: id `noteFld <text>`, no time.
  Future<void> _addNoteField() async {
    final l10n = context.l10n;
    final result = await showPlanFieldDialog(
      context,
      title: l10n.typeSettingsAddNoteField,
      nameLabel: '',
      nameHint: l10n.typeSettingsNotePh,
      withConductor: false,
      withInfo: false,
      withMinutes: false,
      requireName: false,
    );
    if (result == null || !mounted) return;
    _addPlanRow({
      'id': 'noteFld ${result.name}',
      'name': result.name,
      'conductor': '',
      'time': '0',
    });
  }

  /// Ionic addSongPlaceholder: numbered from 1.
  void _addSongPlaceholder() {
    final n = _planFields.where((f) => '${f['id'] ?? ''}'.startsWith('song-placeholder-')).length + 1;
    _addPlanRow({
      'id': 'song-placeholder-$n',
      'name': context.l10n.typeSettingsSongPlaceholderN(n),
      'time': '20',
    });
  }

  /// Ionic addAgendaItemsPlaceholder: only once.
  void _addAgendaPlaceholder() {
    if (hasAgendaPlaceholder(_planFields)) {
      ToastHelper.showWarning(context, context.l10n.typeSettingsAgendaExists);
      return;
    }
    _addPlanRow(agendaPlaceholderField());
  }

  // ---------------------------------------------------------------------------
  // Checkliste (Ionic type.page)
  // ---------------------------------------------------------------------------

  static const _deadlinePresets = [1, 24, 48, 168];

  String _deadlinePresetLabel(int hours) =>
      hours == 168 ? context.l10n.redesignCreateDeadlineWeek : _checklistDeadlineText(hours);

  Widget _buildChecklistSection() {
    final l10n = context.l10n;
    final showCustom = _newTodoDeadline == -1;
    return _section(
      title: l10n.typeSettingsChecklist,
      action: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: IonBadge(text: '${_checklist.length}', color: AppColors.mediumOf(context)),
      ),
      items: [
          if (_checklist.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _checklist.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _checklist.removeAt(oldIndex);
                  _checklist.insert(newIndex, item);
                  _hasChanges = true;
                });
              },
              itemBuilder: (context, index) {
                final item = _checklist[index];
                // Ionic: ion-item-sliding with a trash option,
                // deadline text as subtitle, reorder handle at the end.
                return SwipeActions.delete(
                  key: ObjectKey(item),
                  onDelete: () => setState(() {
                    _checklist.removeAt(index);
                    _hasChanges = true;
                  }),
                  child: ListTile(
                    contentPadding: _rowPad,
                    title: Text(item.text),
                    subtitle: Text(_checklistDeadlineText(item.deadlineHours)),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Icon(AppIcons.reorder, color: AppColors.mediumOf(context)),
                    ),
                    onTap: () => _editChecklistItem(index),
                  ),
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(AppIcons.checkBoxOutlined, size: 32, color: AppColors.mediumOf(context)),
                  const SizedBox(height: 4),
                  Text(l10n.typeSettingsNoTodos, style: TextStyle(color: AppColors.mediumOf(context))),
                ],
              ),
            ),
          // Ionic: inline "Neues To-Do" + "Deadline" (action sheet) + button.
          SettingsStackedField(
            flush: _flush,
            label: l10n.typeSettingsNewTodo,
            hint: l10n.typeSettingsTodoPlaceholder,
            builder: (decoration) => TextField(
              controller: _newTodoController,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SettingsStackedField(
            flush: _flush,
            label: l10n.typeSettingsDeadline,
            // Own Form: a deadline for a not yet added to-do is no change of
            // the type (Ionic compares only the type).
            builder: (decoration) => Form(
              child: AppDropdownFormField<int?>(
                interface: AppSelectInterface.actionSheet,
                decoration: decoration.copyWith(hintText: l10n.typeSettingsNoDeadline),
                value: _newTodoDeadline,
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.typeSettingsNoDeadline)),
                  for (final h in _deadlinePresets)
                    DropdownMenuItem(value: h, child: Text(_deadlinePresetLabel(h))),
                  DropdownMenuItem(value: -1, child: Text(l10n.typeSettingsCustomDots)),
                ],
                onChanged: (v) => setState(() => _newTodoDeadline = v),
              ),
            ),
          ),
          if (showCustom)
            SettingsStackedField(
              flush: _flush,
              label: l10n.typeSettingsHoursBefore,
              hint: 'z.B. 12',
              builder: (decoration) => TextField(
                controller: _customDeadlineController,
                keyboardType: TextInputType.number,
                decoration: decoration,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _newTodoController.text.trim().isEmpty ? null : _addChecklistItem,
              icon: Icon(AppIcons.addCircleOutline),
              label: IonButtonLabel(l10n.typeSettingsAddTodo),
            ),
          ),
        ],
    );
  }

  /// Ionic addChecklistItem.
  void _addChecklistItem() {
    final text = _newTodoController.text.trim();
    if (text.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.typeSettingsEnterTodo);
      return;
    }
    int? deadline = _newTodoDeadline;
    if (deadline == -1) {
      final custom = int.tryParse(_customDeadlineController.text.trim());
      deadline = custom != null && custom != 0 ? custom : null;
    }
    setState(() {
      _checklist = [
        ..._checklist,
        ChecklistItem(id: PlanUtils.uuid(), text: text, deadlineHours: deadline),
      ];
      _newTodoController.clear();
      _customDeadlineController.clear();
      _newTodoDeadline = null;
      _hasChanges = true;
    });
  }

  /// Ionic editChecklistItem: alert "To-Do bearbeiten" with the text only.
  Future<void> _editChecklistItem(int index) async {
    final item = _checklist[index];
    final text = await showPlanFieldDialog(
      context,
      title: context.l10n.typeSettingsEditTodo,
      nameLabel: '',
      nameHint: context.l10n.typeSettingsTodoTextPh,
      initialName: item.text,
      confirmText: context.l10n.commonSave,
      withConductor: false,
      withInfo: false,
      withMinutes: false,
      requireName: false,
    );
    if (text == null || text.name.isEmpty || !mounted) return;
    setState(() {
      _checklist[index] = item.copyWith(text: text.name);
      _hasChanges = true;
    });
  }

  /// Ionic getChecklistDeadlineText / getFormattedReminder.
  String _checklistDeadlineText(int? hours) {
    final l10n = context.l10n;
    if (hours == null) return l10n.typeSettingsNoDeadline;
    if (hours == 0) return l10n.typeSettingsSameTime;
    if (hours < 24) return l10n.typeSettingsHoursBeforeN(hours);
    return l10n.typeSettingsDaysBeforeN(hours ~/ 24);
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
      // Beta: only unused Terminarten get here (see _rdDeleteType), so no
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
