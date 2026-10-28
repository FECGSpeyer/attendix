import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../organisation/presentation/widgets/type_default_org_plan_toggle.dart'; // ORG_PLANS

/// Predefined reminder time options
const _reminderPresets = [
  (hours: 1, label: '1 Stunde'),
  (hours: 2, label: '2 Stunden'),
  (hours: 24, label: '1 Tag'),
  (hours: 48, label: '2 Tage'),
  (hours: 168, label: '1 Woche'),
];

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
  final _customReminderController = TextEditingController();

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
  List<int> _relevantGroups = [];
  Map<String, dynamic>? _additionalFieldsFilter;

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
      } catch (_) {}

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
        _visible = type.visible;
        _highlight = type.highlight;
        _hideName = type.hideName;
        _includeInAverage = type.includeInAverage;
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
    _customReminderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Anwesenheitstyp')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_originalType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Anwesenheitstyp')),
        body: const Center(child: Text('Typ nicht gefunden')),
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
            tooltip: 'Löschen',
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
                          'Wird in $_usageCount Termin(en) verwendet. Änderungen wirken sich auf bestehende Einträge aus.',
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
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'z.B. Probe, Konzert',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte einen Namen eingeben';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Color Picker
            _buildSection(
              title: 'Farbe',
              child: Wrap(
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
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // All-day toggle
            _buildSection(
              title: 'Ganztägig',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Ganztägiger Termin'),
                    subtitle: const Text('Keine Uhrzeit, nur Dauer in Tagen'),
                    value: _allDay,
                    onChanged: (value) => setState(() {
                      _allDay = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_allDay)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Text('Dauer: '),
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
                          const SizedBox(width: 8),
                          Text(_durationDays == 1 ? 'Tag' : 'Tage'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Time Settings (hidden when allDay)
            if (!_allDay) ...[
              _buildSection(
              title: 'Zeiten',
              child: Row(
                children: [
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.access_time, color: AppColors.primary),
                      title: Text(_formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0))),
                      subtitle: const Text('Beginn'),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: AppColors.medium),
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.access_time_filled, color: AppColors.primary),
                      title: Text(_formatTime(_endTime ?? const TimeOfDay(hour: 20, minute: 30))),
                      subtitle: const Text('Ende'),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            ], // end if (!_allDay)

            // Default Status
            _buildSection(
              title: 'Standard-Status',
              child: DropdownButtonFormField<AttendanceStatus>(
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
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Available Statuses
            _buildSection(
              title: 'Verfügbare Status',
              child: Column(
                children: AttendanceStatus.values.map((status) {
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
                }).toList(),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Options
            _buildSection(
              title: 'Optionen',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Mit Programm/Werke'),
                    subtitle: const Text('Songs können diesem Typ zugeordnet werden'),
                    value: _manageSongs,
                    onChanged: (value) => setState(() {
                      _manageSongs = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Sichtbar'),
                    subtitle: const Text('In der Auswahl anzeigen'),
                    value: _visible,
                    onChanged: (value) => setState(() {
                      _visible = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Hervorheben'),
                    subtitle: const Text('Visuell hervorheben'),
                    value: _highlight,
                    onChanged: (value) => setState(() {
                      _highlight = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Name verbergen'),
                    subtitle: const Text('Nur Datum anzeigen'),
                    value: _hideName,
                    onChanged: (value) => setState(() {
                      _hideName = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('In Durchschnitt einbeziehen'),
                    subtitle: const Text('Für Anwesenheitsstatistiken berücksichtigen'),
                    value: _includeInAverage,
                    onChanged: (value) => setState(() {
                      _includeInAverage = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
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
                title: 'Ablaufplan-Vorlage',
                child: Column(
                  children: [
                    // Planning title
                    TextFormField(
                      controller: _planningTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Ablaufplan-Titel',
                        hintText: 'z.B. Probenplan',
                      ),
                      onChanged: (value) {
                        _planningTitle = value;
                        _hasChanges = true;
                      },
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
                          return ListTile(
                            key: ValueKey('plan-field-${field['id']}'),
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                            title: Text(
                              field['name'] as String? ?? '',
                              style: isSongPlaceholder
                                  ? const TextStyle(fontStyle: FontStyle.italic)
                                  : null,
                            ),
                            subtitle: Text('${field['time'] ?? '0'} Min.'),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setState(() {
                                _planFields.removeAt(index);
                                _hasChanges = true;
                              }),
                            ),
                            onTap: () => _editPlanField(index),
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
                              'Gesamt: ${_totalPlanMinutes()} Min.',
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
                            label: const Text('Feld'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addSongPlaceholder,
                            icon: const Icon(Icons.music_note, size: 18),
                            label: const Text('Werk'),
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

            // Terminerinnerungen
            _buildSection(
              title: 'Erinnerungen',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Erinnerungen aktivieren'),
                    subtitle: const Text('Vor dem Termin erinnern'),
                    value: _notification,
                    onChanged: (value) => setState(() {
                      _notification = value;
                      _hasChanges = true;
                    }),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_notification) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reminderPresets.map((preset) {
                        final isSelected = _reminders.contains(preset.hours);
                        return FilterChip(
                          label: Text(preset.label),
                          selected: isSelected,
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _reminders.add(preset.hours);
                              _reminders.sort();
                            } else {
                              _reminders.remove(preset.hours);
                            }
                            _hasChanges = true;
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Custom reminder
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customReminderController,
                            decoration: const InputDecoration(
                              labelText: 'Eigene (Stunden)',
                              hintText: 'z.B. 72',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (value) {
                              final hours = int.tryParse(value);
                              if (hours != null && hours > 0 && !_reminders.contains(hours)) {
                                setState(() {
                                  _reminders.add(hours);
                                  _reminders.sort();
                                  _hasChanges = true;
                                  _customReminderController.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_reminders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          children: _reminders.map((hours) {
                            return Chip(
                              label: Text(_formatReminderHours(hours)),
                              onDeleted: () => setState(() {
                                _reminders.remove(hours);
                                _hasChanges = true;
                              }),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),

            // Checkliste (Template)
            _buildSection(
              title: 'Checkliste',
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
                        return ListTile(
                          key: ValueKey('checklist-${item.id}'),
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Text(item.text),
                          subtitle: item.deadlineHours != null
                              ? Text('Frist: ${_formatReminderHours(item.deadlineHours!)} vorher')
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() {
                              _checklist.removeAt(index);
                              _hasChanges = true;
                            }),
                          ),
                          onTap: () => _editChecklistItem(index),
                        );
                      },
                    ),
                  if (_checklist.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Keine To-Dos definiert',
                        style: TextStyle(color: AppColors.medium),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _addChecklistItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('To-Do hinzufügen'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.paddingXL),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: ElevatedButton(
            onPressed: _hasChanges ? _save : null,
            child: const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingM),
              child: Text('Speichern'),
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

  Widget _buildRelevantGroupsSection() {
    final groupsAsync = ref.watch(groupsProvider);

    return _buildSection(
      title: 'Relevante Gruppen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leer = gilt für alle Gruppen',
            style: TextStyle(fontSize: 12, color: AppColors.medium),
          ),
          const SizedBox(height: 8),
          groupsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Fehler: $e'),
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
      title: 'Zusatzfeld-Filter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nur Spieler mit diesem Zusatzfeld-Wert einbeziehen',
            style: TextStyle(fontSize: 12, color: AppColors.medium),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: selectedFieldId,
            decoration: const InputDecoration(
              labelText: 'Zusatzfeld',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Kein Filter'),
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
              decoration: const InputDecoration(
                labelText: 'Wert',
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
    switch (status) {
      case AttendanceStatus.present:
        return 'Anwesend';
      case AttendanceStatus.absent:
        return 'Abwesend';
      case AttendanceStatus.excused:
        return 'Entschuldigt';
      case AttendanceStatus.late:
        return 'Verspätet';
      case AttendanceStatus.lateExcused:
        return 'Verspätet (entsch.)';
      case AttendanceStatus.neutral:
        return 'Neutral';
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
        'name': 'Werk ${index + 1}',
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
          title: Text(existing != null ? 'Feld bearbeiten' : 'Neues Feld'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bezeichnung',
                  hintText: 'z.B. Einspielen, Pause',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dauer (Minuten)',
                  hintText: 'z.B. 10',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
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
              child: const Text('OK'),
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
          title: Text(existing != null ? 'To-Do bearbeiten' : 'Neues To-Do'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Aufgabe',
                  hintText: 'z.B. Noten vorbereiten',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deadlineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Frist (Stunden vorher, optional)',
                  hintText: 'z.B. 24 für 1 Tag',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
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
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      textCtrl.dispose();
      deadlineCtrl.dispose();
    }
  }

  String _formatReminderHours(int hours) {
    if (hours < 24) return '$hours Std.';
    final days = hours ~/ 24;
    final remaining = hours % 24;
    if (remaining == 0) {
      if (days == 7) return '1 Woche';
      if (days == 14) return '2 Wochen';
      return '$days ${days == 1 ? 'Tag' : 'Tage'}';
    }
    return '$days ${days == 1 ? 'Tag' : 'Tage'} $remaining Std.';
  }

  Future<void> _onBackPressed() async {
    if (_hasChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ungespeicherte Änderungen'),
          content: const Text('Du hast ungespeicherte Änderungen. Was möchtest du tun?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Verwerfen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Text('Speichern'),
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

    try {
      final updates = {
        'name': _nameController.text.trim(),
        'start_time': _allDay ? null : _formatTime(_startTime ?? const TimeOfDay(hour: 19, minute: 0)),
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
        'relevant_groups': _relevantGroups.isNotEmpty ? _relevantGroups : null,
        'additional_fields_filter': _additionalFieldsFilter,
      };

      await ref.read(attendanceTypeNotifierProvider.notifier).updateType(widget.typeId, updates);

      if (mounted) {
        ToastHelper.showSuccess(context, 'Änderungen gespeichert');
        setState(() => _hasChanges = false);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Speichern: $e');
      }
    }
  }

  Future<void> _deleteType() async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Typ löschen',
      message:
          'Möchtest du "${_originalType!.name}" wirklich löschen? Alle Anwesenheiten dieses Typs werden ebenfalls gelöscht.',
      confirmText: 'Löschen',
      cancelText: 'Abbrechen',
    );

    if (!confirmed) return;

    try {
      final success = await ref.read(attendanceTypeNotifierProvider.notifier).deleteType(widget.typeId);

      if (success && mounted) {
        ToastHelper.showSuccess(context, 'Typ gelöscht');
        context.pop();
      } else if (!success && mounted) {
        ToastHelper.showError(context, 'Fehler beim Löschen');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Löschen: $e');
      }
    }
  }
}
