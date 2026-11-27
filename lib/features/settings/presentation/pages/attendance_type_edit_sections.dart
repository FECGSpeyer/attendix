part of 'attendance_type_edit_page.dart';

extension _AttendanceTypeEditSections on _AttendanceTypeEditPageState {
  // DUTY: Dienstplan section (Ionic type.page "Dienstplan")
  Widget _buildDutySection() {
    void mark(VoidCallback fn) => _update(() {
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
                onChanged: (value) => _update(() {
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
                onChanged: (value) => _update(() {
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
                onChanged: (value) => _update(() {
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
    _update(() {
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
                    _update(() {
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
      _update(() {
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
}

/// Ionic type.page `attendanceStatuses`: Verspätet (entsch.) is never offered.
const _ionicStatusOptions = [
  AttendanceStatus.neutral,
  AttendanceStatus.present,
  AttendanceStatus.absent,
  AttendanceStatus.excused,
  AttendanceStatus.late,
];

/// Display order: Ionic options, then a status stored by older Flutter
/// versions (kept, not offered).
const _statusOrder = [..._ionicStatusOptions, AttendanceStatus.lateExcused];
