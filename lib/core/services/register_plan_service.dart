import 'dart:convert';
import 'dart:math';

import '../../data/models/instrument/instrument.dart';
import '../../data/models/person/person.dart';
import '../../data/models/plan/plan.dart';
import '../utils/plan_utils.dart';

/// Register rehearsal plan (Ionic `planning.page.ts` `createPlan`).
class RegisterPlan {
  const RegisterPlan({required this.groups, required this.rows});

  /// Column heads after the minutes column.
  final List<String> groups;

  /// One row per slot: `[minutes, conductor of group 1, …]`.
  final List<List<String>> rows;
}

/// Pure logic of the Registerprobenplan, ported 1:1 from Ionic
/// `createPlan`, `getDefaultPlanGroups`, `loadPlanGroups` / `savePlanGroups`
/// and the conductor list of `showOptions`.
class RegisterPlanService {
  const RegisterPlanService();

  /// Local storage key of the edited groups (Ionic `registerplan-groups-<tid>`).
  static String groupsStorageKey(int tenantId) => 'registerplan-groups-$tenantId';

  /// Ionic `getDefaultPlanGroups`: the group category names, otherwise the
  /// type defaults (choir voices, else Streicher / Holzbläser / Sonstige).
  static List<String> defaultGroups({
    required List<String> categoryNames,
    required bool isChoir,
    required List<String> choirDefaults,
    required List<String> otherDefaults,
  }) {
    if (categoryNames.isNotEmpty) return [...categoryNames];
    return [...(isChoir ? choirDefaults : otherDefaults)];
  }

  /// Beta: the group categories that only hold the main group (the
  /// conductors). They lead a Registerprobe, they are no group of it.
  static Set<int> conductorCategoryIds(List<Group> groups) {
    final byCategory = <int, List<Group>>{};
    for (final g in groups) {
      final c = g.categoryId;
      if (c != null) byCategory.putIfAbsent(c, () => []).add(g);
    }
    return {
      for (final e in byCategory.entries)
        if (e.value.every((g) => g.maingroup == true)) e.key,
    };
  }

  /// Ionic `loadPlanGroups`: the stored list when it is a JSON array with at
  /// least two entries, otherwise [defaults].
  static List<String> parseStoredGroups(String? stored, List<String> defaults) {
    if (stored != null && stored.isNotEmpty) {
      try {
        final parsed = jsonDecode(stored);
        if (parsed is List && parsed.length >= 2) {
          return parsed.map((e) => e?.toString() ?? '').toList();
        }
      } catch (_) {}
    }
    return [...defaults];
  }

  /// Beta: local storage key of the own groups ("+ Eigene Gruppe"), kept
  /// even when not picked.
  static String ownGroupsStorageKey(int tenantId) => 'registerplan-own-groups-$tenantId';

  /// The stored own groups (a JSON array of names), empty when unreadable.
  static List<String> parseOwnGroups(String? stored) {
    if (stored == null || stored.isEmpty) return const [];
    try {
      final parsed = jsonDecode(stored);
      if (parsed is List) {
        return [for (final e in parsed) if (e is String && e.trim().isNotEmpty) e];
      }
    } catch (_) {}
    return const [];
  }

  /// Ionic `savePlanGroups` payload.
  static String encodeGroups(List<String> groups) => jsonEncode(groups);

  /// Ionic: `${c.firstName} ${c.lastName.substr(0, 1)}.` of every conductor not left.
  static List<String> conductorNames(List<Person> conductors) => [
        for (final c in conductors)
          if (c.left == null) '${c.firstName} ${c.lastName.isEmpty ? '' : c.lastName.substring(0, 1)}.',
      ];

  /// Ionic `isPlanExportDisabled`.
  static bool isExportDisabled({
    required List<String> conductors,
    required List<String> groups,
    required String time,
  }) =>
      conductors.isEmpty ||
      conductors.any((c) => c.trim().isEmpty) ||
      time.isEmpty ||
      groups.length < 2 ||
      groups.any((g) => g.trim().isEmpty);

  /// Fisher-Yates shuffle (Ionic `shuffle`).
  static List<T> shuffle<T>(List<T> items, [Random? random]) {
    final rnd = random ?? Random();
    final result = List<T>.of(items);
    for (var i = result.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }
    return result;
  }

  /// Ionic `createPlan` matrix: `max(conductors, groups)` rows, the first
  /// column holds the relative minute `round(total / rows * i)`, group `g` in
  /// row `i` gets conductor `(i + g) % rows` (empty when there is none).
  ///
  /// [conductors] are used in the given order; shuffle them first.
  static RegisterPlan generate({
    required List<String> conductors,
    required List<String> groups,
    required num totalMinutes,
  }) {
    final groupCount = groups.length;
    final numRows = max(conductors.length, groupCount);
    final timePerUnit = numRows == 0 ? 0 : totalMinutes / numRows;
    final rows = <List<String>>[];
    for (var index = 0; index < numRows; index++) {
      final slotTime = _jsRound(timePerUnit * index);
      final row = <String>['$slotTime'];
      for (var g = 0; g < groupCount; g++) {
        final candidate = (index + g) % numRows;
        row.add(candidate < conductors.length ? conductors[candidate] : '');
      }
      rows.add(row);
    }
    return RegisterPlan(groups: [...groups], rows: rows);
  }

  /// Minutes of each round of [plan] (the gaps between the start minutes,
  /// the last one up to [totalMinutes]).
  static List<int> roundMinutes(RegisterPlan plan, num totalMinutes) {
    final starts = [for (final r in plan.rows) int.tryParse(r.first) ?? 0];
    final total = _jsRound(totalMinutes);
    return [for (var i = 0; i < starts.length; i++) (i + 1 < starts.length ? starts[i + 1] : total) - starts[i]];
  }

  /// "Streicher: Anna M. · Holzbläser: Ben K." for round [row] ([empty]
  /// for a group without conductor).
  static String roundInfo(RegisterPlan plan, int row, {String empty = '–'}) => [
        for (var g = 0; g < plan.groups.length; g++)
          '${plan.groups[g]}: ${plan.rows[row][g + 1].trim().isEmpty ? empty : plan.rows[row][g + 1]}',
      ].join(' · ');

  /// The Ablauf rows of a Registerprobe (Beta): a block [name] that keeps
  /// the groups and the drawn order of the [conductors], and one
  /// Unterpunkt per round ("[roundName] n", its minutes, the distribution
  /// as info). [conductors] are used in the given order (shuffle first).
  static List<PlanField> blockFields({
    required String name,
    required String Function(int round) roundName,
    required List<String> groups,
    required List<String> conductors,
    required num totalMinutes,
    String empty = '–',
  }) {
    final plan = generate(conductors: conductors, groups: groups, totalMinutes: totalMinutes);
    final minutes = roundMinutes(plan, totalMinutes);
    final head = PlanUtils.newGroupHead(name)
        .copyWith(registerPlan: RegisterPlanSettings(groups: [...groups], conductors: [...conductors]));
    return [
      head,
      for (var i = 0; i < plan.rows.length; i++)
        PlanField(
          id: 'fld-${PlanUtils.uuid()}',
          name: roundName(i + 1),
          time: '${minutes[i]}',
          info: roundInfo(plan, i, empty: empty),
          groupId: head.id,
        ),
    ];
  }

  /// The table of a Registerprobe block as it is now: one row per
  /// Unterpunkt in its order ([rounds]: its start, clock time or minutes,
  /// and its info), the conductors read from the "Gruppe: Dirigent" info
  /// (empty when a group is not named there or has none).
  static RegisterPlan tableOf(List<String> groups, List<({String start, String? info})> rounds) {
    Map<String, String> parse(String? info) {
      final out = <String, String>{};
      for (final part in (info ?? '').split(' · ')) {
        final at = part.indexOf(': ');
        if (at <= 0) continue;
        final who = part.substring(at + 2).trim();
        out[part.substring(0, at).trim()] = who == '–' ? '' : who;
      }
      return out;
    }

    return RegisterPlan(
      groups: [...groups],
      rows: [
        for (final r in rounds)
          [r.start, for (final g in groups) parse(r.info)[g.trim()] ?? ''],
      ],
    );
  }

  /// JavaScript `Math.round` (halves round up, also for negatives).
  static int _jsRound(num value) => (value + 0.5).floor();
}
