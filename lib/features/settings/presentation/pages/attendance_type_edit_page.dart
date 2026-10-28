import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../shared/widgets/common/swipe_actions.dart';
import '../../../../core/providers/team_org_providers.dart'; // PROTOCOL
import '../widgets/type_protocol_settings.dart'; // PROTOCOL
import '../widgets/registration_fields_editor.dart'; // ATTENDANCE_SIGNOUT
import '../widgets/type_reminders_editor.dart'; // SETTINGS2
import '../../../organisation/presentation/widgets/type_default_org_plan_toggle.dart'; // ORG_PLANS
import '../../../../l10n/l10n.dart';


/// Attendance Type Edit Page
///
/// Edit an existing attendance type or create a new one.
class AttendanceTypeEditPage extends ConsumerStatefulWidget {
  final String typeId;

  const AttendanceTypeEditPage({
    super.key,
    required this.typeId,
  });

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
  bool _placeEnabled = false; // ATTENDANCE_SIGNOUT
  List<RegistrationField> _registrationFields = []; // ATTENDANCE_SIGNOUT
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
  List<Map<String, dynamic>> _planFields = [];
  String _planningTitle = '';
  bool _planningPrefixInstanceName = false; // SETTINGS2
  List<int> _relevantGroups = [];
  Map<String, dynamic>? _additionalFieldsFilter;
  TypeProtocolSettings _protocol = const TypeProtocolSettings(); // PROTOCOL

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

  @override
  void initState() {
    super.initState();
    _loadType();
  }

  Future<void> _loadType() async {
    final type = await ref.read(attendanceTypeByIdProvider(widget.typeId).future);

    if (type != null && mounted) {
      // Fetch usage count
      try {
        final repo = ref.read(attendanceTypeRepositoryWithTenantProvider);
        _usageCount = await repo.getAttendanceCountForType(widget.typeId);
        // SETTINGS2: "Instanz-Name vor Werken"
        _planningPrefixInstanceName =
            await repo.getPlanningPrefixInstanceName(widget.typeId);
      } catch (_) {}

      // PROTOCOL: enable_protocol etc. are not part of the AttendanceType model
      try {
        final types = await ref.read(protocolRepositoryWithTenantProvider).getProtocolTypes();
        _protocol = TypeProtocolSettings.fromType(types.where((t) => t.id == widget.typeId).firstOrNull);
      } catch (_) {}
      if (!mounted) return;

      setState(() {
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
        _placeEnabled = type.placeEnabled; // ATTENDANCE_SIGNOUT
        _registrationFields = List<RegistrationField>.from(type.registrationFields ?? []); // ATTENDANCE_SIGNOUT
        _visible = type.visible;
        _highlight = type.highlight;
        _hideName = type.hideName;
        _includeInAverage = type.includeInAverage;
        // DUTY
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
        _planningTitle = type.planningTitle ?? '';
        _planningTitleController.text = _planningTitle;
        _planFields = _parsePlanFields(type.defaultPlan);
        _relevantGroups = List<int>.from(type.relevantGroups ?? []);
        _additionalFieldsFilter = type.additionalFieldsFilter != null
            ? Map<String, dynamic>.from(type.additionalFieldsFilter!)
            : null;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationDaysController.dispose();
    _planningTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.typeSettingsFlutterTypeTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_originalType == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.typeSettingsFlutterTypeTitle)),
        body: Center(child: Text(context.l10n.typeSettingsFlutterNotFound)),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_originalType!.name),
          leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBackPressed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.commonDelete,
            onPressed: _deleteType,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() => _hasChanges = true),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
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
            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '${context.l10n.typeSettingsName} *',
                hintText: context.l10n.typeSettingsFlutterNamePhShort,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.typeSettingsEnterName;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // UX_SETTINGS: Ionic "Optionen" (type.page.html order): Aktiv, verfügbare
            // Status, Standard-Status, Werke verwalten, Ganztägig/Zeiten, Name
            // verbergen, Hervorheben, Für Ø berücksichtigen, Protokoll, Ort.
            _buildSection(
              title: context.l10n.typeSettingsOptions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
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
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(context.l10n.typeSettingsAvailableStatus, style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ...AttendanceStatus.values.map((status) {
                    return CheckboxListTile(
                      title: Text(_getStatusName(status)),
                      value: _availableStatuses.contains(status),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _availableStatuses.add(status);
                          } else {
                            // Don't allow removing last status
                            if (_availableStatuses.length > 1) {
                              _availableStatuses.remove(status);
                              // Reset default if removed (Issue #21 - safe .first)
                              if (_defaultStatus == status) {
                                _defaultStatus = _availableStatuses.firstOrNull ?? AttendanceStatus.present;
                              }
                            }
                          }
                          _hasChanges = true;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                  DropdownButtonFormField<AttendanceStatus>(
                    decoration: InputDecoration(labelText: context.l10n.typeSettingsDefaultStatus),
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
                    items: _availableStatuses
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusName(status)),
                            ))
                        .toList(),
                  ),
                  SwitchListTile(
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
                  SwitchListTile(
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
                  SwitchListTile(
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
                  SwitchListTile(
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
                  SwitchListTile(
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
                    hasPlaceholder: hasAgendaPlaceholder(_planFields),
                    onChanged: (v) => setState(() {
                      _protocol = v;
                      _hasChanges = true;
                    }),
                    onInsertPlaceholder: () => setState(() {
                      if (!hasAgendaPlaceholder(_planFields)) _planFields.add(agendaPlaceholderField());
                      _hasChanges = true;
                    }),
                  ),
                  // ATTENDANCE_SIGNOUT: place / navigation
                  SwitchListTile(
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
                  SwitchListTile(
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
                  if (_notification)
                    TypeRemindersEditor(
                      reminders: _reminders,
                      onChanged: (list) => setState(() {
                        _reminders = list;
                        _hasChanges = true;
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Color Picker
            _buildSection(
              title: context.l10n.typeSettingsAppearance,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.typeSettingsColor, style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ColorUtils.availableColors.map((colorName) {
                  final color = ColorUtils.getColorForPicker(colorName);
                  final isSelected = _color == colorName;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _color = colorName;
                      _hasChanges = true;
                    }),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.typeSettingsColorHint,
                    style: TextStyle(fontSize: 12, color: AppColors.medium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Relevant Groups (B8-009)
            _buildRelevantGroupsSection(),
            const SizedBox(height: AppDimensions.paddingL),

            // Additional Fields Filter (B8-010)
            _buildAdditionalFieldsFilterSection(),
            const SizedBox(height: AppDimensions.paddingL),

            // Ablaufplan (Default Plan) - only when manageSongs is enabled
            if (_manageSongs) ...[
              _buildSection(
                title: context.l10n.typeSettingsRunSheet,
                child: Column(
                  children: [
                    // Planning title
                    TextFormField(
                      controller: _planningTitleController,
                      decoration: InputDecoration(
                        labelText: context.l10n.typeSettingsPlanHeading,
                        hintText: context.l10n.typeSettingsFlutterPlanHeadingPh,
                      ),
                      onChanged: (value) {
                        _planningTitle = value;
                        _hasChanges = true;
                      },
                    ),
                    // SETTINGS2: Ionic "Instanz-Name vor Werken" (not for general tenants)
                    if (ref.watch(currentTenantProvider)?.type != 'general')
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.typeSettingsTenantNameBefore),
                        subtitle: Text(
                          context.l10n.typeSettingsTenantNameHelper,
                        ),
                        value: _planningPrefixInstanceName,
                        onChanged: (v) => setState(() {
                          _planningPrefixInstanceName = v;
                          _hasChanges = true;
                        }),
                      ),
                    // SETTINGS2: plan start time for all-day types (Ionic type.start_time)
                    if (_allDay)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.typeSettingsStartShort),
                        subtitle: Text(context.l10n.typeSettingsStartAllDay),
                        trailing: Text(
                          _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0)),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        onTap: () => _pickTime(isStart: true),
                      ),
                    const SizedBox(height: 12),
                    // Plan fields list
                    if (_planFields.isNotEmpty)
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _planFields.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _planFields.removeAt(oldIndex);
                            _planFields.insert(newIndex, item);
                            _hasChanges = true;
                          });
                        },
                        itemBuilder: (context, index) {
                          final field = _planFields[index];
                          final isSongPlaceholder = (field['id'] as String? ?? '').startsWith('song-placeholder');
                          // Ionic: ion-item-sliding, expandable trash option
                          // (full swipe deletes), reorder handle at the end.
                          return SwipeActions.delete(
                            key: ValueKey('plan-field-${field['id']}'),
                            fullSwipe: true,
                            onDelete: () => setState(() {
                              _planFields.removeAt(index);
                              _hasChanges = true;
                            }),
                            child: ListTile(
                              title: Text(
                                field['name'] as String? ?? '',
                                style: isSongPlaceholder
                                    ? const TextStyle(fontStyle: FontStyle.italic)
                                    : null,
                              ),
                              subtitle: Text(context.l10n.typeSettingsFlutterMinutes('${field['time'] ?? '0'}')),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              onTap: () => _editPlanField(index),
                            ),
                          );
                        },
                      ),
                    // Total duration
                    if (_planFields.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              context.l10n.typeSettingsFlutterTotalMinutes(_totalPlanMinutes()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.medium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Add buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addPlanField,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(context.l10n.typeSettingsAddField),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addSongPlaceholder,
                            icon: const Icon(Icons.music_note, size: 18),
                            label: Text(context.l10n.typeSettingsSongPlaceholder),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
            ],
            // ORG_PLANS: Termine of this type start as org plan
            TypeDefaultOrgPlanToggle(typeId: widget.typeId),

            // Checkliste (Template)
            _buildSection(
              title: context.l10n.typeSettingsChecklist,
              child: Column(
                children: [
                  if (_checklist.isNotEmpty)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                          key: ValueKey('checklist-${item.id}'),
                          onDelete: () => setState(() {
                            _checklist.removeAt(index);
                            _hasChanges = true;
                          }),
                          child: ListTile(
                            title: Text(item.text),
                            subtitle: Text(_checklistDeadlineText(item.deadlineHours)),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                            onTap: () => _editChecklistItem(index),
                          ),
                        );
                      },
                    ),
                  if (_checklist.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        context.l10n.typeSettingsNoTodos,
                        style: TextStyle(color: AppColors.medium),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _addChecklistItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.typeSettingsAddTodo),
                  ),
                ],
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
            const SizedBox(height: AppDimensions.paddingXL),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: ElevatedButton(
            onPressed: _hasChanges ? _save : null,
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingM),
              child: Text(context.l10n.commonSave),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.medium,
          ),
        ),
        const SizedBox(height: 8),
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
          SwitchListTile(
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
            SwitchListTile(
              title: Text(context.l10n.typeSettingsSelfAssign),
              subtitle: Text(context.l10n.typeSettingsSelfAssignHelper),
              value: _dutySelfSignup,
              onChanged: (v) => mark(() => _dutySelfSignup = v),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.typeSettingsRemindUnconfirmed),
              trailing: DropdownButton<int?>(
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
            SwitchListTile(
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
              trailing: DropdownButton<int?>(
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
    if (!_dutyMode || _dutyModeAtLoad) return;
    _dutyModeAtLoad = true;
    final tenant = ref.read(currentTenantProvider);
    if (tenant == null || tenant.dutyView) return;
    final types = ref.read(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    if (types.any((t) => t.dutyMode && t.id != widget.typeId)) return;
    final useIt = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.typeSettingsUseDutyView,
      message: context.l10n.typeSettingsUseDutyViewMessage,
      confirmText: context.l10n.typeSettingsUseIt,
      cancelText: context.l10n.typeSettingsNormalView,
    );
    if (!useIt || !mounted) return;
    try {
      await ref.read(dutyRepositoryWithTenantProvider).setDutyView(true);
      await ref.read(currentTenantProvider.notifier).setTenantLocal(tenant.copyWith(dutyView: true));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.typeSettingsDutyViewActive);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.typeSettingsViewFailed);
    }
  }

  Widget _buildRelevantGroupsSection() {
    final groupsAsync = ref.watch(groupsProvider);

    return _buildSection(
      title: context.l10n.typeSettingsRelevantGroups,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.typeSettingsFlutterAllGroupsHint,
            style: TextStyle(fontSize: 12, color: AppColors.medium),
          ),
          const SizedBox(height: 8),
          groupsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(context.l10n.settingsFlutterErrorDetail(e)),
            data: (groups) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: groups.where((g) => g.id != null).map((group) {
                final isSelected = _relevantGroups.contains(group.id);
                return FilterChip(
                  label: Text(group.shortName ?? group.name),
                  selected: isSelected,
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _relevantGroups.add(group.id!);
                    } else {
                      _relevantGroups.remove(group.id!);
                    }
                    _hasChanges = true;
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalFieldsFilterSection() {
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = (tenant?.additionalFields ?? [])
        .where((f) => f.type == 'select')
        .toList();

    if (extraFields.isEmpty) return const SizedBox.shrink();

    final selectedFieldId = _additionalFieldsFilter?['key'] as String?;
    final selectedOption = _additionalFieldsFilter?['option'] as String?;
    final selectedField = extraFields.where((f) => f.id == selectedFieldId).firstOrNull;
    final options = selectedField?.options ?? [];

    return _buildSection(
      title: context.l10n.typeSettingsExtraFilter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.typeSettingsFlutterExtraFilterHint,
            style: TextStyle(fontSize: 12, color: AppColors.medium),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: selectedFieldId,
            decoration: InputDecoration(
              labelText: context.l10n.typeSettingsFlutterExtraField,
              isDense: true,
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(context.l10n.typeSettingsNoFilter),
              ),
              ...extraFields.map((f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(f.name),
                  )),
            ],
            onChanged: (value) => setState(() {
              if (value == null) {
                _additionalFieldsFilter = null;
              } else {
                final field = extraFields.where((f) => f.id == value).firstOrNull;
                _additionalFieldsFilter = {
                  'key': value,
                  'option': field?.options?.firstOrNull ?? '',
                };
              }
              _hasChanges = true;
            }),
          ),
          if (selectedFieldId != null && options.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: options.contains(selectedOption) ? selectedOption : options.firstOrNull,
              decoration: InputDecoration(
                labelText: context.l10n.typeSettingsValue,
                isDense: true,
              ),
              items: options
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (value) => setState(() {
                _additionalFieldsFilter = {
                  'key': selectedFieldId,
                  'option': value,
                };
                _hasChanges = true;
              }),
            ),
          ],
        ],
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
        return l10n.commonStatusLateShort;
      case AttendanceStatus.lateExcused:
        return l10n.generalSettingsLateExcusedShort;
      case AttendanceStatus.neutral:
        return l10n.generalSettingsNeutral;
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 19, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 20, minute: 30)),
    );
    if (time != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = time;
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

  int _totalPlanMinutes() {
    return _planFields.fold<int>(0, (sum, f) {
      return sum + (int.tryParse('${f['time'] ?? '0'}') ?? 0);
    });
  }

  Future<void> _addPlanField() async {
    final result = await _showPlanFieldDialog();
    if (result != null) {
      setState(() {
        _planFields.add(result);
        _hasChanges = true;
      });
    }
  }

  Future<void> _addSongPlaceholder() async {
    final index = _planFields.where((f) =>
        (f['id'] as String? ?? '').startsWith('song-placeholder')).length;
    setState(() {
      _planFields.add({
        'id': 'song-placeholder-$index',
        'name': context.l10n.typeSettingsSongPlaceholderN(index + 1),
        'time': '20',
      });
      _hasChanges = true;
    });
  }

  Future<void> _editPlanField(int index) async {
    final result = await _showPlanFieldDialog(existing: _planFields[index]);
    if (result != null) {
      setState(() {
        _planFields[index] = result;
        _hasChanges = true;
      });
    }
  }

  Future<Map<String, dynamic>?> _showPlanFieldDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final timeCtrl = TextEditingController(text: existing?['time'] as String? ?? '10');
    final id = existing?['id'] as String? ?? 'custom-${DateTime.now().millisecondsSinceEpoch}';

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(existing != null ? context.l10n.typeSettingsEditField : context.l10n.typeSettingsFlutterNewField),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.shiftsLabel,
                  hintText: context.l10n.typeSettingsFlutterFieldNamePh,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.typeSettingsFlutterDurationMinutes,
                  hintText: context.l10n.typeSettingsFlutterDurationPh,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context, {
                  'id': id,
                  'name': name,
                  'time': timeCtrl.text.trim().isEmpty ? '0' : timeCtrl.text.trim(),
                });
              },
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
      timeCtrl.dispose();
    }
  }

  Future<void> _addChecklistItem() async {
    final result = await _showChecklistItemDialog();
    if (result != null) {
      setState(() {
        _checklist.add(result);
        _hasChanges = true;
      });
    }
  }

  Future<void> _editChecklistItem(int index) async {
    final result = await _showChecklistItemDialog(existing: _checklist[index]);
    if (result != null) {
      setState(() {
        _checklist[index] = result;
        _hasChanges = true;
      });
    }
  }

  Future<ChecklistItem?> _showChecklistItemDialog({ChecklistItem? existing}) async {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    final deadlineCtrl = TextEditingController(
      text: existing?.deadlineHours?.toString() ?? '',
    );

    try {
      return await showDialog<ChecklistItem>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(existing != null ? context.l10n.typeSettingsEditTodo : context.l10n.typeSettingsNewTodo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.tasksTask,
                  hintText: context.l10n.typeSettingsFlutterTodoPh,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deadlineCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.typeSettingsFlutterDeadlineLabel,
                  hintText: context.l10n.typeSettingsFlutterDeadlinePh,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final text = textCtrl.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, ChecklistItem(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  text: text,
                  deadlineHours: int.tryParse(deadlineCtrl.text.trim()),
                ));
              },
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      );
    } finally {
      textCtrl.dispose();
      deadlineCtrl.dispose();
    }
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
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
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
      final updates = {
        'name': _nameController.text.trim(),
        // SETTINGS2: for all-day types start_time is the plan start (Ionic)
        'start_time': _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0)),
        'end_time': _allDay ? null : _formatTime(_endTime ?? const TimeOfDay(hour: 20, minute: 30)),
        'default_status': _defaultStatus.value,
        'available_statuses': _availableStatuses.map((s) => s.value).toList(),
        'manage_songs': _manageSongs,
        'visible': _visible,
        'highlight': _highlight,
        'hide_name': _hideName,
        'include_in_average': _includeInAverage,
        'color': _color,
        'all_day': _allDay,
        'duration_days': _allDay ? _durationDays : null,
        'notification': _notification,
        'reminders': _reminders.isNotEmpty ? _reminders : null,
        'checklist': _checklist.isNotEmpty
            ? _checklist.map((item) => item.toJson()).toList()
            : null,
        'default_plan': _planFields.isNotEmpty
            ? {'fields': _planFields}
            : null,
        'planning_title': _planningTitle.isNotEmpty ? _planningTitle : null,
        'planning_prefix_instance_name': _planningPrefixInstanceName, // SETTINGS2
        'relevant_groups': _relevantGroups.isNotEmpty ? _relevantGroups : null,
        'additional_fields_filter': _additionalFieldsFilter,
        // ATTENDANCE_SIGNOUT
        'place_enabled': _placeEnabled,
        'registration_fields': _registrationFields.map((f) => f.toJson()).toList(),
        // DUTY
        'duty_mode': _dutyMode,
        'duty_required': _dutyRequired < 1 ? 1 : _dutyRequired,
        'duty_self_signup': _dutySelfSignup,
        'duty_confirm_reminder_days': _dutyConfirmReminderDays,
        'duty_notify_understaffed': _dutyNotifyUnderstaffed,
        'duty_urgent_hours': _dutyUrgentHours,
        ..._protocol.toUpdate(), // PROTOCOL
      };

      await ref.read(attendanceTypeNotifierProvider.notifier).updateType(widget.typeId, updates);
      ref.invalidate(protocolTypesProvider); // PROTOCOL

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.typeSettingsUpdated);
        setState(() => _hasChanges = false);
        await _offerDutyView(); // DUTY
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.typeSettingsUpdateFailed);
      }
    }
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
      final success = await ref.read(attendanceTypeNotifierProvider.notifier).deleteType(widget.typeId);

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
