import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/extra_field_utils.dart' show ExtraFieldType;
import '../../../../../core/providers/church_providers.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/organisation_providers.dart';
import '../../../../../core/providers/profile_providers.dart';
import '../../../../../core/providers/statistics_providers.dart' show fieldStatsPersonsProvider;
import '../../../../../core/providers/tenant_providers.dart' show currentTenantIdProvider;
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/field_stats.dart';
import '../../../../../core/utils/person_matcher.dart' show personIdentityKey;
import '../../../../../data/models/church/church.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/organisation/organisation.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../l10n/l10n.dart';
import '../../../data/providers/rd_stats_providers.dart' show rdStatsPeopleOf;
import '../../../data/rd_stats_logic.dart';
import '../../../data/rd_words.dart';
import '../rd_widgets.dart';
import 'rd_stats_widgets.dart' show rdPercent;

// REDESIGN: "Zusatzfelder" and the organisation of the Auswertung (Ionic
// stats, canvas "Auswertung neu gedacht" Paket 2) in the Beta design.

/// "Zusatzfelder": how the select, yes/no and church fields split up
/// (Ionic `initFieldStats`), for the Register chosen in the filter (one
/// Register, else all), optionally with the paused people. With all
/// Register also one bar per Register. Nothing without such a field.
class RdStatsFieldsCard extends ConsumerStatefulWidget {
  const RdStatsFieldsCard({super.key, required this.filter});

  final RdStatsFilter filter;

  @override
  ConsumerState<RdStatsFieldsCard> createState() => _RdStatsFieldsCardState();
}

class _RdStatsFieldsCardState extends ConsumerState<RdStatsFieldsCard> {
  String? _fieldId;
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final fields = distributionFields(ref.watch(personListExtraFieldsProvider));
    if (fields.isEmpty) return const SizedBox.shrink();
    final p = context.rd;
    final l10n = context.l10n;
    final field = fields.firstWhere((f) => f.id == _fieldId, orElse: () => fields.first);
    final personsAsync = ref.watch(fieldStatsPersonsProvider);
    final groups = rdStatsGroups(ref.watch(groupsProvider).valueOrNull ?? const <Group>[]);
    final churchesAsync = fields.any((f) => f.type == ExtraFieldType.bfecgChurch) ? ref.watch(churchesProvider) : null;
    final waiting = !personsAsync.hasValue ||
        (field.type == ExtraFieldType.bfecgChurch && churchesAsync != null && !churchesAsync.hasValue && !churchesAsync.hasError);
    // The Register of the filter: only their people (one bar each).
    final chosen = widget.filter.groupIds;
    final stats = computeFieldStats(
      field: field,
      persons: [
        for (final person in rdStatsPeopleOf(personsAsync, ref.watch(currentTenantIdProvider)))
          if (chosen.isEmpty || chosen.contains(person.instrument)) person,
      ],
      groups: groups,
      labels: FieldStatsLabels(yes: l10n.commonYes, no: l10n.commonNo, noValue: l10n.statsFieldNoValue),
      includePaused: _paused,
      churches: churchesAsync?.valueOrNull ?? const <Church>[],
    );
    final shown = stats.shownRows;
    final bars = stats.groupBars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(l10n.rdStatsFields),
        RdCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fields.length > 1) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in fields)
                      RdChoiceChip(label: f.name, selected: f.id == field.id, onTap: () => setState(() => _fieldId = f.id)),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(field.name, style: RdType.section(p)),
                const SizedBox(height: 10),
              ],
              if (waiting)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator.adaptive()))
              else if (stats.total == 0)
                Text(l10n.statsFieldNoPersons, style: RdType.meta(p, size: 14))
              else ...[
                RdStatusBar(
                  segments: [for (final r in shown) RdBarSegment(r.count, r.color)],
                  total: stats.total,
                  semanticLabel: [for (final r in shown) '${r.label} ${rdPercent(r.perc)}'].join(', '),
                ),
                const SizedBox(height: 6),
                for (final r in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: r.color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.label, style: RdType.body(p))),
                        Text('${r.count}', style: RdType.body(p).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                        SizedBox(
                          width: 56,
                          child: Text(rdPercent(r.perc), textAlign: TextAlign.end, style: RdType.meta(p, size: 14)),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.rdStatsMembersTotal, style: RdType.body(p).copyWith(fontWeight: FontWeight.w600))),
                      Text('${stats.total}', style: RdType.body(p).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
                if (bars.length > 1) ...[
                  const SizedBox(height: 14),
                  Text(l10n.redesignStatsPerGroup(ref.watch(rdGroupKindProvider)), style: RdType.section(p)),
                  const SizedBox(height: 8),
                  for (final b in bars)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(b.name, style: RdType.body(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RdStatusBar(
                              segments: [for (final r in shown) RdBarSegment(b.percByLabel[r.label] ?? 0, r.color)],
                              total: 100,
                              semanticLabel: [
                                b.name,
                                for (final r in shown)
                                  if ((b.percByLabel[r.label] ?? 0) > 0) '${r.label} ${rdPercent(b.percByLabel[r.label]!)}',
                              ].join(', '),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        RdGroupedList(
          children: [
            RdSwitchRow(title: l10n.rdStatsFieldsPaused, value: _paused, onChanged: (v) => setState(() => _paused = v)),
          ],
        ),
      ],
    );
  }
}

/// The organisation of the group (Ionic stats "🏢"): which of its groups
/// count and how many different people they have together (the same
/// person in several groups once).
class RdStatsOrganisationCard extends ConsumerStatefulWidget {
  const RdStatsOrganisationCard({super.key});

  @override
  ConsumerState<RdStatsOrganisationCard> createState() => _RdStatsOrganisationCardState();
}

class _RdStatsOrganisationCardState extends ConsumerState<RdStatsOrganisationCard> {
  /// Empty: all groups of the organisation.
  Set<int> _chosen = {};

  /// [async]'s value, but not while it reloads (other group or account) or
  /// after a failed load: Riverpod keeps the old value then.
  static T? _current<T>(AsyncValue<T> async) => async.isReloading || async.hasError ? null : async.valueOrNull;

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(currentTenantIdProvider);
    final org = _current(ref.watch(currentOrganisationProvider));
    if (tenantId == null || org?.id == null) return const SizedBox.shrink();
    final tenants = _current(ref.watch(organisationTenantsProvider(org!.id!)));
    // Keyed by the group: only an organisation the current group is part of.
    if (tenants == null || !tenants.any((t) => t.id == tenantId)) return const SizedBox.shrink();
    return _content(context, org, tenants);
  }

  Widget _content(BuildContext context, Organisation org, List<Tenant> tenants) {
    final l10n = context.l10n;
    final personsAsync = ref.watch(organisationPersonsProvider(tenants));
    final persons = _current(personsAsync);
    // A choice from another organisation does not count.
    final chosen = {for (final t in tenants) if (t.id != null && _chosen.contains(t.id)) t.id!};
    final people = rdStatsOrgPeople(
      [
        for (final person in persons ?? const <Person>[])
          if (chosen.isEmpty || chosen.contains(person.tenantId)) person,
      ],
      {for (final t in tenants) if (t.id != null) t.id!: t.longName},
    );
    final chosenNames = [for (final t in tenants) if (chosen.contains(t.id)) t.longName];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(org.name),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.rdStatsOrgGroups,
              value: chosenNames.isEmpty ? l10n.rdStatsOrgGroupsAll(tenants.length) : chosenNames.join(', '),
              onTap: () => _pickGroups(tenants),
            ),
            RdListRow(
              title: l10n.rdStatsOrgPeople,
              value: persons != null ? '${people.length}' : '…',
              onTap: persons != null ? () => _showPeople(people) : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickGroups(List<Tenant> tenants) => showRdSheet<void>(
        context,
        StatefulBuilder(
          builder: (context, setSheet) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              RdSheetTitle(context.l10n.rdStatsOrgGroups),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RdGroupedList(
                  children: [
                    for (final t in tenants)
                      if (t.id != null)
                        RdListRow(
                          title: t.longName,
                          showChevron: false,
                          selected: _chosen.contains(t.id),
                          trailing: RdSheetCheck(_chosen.contains(t.id)),
                          onTap: () {
                            final next = {..._chosen};
                            next.contains(t.id) ? next.remove(t.id) : next.add(t.id!);
                            // All chosen = no choice.
                            setState(() => _chosen = next.length == tenants.length ? {} : next);
                            setSheet(() {});
                          },
                        ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(context.l10n.rdStatsOrgGroupsHint, style: RdType.meta(context.rd, size: 13)),
              ),
            ],
          ),
        ),
      );

  Future<void> _showPeople(List<RdStatsOrgPerson> people) => showRdSheet<void>(
        context,
        Builder(
          builder: (context) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Semantics(
                header: true,
                child: Text(context.l10n.commonPersons(people.length), style: RdType.cardTitle(context.rd)),
              ),
              const SizedBox(height: 12),
              if (people.isNotEmpty)
                RdGroupedList(
                  children: [
                    for (final person in people)
                      RdListRow(
                        title: rdPersonName(person.person),
                        subtitle: person.groups.join(', '),
                        showChevron: false,
                        trailing: RdPill('${person.groups.length}'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
}

/// One person of the organisation with the groups they are in.
class RdStatsOrgPerson {
  RdStatsOrgPerson(this.person, this.groups);

  final Person person;
  final Set<String> groups;
}

/// The people of the organisation's groups, the same person once (Ionic
/// `getOrganizationStats`: global person, app account, else name and
/// birthday); most groups first, then by last name.
List<RdStatsOrgPerson> rdStatsOrgPeople(List<Person> people, Map<int, String> groupName) {
  final byKey = <String, RdStatsOrgPerson>{};
  for (final person in people) {
    final key = personIdentityKey(
      globalPersonId: person.globalPersonId,
      appId: person.appId,
      firstName: person.firstName,
      lastName: person.lastName,
      birthday: person.birthday,
    );
    final name = groupName[person.tenantId] ?? '';
    byKey.putIfAbsent(key, () => RdStatsOrgPerson(person, {})).groups.add(name);
  }
  return byKey.values.toList()
    ..sort((a, b) => a.groups.length != b.groups.length
        ? b.groups.length.compareTo(a.groups.length)
        : a.person.lastName.compareTo(b.person.lastName));
}
