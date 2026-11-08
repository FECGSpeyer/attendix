import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../rd_critical_logic.dart';

/// REDESIGN: recorded statuses of the group's Termine after [since] up to
/// now, by person – what the Problemfall rules count (preview in the rule
/// editor, reasons on Mitglieder and the person). Leads only: the rows come
/// from `person_attendances` of the current group (tenant filter in the
/// repository). [since] is a whole day from [rdCriticalLoadStart], so the
/// pages share one load.
final rdCriticalEntriesProvider = FutureProvider.autoDispose.family<Map<int, List<RdCriticalEntry>>, DateTime>((
  ref,
  since,
) async {
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const {};
  final now = DateTime.now();
  final attendances = await repo.getAttendances(since: since);
  final byId = <int, ({DateTime date, String? typeId})>{};
  for (final a in attendances) {
    final id = a.id;
    final date = DateTime.tryParse(a.date);
    if (id == null || date == null || date.isAfter(now)) continue;
    byId[id] = (date: date, typeId: a.typeId);
  }
  if (byId.isEmpty) return const {};
  final rows = await repo.getPersonAttendancesForAttendances(byId.keys.toList());
  final result = <int, List<RdCriticalEntry>>{};
  for (final r in rows) {
    final personId = r.personId;
    final att = byId[r.attendanceId];
    if (personId == null || att == null) continue;
    (result[personId] ??= []).add(
      RdCriticalEntry(personId: personId, status: r.status.value, date: att.date, typeId: att.typeId),
    );
  }
  return result;
});

/// Why a person is a Problemfall: the first rule that hits, with its count.
class RdCriticalReason {
  const RdCriticalReason(this.rule, this.result);

  final CriticalRule rule;
  final RdRuleResult result;
}

/// The reason of every person the server marked as Problemfall (by id).
/// A person missing here is still a Problemfall (the server decides), e.g.
/// right after the rules changed; the pages then show no reason.
final rdCriticalReasonsProvider = FutureProvider.autoDispose<Map<int, RdCriticalReason>>((ref) async {
  final tenant = ref.watch(currentTenantProvider);
  final rules = tenant?.criticalRules ?? const <CriticalRule>[];
  if (rules.isEmpty) return const {};
  final season = rdSeasonStartOf(tenant?.seasonStart);
  final start = rdCriticalLoadStart(rules, seasonStart: season, today: DateTime.now());
  final persons = await ref.watch(criticalPlayersProvider.future);
  if (persons.isEmpty) return const {};
  final entries = await ref.watch(rdCriticalEntriesProvider(start).future);
  final now = DateTime.now();
  return {
    for (final x in persons)
      if (x.id != null)
        if (_reasonOf(x, rules, entries[x.id] ?? const [], season, now) case final reason?) x.id!: reason,
  };
});

RdCriticalReason? _reasonOf(
  Person person,
  List<CriticalRule> rules,
  List<RdCriticalEntry> entries,
  DateTime? season,
  DateTime now,
) {
  final hits = rdCriticalHits(
    rules,
    entries,
    lastSolve: person.lastSolve == null ? null : DateTime.tryParse(person.lastSolve!),
    seasonStart: season,
    now: now,
  );
  if (hits.isEmpty) return null;
  return RdCriticalReason(hits.first.$1, hits.first.$2);
}
