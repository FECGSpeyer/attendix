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
import 'settings_form_items.dart';
import 'settings_list.dart';

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
                    interface: AppSelectInterface.alert,
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
              interface: AppSelectInterface.alert,
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
      final dark = Theme.of(context).brightness == Brightness.dark;
      return IonSheetScaffold(
        title: title,
        // `ion-content color="light"`.
        backgroundColor: dark ? null : AppColors.light,
        body: SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            ionListMargin(context),
            AppDimensions.paddingM,
            ionListMargin(context),
            AppDimensions.paddingM + MediaQuery.paddingOf(context).bottom,
          ),
          child: _classicForm(context),
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

  /// Opens the Ionic select alert for a single-value `ion-select [label]`.
  Future<void> _pickOne<T>(
    BuildContext anchor, {
    required String header,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onPicked,
  }) async {
    final picked = await showAppSelect<T>(
      context: anchor,
      interface: AppSelectInterface.alert,
      header: header,
      value: value,
      options: [
        for (final e in options.entries) AppSelectOption(value: e.key, label: e.value),
      ],
    );
    if (picked == null || !mounted) return;
    final v = picked.value;
    setState(() => onPicked(v));
  }

  /// EIA-03: the Ionic form (general.page.html): one inset list with item
  /// groups – stacked name input, `ion-select multiple` rows (label start,
  /// value end), threshold type select + stacked number input, period
  /// select (+ days), operator select, and the primary label item as
  /// submit.
  Widget _classicForm(BuildContext context) {
    final l10n = context.l10n;
    final typeNames = [
      for (final type in widget.attendanceTypes)
        if (type.id != null && _selectedTypeIds.contains(type.id)) type.name,
    ];
    final statusNames = [
      for (final status in criticalRuleStatuses)
        if (_selectedStatuses.contains(status.value)) criticalRuleStatusName(status.value, l10n),
    ];
    final thresholdTypes = {
      CriticalRuleThresholdType.count: l10n.generalSettingsCount,
      CriticalRuleThresholdType.percentage: l10n.generalSettingsPercent,
    };
    final periodTypes = {
      CriticalRulePeriodType.days: l10n.generalSettingsLastXDays,
      CriticalRulePeriodType.season: l10n.generalSettingsSinceSeason,
      CriticalRulePeriodType.allTime: l10n.generalSettingsAllTime,
    };
    final operators = {
      CriticalRuleOperator.or: l10n.generalSettingsOr,
      CriticalRuleOperator.and: l10n.generalSettingsAnd,
    };
    final ios = ionIsIos(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsListSection(icons: false, children: [
          SettingsStackedField(
            label: l10n.generalSettingsNameOptional,
            hint: l10n.generalSettingsRulePh,
            builder: (decoration) => TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoration,
            ),
          ),
          SettingsSelectItem(
            label: l10n.generalSettingsAttTypes,
            value: typeNames.join(', '),
            placeholder: l10n.generalSettingsAllTypes,
            onTap: () async {
              final result = await showAppMultiSelect<String>(
                context: context,
                header: l10n.generalSettingsAttTypes,
                options: [
                  for (final type in widget.attendanceTypes)
                    if (type.id != null) AppSelectOption(value: type.id!, label: type.name),
                ],
                values: _selectedTypeIds,
              );
              if (result != null && mounted) setState(() => _selectedTypeIds = result);
            },
          ),
          SettingsSelectItem(
            label: l10n.agendaStatus,
            value: statusNames.join(', '),
            onTap: () async {
              final result = await showAppMultiSelect<int>(
                context: context,
                header: l10n.agendaStatus,
                options: [
                  for (final status in criticalRuleStatuses)
                    AppSelectOption(value: status.value, label: criticalRuleStatusName(status.value, l10n)),
                ],
                values: _selectedStatuses,
              );
              if (result != null && mounted) setState(() => _selectedStatuses = result);
            },
          ),
        ]),
        SettingsListSection(icons: false, children: [
          Builder(
            builder: (anchor) => SettingsSelectItem(
              label: l10n.generalSettingsThresholdType,
              value: thresholdTypes[_thresholdType] ?? '',
              onTap: () => _pickOne<CriticalRuleThresholdType>(
                anchor,
                header: l10n.generalSettingsThresholdType,
                value: _thresholdType,
                options: thresholdTypes,
                onPicked: (v) => _thresholdType = v,
              ),
            ),
          ),
          SettingsStackedField(
            // Ionic general.page: label "Anzahl" / "Prozent".
            label: _thresholdType == CriticalRuleThresholdType.percentage
                ? l10n.generalSettingsPercent
                : l10n.generalSettingsCount,
            builder: (decoration) => TextField(
              controller: _thresholdController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: decoration,
            ),
          ),
        ]),
        SettingsListSection(icons: false, children: [
          Builder(
            builder: (anchor) => SettingsSelectItem(
              label: l10n.generalSettingsPeriodType,
              value: periodTypes[_periodType] ?? '',
              helper: l10n.generalSettingsPeriodHelper,
              onTap: () => _pickOne<CriticalRulePeriodType>(
                anchor,
                header: l10n.generalSettingsPeriodType,
                value: _periodType,
                options: periodTypes,
                onPicked: (v) => _periodType = v,
              ),
            ),
          ),
          if (_periodType == CriticalRulePeriodType.days)
            SettingsStackedField(
              label: l10n.generalSettingsDays,
              helper: l10n.generalSettingsDaysHelper,
              builder: (decoration) => TextField(
                controller: _periodDaysController,
                keyboardType: TextInputType.number,
                decoration: decoration,
              ),
            ),
        ]),
        SettingsListSection(icons: false, children: [
          Builder(
            builder: (anchor) => SettingsSelectItem(
              label: l10n.generalSettingsCombine,
              value: operators[_operator] ?? '',
              helper: l10n.generalSettingsCombineHelper,
              onTap: () => _pickOne<CriticalRuleOperator>(
                anchor,
                header: l10n.generalSettingsCombine,
                value: _operator,
                options: operators,
                onPicked: (v) => _operator = v,
              ),
            ),
          ),
        ]),
        SettingsListSection(icons: false, children: [
          // `ion-item button detail="false"` with a primary label.
          ListTile(
            contentPadding: ios
                ? null
                : const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              _isEditing ? l10n.commonSave : l10n.generalSettingsAddRule,
              style: const TextStyle(color: AppColors.primary),
            ),
            onTap: _save,
          ),
        ]),
      ],
    );
  }
}
