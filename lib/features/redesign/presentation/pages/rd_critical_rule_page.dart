import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// Opens "Neue Regel" / "Regel" full screen; returns the rule on "Fertig",
/// null on "Abbrechen".
Future<CriticalRule?> openRdCriticalRulePage(
  BuildContext context, {
  CriticalRule? rule,
  required List<AttendanceType> attendanceTypes,
}) {
  return Navigator.of(context, rootNavigator: true).push<CriticalRule>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RdCriticalRulePage(rule: rule, attendanceTypes: attendanceTypes),
    ),
  );
}

/// A rule value as typed in German ("33,5"), without ".0".
String _num(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');

/// REDESIGN: Problemfall-Regel as a Beta edit page (page type of the
/// Auto-Nachricht rule): "Abbrechen · Neue Regel · Fertig", the options of
/// the old sheet in sections (Name, Was zählt, Kritisch ab, Zeitraum,
/// Verknüpfung). "Fertig" checks like the old sheet and builds the same
/// [CriticalRule]; saving stays with the caller.
class RdCriticalRulePage extends StatefulWidget {
  const RdCriticalRulePage({super.key, this.rule, required this.attendanceTypes});

  final CriticalRule? rule;
  final List<AttendanceType> attendanceTypes;

  @override
  State<RdCriticalRulePage> createState() => _RdCriticalRulePageState();
}

class _RdCriticalRulePageState extends State<RdCriticalRulePage> {
  late final _name = TextEditingController(text: widget.rule?.name ?? '');

  // Ionic getEmptyCriticalRule: no types (= "Alle Typen"), no status,
  // 3x in the last 30 days, OR.
  late List<String> _typeIds = [...?widget.rule?.attendanceTypeIds];
  late List<int> _statuses = [...?widget.rule?.statuses];
  late CriticalRuleThresholdType _thresholdType = widget.rule?.thresholdType ?? CriticalRuleThresholdType.count;
  late num _threshold = widget.rule?.thresholdValue ?? 3;
  late CriticalRulePeriodType _periodType = widget.rule?.periodType ?? CriticalRulePeriodType.days;
  late int _days = widget.rule?.periodDays ?? 30;
  late CriticalRuleOperator _operator = widget.rule?.operator ?? CriticalRuleOperator.or;

  bool get _percent => _thresholdType == CriticalRuleThresholdType.percentage;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final l10n = context.l10n;
    // Same checks as the old sheet (Ionic addCriticalRule). An empty type
    // list means "Alle Typen".
    if (_statuses.isEmpty) {
      ToastHelper.showError(context, l10n.generalSettingsSelectStatus);
      return;
    }
    if (!_threshold.isFinite || _threshold <= 0) {
      ToastHelper.showError(context, l10n.generalSettingsThresholdPositive);
      return;
    }
    if (_periodType == CriticalRulePeriodType.days && _days <= 0) {
      ToastHelper.showError(context, l10n.generalSettingsPeriodPositive);
      return;
    }
    final name = _name.text.trim();
    Navigator.of(context).pop(
      CriticalRule(
        id: widget.rule?.id ?? const Uuid().v4(),
        name: name.isEmpty ? null : name,
        // Statuses in the order of the old select.
        attendanceTypeIds: _typeIds,
        statuses: [
          for (final s in criticalRuleStatuses)
            if (_statuses.contains(s.value)) s.value,
          ..._statuses.where((s) => !criticalRuleStatuses.any((x) => x.value == s)),
        ],
        thresholdType: _thresholdType,
        thresholdValue: _threshold,
        periodType: _periodType,
        periodDays: _periodType == CriticalRulePeriodType.days ? _days : null,
        operator: _operator,
        // Ionic + `evaluate-critical-rules` have no `enabled` flag.
        enabled: true,
      ),
    );
  }

  Future<void> _pickTypes() async {
    final types = [
      for (final t in widget.attendanceTypes)
        if (t.id != null) t,
    ];
    final picked = await showRdMultiChoiceSheet(
      context,
      title: context.l10n.rdSettingsRuleTypes,
      options: [for (final t in types) (key: t.id!, label: t.name, locked: false)],
      selected: _typeIds,
      hint: context.l10n.generalSettingsAllTypes,
    );
    if (picked != null && mounted) setState(() => _typeIds = picked);
  }

  /// Types the exact value (e.g. 33,5 %); null on cancel or invalid input.
  Future<num?> _typeNumber(String title, num value, {bool decimal = false}) async {
    final text = await showRdTextSheet(
      context,
      title: title,
      initial: _num(value),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    );
    if (text == null || !mounted) return null;
    final parsed = decimal ? num.tryParse(text.replaceAll(',', '.')) : int.tryParse(text);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      ToastHelper.showError(context, context.l10n.rdSettingsRuleValueInvalid);
      return null;
    }
    return parsed;
  }

  Widget _section(String label, List<Widget> children, {String? hint}) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(label),
        ...children,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(hint, style: RdType.meta(context.rd, size: 13)),
          ),
      ],
    ),
  );

  /// "Anzahl  − 3 +"; tapping the value types it.
  Widget _stepper({
    required String label,
    required String value,
    required VoidCallback? onLess,
    required VoidCallback onMore,
    required VoidCallback onType,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdListRow(
      title: label,
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: onLess == null ? 0.4 : 1,
            child: RdCircleButton(icon: Icons.remove, label: l10n.autoMessagesLess, onPressed: onLess ?? () {}),
          ),
          Semantics(
            button: true,
            label: '$label $value',
            excludeSemantics: true,
            child: InkWell(
              onTap: onType,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 40,
                child: Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          RdCircleButton(icon: Icons.add, label: l10n.autoMessagesMore, onPressed: onMore),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final typeNames = [
      for (final t in widget.attendanceTypes)
        if (_typeIds.contains(t.id)) t.name,
    ];
    final step = _percent ? 5 : 1;
    final thresholdLabel = _percent ? l10n.generalSettingsPercent : l10n.generalSettingsCount;
    final thresholdText = _percent ? '${_num(_threshold)} %' : '${_num(_threshold)}×';

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdFormTopBar(
              title: widget.rule == null ? l10n.rdSettingsRuleNewTitle : l10n.rdSettingsRuleEditTitle,
              cancel: l10n.redesignCommonCancel,
              submit: l10n.redesignCommonDone,
              saving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _done,
            ),
            Expanded(
              child: RdFormBody(
                children: [
                  _section(l10n.rdSettingsRuleName, [
                    RdGroupedList(
                      children: [
                        RdFieldRow(
                          label: l10n.generalSettingsNameOptional,
                          child: TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: rdInputDecoration(p, l10n.generalSettingsRulePh),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  _section(l10n.rdSettingsRuleCounts, [
                    RdGroupedList(
                      children: [
                        RdListRow(
                          title: l10n.rdSettingsRuleTypes,
                          value: typeNames.isEmpty ? l10n.redesignCommonAll : typeNames.join(', '),
                          onTap: _pickTypes,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in criticalRuleStatuses)
                          RdChoiceChip(
                            label: criticalRuleStatusName(s.value, l10n),
                            selected: _statuses.contains(s.value),
                            onTap:
                                () => setState(() {
                                  if (!_statuses.remove(s.value)) _statuses = [..._statuses, s.value];
                                }),
                          ),
                      ],
                    ),
                  ], hint: l10n.rdSettingsRuleStatusHint),
                  _section(l10n.rdSettingsRuleThreshold, [
                    RdSegmented<CriticalRuleThresholdType>(
                      values: const [CriticalRuleThresholdType.count, CriticalRuleThresholdType.percentage],
                      selected: _thresholdType,
                      labelOf:
                          (t) =>
                              t == CriticalRuleThresholdType.count
                                  ? l10n.generalSettingsCount
                                  : l10n.generalSettingsPercent,
                      onChanged: (v) => setState(() => _thresholdType = v),
                    ),
                    const SizedBox(height: 12),
                    RdGroupedList(
                      children: [
                        _stepper(
                          label: thresholdLabel,
                          value: thresholdText,
                          onLess: _threshold - step > 0 ? () => setState(() => _threshold -= step) : null,
                          onMore: () => setState(() => _threshold += step),
                          onType: () async {
                            final v = await _typeNumber(thresholdLabel, _threshold, decimal: true);
                            if (v != null && mounted) setState(() => _threshold = v);
                          },
                        ),
                      ],
                    ),
                  ]),
                  _section(
                    l10n.rdSettingsRulePeriod,
                    [
                      RdSegmented<CriticalRulePeriodType>(
                        values: CriticalRulePeriodType.values,
                        selected: _periodType,
                        labelOf:
                            (t) => switch (t) {
                              CriticalRulePeriodType.days => l10n.rdSettingsRulePeriodDays,
                              CriticalRulePeriodType.season => l10n.rdSettingsRulePeriodSeason,
                              CriticalRulePeriodType.allTime => l10n.rdSettingsRulePeriodAll,
                            },
                        onChanged: (v) => setState(() => _periodType = v),
                      ),
                      if (_periodType == CriticalRulePeriodType.days) ...[
                        const SizedBox(height: 12),
                        RdGroupedList(
                          children: [
                            _stepper(
                              label: l10n.rdSettingsRuleDays,
                              value: '$_days',
                              onLess: _days > 1 ? () => setState(() => _days = (_days - 7).clamp(1, 1 << 30)) : null,
                              onMore: () => setState(() => _days += 7),
                              onType: () async {
                                final v = await _typeNumber(l10n.rdSettingsRuleDays, _days);
                                if (v != null && mounted) setState(() => _days = v.toInt());
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                    hint: switch (_periodType) {
                      CriticalRulePeriodType.days => l10n.generalSettingsDaysHelper,
                      CriticalRulePeriodType.season => l10n.rdSettingsRulePeriodSeasonHint,
                      CriticalRulePeriodType.allTime => l10n.rdSettingsRulePeriodAllHint,
                    },
                  ),
                  _section(
                    l10n.generalSettingsCombine,
                    [
                      RdSegmented<CriticalRuleOperator>(
                        values: const [CriticalRuleOperator.or, CriticalRuleOperator.and],
                        selected: _operator,
                        labelOf: (o) => o == CriticalRuleOperator.or ? l10n.rdSettingsRuleOr : l10n.rdSettingsRuleAnd,
                        onChanged: (v) => setState(() => _operator = v),
                      ),
                    ],
                    hint:
                        _operator == CriticalRuleOperator.or
                            ? l10n.generalSettingsFlutterOrHint
                            : l10n.generalSettingsFlutterAndHint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
