import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/realtime_providers.dart';
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
import '../widgets/manage/rd_manage_list.dart' show rdLoadedValue;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

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

/// "Trifft gerade auf 2 Personen zu" and who: the rule (all its conditions
/// together) on its own, for the active members (paused ones are not shown
/// as Problemfall either).
class _Preview extends ConsumerWidget {
  const _Preview({required this.parts});

  final List<CriticalRule> parts;

  static const _rows = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final season = rdSeasonStartOf(tenant?.seasonStart);
    final now = DateTime.now();
    final key = rdCriticalKeyFor(tenant, [...?tenant?.criticalRules, ...parts]);
    if (key == null) return const SizedBox.shrink();
    final entries = ref.watch(rdCriticalEntriesProvider(key));
    // Live people: a talk („Mit Person gesprochen“) or a pause counts at once.
    final players = ref.watch(realtimePlayersProvider);

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
    // Only data of this group: nothing from before a group switch.
    final data = entries.valueOrNull; // the key holds the group
    final people = rdLoadedValue(players);
    if (data == null || people == null) return note(l10n.rdCriticalPreviewLoading, spinner: true);

    final hits = <(Person, List<RdRuleResult>)>[];
    for (final x in people) {
      if (x.id == null || x.paused || x.pending || x.left != null) continue;
      final results = [
        for (final r in parts)
          rdEvaluateCriticalRule(
            r,
            data[x.id] ?? const [],
            lastSolve: x.lastSolve == null ? null : DateTime.tryParse(x.lastSolve!),
            seasonStart: season,
            now: now,
          ),
      ];
      if (results.every((r) => r.matches)) hits.add((x, results));
    }
    hits.sort((a, b) {
      final byCount = b.$2.first.matching.compareTo(a.$2.first.matching);
      return byCount != 0 ? byCount : a.$1.lastName.compareTo(b.$1.lastName);
    });
    final date = DateFormat.MMMd(currentIntlLocale());

    // The sentence above says what counts; here only the numbers.
    String numbers(CriticalRule rule, RdRuleResult r) {
      final percent = rule.thresholdType == CriticalRuleThresholdType.percentage;
      return [
        if (percent) ...[
          '${r.percent.round()} %',
          l10n.rdCriticalPreviewOf(r.matching, r.total),
        ] else
          l10n.rdCriticalPreviewTimes(r.matching),
        if (!percent && r.last != null) l10n.rdCriticalPreviewLast(date.format(r.last!.toLocal())),
      ].join(' · ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Semantics(liveRegion: true, child: RdGroupLabel(l10n.rdCriticalPreviewTitle(hits.length))),
        if (hits.isNotEmpty)
          RdGroupedList(
            children: [
              for (final (x, results) in hits.take(_rows))
                RdListRow(
                  leading: RdInitials(rdInitialsOf('${x.firstName} ${x.lastName}'), size: 34),
                  title: '${x.firstName} ${x.lastName}'.trim(),
                  subtitle: [
                    for (final (i, r) in results.indexed) numbers(parts[i], r),
                  ].join(' ${l10n.rdCriticalAnd} '),
                  showChevron: false,
                ),
              if (hits.length > _rows)
                RdListRow(title: l10n.rdCriticalPreviewMore(hits.length - _rows), showChevron: false),
            ],
          ),
        RdListNote(l10n.rdCriticalPreviewSolveHint),
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
    final label = l10n.rdCriticalAtLeast;
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
