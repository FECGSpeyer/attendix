import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
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
import '../widgets/settings_list.dart';
import '../../../../core/providers/organisation_providers.dart' show currentOrganisationProvider;
import '../../../../core/providers/plan_providers.dart' show planAttendanceTypesProvider;
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/team_org/team_org.dart' show agendaItemsPlaceholderId;
import '../../../../data/models/plan/plan.dart' show PlanField;
import '../../../planning/presentation/widgets/plan_field_dialogs.dart' show showPlanFieldDialog;
import '../../../planning/presentation/widgets/plan_fields_editor.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/services/error_reporter.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../core/services/web_window.dart' show setUnloadWarning;


/// Ionic `types.page.ts openTypeModal()`: "+" presents the type page with
/// `isNew: true` as a modal (iOS: card modal over the list, md: full-screen
/// `ion-modal`, centred card on desktop). Nothing is written before the FAB
/// creates the type. Returns true when a type was created.
Future<bool?> showAttendanceTypeCreateModal(BuildContext context) {
  Widget build(BuildContext _) => const AttendanceTypeEditPage.create();
  if (useIosLook(context)) {
    return showIosCardModal<bool>(
      context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : AppColors.light,
      builder: build,
    );
  }
  return showIonModal<bool>(context, builder: build);
}

/// Attendance Type Edit Page
///
/// Edit an existing attendance type or – with [AttendanceTypeEditPage.create]
/// (Ionic `isNew`) – configure and create a new one.
class AttendanceTypeEditPage extends ConsumerStatefulWidget {
  /// Null in the "new" mode.
  final String? typeId;

  const AttendanceTypeEditPage({
    super.key,
    required String this.typeId,
  });

  /// Ionic type.page with `isNew: true`: starts with the defaults of
  /// [buildNewAttendanceType] and creates the type on the FAB.
  const AttendanceTypeEditPage.create({super.key}) : typeId = null;

  bool get isNew => typeId == null;

  @override
  ConsumerState<AttendanceTypeEditPage> createState() => _AttendanceTypeEditPageState();
}

class _AttendanceTypeEditPageState extends ConsumerState<AttendanceTypeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationDaysController = TextEditingController(text: '1');
  final _planningTitleController = TextEditingController();

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
  bool _dutyModeAtLoad = false;
  int _dutyRequired = 1;
  bool _dutySelfSignup = true;
  int? _dutyConfirmReminderDays = 2;
  bool _dutyNotifyUnderstaffed = true;
  int? _dutyUrgentHours;

  bool _isLoading = true;
  bool _hasChanges = false;
  AttendanceType? _originalType;
  int _usageCount = 0;

  /// Id of the type created in the "new" mode (for the duty view offer).
  String? _createdId;
  bool _isCreating = false;

  bool get _isNew => widget.isNew;

  /// Ionic `dismissModal`: the discard alert only once a name was entered.
  bool get _hasNewInput => _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      // Ionic isNew: nothing is loaded; the org plan flag starts false and
      // is written with the insert.
      _isDefaultOrgPlanLoaded = true;
      _applyType(buildNewAttendanceType(''));
    } else {
      _loadType();
    }
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
        _dutyModeAtLoad = type.dutyMode;
        _dutyRequired = type.dutyRequired ?? 1;
        _dutySelfSignup = type.dutySelfSignup;
        _dutyConfirmReminderDays = type.dutyConfirmReminderDays;
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
    setUnloadWarning(this, false);
    _nameController.dispose();
    _durationDaysController.dispose();
    _planningTitleController.dispose();
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

    // Ionic beforeunload: closing/reloading the browser tab warns too.
    final dirty = _isNew ? _hasNewInput : _hasChanges;
    setUnloadWarning(this, dirty);
    return PopScope(
      // Während des Anlegens nicht schließen (Wischen/Zurück blockiert).
      canPop: !dirty && !_isCreating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _isNew ? _closeNew() : _onBackPressed();
      },
      child: Scaffold(
        // UX_SETTINGS (WAVE 8): type.page.html — no title, arrow-back,
        // red trash at the end, save via FAB (save-outline).
        // IOS_R6: Ionic `ion-content fullscreen` under the
        // `ion-header translucent` (no large title: always blurred)
        // Ionic isNew (modal): no back arrow and no trash, ✕ at the end.
        extendBodyBehindAppBar: !_isNew && useIosLook(context),
        appBar: _isNew
            ? AppBar(
                automaticallyImplyLeading: false,
                toolbarHeight: ionModalToolbarHeight(context),
                actions: [
                  ToolbarButtonGroup(children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: context.l10n.commonClose,
                      onPressed: _isCreating ? null : _closeNew,
                    ),
                  ]),
                ],
              )
            : IonTranslucentAppBar(child: AppBar(
          leading: IconButton(
          icon: Icon(Icons.arrow_back, semanticLabel: context.l10n.commonBack),
          onPressed: _onBackPressed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: context.l10n.commonDelete,
            onPressed: _deleteType,
          ),
        ],
      )),
      // Ionic isNew: "+" FAB creates the type (always enabled).
      floatingActionButton: _isNew
          ? FloatingActionButton(
              onPressed: _isCreating ? null : _create,
              tooltip: context.l10n.typeSettingsFlutterCreateType,
              child: const Icon(Icons.add),
            )
          : TabBarFab.wrap(FloatingActionButton(
        onPressed: _hasChanges ? _save : null,
        tooltip: context.l10n.commonSave,
        child: const Icon(Icons.save_outlined),
      )),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() => _hasChanges = true),
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
          children: [
            const IonContentTopInset(),
            // Usage warning
            if (_usageCount > 0) ...[
              Card(
                color: AppColors.warning.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingS),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.typeSettingsFlutterUsageWarning(_usageCount),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
            // Name (Ionic: first inset group, stacked label)
            _nameField(),
            const SizedBox(height: AppDimensions.paddingL),

            // UX_SETTINGS: Ionic "Optionen" (type.page.html order): Aktiv, verfügbare
            // Status, Standard-Status, Werke verwalten, Ganztägig/Zeiten, Name
            // verbergen, Hervorheben, Für Ø berücksichtigen, Protokoll, Ort.
            _buildSection(
              title: context.l10n.typeSettingsOptions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsActive),
                    subtitle: Text(
                      context.l10n.typeSettingsActiveHelper,
                    ),
                    value: _visible,
                    onChanged: (value) => setState(() {
                      _visible = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  // UX_SETTINGS (WAVE 8): Ionic stacked ion-select (multiple)
                  // → value row opening a checkbox list; default status as
                  // stacked select.
                  IonStackedValue(
                    label: context.l10n.typeSettingsAvailableStatus,
                    value: _statusOrder
                        .where(_availableStatuses.contains)
                        .map(_getStatusName)
                        .join(', '),
                    onTap: _pickAvailableStatuses,
                    flush: true,
                  ),
                  IonStackedField(
                    flush: true,
                    label: context.l10n.typeSettingsDefaultStatus,
                    builder: (decoration) => AppDropdownFormField<AttendanceStatus>(
                      iosInterface: AppSelectInterface.alert,
                      decoration: decoration,
                      value: _availableStatuses.contains(_defaultStatus)
                          ? _defaultStatus
                          : _availableStatuses.firstOrNull ?? AttendanceStatus.present,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _defaultStatus = value;
                            _hasChanges = true;
                          });
                        }
                      },
                      items: _statusOrder
                          .where(_availableStatuses.contains)
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(_getStatusName(status)),
                              ))
                          .toList(),
                    ),
                  ),
                  // Ionic: `@if (!isGeneral)`.
                  if (!_isGeneral)
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsManageSongs),
                    subtitle: Text(
                      context.l10n.typeSettingsSongsHelper,
                    ),
                    value: _manageSongs,
                    onChanged: (value) => setState(() {
                      _manageSongs = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsAllDay),
                    subtitle: Text(
                      context.l10n.typeSettingsAllDayHelper,
                    ),
                    value: _allDay,
                    onChanged: (value) => setState(() {
                      _allDay = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_allDay)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(context.l10n.typeSettingsDefaultDays)),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              controller: _durationDaysController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null && parsed > 0) {
                                  _durationDays = parsed;
                                  _hasChanges = true;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.typeSettingsStart),
                      subtitle: Text(
                        context.l10n.typeSettingsTimesHint,
                      ),
                      trailing: Text(_formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0)),
                          style: Theme.of(context).textTheme.titleMedium),
                      onTap: () => _pickTime(isStart: true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.typeSettingsEnd),
                      trailing: Text(_formatTime(_endTime ?? const TimeOfDay(hour: 20, minute: 30)),
                          style: Theme.of(context).textTheme.titleMedium),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ],
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsHideName),
                    subtitle: Text(
                      context.l10n.typeSettingsHideNameHelper,
                    ),
                    value: _hideName,
                    onChanged: (value) => setState(() {
                      _hideName = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsHighlight),
                    subtitle: Text(
                      context.l10n.typeSettingsHighlightHelper,
                    ),
                    value: _highlight,
                    onChanged: (value) => setState(() {
                      _highlight = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsCountForAvg),
                    subtitle: Text(
                      context.l10n.typeSettingsCountForAvgHelper,
                    ),
                    value: _includeInAverage,
                    onChanged: (value) => setState(() {
                      _includeInAverage = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  // PROTOCOL: Protokoll & Tagesordnung
                  TypeProtocolSettingsTiles(
                    settings: _protocol,
                    // Ionic: "Mehr erfahren" is hidden while creating.
                    showLearnMore: !_isNew,
                    hasPlaceholder: hasAgendaPlaceholder(_planFields),
                    onChanged: (v) => setState(() {
                      _protocol = v;
                      _hasChanges = true;
                    }),
                    onInsertPlaceholder: () => setState(() {
                      if (!hasAgendaPlaceholder(_planFields)) _planFields.add(_withRowUid(agendaPlaceholderField()));
                      _hasChanges = true;
                    }),
                  ),
                  // ATTENDANCE_SIGNOUT: place / navigation
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsEnableLocation),
                    subtitle: Text(
                      context.l10n.typeSettingsLocationHelper,
                    ),
                    value: _placeEnabled,
                    onChanged: (value) => setState(() {
                      _placeEnabled = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // DUTY: Dienstplan
            _buildDutySection(),
            const SizedBox(height: AppDimensions.paddingL),

            // Terminerinnerungen (SETTINGS2: Ionic reminders modal)
            _buildSection(
              title: context.l10n.typeSettingsEventReminders,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.typeSettingsEventReminder),
                    subtitle: Text(
                      context.l10n.typeSettingsEventReminderHelper,
                    ),
                    value: _notification,
                    onChanged: (value) => setState(() {
                      _notification = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  // Ionic: item "Erinnerungen konfigurieren" opening the sheet.
                  if (_notification)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.typeSettingsConfigureReminders),
                      subtitle: Text(_reminders.isNotEmpty
                          ? context.l10n.typeSettingsRemindersActive(_reminders.length)
                          : context.l10n.typeSettingsNoReminders),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_reminders.isNotEmpty)
                            IonBadge(
                              text: '${_reminders.length}/${TypeRemindersEditor.maxReminders}',
                              color: AppColors.primary,
                            ),
                          const Icon(Icons.chevron_right, color: AppColors.medium),
                        ],
                      ),
                      onTap: _openReminders,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Color Picker
            // UX_SETTINGS (WAVE 8): Ionic item (h2 Farbe, h3 hint, ellipse in
            // the colour at the end) opening a colour grid popover.
            _buildSection(
              title: context.l10n.typeSettingsAppearance,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.typeSettingsColor),
                subtitle: Text(context.l10n.typeSettingsColorHint),
                trailing: Icon(Icons.circle, color: ColorUtils.getColorForPicker(_color)),
                onTap: _pickColor,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Ionic "Filter": Relevante Gruppen + Zusatzfeld-Filter
            _buildFilterSection(),
            const SizedBox(height: AppDimensions.paddingL),

            // Ionic: "Ablaufplan" is always shown (default_plan is created
            // on load), with the "+" popover in the header.
            _buildPlanSection(),
            const SizedBox(height: AppDimensions.paddingL),

            // Checkliste (Template) – only while enabled (Ionic `@if (type.checklist)`)
            if (_checklistEnabled) ...[
              _buildChecklistSection(),
              const SizedBox(height: AppDimensions.paddingL),
            ],
            // Ionic: toggle "Checkliste aktivieren" (off = checklist null)
            _buildSection(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.typeSettingsEnableChecklist),
                subtitle: Text(context.l10n.typeSettingsChecklistHelper),
                value: _checklistEnabled,
                onChanged: (v) => setState(() {
                  _checklistEnabled = v;
                  _checklist = [];
                  _hasChanges = true;
                }),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            // ATTENDANCE_SIGNOUT: Anmeldefelder (adjustable at any time)
            _buildSection(
              title: context.l10n.typeSettingsSignupFields,
              child: RegistrationFieldsEditor(
                fields: _registrationFields,
                onChanged: (fields) => setState(() {
                  _registrationFields = fields;
                  _hasChanges = true;
                }),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            const SizedBox(height: 64),
          ],
        ),
      ),
    ),
    );
  }

  /// Ionic colour popover: a grid of ellipses, the selected one on a grey
  /// rounded background.
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
                    color: _color == colorName ? AppColors.medium : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.circle,
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

  Widget _nameField() {
    String? validate(String? value) {
      if (value == null || value.trim().isEmpty) {
        return context.l10n.typeSettingsEnterName;
      }
      return null;
    }

    if (!ionIsIos(context)) {
      return TextFormField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: '${context.l10n.typeSettingsName} *',
          hintText: context.l10n.typeSettingsFlutterNamePhShort,
        ),
        validator: validate,
      );
    }
    return IonInsetGroup(children: [
      IonStackedField(
        label: context.l10n.typeSettingsName,
        builder: (decoration) => TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoration,
          validator: validate,
        ),
      ),
    ]);
  }

  Widget _buildSection({String? title, required Widget child, Widget? action}) {
    // UX_SETTINGS (WAVE 8): iOS → ion-list-header + inset item group.
    if (ionIsIos(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) IonListHeader(title: title, action: action),
          IonInsetGroup(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IonIos.itemPaddingStart,
                4,
                IonIos.itemPaddingEnd,
                4,
              ),
              child: child,
            ),
          ]),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.medium,
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

    return _buildSection(
      title: context.l10n.typeSettingsDutyRoster,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
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
                _availableStatuses = {
                  ..._availableStatuses,
                  AttendanceStatus.neutral,
                  AttendanceStatus.present,
                  AttendanceStatus.excused,
                };
                _defaultStatus = AttendanceStatus.neutral;
              }
            }),
            contentPadding: EdgeInsets.zero,
          ),
          // Ionic openDutyHelp: "Mehr erfahren" → help article duty-setup
          // (not while creating a new type).
          if (!_isNew)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, color: AppColors.primary),
            title: Text(context.l10n.typeSettingsLearnMore, style: const TextStyle(color: AppColors.primary)),
            onTap: () => context.push('/settings/help/article/duty-setup'),
          ),
          if (_dutyMode) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.typeSettingsNeededPeople),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: context.l10n.attListLess,
                    onPressed: _dutyRequired <= 1 ? null : () => mark(() => _dutyRequired--),
                  ),
                  Text('$_dutyRequired'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: context.l10n.attListMore,
                    onPressed: () => mark(() => _dutyRequired++),
                  ),
                ],
              ),
            ),
            SwitchListTile.adaptive(
              title: Text(context.l10n.typeSettingsSelfAssign),
              subtitle: Text(context.l10n.typeSettingsSelfAssignHelper),
              value: _dutySelfSignup,
              onChanged: (v) => mark(() => _dutySelfSignup = v),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
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
                onChanged: (v) => mark(() => _dutyConfirmReminderDays = v),
              ),
            ),
            SwitchListTile.adaptive(
              title: Text(context.l10n.typeSettingsNotifyGroup),
              subtitle: Text(
                context.l10n.typeSettingsNotifyGroupHelper,
              ),
              value: _dutyNotifyUnderstaffed,
              onChanged: (v) => mark(() => _dutyNotifyUnderstaffed = v),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
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
              padding: EdgeInsets.only(top: AppDimensions.paddingS),
              child: Text(
                context.l10n.typeSettingsCircleHint,
                style: TextStyle(color: AppColors.medium, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// DUTY: after the first Termintyp with Dienst-Modus ask once whether
  /// "Meine Termine" should become the Dienstplan view.
  Future<void> _offerDutyView() async {
    final dutyRepo = ref.read(dutyRepositoryWithTenantProvider);
    if (!_dutyMode || _dutyModeAtLoad) return;
    _dutyModeAtLoad = true;
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null || tenant.dutyView) return;
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final ownId = widget.typeId ?? _createdId;
    if (types.any((t) => t.dutyMode && t.id != ownId)) return;
    final useIt = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.typeSettingsUseDutyView,
      message: context.l10n.typeSettingsUseDutyViewMessage,
      confirmText: context.l10n.typeSettingsUseIt,
      cancelText: context.l10n.typeSettingsNormalView,
    );
    if (!useIt || !mounted) return;
    try {
      await dutyRepo.setDutyView(true);
      // SOL_FIX19: only while the tenant the view was saved for is still the
      // current one (a switch during the dialog / save keeps the other one).
      await ref
          .read(currentTenantProvider.notifier)
          .updateTenantLocalIfCurrent(tenant.id, (current) => current.copyWith(dutyView: true));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.typeSettingsDutyViewActive);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.typeSettingsViewFailed);
    }
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

    return _buildSection(
      title: context.l10n.typeSettingsFilter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IonStackedValue(
            flush: true,
            label: context.l10n.typeSettingsRelevantGroups,
            value: groupNames.join(', '),
            helper: context.l10n.typeSettingsRelevantGroupsHelper,
            onTap: groups.isEmpty ? null : () => _pickRelevantGroups(groups),
          ),
          if (extraFields.isNotEmpty)
            IonStackedField(
              flush: true,
              label: context.l10n.typeSettingsExtraFilter,
              helper: context.l10n.typeSettingsExtraFilterHelper,
              builder: (decoration) => AppDropdownFormField<String?>(
                iosInterface: AppSelectInterface.alert,
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
            IonStackedField(
              flush: true,
              label: context.l10n.typeSettingsValue,
              builder: (decoration) => AppDropdownFormField<bool>(
                iosInterface: AppSelectInterface.alert,
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
            IonStackedField(
              flush: true,
              label: context.l10n.typeSettingsOption,
              builder: (decoration) => AppDropdownFormField<String>(
                iosInterface: AppSelectInterface.alert,
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
      ),
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

  /// Ionic reminders sheet (breakpoint 1, checkmark closes).
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
                  icon: const Icon(Icons.check),
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

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showAppTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 19, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 20, minute: 30)),
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
    return _buildSection(
      title: l10n.typeSettingsRunSheet,
      action: Builder(
        builder: (anchorContext) => IconButton(
          tooltip: l10n.typeSettingsAddField,
          icon: const Icon(Icons.add, color: AppColors.primary),
          onPressed: () => _showPlanAddMenu(anchorContext),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IonStackedField(
            flush: true,
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
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
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.typeSettingsStartShort),
            subtitle: _allDay ? Text(l10n.typeSettingsStartAllDay) : null,
            trailing: Text(
              start,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _allDay ? null : AppColors.medium,
                  ),
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
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.typeSettingsEnd),
              trailing: Text(
                _planEnd!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.medium),
              ),
            ),
        ],
      ),
    );
  }

  /// Ionic `ion-popover` at the "+": Feld, Notizfeld, Werk Platzhalter
  /// (not for general tenants), Tagesordnung Platzhalter (protocol types).
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
              const Icon(Icons.commit, color: AppColors.medium),
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
    return _buildSection(
      title: l10n.typeSettingsChecklist,
      action: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: IonBadge(text: '${_checklist.length}', color: AppColors.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_checklist.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _checklist.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
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
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.text),
                    subtitle: Text(_checklistDeadlineText(item.deadlineHours)),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.reorder, color: AppColors.medium),
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
                  const Icon(Icons.check_box_outlined, size: 32, color: AppColors.medium),
                  const SizedBox(height: 4),
                  Text(l10n.typeSettingsNoTodos, style: const TextStyle(color: AppColors.medium)),
                ],
              ),
            ),
          // Ionic: inline "Neues To-Do" + "Deadline" (action sheet) + button.
          IonStackedField(
            flush: true,
            label: l10n.typeSettingsNewTodo,
            hint: l10n.typeSettingsTodoPlaceholder,
            builder: (decoration) => TextField(
              controller: _newTodoController,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
              onChanged: (_) => setState(() {}),
            ),
          ),
          IonStackedField(
            flush: true,
            label: l10n.typeSettingsDeadline,
            // Own Form: a deadline for a not yet added to-do is no change of
            // the type (Ionic compares only the type).
            builder: (decoration) => Form(
              child: AppDropdownFormField<int?>(
                iosInterface: AppSelectInterface.actionSheet,
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
            IonStackedField(
              flush: true,
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
              icon: const Icon(Icons.add_circle_outline),
              label: IonButtonLabel(l10n.typeSettingsAddTodo),
            ),
          ),
        ],
      ),
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

  Future<void> _onBackPressed() async {
    if (_hasChanges) {
      final result = await showAppDialog<String>(
        context: context,
        builder: (context) => AppAlertDialog(
          title: Text(context.l10n.rolePermUnsaved),
          content: Text(context.l10n.rolePermUnsavedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(context.l10n.rolePermDiscard),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      );

      if (result == null || result == 'cancel') return;
      if (result == 'save') {
        await _save();
      }
    }

    if (mounted) {
      context.pop();
    }
  }

  /// Ionic `dismissModal` (isNew): once a name was entered ask
  /// "Änderungen verwerfen?", otherwise close right away.
  Future<void> _closeNew() async {
    // Während des Anlegens gesperrt: der Insert läuft schon.
    if (_isCreating) return;
    if (_hasNewInput) {
      final discard = await DialogHelper.showConfirmation(
        context,
        title: context.l10n.typeSettingsDiscardChanges,
        message: context.l10n.typeSettingsDiscardMessage,
        confirmText: context.l10n.rolePermDiscard,
        cancelText: context.l10n.commonCancel,
        isDestructive: true,
      );
      if (!discard || !mounted || _isCreating) return;
    }
    // pop() ignores the PopScope; the unload warning goes with the modal.
    setUnloadWarning(this, false);
    Navigator.of(context).pop(false);
  }

  /// Ionic `createType` (isNew): validate, insert with the tenant, success
  /// toast, the duty view offer, then close the modal.
  Future<void> _create() async {
    // Ionic validate(): name first, then at least two statuses.
    if (_nameController.text.trim().isEmpty) {
      ToastHelper.showError(context, context.l10n.typeSettingsEnterName);
      return;
    }
    if (_availableStatuses.length < 2) {
      ToastHelper.showError(context, context.l10n.typeSettingsTwoStatus);
      return;
    }

    // Provider-Zugriffe vor dem await holen: danach darf `ref` nicht mehr
    // angefasst werden (State könnte disposed sein).
    final notifier = ref.read(attendanceTypeNotifierProvider.notifier);
    final container = ProviderScope.containerOf(context);
    final data = _buildTypeData();

    setState(() => _isCreating = true);
    try {
      final created = await notifier.createTypeFromData(data);
      container.invalidate(protocolTypesProvider);
      container.invalidate(planAttendanceTypesProvider);
      if (!mounted) return;
      _createdId = created.id;
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.typeSettingsCreated);
      await _offerDutyView();
      if (!mounted) return;
      setUnloadWarning(this, false);
      Navigator.of(context).pop(true);
    } on DemoModeException {
      // DEMO_GUARD: the demo warning toast was already shown.
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsCreateFailed);
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // SETTINGS2: Ionic validate() — at least two available statuses
    if (_availableStatuses.length < 2) {
      ToastHelper.showError(
        context,
        context.l10n.typeSettingsTwoStatus,
      );
      return;
    }

    try {
      final updates = _buildTypeData();

      final updated = await ref
          .read(attendanceTypeNotifierProvider.notifier)
          .updateType(widget.typeId!, updates);
      ref.invalidate(protocolTypesProvider);
      ref.invalidate(planAttendanceTypesProvider);
      // LOGIC_SETTINGS: Ionic shows updateFailed when the save fails
      if (updated == null) {
        if (mounted) {
          ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
        }
        return;
      }

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.typeSettingsUpdated);
        setState(() => _hasChanges = false);
        await _offerDutyView();
      }
    } on DemoModeException {
      // DEMO_GUARD: the demo warning toast was already shown.
      return;
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
      }
    }
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
        // Ionic isNew: index 999 (end of the list).
        if (_isNew) 'index': _originalType?.index ?? 999,
      };
  }

  Future<void> _deleteType() async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.typeSettingsDeleteType,
      message: context.l10n.typeSettingsDeleteTypeMessage(_originalType!.name),
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
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
