import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../data/providers/rd_critical_providers.dart';
import '../../data/rd_critical_logic.dart';
import '../widgets/event/rd_form_widgets.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// Opens "Neue Regel" / "Regel" in the content area (the sidebar stays);
/// returns the rule on "Fertig", null on "Abbrechen". [otherRules] are the
/// group's other rules (they decide whether "Nur zusammen …" is offered).
Future<CriticalRule?> openRdCriticalRulePage(
  BuildContext context, {
  CriticalRule? rule,
  required List<AttendanceType> attendanceTypes,
  required bool otherRules,
}) {
  return Navigator.of(context).push<CriticalRule>(
    MaterialPageRoute(
      builder: (_) => RdCriticalRulePage(rule: rule, attendanceTypes: attendanceTypes, otherRules: otherRules),
    ),
  );
}

/// REDESIGN (canvas "Problemfälle neu gedacht", variant B): a Problemfall
/// rule as a sentence – "Problemfall ist, wer [in den letzten 30 Tagen]
/// [mindestens 3-mal] [unentschuldigt gefehlt] hat, bei [allen Terminen]."
/// Each marked part opens a small sheet; presets fill a new rule; below, a
/// live preview of who the rule hits right now. Builds the same
/// [CriticalRule] as Ionic; saving stays with the caller.
class RdCriticalRulePage extends ConsumerStatefulWidget {
  const RdCriticalRulePage({super.key, this.rule, required this.attendanceTypes, this.otherRules = false});

  final CriticalRule? rule;
  final List<AttendanceType> attendanceTypes;
  final bool otherRules;

  @override
  ConsumerState<RdCriticalRulePage> createState() => _RdCriticalRulePageState();
}

class _RdCriticalRulePageState extends ConsumerState<RdCriticalRulePage> {
  late final _id = widget.rule?.id ?? const Uuid().v4();

  late CriticalRule _rule =
      widget.rule ??
      rdCriticalPresetRule(
        RdCriticalPreset.oftenAbsent,
        id: _id,
        name: rdCriticalPresetLabel(RdCriticalPreset.oftenAbsent, l10nWithoutContext),
      );

  late final _name = TextEditingController(text: _rule.name ?? '');

  /// Tap handlers of the sentence parts, renewed on every build.
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  bool get _isNew => widget.rule == null;

  @override
  void dispose() {
    _disposeRecognizers();
    _name.dispose();
    super.dispose();
  }

  void _set(CriticalRule rule) => setState(() => _rule = rule);

  void _applyPreset(RdCriticalPreset preset) {
    final l10n = context.l10n;
    // The name follows the preset until it was typed by hand.
    final name = _name.text.trim();
    final presetNames = [for (final x in RdCriticalPreset.values) rdCriticalPresetLabel(x, l10n)];
    if (name.isEmpty || presetNames.contains(name)) _name.text = rdCriticalPresetLabel(preset, l10n);
    _set(rdCriticalPresetRule(preset, id: _id).copyWith(attendanceTypeIds: _rule.attendanceTypeIds, operator: _rule.operator));
  }

  void _done() {
    final l10n = context.l10n;
    // Same checks as the old sheet (Ionic addCriticalRule).
    if (_rule.statuses.isEmpty) {
      ToastHelper.showError(context, l10n.generalSettingsSelectStatus);
      return;
    }
    if (!_rule.thresholdValue.isFinite || _rule.thresholdValue <= 0) {
      ToastHelper.showError(context, l10n.generalSettingsThresholdPositive);
      return;
    }
    if (_rule.periodType == CriticalRulePeriodType.days && (_rule.periodDays ?? 0) <= 0) {
      ToastHelper.showError(context, l10n.generalSettingsPeriodPositive);
      return;
    }
    final name = _name.text.trim();
    Navigator.of(context).pop(
      _rule.copyWith(
        id: _id,
        name: name.isEmpty ? null : name,
        // Statuses in the order of the old select.
        statuses: [
          for (final s in criticalRuleStatuses)
            if (_rule.statuses.contains(s.value)) s.value,
          ..._rule.statuses.where((s) => !criticalRuleStatuses.any((x) => x.value == s)),
        ],
        periodDays: _rule.periodType == CriticalRulePeriodType.days ? _rule.periodDays : null,
        // Ionic + `evaluate-critical-rules` have no `enabled` flag.
        enabled: true,
      ),
    );
  }

  // ------------------------------------------------------------- sheets

  Future<void> _pickPeriod() async {
    final l10n = context.l10n;
    final days = _rule.periodType == CriticalRulePeriodType.days ? _rule.periodDays ?? 30 : null;
    final dayOptions = <int>{14, 30, 60, 90, if (days != null) days}.toList()..sort();
    final current = days != null ? 'd$days' : (_rule.periodType == CriticalRulePeriodType.season ? 'season' : 'all');
    final picked = await showRdChoiceSheet<String>(
      context,
      title: l10n.rdCriticalSheetPeriod,
      selected: current,
      options: [
        for (final d in dayOptions) ('d$d', l10n.rdCriticalPeriodDays(d)),
        ('season', l10n.rdCriticalPeriodSeason),
        ('all', l10n.rdCriticalPeriodAll),
        ('other', l10n.rdCriticalPeriodOther),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'season':
        _set(_rule.copyWith(periodType: CriticalRulePeriodType.season));
      case 'all':
        _set(_rule.copyWith(periodType: CriticalRulePeriodType.allTime));
      case 'other':
        final v = await _typeNumber(l10n.rdCriticalDays, days ?? 30);
        if (v != null && mounted) {
          _set(_rule.copyWith(periodType: CriticalRulePeriodType.days, periodDays: v.toInt()));
        }
      default:
        _set(_rule.copyWith(periodType: CriticalRulePeriodType.days, periodDays: int.parse(picked.substring(1))));
    }
  }

  Future<void> _pickThreshold() async {
    final picked = await showRdSettingsSheet<(CriticalRuleThresholdType, num)>(
      context,
      (_) => _ThresholdSheet(type: _rule.thresholdType, value: _rule.thresholdValue, typeNumber: _typeNumber),
    );
    if (picked == null || !mounted) return;
    _set(_rule.copyWith(thresholdType: picked.$1, thresholdValue: picked.$2));
  }

  Future<void> _pickWhat() async {
    final l10n = context.l10n;
    final current = rdCriticalWhatOf(_rule.statuses);
    final picked = await showRdChoiceSheet<RdCriticalWhat>(
      context,
      title: l10n.rdCriticalSheetWhat,
      selected: current,
      options: [
        (RdCriticalWhat.absent, l10n.rdCriticalWhatAbsent),
        (RdCriticalWhat.absentAll, l10n.rdCriticalWhatAbsentAll),
        (RdCriticalWhat.late, l10n.rdCriticalWhatLate),
        (RdCriticalWhat.custom, l10n.rdCriticalWhatPick),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked != RdCriticalWhat.custom) {
      _set(_rule.copyWith(statuses: rdCriticalStatusesOf(picked)));
      return;
    }
    final keys = await showRdMultiChoiceSheet(
      context,
      title: l10n.rdCriticalSheetWhat,
      options: [
        for (final s in criticalRuleStatuses)
          (key: '${s.value}', label: criticalRuleStatusName(s.value, l10n), locked: false),
      ],
      selected: [for (final s in _rule.statuses) '$s'],
      hint: l10n.rdCriticalWhatPickHint,
    );
    if (keys == null || !mounted) return;
    if (keys.isEmpty) {
      ToastHelper.showError(context, l10n.generalSettingsSelectStatus);
      return;
    }
    _set(_rule.copyWith(statuses: [for (final k in keys) int.parse(k)]));
  }

  Future<void> _pickTypes() async {
    final types = [
      for (final t in widget.attendanceTypes)
        if (t.id != null) t,
    ];
    final picked = await showRdMultiChoiceSheet(
      context,
      title: context.l10n.rdCriticalSheetTypes,
      options: [for (final t in types) (key: t.id!, label: t.name, locked: false)],
      selected: _rule.attendanceTypeIds,
      hint: context.l10n.generalSettingsAllTypes,
    );
    if (picked != null && mounted) _set(_rule.copyWith(attendanceTypeIds: picked));
  }

  /// Types the exact value (e.g. 33,5 %); null on cancel or invalid input.
  Future<num?> _typeNumber(String title, num value, {bool decimal = false}) async {
    final text = await showRdTextSheet(
      context,
      title: title,
      initial: rdCriticalNum(value),
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

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final preset = rdCriticalPresetOf(_rule);
    final showAnd = widget.otherRules || _rule.operator == CriticalRuleOperator.and;
    final verb = rdCriticalVerb(_rule.statuses, l10n);
    final types = rdCriticalTypesText(_rule, widget.attendanceTypes) ?? l10n.rdCriticalTypesAll;
    final textStyle = TextStyle(fontSize: 18, height: 1.7, color: p.text);
    _disposeRecognizers();

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdFormTopBar(
              title: _isNew ? l10n.rdSettingsRuleNewTitle : l10n.rdSettingsRuleEditTitle,
              cancel: l10n.redesignCommonCancel,
              submit: l10n.redesignCommonDone,
              saving: false,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _done,
            ),
            Expanded(
              child: RdFormBody(
                children: [
                  if (_isNew) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final x in RdCriticalPreset.values)
                          RdChoiceChip(
                            label: rdCriticalPresetLabel(x, l10n),
                            selected: preset == x,
                            onTap: () => _applyPreset(x),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  RdCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Text.rich(
                      TextSpan(
                        style: textStyle,
                        children: [
                          TextSpan(text: '${l10n.rdCriticalSentenceLead} '),
                          _token(rdCriticalPeriodText(_rule, l10n), _pickPeriod),
                          const TextSpan(text: ' '),
                          _token(rdCriticalThresholdText(_rule, l10n), _pickThreshold),
                          const TextSpan(text: ' '),
                          _token(rdCriticalWhatText(_rule.statuses, l10n), _pickWhat),
                          TextSpan(text: '${verb.isEmpty ? '' : ' $verb'}${l10n.rdCriticalSentenceTypes} '),
                          _token(types, _pickTypes),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                  if (_rule.statuses.contains(1))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(l10n.rdCriticalPresentWarning, style: TextStyle(fontSize: 13, color: p.absent)),
                    ),
                  _Preview(rule: _rule),
                  const SizedBox(height: 22),
                  RdGroupLabel(l10n.rdCriticalMore),
                  RdGroupedList(
                    children: [
                      RdFieldRow(
                        label: l10n.rdCriticalName,
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: rdInputDecoration(p, l10n.rdCriticalNamePh),
                        ),
                      ),
                      if (showAnd)
                        RdSwitchRow(
                          title: l10n.rdCriticalAndTitle,
                          subtitle: l10n.rdCriticalAndHint,
                          value: _rule.operator == CriticalRuleOperator.and,
                          onChanged:
                              (v) => _set(_rule.copyWith(operator: v ? CriticalRuleOperator.and : CriticalRuleOperator.or)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A tappable part of the sentence: marked text that wraps with it.
  InlineSpan _token(String label, VoidCallback onTap) {
    final p = context.rd;
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return TextSpan(
      text: label,
      semanticsLabel: '$label, ${context.l10n.rdCriticalChange}',
      recognizer: recognizer,
      mouseCursor: SystemMouseCursors.click,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: p.softText,
        backgroundColor: p.soft,
        decoration: TextDecoration.underline,
        decorationColor: p.primary,
        decorationThickness: 2,
      ),
    );
  }
}

/// "Trifft gerade auf 2 Personen zu" and who: the rule on its own, for the
/// active members (paused ones are not shown as Problemfall either).
class _Preview extends ConsumerWidget {
  const _Preview({required this.rule});

  final CriticalRule rule;

  static const _rows = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final season = rdSeasonStartOf(tenant?.seasonStart);
    final now = DateTime.now();
    final start = rdCriticalLoadStart([...?tenant?.criticalRules, rule], seasonStart: season, today: now);
    final entries = ref.watch(rdCriticalEntriesProvider(start));
    final players = ref.watch(playersProvider);

    Widget note(String text, {bool spinner = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 0),
      child: Row(
        children: [
          if (spinner) ...[
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.text2)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: RdType.meta(p, size: 13))),
        ],
      ),
    );

    if (entries.hasError || players.hasError) return note(l10n.rdCriticalPreviewError);
    final data = entries.valueOrNull;
    final people = players.valueOrNull;
    if (data == null || people == null) return note(l10n.rdCriticalPreviewLoading, spinner: true);

    final hits = <(Person, RdRuleResult)>[];
    for (final x in people) {
      if (x.id == null || x.paused || x.pending || x.left != null) continue;
      final result = rdEvaluateCriticalRule(
        rule,
        data[x.id] ?? const [],
        lastSolve: x.lastSolve == null ? null : DateTime.tryParse(x.lastSolve!),
        seasonStart: season,
        now: now,
      );
      if (result.matches) hits.add((x, result));
    }
    hits.sort((a, b) {
      final byCount = b.$2.matching.compareTo(a.$2.matching);
      return byCount != 0 ? byCount : a.$1.lastName.compareTo(b.$1.lastName);
    });
    final percent = rule.thresholdType == CriticalRuleThresholdType.percentage;
    final date = DateFormat.MMMd(currentIntlLocale());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Semantics(liveRegion: true, child: RdGroupLabel(l10n.rdCriticalPreviewTitle(hits.length))),
        if (hits.isNotEmpty)
          RdGroupedList(
            children: [
              for (final (x, r) in hits.take(_rows))
                RdListRow(
                  leading: RdInitials(rdInitialsOf('${x.firstName} ${x.lastName}'), size: 34),
                  title: '${x.firstName} ${x.lastName}'.trim(),
                  subtitle: [
                    rdCriticalHitText(rule, r, l10n),
                    if (percent) l10n.rdCriticalPreviewOf(r.matching, r.total),
                    if (!percent && r.last != null) l10n.rdCriticalPreviewLast(date.format(r.last!.toLocal())),
                  ].join(' · '),
                  showChevron: false,
                ),
              if (hits.length > _rows)
                RdListRow(title: l10n.rdCriticalPreviewMore(hits.length - _rows), showChevron: false),
            ],
          ),
        RdListNote(
          rule.operator == CriticalRuleOperator.and ? l10n.rdCriticalPreviewAndHint : l10n.rdCriticalPreviewSolveHint,
        ),
      ],
    );
  }
}

/// "Wie oft?": Anzahl or Anteil, with − value +; the value can be typed.
class _ThresholdSheet extends StatefulWidget {
  const _ThresholdSheet({required this.type, required this.value, required this.typeNumber});

  final CriticalRuleThresholdType type;
  final num value;
  final Future<num?> Function(String title, num value, {bool decimal}) typeNumber;

  @override
  State<_ThresholdSheet> createState() => _ThresholdSheetState();
}

class _ThresholdSheetState extends State<_ThresholdSheet> {
  late var _type = widget.type;
  late num _value = widget.value;

  /// Last value of the other mode, so switching back keeps it.
  late num _other = widget.type == CriticalRuleThresholdType.count ? 40 : 3;

  bool get _percent => _type == CriticalRuleThresholdType.percentage;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final step = _percent ? 5 : 1;
    final label = _percent ? l10n.rdCriticalPercent : l10n.rdCriticalTimes;
    final text = _percent ? '${rdCriticalNum(_value)} %' : '${rdCriticalNum(_value)}×';
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetHead(title: l10n.rdCriticalSheetThreshold, onDone: () => Navigator.of(context).pop((_type, _value))),
        RdSegmented<CriticalRuleThresholdType>(
          values: const [CriticalRuleThresholdType.count, CriticalRuleThresholdType.percentage],
          selected: _type,
          labelOf: (t) => t == CriticalRuleThresholdType.count ? l10n.rdCriticalModeCount : l10n.rdCriticalModePercent,
          onChanged: (v) {
            if (v == _type) return;
            setState(() {
              final keep = _value;
              _value = _other;
              _other = keep;
              _type = v;
            });
          },
        ),
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            RdListRow(
              title: label,
              showChevron: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _value - step > 0 ? 1 : 0.4,
                    child: RdCircleButton(
                      icon: Icons.remove,
                      label: l10n.autoMessagesLess,
                      onPressed: () {
                        if (_value - step > 0) setState(() => _value -= step);
                      },
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '$label $text',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () async {
                        final v = await widget.typeNumber(label, _value, decimal: true);
                        if (v != null && mounted) setState(() => _value = v);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 40,
                        child: Center(
                          child: Text(
                            text,
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
                  RdCircleButton(
                    icon: Icons.add,
                    label: l10n.autoMessagesMore,
                    onPressed: () => setState(() => _value += step),
                  ),
                ],
              ),
            ),
          ],
        ),
        RdListNote(
          _percent
              ? l10n.rdCriticalThresholdPercent(rdCriticalNum(_value))
              : l10n.rdCriticalThresholdCountText(rdCriticalNum(_value)),
        ),
      ],
    );
  }
}
