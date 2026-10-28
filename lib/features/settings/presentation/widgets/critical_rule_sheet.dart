import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/tenant/tenant.dart';

/// Bottom sheet for creating or editing a critical rule
class CriticalRuleSheet extends StatefulWidget {
  const CriticalRuleSheet({
    super.key,
    this.rule,
    required this.attendanceTypes,
    required this.onSave,
  });

  /// The rule to edit, or null for creating a new rule
  final CriticalRule? rule;

  /// Available attendance types to select from
  final List<AttendanceType> attendanceTypes;

  /// Callback when the rule is saved
  final void Function(CriticalRule rule) onSave;

  @override
  State<CriticalRuleSheet> createState() => _CriticalRuleSheetState();
}

class _CriticalRuleSheetState extends State<CriticalRuleSheet> {
  final _nameController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _periodDaysController = TextEditingController();

  late List<String> _selectedTypeIds;
  late List<int> _selectedStatuses;
  late CriticalRuleThresholdType _thresholdType;
  late CriticalRulePeriodType _periodType;
  late CriticalRuleOperator _operator;
  late bool _enabled;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    if (rule != null) {
      _nameController.text = rule.name ?? '';
      _thresholdController.text = rule.thresholdValue.toString();
      _periodDaysController.text = (rule.periodDays ?? 30).toString();
      _selectedTypeIds = List.from(rule.attendanceTypeIds);
      _selectedStatuses = List.from(rule.statuses);
      _thresholdType = rule.thresholdType;
      _periodType = rule.periodType ?? CriticalRulePeriodType.days;
      _operator = rule.operator;
      _enabled = rule.enabled;
    } else {
      _thresholdController.text = '3';
      _periodDaysController.text = '30';
      _selectedTypeIds = widget.attendanceTypes.isNotEmpty
          ? [widget.attendanceTypes.first.id ?? '']
          : [];
      _selectedStatuses = [AttendanceStatus.absent.value];
      _thresholdType = CriticalRuleThresholdType.count;
      _periodType = CriticalRulePeriodType.days;
      _operator = CriticalRuleOperator.or;
      _enabled = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    _periodDaysController.dispose();
    super.dispose();
  }

  void _save() {
    // Validation
    // SETTINGS2: Ionic addCriticalRule validation. An empty type list means
    // "Alle Typen" (evaluate-critical-rules treats [] as every type).
    if (_selectedStatuses.isEmpty) {
      ToastHelper.showError(context, 'Bitte wähle mindestens einen Status aus.');
      return;
    }
    final threshold = int.tryParse(_thresholdController.text);
    if (threshold == null || threshold <= 0) {
      ToastHelper.showError(context, 'Der Schwellenwert muss größer als 0 sein.');
      return;
    }
    if (_periodType == CriticalRulePeriodType.days) {
      final days = int.tryParse(_periodDaysController.text);
      if (days == null || days <= 0) {
        ToastHelper.showError(context, 'Der Zeitraum muss größer als 0 sein.');
        return;
      }
    }

    final rule = CriticalRule(
      id: widget.rule?.id ?? const Uuid().v4(),
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      attendanceTypeIds: _selectedTypeIds,
      statuses: _selectedStatuses,
      thresholdType: _thresholdType,
      thresholdValue: threshold,
      periodType: _periodType,
      periodDays: _periodType == CriticalRulePeriodType.days
          ? int.tryParse(_periodDaysController.text) ?? 30
          : null,
      operator: _operator,
      enabled: _enabled,
    );

    widget.onSave(rule);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        top: AppDimensions.paddingM,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Regel bearbeiten' : 'Neue Problemfall-Regel',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Optional name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'z.B. "Zu oft abwesend"',
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Attendance types selection
            Text(
              'Anwesenheits-Typen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (_selectedTypeIds.isEmpty)
              Text(
                'Alle Typen',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppDimensions.paddingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.attendanceTypes.map((type) {
                final isSelected = _selectedTypeIds.contains(type.id);
                return FilterChip(
                  label: Text(type.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTypeIds.add(type.id ?? '');
                      } else {
                        _selectedTypeIds.remove(type.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Status selection
            Text(
              'Status (zählt als kritisch)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AttendanceStatus.absent,
                AttendanceStatus.late,
                AttendanceStatus.lateExcused,
              ].map((status) {
                final isSelected = _selectedStatuses.contains(status.value);
                return FilterChip(
                  label: Text(status.label),
                  selected: isSelected,
                  selectedColor: status.color.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedStatuses.add(status.value);
                      } else {
                        _selectedStatuses.remove(status.value);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Threshold type and value
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CriticalRuleThresholdType>(
                    value: _thresholdType,
                    decoration: const InputDecoration(
                      labelText: 'Schwellentyp',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: CriticalRuleThresholdType.count,
                        child: Text('Anzahl'),
                      ),
                      DropdownMenuItem(
                        value: CriticalRuleThresholdType.percentage,
                        child: Text('Prozent'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _thresholdType = v);
                    },
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: TextField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Wert',
                      suffixText: _thresholdType == CriticalRuleThresholdType.percentage
                          ? '%'
                          : 'x',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Period type
            DropdownButtonFormField<CriticalRulePeriodType>(
              value: _periodType,
              decoration: const InputDecoration(
                labelText: 'Zeitraum',
              ),
              items: const [
                DropdownMenuItem(
                  value: CriticalRulePeriodType.days,
                  child: Text('Letzte X Tage'),
                ),
                DropdownMenuItem(
                  value: CriticalRulePeriodType.season,
                  child: Text('Seit Saisonstart'),
                ),
                DropdownMenuItem(
                  value: CriticalRulePeriodType.allTime,
                  child: Text('Gesamte Zeit'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _periodType = v);
              },
            ),

            // Period days (only for days type)
            if (_periodType == CriticalRulePeriodType.days) ...[
              const SizedBox(height: AppDimensions.paddingM),
              TextField(
                controller: _periodDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Anzahl Tage',
                  suffixText: 'Tage',
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingM),

            // Operator
            Row(
              children: [
                Text(
                  'Verknüpfung mit anderen Regeln:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                SegmentedButton<CriticalRuleOperator>(
                  segments: const [
                    ButtonSegment(
                      value: CriticalRuleOperator.or,
                      label: Text('ODER'),
                    ),
                    ButtonSegment(
                      value: CriticalRuleOperator.and,
                      label: Text('UND'),
                    ),
                  ],
                  selected: {_operator},
                  onSelectionChanged: (v) {
                    setState(() => _operator = v.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              _operator == CriticalRuleOperator.or
                  ? 'Person ist kritisch, wenn EINE der Regeln zutrifft'
                  : 'Person ist kritisch, wenn ALLE Regeln zutreffen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.medium,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Enabled toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Regel aktiviert'),
              subtitle: const Text('Deaktivierte Regeln werden nicht ausgewertet'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Speichern' : 'Regel hinzufügen'),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );
  }
}
