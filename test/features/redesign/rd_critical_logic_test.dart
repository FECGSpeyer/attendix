import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/redesign/data/rd_critical_logic.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// REDESIGN: Problemfall rules as sentences and the port of the server's
/// `evaluate-critical-rules` (canvas "Problemfälle neu gedacht", B).
void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final now = DateTime(2026, 11, 8, 12);

  RdCriticalEntry e(int status, int daysAgo, {String type = 't1'}) =>
      RdCriticalEntry(personId: 1, status: status, date: now.subtract(Duration(days: daysAgo)), typeId: type);

  CriticalRule rule({
    List<int> statuses = const [4],
    CriticalRuleThresholdType type = CriticalRuleThresholdType.count,
    num value = 3,
    CriticalRulePeriodType period = CriticalRulePeriodType.days,
    int? days = 30,
    CriticalRuleOperator op = CriticalRuleOperator.or,
    List<String> types = const [],
  }) => CriticalRule(
    id: 'r',
    attendanceTypeIds: types,
    statuses: statuses,
    thresholdType: type,
    thresholdValue: value,
    periodType: period,
    periodDays: days,
    operator: op,
  );

  test('rules read as plain sentences', () {
    expect(rdCriticalSummary(rule(), const [], de), 'Mindestens 3-mal unentschuldigt gefehlt in den letzten 30 Tagen');
    expect(
      rdCriticalSummary(
        rule(statuses: [4, 2], type: CriticalRuleThresholdType.percentage, value: 33.5, period: CriticalRulePeriodType.season),
        const [],
        de,
      ),
      'Bei mindestens 33,5 % der Termine gefehlt (auch entschuldigt) seit Saisonbeginn',
    );
    // An odd Ionic rule stays visible as what it is.
    expect(rdCriticalSummary(rule(statuses: [1, 4]), const [], de), 'Mindestens 3-mal Status Anwesend oder Abwesend in den letzten 30 Tagen');
    expect(rdCriticalWhatOf([5, 3]), RdCriticalWhat.late);
    expect(rdCriticalPresetOf(rdCriticalPresetRule(RdCriticalPreset.rarelyThere, id: 'x')), RdCriticalPreset.rarelyThere);
  });

  test('counts like the server: period, types, future and "Gespräch geführt"', () {
    final entries = [e(4, 2), e(4, 10), e(4, 20), e(4, 40), e(4, -3), e(4, 5, type: 't2'), e(1, 1)];
    expect(rdEvaluateCriticalRule(rule(types: ['t1']), entries, now: now).matching, 3);
    expect(rdEvaluateCriticalRule(rule(types: ['t1']), entries, now: now).matches, isTrue);
    // After the talk 12 days ago only the newer absences count.
    final solved = rdEvaluateCriticalRule(rule(types: ['t1']), entries, lastSolve: now.subtract(const Duration(days: 12)), now: now);
    expect((solved.matching, solved.matches), (2, false));
  });

  test('percentage of all Termine in the period, never with none', () {
    final r = rule(type: CriticalRuleThresholdType.percentage, value: 50);
    expect(rdEvaluateCriticalRule(r, [e(4, 1), e(1, 2), e(4, 3), e(1, 4)], now: now).matches, isTrue);
    expect(rdEvaluateCriticalRule(r, [e(4, 1), e(1, 2), e(1, 3)], now: now).matches, isFalse);
    expect(rdEvaluateCriticalRule(r, const [], now: now).matches, isFalse);
  });

  test('one "eine reicht" rule is enough, "nur zusammen" rules need each other', () {
    final entries = [e(4, 1), e(4, 2), e(4, 3), e(3, 4)];
    final late = rule(statuses: [3], value: 1, op: CriticalRuleOperator.and);
    final absentAnd = rule(op: CriticalRuleOperator.and);
    expect(rdCriticalHits([late, absentAnd], entries, now: now).length, 2);
    expect(rdCriticalHits([late, rule(value: 9, op: CriticalRuleOperator.and)], entries, now: now), isEmpty);
    expect(rdCriticalHits([rule(), late], entries, now: now).single.$1.operator, CriticalRuleOperator.or);
  });

  test('"und" parts are one rule in the list and are replaced together', () {
    CriticalRule r(String id, CriticalRuleOperator op) => rule(op: op).copyWith(id: id);
    final rules = [
      r('a', CriticalRuleOperator.or),
      r('x', CriticalRuleOperator.and),
      r('b', CriticalRuleOperator.or),
      r('y', CriticalRuleOperator.and),
    ];
    final groups = rdCriticalRuleGroups(rules);
    expect([for (final g in groups) g.map((x) => x.id).join()], ['a', 'xy', 'b']);

    // Editing the "und" rule down to one condition: an "eine reicht" rule
    // at the place of the first part.
    final one = rdCriticalReplaceGroup(rules, groups[1], [r('x', CriticalRuleOperator.and)]);
    expect([for (final x in one) '${x.id}${x.operator.name}'], ['aor', 'xor', 'bor']);

    // A rule gets a second condition: both parts are "nur zusammen".
    final two = rdCriticalReplaceGroup(one, [one.first], [one.first, r('z', CriticalRuleOperator.or)]);
    expect([for (final x in two) '${x.id}${x.operator.name}'], ['aand', 'zand', 'xor', 'bor']);
  });
}
