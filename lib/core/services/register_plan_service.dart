import 'dart:convert';
import 'dart:math';

import '../../data/models/person/person.dart';

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

  /// JavaScript `Math.round` (halves round up, also for negatives).
  static int _jsRound(num value) => (value + 0.5).floor();
}
