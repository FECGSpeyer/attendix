import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Opens the rule editor. Classic design: the Ionic sheet modal
/// (`initialBreakpoint="1" [breakpoints]="[0, 1]"`, toolbar with the
/// ion-title only); the Beta design keeps its sheet.
Future<void> showCriticalRuleSheet(
  BuildContext context, {
  CriticalRule? rule,
  required List<AttendanceType> attendanceTypes,
  required void Function(CriticalRule rule) onSave,
}) {
  if (context.rdSkin == null) {
    return showIonSheet<void>(
      context,
      builder: (ctx, controller) => CriticalRuleSheet(
        rule: rule,
        attendanceTypes: attendanceTypes,
        onSave: onSave,
        scrollController: controller,
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    builder: (ctx) => CriticalRuleSheet(
      rule: rule,
      attendanceTypes: attendanceTypes,
      onSave: onSave,
    ),
  );
}

/// Bottom sheet for creating or editing a critical rule
class CriticalRuleSheet extends StatefulWidget {
  const CriticalRuleSheet({
    super.key,
    this.rule,
    required this.attendanceTypes,
    required this.onSave,
    this.scrollController,
  });

  /// Classic design: the controller of the breakpoint sheet; the title is
  /// then in the sheet toolbar.
  final ScrollController? scrollController;

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
    } else {
      _thresholdController.text = '3';
      _periodDaysController.text = '30';
      // Ionic getEmptyCriticalRule: no types (= "Alle Typen"), no status.
      _selectedTypeIds = [];
      _selectedStatuses = [];
      _thresholdType = CriticalRuleThresholdType.count;
      _periodType = CriticalRulePeriodType.days;
      _operator = CriticalRuleOperator.or;
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
      ToastHelper.showError(context, context.l10n.generalSettingsSelectStatus);
      return;
    }
    // Ionic number input: decimals allowed (e.g. 33.5 %); a decimal comma
    // from the German keyboard counts as the decimal point.
    final threshold =
        num.tryParse(_thresholdController.text.trim().replaceAll(',', '.'));
    // NaN/Infinity would pass `<= 0` but break the JSON encoding on save.
    if (threshold == null || !threshold.isFinite || threshold <= 0) {
      ToastHelper.showError(context, context.l10n.generalSettingsThresholdPositive);
      return;
    }
    if (_periodType == CriticalRulePeriodType.days) {
      final days = int.tryParse(_periodDaysController.text);
      if (days == null || days <= 0) {
        ToastHelper.showError(context, context.l10n.generalSettingsPeriodPositive);
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
      // DB_REVIEW_REST (M3): Ionic + edge function `evaluate-critical-rules`
      // have no `enabled` flag; every saved rule is active.
      enabled: true,
    );

    widget.onSave(rule);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final classic = widget.scrollController != null;
    final title = _isEditing ? context.l10n.generalSettingsFlutterEditRule : context.l10n.generalSettingsNewRule;
    final form = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (!classic) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
            ],

            // Optional name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.generalSettingsNameOptional,
                hintText: context.l10n.generalSettingsRulePh,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Ionic ion-select multiple "Anwesenheits-Typen" (placeholder
            // "Alle Typen") and "Status".
            AppMultiSelectFormField<String>(
              decoration: InputDecoration(labelText: context.l10n.generalSettingsAttTypes),
              placeholder: context.l10n.generalSettingsAllTypes,
              options: [
                for (final type in widget.attendanceTypes)
                  if (type.id != null) AppSelectOption(value: type.id!, label: type.name),
              ],
              values: _selectedTypeIds,
              onChanged: (v) => setState(() => _selectedTypeIds = v),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            AppMultiSelectFormField<int>(
              decoration: InputDecoration(labelText: context.l10n.agendaStatus),
              options: [
                for (final status in criticalRuleStatuses)
                  AppSelectOption(value: status.value, label: criticalRuleStatusName(status.value, context.l10n)),
              ],
              values: _selectedStatuses,
              onChanged: (v) => setState(() => _selectedStatuses = v),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Threshold type and value
            Row(
              children: [
                Expanded(
                  child: AppDropdownFormField<CriticalRuleThresholdType>(
                    iosInterface: AppSelectInterface.alert,
                    value: _thresholdType,
                    decoration: InputDecoration(
                      labelText: context.l10n.generalSettingsThresholdType,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: CriticalRuleThresholdType.count,
                        child: Text(context.l10n.generalSettingsCount),
                      ),
                      DropdownMenuItem(
                        value: CriticalRuleThresholdType.percentage,
                        child: Text(context.l10n.generalSettingsPercent),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    // Ionic general.page: label "Anzahl" / "Prozent"
                    decoration: InputDecoration(
                      labelText: _thresholdType == CriticalRuleThresholdType.percentage
                          ? context.l10n.generalSettingsPercent
                          : context.l10n.generalSettingsCount,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Period type
            AppDropdownFormField<CriticalRulePeriodType>(
              iosInterface: AppSelectInterface.alert,
              value: _periodType,
              decoration: InputDecoration(
                labelText: context.l10n.generalSettingsPeriodType,
                helperText: context.l10n.generalSettingsPeriodHelper,
              ),
              items: [
                DropdownMenuItem(
                  value: CriticalRulePeriodType.days,
                  child: Text(context.l10n.generalSettingsLastXDays),
                ),
                DropdownMenuItem(
                  value: CriticalRulePeriodType.season,
                  child: Text(context.l10n.generalSettingsSinceSeason),
                ),
                DropdownMenuItem(
                  value: CriticalRulePeriodType.allTime,
                  child: Text(context.l10n.generalSettingsAllTime),
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
                decoration: InputDecoration(
                  labelText: context.l10n.generalSettingsDays,
                  helperText: context.l10n.generalSettingsDaysHelper,
                  suffixText: context.l10n.generalSettingsFlutterDaysSuffix,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingM),

            // Operator
            Row(
              children: [
                Text(
                  context.l10n.generalSettingsCombine,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                AppSegmentedButton<CriticalRuleOperator>(
                  segments: [
                    ButtonSegment(
                      value: CriticalRuleOperator.or,
                      label: Text(context.l10n.generalSettingsFlutterOrShort),
                    ),
                    ButtonSegment(
                      value: CriticalRuleOperator.and,
                      label: Text(context.l10n.generalSettingsFlutterAndShort),
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
                  ? context.l10n.generalSettingsFlutterOrHint
                  : context.l10n.generalSettingsFlutterAndHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.medium,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? context.l10n.commonSave : context.l10n.generalSettingsAddRule),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        );
    if (classic) {
      return IonSheetScaffold(
        title: title,
        body: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.only(
            left: AppDimensions.paddingM,
            right: AppDimensions.paddingM,
            top: AppDimensions.paddingM,
          ),
          child: form,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        top: AppDimensions.paddingM,
      ),
      child: SingleChildScrollView(
        child: form,
      ),
    );
  }
}
