import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';

import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../rd_critical_logic.dart';

/// Which group and from which day the Problemfall data is loaded. The
/// group is part of the key, so a group switch never shows the previous
/// group's people while the new data loads.
typedef RdCriticalKey = ({int tenantId, DateTime since});

/// The key for [rules] of [tenant] (null without a group).
RdCriticalKey? rdCriticalKeyFor(Tenant? tenant, Iterable<CriticalRule> rules) {
  final id = tenant?.id;
  if (id == null) return null;
  return (
    tenantId: id,
    since: rdCriticalLoadStart(rules, seasonStart: rdSeasonStartOf(tenant?.seasonStart), today: DateTime.now()),
  );
}

/// REDESIGN: recorded statuses of the group's Termine after `since` up to
/// now, by person – what the Problemfall rules count (preview in the rule
/// editor, hit counts, reasons on Mitglieder and the person). Leads only:
/// the rows come from `person_attendances` of the current group (tenant
/// filter in the repository). Reloads when a Termin's attendance changes.
final rdCriticalEntriesProvider = FutureProvider.autoDispose.family<Map<int, List<RdCriticalEntry>>, RdCriticalKey>((
  ref,
  key,
) async {
  // Changes on other devices bump the counter via the subscription, also
  // when the Termine list is not open.
  ref.watch(attendanceRealtimeSubscriptionProvider);
  ref.watch(attendanceRefetchCounter);
  ref.watch(rdPersonAttendanceAddRemoveSubscriptionProvider);
  final repo = ref.watch(attendanceRepositoryWithTenantProvider);
  if (!repo.hasTenantId || repo.currentTenantId != key.tenantId) return const {};
  final now = DateTime.now();
  final attendances = await repo.getAttendances(since: key.since);
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

/// Supabase realtime for INSERT and DELETE on `person_attendances`: people
/// added to or removed from a Termin on any device (the shared subscription
/// only sees status updates). The table has no tenant column, so events are
/// not filtered; a spurious event only reloads the tenant-filtered query
/// above. Debounced: a new Termin inserts one row per person at once.
final AutoDisposeProvider<void> rdPersonAttendanceAddRemoveSubscriptionProvider = Provider.autoDispose<void>((ref) {
  final tenantId = ref.watch(currentTenantProvider)?.id;
  if (tenantId == null) return;
  final supabase = ref.watch(supabaseClientProvider);
  Timer? debounce;
  void onChanged(PostgresChangePayload _) {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 2), () {
      ref.invalidate(rdCriticalEntriesProvider);
    });
  }

  final channel = supabase
      .channel('rd_critical_person_attendances_$tenantId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'person_attendances',
        callback: onChanged,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'person_attendances',
        callback: onChanged,
      )
      .subscribe();
  ref.onDispose(() {
    debounce?.cancel();
    channel.unsubscribe();
  });
});

/// Why a person is a Problemfall: the first rule that hits, with its count.
class RdCriticalReason {
  const RdCriticalReason(this.rule, this.result);

  final CriticalRule rule;
  final RdRuleResult result;
}

/// The group's rules with the loaded statuses; the pages ask it about the
/// person they show (their own, live copy of the person).
class RdCriticalContext {
  RdCriticalContext({
    required this.tenantId,
    required this.rules,
    required this.entries,
    this.seasonStart,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  /// The group this was computed for.
  final int tenantId;
  final List<CriticalRule> rules;
  final Map<int, List<RdCriticalEntry>> entries;
  final DateTime? seasonStart;
  final DateTime now;

  DateTime? _lastSolve(Person person) => person.lastSolve == null ? null : DateTime.tryParse(person.lastSolve!);

  /// [rule] on its own for [person].
  RdRuleResult resultOf(CriticalRule rule, Person person) => rdEvaluateCriticalRule(
    rule,
    entries[person.id] ?? const [],
    lastSolve: _lastSolve(person),
    seasonStart: seasonStart,
    now: now,
  );

  /// Every rule that makes [person] a Problemfall, in the rules' order
  /// (the "nur zusammen" parts all at once); empty when none hits.
  List<RdCriticalReason> hitsOf(Person person) => [
    for (final (rule, result) in rdCriticalHits(
      rules,
      entries[person.id] ?? const [],
      lastSolve: _lastSolve(person),
      seasonStart: seasonStart,
      now: now,
    ))
      RdCriticalReason(rule, result),
  ];

  /// Why [person] is a Problemfall by all rules; null when no rule hits
  /// (e.g. right after the rules changed, before the server checked again).
  RdCriticalReason? reasonOf(Person person) {
    final hits = hitsOf(person);
    return hits.isEmpty ? null : hits.first;
  }
}

/// [RdCriticalContext] for the current group's rules; null without rules.
final rdCriticalContextProvider = FutureProvider.autoDispose<RdCriticalContext?>((ref) async {
  final tenant = ref.watch(currentTenantProvider);
  final rules = tenant?.criticalRules ?? const <CriticalRule>[];
  final key = rdCriticalKeyFor(tenant, rules);
  if (rules.isEmpty || key == null) return null;
  final entries = await ref.watch(rdCriticalEntriesProvider(key).future);
  return RdCriticalContext(
    tenantId: key.tenantId,
    rules: rules,
    entries: entries,
    seasonStart: rdSeasonStartOf(tenant?.seasonStart),
  );
});

/// The loaded [RdCriticalContext] of the current group: keeps the last
/// value while statuses reload, but never shows another group's.
RdCriticalContext? rdCriticalContextOf(WidgetRef ref) {
  final ctx = ref.watch(rdCriticalContextProvider).valueOrNull;
  final tenantId = ref.watch(currentTenantProvider)?.id;
  return ctx != null && ctx.tenantId == tenantId ? ctx : null;
}
