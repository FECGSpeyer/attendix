part of 'rd_critical_rule_page.dart';

/// Picker sheets, live preview, and threshold editor for [RdCriticalRulePage].
extension _RdCriticalRuleSheets on _RdCriticalRulePageState {
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
