import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/data/providers/critical_providers.dart';
import '../../../people/data/critical_logic.dart';
import '../../../attendance/presentation/widgets/event/form_widgets.dart';
import '../widgets/manage/manage_list.dart' show rdLoadedValue;
import '../widgets/manage/settings_sheets.dart';
import '../../../../shared/widgets/components/components.dart';

part 'critical_rule_sheets.dart';

/// Opens "Neue Regel" / "Regel" in the content area (the sidebar stays);
/// returns the rule's parts on "Fertig" (more than one = joined by "und"),
/// null on "Abbrechen". [combinedElsewhere] names the group's other rule
/// with "und": the server knows only one, so this rule can't get a second.
Future<List<CriticalRule>?> openRdCriticalRulePage(
  BuildContext context, {
  List<CriticalRule>? parts,
  required List<AttendanceType> attendanceTypes,
  String? combinedElsewhere,
}) {
  return Navigator.of(context).push<List<CriticalRule>>(
    MaterialPageRoute(
      builder:
          (_) => RdCriticalRulePage(
            parts: parts,
            attendanceTypes: attendanceTypes,
            combinedElsewhere: combinedElsewhere,
          ),
    ),
  );
}

/// REDESIGN (canvas "Problemfälle neu gedacht", variant B): a Problemfall
/// rule as a sentence – "Problemfall ist, wer [in den letzten 30 Tagen]
/// [mindestens 3-mal] [unentschuldigt gefehlt] hat, bei [allen Terminen]."
/// Each marked part opens a small sheet; presets fill a new rule; "und
/// außerdem …" adds a condition that must hold too (stored as Ionic's
/// "nur zusammen" rules); below, a live preview of who the rule hits right
/// now. Builds the same [CriticalRule]s as Ionic; saving stays with the
/// caller.
class RdCriticalRulePage extends ConsumerStatefulWidget {
  const RdCriticalRulePage({super.key, this.parts, required this.attendanceTypes, this.combinedElsewhere});

  final List<CriticalRule>? parts;
  final List<AttendanceType> attendanceTypes;
  final String? combinedElsewhere;

  @override
  ConsumerState<RdCriticalRulePage> createState() => _RdCriticalRulePageState();
}

class _RdCriticalRulePageState extends ConsumerState<RdCriticalRulePage> {
  late final _id = widget.parts?.firstOrNull?.id ?? const Uuid().v4();

  /// The conditions, joined by "und"; the first one is the rule's sentence.
  late List<CriticalRule> _parts = [
    for (final r in widget.parts ?? const <CriticalRule>[]) _normalised(r),
    if (widget.parts?.isEmpty ?? true)
      rdCriticalPresetRule(
        RdCriticalPreset.oftenAbsent,
        id: _id,
        name: rdCriticalPresetLabel(RdCriticalPreset.oftenAbsent, l10nWithoutContext),
      ),
  ];

  /// The condition the sheets change (the one whose part was tapped).
  int _at = 0;

  CriticalRule get _rule => _parts[_at];

  late final _name = TextEditingController(text: _parts.first.name ?? '');

  /// Legacy Ionic rules without period type count their days (or all
  /// time): keep that meaning explicitly, so saving never changes it.
  static CriticalRule _normalised(CriticalRule rule) {
    if (rule.periodType != null) return rule;
    final days = rule.periodDays;
    return days != null && days > 0
        ? rule.copyWith(periodType: CriticalRulePeriodType.days)
        : rule.copyWith(periodType: CriticalRulePeriodType.allTime, periodDays: null);
  }

  /// Tap handlers of the sentence parts, renewed on every build.
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  bool get _isNew => widget.parts == null;

  @override
  void dispose() {
    _disposeRecognizers();
    _name.dispose();
    super.dispose();
  }

  void _set(CriticalRule rule) => setState(() => _parts = [..._parts]..[_at] = rule);

  /// "und außerdem …": a second condition, by default the other common one
  /// (late after absent and vice versa) for the same period and Termine.
  void _addPart() {
    final first = _parts.first;
    final preset =
        rdCriticalWhatOf(first.statuses) == RdCriticalWhat.late ? RdCriticalPreset.oftenAbsent : RdCriticalPreset.oftenLate;
    setState(() {
      _parts = [
        ..._parts,
        rdCriticalPresetRule(preset, id: const Uuid().v4()).copyWith(
          attendanceTypeIds: first.attendanceTypeIds,
          periodType: first.periodType,
          periodDays: first.periodDays,
        ),
      ];
      _at = 0;
    });
  }

  void _removePart(int index) => setState(() {
    _parts = [..._parts]..removeAt(index);
    _at = 0;
  });

  void _applyPreset(RdCriticalPreset preset) {
    final l10n = context.l10n;
    // The name follows the preset until it was typed by hand.
    final name = _name.text.trim();
    final presetNames = [for (final x in RdCriticalPreset.values) rdCriticalPresetLabel(x, l10n)];
    if (name.isEmpty || presetNames.contains(name)) _name.text = rdCriticalPresetLabel(preset, l10n);
    _at = 0;
    _set(rdCriticalPresetRule(preset, id: _id).copyWith(attendanceTypeIds: _parts.first.attendanceTypeIds));
  }

  void _done() {
    final l10n = context.l10n;
    // Same checks as the old sheet (Ionic addCriticalRule), per condition.
    for (final r in _parts) {
      if (r.statuses.isEmpty) {
        ToastHelper.showError(context, l10n.generalSettingsSelectStatus);
        return;
      }
      if (!r.thresholdValue.isFinite || r.thresholdValue <= 0) {
        ToastHelper.showError(context, l10n.generalSettingsThresholdPositive);
        return;
      }
      if (r.periodType == CriticalRulePeriodType.days && (r.periodDays ?? 0) <= 0) {
        ToastHelper.showError(context, l10n.generalSettingsPeriodPositive);
        return;
      }
    }
    final name = _name.text.trim();
    final combined = _parts.length > 1;
    Navigator.of(context).pop([
      for (final (i, r) in _parts.indexed)
        r.copyWith(
          id: i == 0 ? _id : r.id,
          // Every part carries the name, so Ionic lists them recognisably.
          name: name.isEmpty ? null : name,
          // Statuses in the order of the old select.
          statuses: [
            for (final s in criticalRuleStatuses)
              if (r.statuses.contains(s.value)) s.value,
            ...r.statuses.where((s) => !criticalRuleStatuses.any((x) => x.value == s)),
          ],
          periodDays: r.periodType == CriticalRulePeriodType.days ? r.periodDays : null,
          operator: combined ? CriticalRuleOperator.and : CriticalRuleOperator.or,
          // Ionic + `evaluate-critical-rules` have no `enabled` flag.
          enabled: true,
        ),
    ]);
  }

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final preset = _parts.length == 1 ? rdCriticalPresetOf(_parts.first) : null;
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _parts.length; i++)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                                  child: Text.rich(TextSpan(style: textStyle, children: _clause(i))),
                                ),
                              ),
                              if (i > 0)
                                IconButton(
                                  icon: Icon(Icons.close, size: 20, color: p.text2),
                                  tooltip: l10n.rdCriticalRemoveAnd,
                                  onPressed: () => _removePart(i),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (_parts.any((r) => r.statuses.contains(1)))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(l10n.rdCriticalPresentWarning, style: TextStyle(fontSize: 13, color: p.absent)),
                    ),
                  if (widget.combinedElsewhere == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addPart,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.rdCriticalAddAnd),
                        style: TextButton.styleFrom(foregroundColor: p.primary),
                      ),
                    )
                  else
                    RdListNote(l10n.rdCriticalAndElsewhere(widget.combinedElsewhere!)),
                  _Preview(parts: _parts),
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

  /// Condition [i] as sentence parts: "Problemfall ist, wer […] […] […]
  /// hat, bei […]" for the first, "und […] […] […] ist, bei […]" for the
  /// others; the last one ends with ".".
  List<InlineSpan> _clause(int i) {
    final l10n = context.l10n;
    final r = _parts[i];
    final verb = rdCriticalVerb(r.statuses, l10n);
    final types = rdCriticalTypesText(r, widget.attendanceTypes) ?? l10n.rdCriticalTypesAll;
    VoidCallback at(Future<void> Function() pick) => () {
      _at = i;
      pick();
    };
    return [
      TextSpan(text: i == 0 ? '${l10n.rdCriticalSentenceLead} ' : '${l10n.rdCriticalAnd} '),
      _token(rdCriticalPeriodText(r, l10n), at(_pickPeriod)),
      const TextSpan(text: ' '),
      _token(rdCriticalThresholdText(r, l10n), at(_pickThreshold)),
      const TextSpan(text: ' '),
      _token(rdCriticalWhatText(r.statuses, l10n), at(_pickWhat)),
      TextSpan(text: '${verb.isEmpty ? '' : ' $verb'}${l10n.rdCriticalSentenceTypes} '),
      _token(types, at(_pickTypes)),
      if (i == _parts.length - 1) const TextSpan(text: '.'),
    ];
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
        color: p.link,
        decoration: TextDecoration.underline,
        decorationColor: p.link.withValues(alpha: 0.45),
        decorationThickness: 2,
      ),
    );
  }
}
