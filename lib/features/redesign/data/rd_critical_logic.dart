import '../../../data/models/attendance/attendance.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../l10n/l10n.dart';

/// REDESIGN (canvas "Problemfälle neu gedacht", variant B): Problemfall rules
/// as plain sentences, a live preview of who a rule hits, and the reason why
/// a person is a Problemfall.
///
/// The rules stay the Ionic `critical_rules` JSON; the server function
/// `evaluate-critical-rules` remains the only one that sets `isCritical`.
/// [rdEvaluateCriticalRule] is a port of its `evaluateSingleRule` so the
/// app can show what the server will decide.

/// One recorded status of a person at a Termin, as the rules count it.
class RdCriticalEntry {
  const RdCriticalEntry({required this.personId, required this.status, required this.date, this.typeId});

  final int personId;
  final int status;
  final DateTime date;
  final String? typeId;
}

/// What a rule counts, in words.
enum RdCriticalWhat {
  /// Abwesend: "unentschuldigt gefehlt".
  absent,

  /// Abwesend + Entschuldigt: "gefehlt (auch entschuldigt)".
  absentAll,

  /// Verspätet + Verspätet entschuldigt: "zu spät gekommen".
  late,

  /// Any other selection; shown with the status names.
  custom,
}

const _whatStatuses = {
  RdCriticalWhat.absent: [4],
  RdCriticalWhat.absentAll: [4, 2],
  RdCriticalWhat.late: [3, 5],
};

/// The statuses a [what] stands for (empty for [RdCriticalWhat.custom]).
List<int> rdCriticalStatusesOf(RdCriticalWhat what) => [...?_whatStatuses[what]];

RdCriticalWhat rdCriticalWhatOf(List<int> statuses) {
  final set = statuses.toSet();
  for (final e in _whatStatuses.entries) {
    if (set.length == e.value.length && set.containsAll(e.value)) return e.key;
  }
  return RdCriticalWhat.custom;
}

/// Starting points of a new rule.
enum RdCriticalPreset { oftenAbsent, oftenLate, rarelyThere }

String rdCriticalPresetLabel(RdCriticalPreset preset, AppLocalizations l10n) => switch (preset) {
  RdCriticalPreset.oftenAbsent => l10n.rdCriticalPresetAbsent,
  RdCriticalPreset.oftenLate => l10n.rdCriticalPresetLate,
  RdCriticalPreset.rarelyThere => l10n.rdCriticalPresetRarely,
};

/// The rule of [preset] (all Termin types, "eine Regel reicht").
CriticalRule rdCriticalPresetRule(RdCriticalPreset preset, {required String id, String? name}) => switch (preset) {
  RdCriticalPreset.oftenAbsent => CriticalRule(
    id: id,
    name: name,
    attendanceTypeIds: const [],
    statuses: const [4],
    thresholdType: CriticalRuleThresholdType.count,
    thresholdValue: 3,
    periodType: CriticalRulePeriodType.days,
    periodDays: 30,
    operator: CriticalRuleOperator.or,
  ),
  RdCriticalPreset.oftenLate => CriticalRule(
    id: id,
    name: name,
    attendanceTypeIds: const [],
    statuses: const [3, 5],
    thresholdType: CriticalRuleThresholdType.count,
    thresholdValue: 4,
    periodType: CriticalRulePeriodType.days,
    periodDays: 60,
    operator: CriticalRuleOperator.or,
  ),
  RdCriticalPreset.rarelyThere => CriticalRule(
    id: id,
    name: name,
    attendanceTypeIds: const [],
    statuses: const [4, 2],
    thresholdType: CriticalRuleThresholdType.percentage,
    thresholdValue: 40,
    periodType: CriticalRulePeriodType.season,
    operator: CriticalRuleOperator.or,
  ),
};

/// The preset [rule] still equals (statuses, threshold, period), if any.
RdCriticalPreset? rdCriticalPresetOf(CriticalRule rule) {
  for (final preset in RdCriticalPreset.values) {
    final r = rdCriticalPresetRule(preset, id: '');
    if (rdCriticalWhatOf(rule.statuses) == rdCriticalWhatOf(r.statuses) &&
        rdCriticalWhatOf(r.statuses) != RdCriticalWhat.custom &&
        rule.thresholdType == r.thresholdType &&
        rule.thresholdValue == r.thresholdValue &&
        rule.periodType == r.periodType &&
        (r.periodType != CriticalRulePeriodType.days || rule.periodDays == r.periodDays)) {
      return preset;
    }
  }
  return null;
}

/// Name for a rule without one: the preset word for what it counts
/// ("Fehlt oft", "Oft zu spät", "Selten da"), else "Eigene Regel".
String rdCriticalDefaultName(CriticalRule rule, AppLocalizations l10n) {
  final percent = rule.thresholdType == CriticalRuleThresholdType.percentage;
  return switch (rdCriticalWhatOf(rule.statuses)) {
    RdCriticalWhat.late => l10n.rdCriticalPresetLate,
    RdCriticalWhat.absent || RdCriticalWhat.absentAll when percent => l10n.rdCriticalPresetRarely,
    RdCriticalWhat.absent || RdCriticalWhat.absentAll => l10n.rdCriticalPresetAbsent,
    RdCriticalWhat.custom => l10n.rdCriticalOwnRule,
  };
}

/// A rule value as typed in German ("33,5"), without ".0".
String rdCriticalNum(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');

// ------------------------------------------------------------------ texts

String _status(int s, AppLocalizations l10n) => criticalRuleStatusName(s, l10n);

/// "unentschuldigt gefehlt", "Status Anwesend oder Abwesend".
String rdCriticalWhatText(List<int> statuses, AppLocalizations l10n) => switch (rdCriticalWhatOf(statuses)) {
  RdCriticalWhat.absent => l10n.rdCriticalWhatAbsent,
  RdCriticalWhat.absentAll => l10n.rdCriticalWhatAbsentAll,
  RdCriticalWhat.late => l10n.rdCriticalWhatLate,
  RdCriticalWhat.custom => l10n.rdCriticalWhatCustom(
    [
      for (final s in criticalRuleStatuses)
        if (statuses.contains(s.value)) _status(s.value, l10n),
      for (final s in statuses)
        if (!criticalRuleStatuses.any((x) => x.value == s)) _status(s, l10n),
    ].join(l10n.rdCriticalOr),
  ),
};

/// " hat" / " ist" / " hatte" after [rdCriticalWhatText] in the sentence.
String rdCriticalVerb(List<int> statuses, AppLocalizations l10n) => switch (rdCriticalWhatOf(statuses)) {
  RdCriticalWhat.late => l10n.rdCriticalVerbIs,
  RdCriticalWhat.custom => l10n.rdCriticalVerbHad,
  _ => l10n.rdCriticalVerbHas,
};

/// "mindestens 3-mal", "bei mindestens 40 % der Termine".
String rdCriticalThresholdText(CriticalRule rule, AppLocalizations l10n) =>
    rule.thresholdType == CriticalRuleThresholdType.percentage
        ? l10n.rdCriticalThresholdPercent(rdCriticalNum(rule.thresholdValue))
        : rule.thresholdValue == rule.thresholdValue.roundToDouble()
        ? l10n.rdCriticalThresholdCount(rule.thresholdValue.toInt())
        : l10n.rdCriticalThresholdCountText(rdCriticalNum(rule.thresholdValue));

/// "in den letzten 30 Tagen", "seit Saisonbeginn", "insgesamt". Legacy
/// rules without period type count their days, otherwise all time (server).
String rdCriticalPeriodText(CriticalRule rule, AppLocalizations l10n) {
  final days = rule.periodDays;
  return switch (rule.periodType) {
    CriticalRulePeriodType.days => l10n.rdCriticalPeriodDays(days ?? 30),
    CriticalRulePeriodType.season => l10n.rdCriticalPeriodSeason,
    CriticalRulePeriodType.allTime => l10n.rdCriticalPeriodAll,
    null => days != null ? l10n.rdCriticalPeriodDays(days) : l10n.rdCriticalPeriodAll,
  };
}

/// Names of the Termin types of [rule] ("Probe, Konzert"); null = all.
String? rdCriticalTypesText(CriticalRule rule, List<AttendanceType> types) {
  if (rule.attendanceTypeIds.isEmpty) return null;
  final names = [
    for (final t in types)
      if (rule.attendanceTypeIds.contains(t.id)) t.name,
  ];
  return names.isEmpty ? null : names.join(', ');
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// One line for the list: "Mindestens 3-mal unentschuldigt gefehlt in den
/// letzten 30 Tagen · Probe".
String rdCriticalSummary(CriticalRule rule, List<AttendanceType> types, AppLocalizations l10n) {
  final text = _capitalize(
    l10n.rdCriticalSummary(
      rdCriticalThresholdText(rule, l10n),
      rdCriticalWhatText(rule.statuses, l10n),
      rdCriticalPeriodText(rule, l10n),
    ),
  );
  final typeNames = rdCriticalTypesText(rule, types);
  return typeNames == null ? text : '$text · $typeNames';
}

/// Why a person is hit: "4-mal unentschuldigt gefehlt", "Bei 45 % der
/// Termine gefehlt (auch entschuldigt)".
String rdCriticalHitText(CriticalRule rule, RdRuleResult result, AppLocalizations l10n) {
  final what = rdCriticalWhatText(rule.statuses, l10n);
  if (rule.thresholdType == CriticalRuleThresholdType.percentage) {
    return _capitalize(l10n.rdCriticalHitPercent(result.percent.round(), what));
  }
  return _capitalize(l10n.rdCriticalHitCount(result.matching, what));
}

// ------------------------------------------------------------- evaluation

/// Result of one rule for one person.
class RdRuleResult {
  const RdRuleResult({required this.matching, required this.total, required this.matches, this.last});

  /// Termine with one of the rule's statuses.
  final int matching;

  /// All Termine of the rule's types in the period.
  final int total;
  final bool matches;

  /// Date of the newest counted Termin.
  final DateTime? last;

  double get percent => total == 0 ? 0 : matching * 100 / total;
}

/// Start of what the rule counts: the period start, or the last
/// "Gespräch geführt" when later (server `evaluateSingleRule`).
DateTime? rdCriticalPeriodStart(
  CriticalRule rule, {
  DateTime? lastSolve,
  DateTime? seasonStart,
  required DateTime now,
}) {
  DateTime? start = switch (rule.periodType) {
    CriticalRulePeriodType.days => now.subtract(Duration(days: rule.periodDays ?? 30)),
    CriticalRulePeriodType.season => seasonStart,
    CriticalRulePeriodType.allTime => null,
    null => rule.periodDays != null && rule.periodDays! > 0 ? now.subtract(Duration(days: rule.periodDays!)) : null,
  };
  if (lastSolve != null && (start == null || lastSolve.isAfter(start))) start = lastSolve;
  return start;
}

/// Port of the server's `evaluateSingleRule` for the [entries] of one person.
RdRuleResult rdEvaluateCriticalRule(
  CriticalRule rule,
  Iterable<RdCriticalEntry> entries, {
  DateTime? lastSolve,
  DateTime? seasonStart,
  required DateTime now,
}) {
  final start = rdCriticalPeriodStart(rule, lastSolve: lastSolve, seasonStart: seasonStart, now: now);
  var total = 0;
  var matching = 0;
  DateTime? last;
  for (final e in entries) {
    if (e.date.isAfter(now)) continue;
    if (start != null && !e.date.isAfter(start)) continue;
    if (rule.attendanceTypeIds.isNotEmpty && !rule.attendanceTypeIds.contains(e.typeId ?? '')) continue;
    total++;
    if (rule.statuses.contains(e.status)) {
      matching++;
      if (last == null || e.date.isAfter(last)) last = e.date;
    }
  }
  final matches =
      rule.thresholdType == CriticalRuleThresholdType.count
          ? matching >= rule.thresholdValue
          : total > 0 && matching * 100 / total >= rule.thresholdValue;
  return RdRuleResult(matching: matching, total: total, matches: matches, last: last);
}

/// The rules that make a person a Problemfall, with their results: every
/// matching "eine reicht" rule, or – when none matches – all "nur zusammen"
/// rules if all of them match (server `evaluateRules`). Empty = no
/// Problemfall.
List<(CriticalRule, RdRuleResult)> rdCriticalHits(
  List<CriticalRule> rules,
  Iterable<RdCriticalEntry> entries, {
  DateTime? lastSolve,
  DateTime? seasonStart,
  required DateTime now,
}) {
  final list = entries.toList();
  RdRuleResult eval(CriticalRule r) =>
      rdEvaluateCriticalRule(r, list, lastSolve: lastSolve, seasonStart: seasonStart, now: now);
  final orHits =
      [
        for (final r in rules)
          if (r.operator == CriticalRuleOperator.or) (r, eval(r)),
      ].where((x) => x.$2.matches).toList();
  if (orHits.isNotEmpty) return orHits;
  final and = [
    for (final r in rules)
      if (r.operator == CriticalRuleOperator.and) (r, eval(r)),
  ];
  if (and.isNotEmpty && and.every((x) => x.$2.matches)) return and;
  return const [];
}

/// Earliest date the app must load to evaluate [rules]: whole days, at
/// least a year back for day rules (so changing the days in the editor
/// needs no new load), the season start, or 2000 for "insgesamt".
DateTime rdCriticalLoadStart(Iterable<CriticalRule> rules, {DateTime? seasonStart, required DateTime today}) {
  final day = DateTime(today.year, today.month, today.day);
  var start = day.subtract(const Duration(days: 366));
  final allTime = DateTime(2000);
  for (final r in rules) {
    final DateTime s = switch (r.periodType) {
      CriticalRulePeriodType.days => day.subtract(Duration(days: (r.periodDays ?? 30) + 1)),
      CriticalRulePeriodType.season =>
        seasonStart == null
            ? allTime
            : DateTime(seasonStart.year, seasonStart.month, seasonStart.day).subtract(const Duration(days: 1)),
      CriticalRulePeriodType.allTime => allTime,
      null => r.periodDays != null && r.periodDays! > 0 ? day.subtract(Duration(days: r.periodDays! + 1)) : allTime,
    };
    if (s.isBefore(start)) start = s;
  }
  return start;
}

/// Season start of the group as the server reads it (null = none).
DateTime? rdSeasonStartOf(String? seasonStart) =>
    seasonStart == null || seasonStart.isEmpty ? null : DateTime.tryParse(seasonStart);
