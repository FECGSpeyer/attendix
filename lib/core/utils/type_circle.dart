/// Circle of an attendance type: its groups (`relevant_groups`) plus single
/// persons (`relevant_persons`). Both empty means everyone; otherwise a
/// person belongs to it through the group or by being named.
bool typeCircleIsEveryone(List<int>? groups, List<int>? persons) =>
    (groups == null || groups.isEmpty) && (persons == null || persons.isEmpty);

bool typeCircleCovers(List<int>? groups, List<int>? persons, {int? groupId, int? personId}) {
  if (typeCircleIsEveryone(groups, persons)) return true;
  if (groupId != null && (groups?.contains(groupId) ?? false)) return true;
  return personId != null && (persons?.contains(personId) ?? false);
}

/// `relevant_persons` from JSON (bigint[]; missing = none).
List<int> typeCirclePersonsFromJson(dynamic v) =>
    v is List ? [for (final e in v) if (e is num) e.toInt()] : const [];
